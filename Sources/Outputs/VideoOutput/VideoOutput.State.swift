//
//  VideoOutput.State.swift
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

extension VideoOutput {

  typealias State = VideoOutputState
}

/// Finite-State Machine
///
/// Associated values are ignored in equation.
public enum VideoOutputState: Equatable {

  public static func == (lhs: VideoOutputState, rhs: VideoOutputState) -> Bool {
    switch (lhs, rhs) {
    case (.starting, starting): return true
    case (.preparing, .preparing): return true
    case (.recording, .recording): return true
    case (.paused, .paused): return true
    case (.canceled, .canceled): return true
    case (.finished, .finished): return true
    case (.failed, .failed): return true
    default: return false
    }
  }

  /// AVAssetWriter is starting.
  case starting

  /// AVAssetWriter is started. Waiting for the resume.
  case ready

  /// Recording is started. Waiting for the first video frame to set up the session.
  /// So far audio frames are ignored
  case preparing

  /// Recording is active.
  /// Appending audio and video frames.
  case recording(time: CMTime, pause: CMTime?, resume: CMTime?)

  /// Recording is paused.
  case paused(time: CMTime, pause: CMTime)

  /// Recording is canceled.
  /// Final state, not further actions are possible.
  case canceled

  /// Recording is finished.
  /// Final state, not further actions are possible.
  case finished

  /// Recording is failed.
  /// AVAssetWriter was failed with an error.
  /// Final state, not further actions are possible.
  case failed(error: Swift.Error)

  var isFinal: Bool {
    switch self {
    case .starting,
         .ready,
         .preparing,
         .recording,
         .paused:
      return false

    case .canceled,
         .finished,
         .failed:
      return true
    }
  }

  func resume(_ videoOutput: VideoOutput) -> Self {
    switch self {

    case .starting:
      return self

    case .ready,
         .preparing:
      return .preparing

    case let .recording(time, pause, resume):
      return .recording(time: time, pause: pause, resume: resume)

    case let .paused(time, pause):
        let resume = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: pause.timescale)
        return .recording(time: time, pause: pause, resume: resume)

    case .canceled,
         .finished,
         .failed:
      return self
    }
  }

  func pause(_ videoOutput: VideoOutput) -> Self {
    switch  self {

    case .starting:
      return .starting

    case .ready,
         .preparing:
      return .ready

    case let .recording(lastTime, pause, resume):
      let current = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: lastTime.timescale)
      if let pause, let resume {
        let adjustedPause = adjustTime(current: current, resume: resume, pause: pause)
        return .paused(time: lastTime, pause: adjustedPause)
      } else {
        return .paused(time: lastTime, pause: current)
      }

    case .paused,
         .canceled,
         .finished,
         .failed:
      return self
    }
  }

  func finish(_ videoOutput: VideoOutput, completionHandler handler: @escaping () -> Void) -> Self {
    switch self {

    case .starting,
         .ready,
         .preparing:
      handler()
      return .canceled

    case let .recording (currentTime, _, _), let .paused(currentTime, _):
      videoOutput.endSession(at: currentTime)
      videoOutput.finishWriting(completionHandler: handler)
      return .finished

    case .canceled,
         .finished,
         .failed:
      handler()
      return self
    }
  }

  func cancel(_ videoOutput: VideoOutput) -> Self {
    switch  self {

    case .starting,
         .ready,
         .preparing:
      return .canceled

    case .recording,
         .paused:
      videoOutput.cancelWriting()
      return .canceled

    case .canceled,
         .finished,
         .failed:
      return self
    }
  }

  func appendVideoSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    to videoOutput: VideoOutput
  ) -> Self {
    do { return try _appendVideoSampleBuffer(sampleBuffer, to: videoOutput) }
    catch { return .failed(error: error) }
  }

  func appendVideoPixelBuffer(
    _ pixelBuffer: CVPixelBuffer,
    at time: CMTime,
    to videoOutput: VideoOutput
  ) -> Self {
    do { return try _appendVideoPixelBuffer(pixelBuffer, at: time, to: videoOutput) }
    catch { return .failed(error: error) }
  }

  func appendAudioSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    to videoOutput: VideoOutput
  ) -> Self {
    do { return try _appendAudioSampleBuffer(sampleBuffer, to: videoOutput) }
    catch { return .failed(error: error) }
  }
}

private extension VideoOutputState {

  func _appendVideoSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    to videoOutput: VideoOutput
  ) throws -> Self {
    switch self {

    case .starting,
         .ready:
      return self

    case .preparing:
      let time: CMTime
      if #available(iOS 13.0, *) {
        time = sampleBuffer.presentationTimeStamp
      } else {
        time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      }
      videoOutput.startSession(at: time)
      try videoOutput.appendVideo(sampleBuffer: sampleBuffer)
      return .recording(time: time, pause: nil, resume: nil)

    case let .recording(time, pause, resume):
      try videoOutput.appendVideo(sampleBuffer: sampleBuffer)
      return .recording(time: time, pause: pause, resume: resume)

    case .paused,
         .canceled,
         .finished,
         .failed:
      return self
    }
  }

  func _appendVideoPixelBuffer(
    _ pixelBuffer: CVPixelBuffer,
    at time: CMTime,
    to videoOutput: VideoOutput
  ) throws -> Self {
    switch self {

    case .starting,
         .ready:
      return self

    case .preparing:
      videoOutput.startSession(at: time)
      try videoOutput.append(pixelBuffer: pixelBuffer, withPresentationTime: time)
      return .recording(time: time, pause: nil, resume: nil)

    case let .recording(_ ,pause, resume):
      let finalTime: CMTime
      if let pause, let resume {
        finalTime = adjustTime(current: time, resume: resume, pause: pause)
      } else {
        finalTime = time
      }
      try videoOutput.append(pixelBuffer: pixelBuffer, withPresentationTime: finalTime)
      return .recording(time: finalTime, pause: pause, resume: resume)

    case .paused,
         .canceled,
         .finished,
         .failed:
      return self
    }
  }

  func _appendAudioSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    to videoOutput: VideoOutput
  ) throws -> Self {
    switch self {

    case .starting,
         .ready,
         .preparing:
      return self

    case let .recording(time, pause, resume):
      try videoOutput.appendAudio(sampleBuffer: sampleBuffer)
      return .recording(time: time, pause: pause, resume: resume)

    case .paused,
         .canceled,
         .finished,
         .failed:
      return self
    }
  }

  func adjustTime(current: CMTime, resume: CMTime, pause: CMTime) -> CMTime {
    return CMTimeSubtract(current, CMTimeSubtract(resume, pause))
  }
}
