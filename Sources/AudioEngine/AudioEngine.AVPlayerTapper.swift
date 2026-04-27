import Foundation
import AVFoundation

extension AudioEngine {
    public final class AVPlayerTapper {
        private weak var player: AVPlayer?
        private var audioFormat: AVAudioFormat? {
            AVAudioFormat(commonFormat: .pcmFormatFloat32,
                          sampleRate: 44100,
                          channels: 2,
                          interleaved: false)
        }
        
        @SCNObservable public internal(set) var error: Swift.Error?
        
        public weak var recorder: BaseRecorder? {
            didSet {
                oldValue?.audioInput.audioFormat = nil
                guard let recorder = recorder else {
                    removeAudioTap()
                    return
                }
                
                recorder.audioInput.audioFormat = audioFormat
                
                guard oldValue == nil else { return }
                removeAudioTap()
                setupAudioTap()
            }
        }
        
        deinit {
            recorder = nil
        }
        
        public init(player: AVPlayer) {
            self.player = player
            guard player.currentItem != nil else {
                fatalError("FATAL: Player item is not initialized.")
            }
        }
        
        private func setupAudioTap() {
            // Create an AVMutableAudioMix
            let audioMix = AVMutableAudioMix()
            
            // Get the first audio track
            guard let audioTrack = player?.currentItem?.asset.tracks(withMediaType: .audio).first else {
                print("ERROR: No audio track found")
                return
            }
            
            // Create AVMutableAudioMixInputParameters for the track
            let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
            
            // Install tap
            inputParams.setVolume(1.0, at: .zero)
            inputParams.audioTapProcessor = createAudioTapProcessor()
            
            audioMix.inputParameters = [inputParams]
            
            // Set the audio mix to the player item
            player?.currentItem?.audioMix = audioMix
        }
        
        private func removeAudioTap() {
            player?.currentItem?.audioMix = nil
        }
        
        private func createAudioTapProcessor() -> MTAudioProcessingTap {
            var callbacks = MTAudioProcessingTapCallbacks(
                version: kMTAudioProcessingTapCallbacksVersion_0,
                clientInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                init: tapInitCallback,
                finalize: tapFinalizeCallback,
                prepare: tapPrepareCallback,
                unprepare: tapUnprepareCallback,
                process: tapProcessCallback
            )
            
            var tap: MTAudioProcessingTap?
            let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
            
            if status != noErr {
                fatalError("FATAL: creating MTAudioProcessingTap: \(status)")
            }
            
            return tap!
        }
        
        // Define the TapContext class
        class TapContext {
            var processingFormat: AVAudioFormat?
            weak var selfInstance: AudioEngine.AVPlayerTapper?
        }
        
        // MTAudioProcessingTap callbacks
        private let tapInitCallback: MTAudioProcessingTapInitCallback = { (tap, clientInfo, tapStorageOut) in
            // Initialization code
            let context = TapContext()
            context.selfInstance = Unmanaged<AudioEngine.AVPlayerTapper>.fromOpaque(clientInfo!).takeUnretainedValue()
            tapStorageOut.pointee = Unmanaged.passRetained(context).toOpaque()
        }
        
        private let tapFinalizeCallback: MTAudioProcessingTapFinalizeCallback = { (tap) in
            // Finalization code
            let storage = MTAudioProcessingTapGetStorage(tap)
            Unmanaged<TapContext>.fromOpaque(storage).release()
        }
        
        private let tapPrepareCallback: MTAudioProcessingTapPrepareCallback = { (tap, maxFrames, processingFormat) in
            // Prepare code
            let storage = MTAudioProcessingTapGetStorage(tap)
            let context = Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()
            // Save the processing format
            var asbd = processingFormat.pointee
            context.processingFormat = AVAudioFormat(streamDescription: &asbd)
        }
        
        private let tapUnprepareCallback: MTAudioProcessingTapUnprepareCallback = { (tap) in
            // Unprepare code if needed
        }
        
        private let tapProcessCallback: MTAudioProcessingTapProcessCallback = {
            (tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut) in
            
            let storage = MTAudioProcessingTapGetStorage(tap)
            let context = Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()
            
            guard let selfInstance = context.selfInstance else {
                print("ERROR: tapProcessCallback: selfInstance not available")
                return
            }
            
            var status = noErr
            var tapFlags: MTAudioProcessingTapFlags = 0
            var numFrames = numberFrames
            var timeRangeOut = CMTimeRange()
            
            // Get source audio
            status = MTAudioProcessingTapGetSourceAudio(
                tap,
                numberFrames,
                bufferListInOut,
                &tapFlags,
                &timeRangeOut,
                &numFrames
            )
            
            if status != noErr {
                print("ERROR: tapProcessCallback: getting source audio, status: \(status)")
                return
            }
            
            numberFramesOut.pointee = numFrames
            flagsOut.pointee = tapFlags
            
            let bufferListPtr = UnsafeMutableAudioBufferListPointer(bufferListInOut)
            
            // MARK: - SAFE FORMAT HANDLING
            let processingFormat: AVAudioFormat
            
            if let format = context.processingFormat {
                processingFormat = format
            } else {
                let channels = min(2, bufferListPtr.count)
                
                guard let fallback = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: 44100,
                    channels: AVAudioChannelCount(channels),
                    interleaved: false
                ) else {
                    print("ERROR: cannot create fallback format")
                    return
                }
                
                context.processingFormat = fallback
                processingFormat = fallback
            }
            
            let audioTime = AVAudioTime(hostTime: mach_absolute_time())
            
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: processingFormat,
                frameCapacity: AVAudioFrameCount(numFrames)
            ) else {
                return
            }
            
            pcmBuffer.frameLength = AVAudioFrameCount(numFrames)
            
            // MARK: - SAFE CHANNEL COPY (FIXED CRASH HERE)
            let dstChannels = Int(processingFormat.channelCount)
            let srcChannels = bufferListPtr.count
            let channelsToCopy = min(dstChannels, srcChannels)
            
            for i in 0..<channelsToCopy {
                
                let srcBuffer = bufferListPtr[i]
                
                guard let src = srcBuffer.mData,
                      let dst = pcmBuffer.floatChannelData?[i] else {
                    continue
                }
                
                let byteSize = min(
                    Int(srcBuffer.mDataByteSize),
                    Int(pcmBuffer.frameCapacity) * MemoryLayout<Float>.size
                )
                
                memcpy(dst, src, byteSize)
            }
            
            // MARK: - SEND TO RECORDER
            do {
                let sampleBuffer = try AudioEngine.createAudioSampleBuffer(
                    from: pcmBuffer,
                    time: audioTime
                )
                
                selfInstance.recorder?.audioInput.audioEngine(
                    didOutputAudioSampleBuffer: sampleBuffer
                )
                
            } catch {
                print("ERROR: tapProcessCallback: failed to create sample buffer: \(error)")
                selfInstance.error = error
            }
        }
    }
}
