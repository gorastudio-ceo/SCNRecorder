//
//  AudioEngine.swift
//  Example
//
//  Created by Vladislav Grigoryev on 15.12.2020.
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
import UIKit

@available(iOS 13.0, *)
public final class AudioEngine {
    
    enum State {
        
        case normal
        
        case interrupted(playing: Bool)
        
        var isInterrupted: Bool {
            if case .interrupted = self { return true }
            return false
        }
        
        var shouldResume: Bool {
            if case .interrupted(true) = self { return true }
            return false
        }
    }
    
    let queue = DispatchQueue(label: "AudioEngine.Processing", qos: .userInteractive)
    
    lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        engine.attach(playerNode)
        engine.attach(raterNode)
        return engine
    }()
    
    lazy var playerNode = AVAudioPlayerNode()
    
    lazy var raterNode = AVAudioUnitTimePitch()
    
    let audioSession = AVAudioSession.sharedInstance()
    
    let notificationCenter = NotificationCenter.default
    
    var observers = [NSObjectProtocol]()
    
    var state: State = .normal
    
    public var player: Player? {
        didSet {
            guard player !== oldValue else { return }
            if let oldPlayer = oldValue { oldPlayer.stop() }
            
            recorder?.audioInput.audioFormat = nil
            guard let player = player else { return }
            recorder?.audioInput.audioFormat = player.audioFormat
            
            engine.connect(playerNode, to: raterNode, format: player.audioFormat)
            engine.connect(raterNode, to: engine.mainMixerNode, format: player.audioFormat)
            
            player.attach(
                playerNode: playerNode,
                raterNode: raterNode,
                queue: queue
            )
            
            player.willStart = { [weak self] in
                guard let self = self else { return false }
                
                let isInterrupted = DispatchQueue.main.sync { () -> Bool in
                    if self.state.isInterrupted { self.state = .interrupted(playing: true) }
                    return self.state.isInterrupted
                }
                guard !isInterrupted else { return false }
                
                do {
                    try self.activateAudioSession()
                    try self.engine.start()
                    return true
                }
                catch {
                    self.error = error
                    return false
                }
            }
            
            player.didPause = { [weak self] in
                guard let self = self else { return }
                self.engine.pause()
                self.deactivateAudioSession()
            }
            
            player.didStop = { [weak self] in
                guard let self = self else { return }
                
                self.engine.stop()
                self.engine.reset()
                self.deactivateAudioSession()
            }
        }
    }
    
    public weak var recorder: BaseRecorder? {
        didSet {
            oldValue?.audioInput.audioFormat = nil
            guard let recorder = recorder else {
                engine.mainMixerNode.removeTap(onBus: 0)
                return
            }
            
            recorder.audioInput.audioFormat = player?.audioFormat
            
            guard oldValue == nil else { return }
            engine.mainMixerNode.removeTap(onBus: 0)
            engine.mainMixerNode.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: engine.mainMixerNode.outputFormat(forBus: 0)
            ) { [weak self] (buffer, time) in
                guard let self = self else { return }
                guard let recorder = self.recorder else {
                    self.engine.mainMixerNode.removeTap(onBus: 0)
                    return
                }
                
                do {
                    let sampleBuffer = try Self.createAudioSampleBuffer(from: buffer, time: time)
                    recorder.audioInput.audioEngine(didOutputAudioSampleBuffer: sampleBuffer)
                }
                catch {
                    self.error = error
                }
            }
        }
    }
    
    let canDeactivateAudioSession: Bool
    
    @SCNObservable public internal(set) var error: Swift.Error?
    
    public init(canDeactivateAudioSession: Bool = true) {
        self.canDeactivateAudioSession = canDeactivateAudioSession
        setupObservers()
    }
    
    deinit {
        recorder?.audioInput.audioFormat = nil
        player?.stop()
        observers.forEach { notificationCenter.removeObserver($0) }
        deactivateAudioSession()
    }
    
    func activateAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
        try audioSession.setActive(true)
    }
    
    func deactivateAudioSession() {
        guard canDeactivateAudioSession else { return }
        
        do { try audioSession.setActive(false) }
        catch { self.error = error }
    }
}

// MARK: - Observers
@available(iOS 13.0, *)
extension AudioEngine {
    
    func setupObservers() {
        observers.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in self?.handleInterruption($0) }
            )
        )
        
        observers.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in self?.handleMediaServicesWereReset($0) }
            )
        )
        
        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in self?.handleApplicationWillResignActiveNotification($0) }
            )
        )
        
        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in self?.handleApplicationDidBecomeActive($0) })
        )
    }
    
    func handleApplicationWillResignActiveNotification(_ notification: Notification) {
        state = .interrupted(playing: queue.sync { player?.state.isPlaying ?? false })
        player?.pause()
    }
    
    func handleApplicationDidBecomeActive(_ notification: Notification) {
        let shouldResume = state.shouldResume
        state = .normal
        if shouldResume { player?.play() }
    }
    
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        
        switch type {
        case .began:
            state = .interrupted(playing: queue.sync { player?.state.isPlaying ?? false })
            player?.pause()
            
        case .ended:
            let shouldResume = state.shouldResume
            state = .normal
            
            guard shouldResume,
                  let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            else { return }
            player?.play()
            
        @unknown default:
            break
        }
    }
    
    func handleMediaServicesWereReset(_ notification: Notification) {
        let player = self.player
        let recorder = self.recorder
        
        self.player = nil
        self.recorder = nil
        
        playerNode = AVAudioPlayerNode()
        raterNode = AVAudioUnitTimePitch()
        engine = AVAudioEngine()
        engine.attach(playerNode)
        engine.attach(raterNode)
        
        self.player = player
        self.recorder = recorder
    }
}

@available(iOS 13.0, *)
extension AudioEngine {
    
    static func createAudioSampleBuffer(from buffer: AVAudioPCMBuffer, time: AVAudioTime) throws -> CMSampleBuffer {
        let audioBufferList = buffer.mutableAudioBufferList
        let streamDescription = buffer.format.streamDescription.pointee
        let timescale = CMTimeScale(streamDescription.mSampleRate)
        let format = try CMAudioFormatDescription(audioStreamBasicDescription: streamDescription)
        let sampleBuffer = try CMSampleBuffer(
            dataBuffer: nil,
            formatDescription: format,
            numSamples: CMItemCount(buffer.frameLength),
            sampleTimings: [
                CMSampleTimingInfo(
                    duration: CMTime(value: 1, timescale: timescale),
                    presentationTimeStamp: CMTime(
                        seconds: AVAudioTime.seconds(forHostTime: time.hostTime),
                        preferredTimescale: timescale
                    ),
                    decodeTimeStamp: .invalid
                )
            ],
            sampleSizes: []
        )
        try sampleBuffer.setDataBuffer(fromAudioBufferList: audioBufferList)
        return sampleBuffer
    }
}
