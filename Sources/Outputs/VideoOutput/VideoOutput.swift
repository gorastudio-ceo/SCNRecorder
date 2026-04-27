//
//  VideoOutput.swift
//  SCNRecorder
//
//  Created by Vladislav Grigoryev on 11/03/2019.
//  Copyright © 2020 GORA Studio. https://gora.studio
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import AVFoundation

final class VideoOutput {

  var assetWriter: AVAssetWriter!

  var videoInput: AVAssetWriterInput!

  var audioInput: AVAssetWriterInput?

  var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!

  let queue: DispatchQueue

  var state: State {
    didSet {
      videoRecording?.state = state
      if state.isFinal { onFinalState(self) }
    }
  }

  var duration: TimeInterval = 0.0 {
    didSet { videoRecording?.duration = duration }
  }

  var lastSeconds: TimeInterval = 0.0

  var onFinalState: (VideoOutput) -> Void = { _ in }

  weak var videoRecording: VideoRecording?

  init(
    url: URL,
    videoSettings: VideoSettings,
    audioSettings: [String: Any]?,
    queue: DispatchQueue
  ) throws {
    self.queue = queue
    self.state = .starting

    queue.async { [weak self] in
      guard let self = self else { return }

      do {
        self.assetWriter = try AVAssetWriter(url: url, fileType: videoSettings.fileType.avFileType)

        try self.addVideoInput(videoSettings)
        try self.addAudioInput(audioSettings)

        guard self.assetWriter.startWriting() else {
          throw self.assetWriter.error ?? Error.cantStartWriting
        }

        self.state = .ready
      }
      catch {
        self.state = .failed(error: error)
      }
    }
  }

  deinit { state = state.cancel(self) }

  func addVideoInput(_ videoSettings: VideoSettings) throws {
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings.outputSettings)
    videoInput.expectsMediaDataInRealTime = true
    videoInput.transform = videoSettings.transform ?? .identity
    if let metadata = videoSettings.metadata {
      videoInput.metadata = metadata
    }
    guard assetWriter.canAdd(videoInput) else { throw Error.cantAddVideoAssetWriterInput }
    assetWriter.add(videoInput)
    self.videoInput = videoInput

    let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput)
    self.pixelBufferAdaptor = pixelBufferAdaptor
  }

  func addAudioInput(_ audioSettings: [String: Any]?) throws {
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
    audioInput.expectsMediaDataInRealTime = true

    guard assetWriter.canAdd(audioInput) else {
      guard let audioSettings = audioSettings else { return }
      throw Error.cantAddAudioAssterWriterInput(audioSettings: audioSettings)
    }

    assetWriter.add(audioInput)
    self.audioInput = audioInput
  }

  func startVideoRecording() -> VideoRecording {
    let videoRecording = VideoRecording(videoOutput: self)
    videoRecording.state = state
    self.videoRecording = videoRecording
    return videoRecording
  }
}

extension VideoOutput {

  func startSession(at sourceTime: CMTime) {
    lastSeconds = sourceTime.seconds
    assetWriter.startSession(atSourceTime: sourceTime)
  }

  func endSession(at sourceTime: CMTime) {
    assetWriter.endSession(atSourceTime: sourceTime)
  }

  func finishWriting(completionHandler handler: @escaping () -> Void) {
    assetWriter.finishWriting(completionHandler: handler)
  }

  func cancelWriting() {
    assetWriter.cancelWriting()
  }

  func append(pixelBuffer: CVPixelBuffer, withPresentationTime time: CMTime) throws {
    guard pixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData else {
      return
    }
    guard pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time) else {
      if assetWriter.status == .failed { throw assetWriter.error ?? Error.unknown }
      return
    }

    let seconds = time.seconds
    duration += seconds - lastSeconds
    lastSeconds = seconds
  }

  func appendVideo(sampleBuffer: CMSampleBuffer) throws {
    guard videoInput.isReadyForMoreMediaData else {
      return
    }
    guard videoInput.append(sampleBuffer) else {
      if assetWriter.status == .failed { throw assetWriter.error ?? Error.unknown }
      return
    }

    let timeStamp: CMTime
    let duration: CMTime

    if #available(iOS 13.0, *) {
      timeStamp = sampleBuffer.presentationTimeStamp
      duration = sampleBuffer.duration
    } else {
      timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      duration = CMSampleBufferGetDuration(sampleBuffer)
    }

    self.duration += duration.seconds
    lastSeconds = (timeStamp + duration).seconds
  }

  func appendAudio(sampleBuffer: CMSampleBuffer) throws {
    guard
      let audioInput = audioInput,
      audioInput.isReadyForMoreMediaData
    else {
        return
    }
    guard audioInput.append(sampleBuffer) else {
      if assetWriter.status == .failed {
          throw assetWriter.error ?? Error.unknown
      }
      return
    }
  }
}

// - MARK: Getters
extension VideoOutput {

  var url: URL { assetWriter.outputURL }

  var fileType: AVFileType { assetWriter.outputFileType }
}

// - MARK: Lifecycle
extension VideoOutput {

  func resume() {
    queue.async { [weak self] in self?.unsafeResume() }
  }

  func pause() {
    queue.async { [weak self] in self?.unsafePause() }
  }

  func finish(completionHandler handler: @escaping () -> Void) {
    queue.async { [weak self] in
      self?.unsafeFinish(completionHandler: handler)
    }
  }

  func cancel() {
    queue.async { [weak self] in self?.unsafeCancel() }
  }
}

// - MARK: Unsafe Lifecycle
private extension VideoOutput {

  func unsafeResume() { state = state.resume(self) }

  func unsafePause() { state = state.pause(self) }

  func unsafeFinish(completionHandler handler: @escaping () -> Void) {
    state = state.finish(self, completionHandler: handler)
  }

  func unsafeCancel() { state = state.cancel(self) }
}

// - MARK: VideoOutput
extension VideoOutput: VideoMediaSessionOutput {

  func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    state = state.appendVideoSampleBuffer(sampleBuffer, to: self)
  }

  func appendVideoPixelBuffer(_ pixelBuffer: CVPixelBuffer, at time: CMTime) {
    state = state.appendVideoPixelBuffer(pixelBuffer, at: time, to: self)
  }
}

// - MARK: AudioOutput
extension VideoOutput: AudioMediaSessionOutput {

  func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    state = state.appendAudioSampleBuffer(sampleBuffer, to: self)
  }
}
