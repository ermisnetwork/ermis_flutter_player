import Flutter
import UIKit
import AVFoundation
import Starscream

typealias StarscreamWebSocket = Starscream.WebSocket

public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
    private var demuxer: Demuxer?
    private var webSocket: StarscreamWebSocket?
    private var playerViewController: Fmp4PlayerViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fmp4_stream_player", binaryMessenger: registrar.messenger())
        let instance = Fmp4StreamPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let factory = Fmp4StreamPlayerViewFactory(messenger: registrar.messenger(), plugin: instance)
        registrar.register(factory, withId: "fmp4_stream_player_view")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startStreaming":
            guard let args = call.arguments as? [String: Any],
                  let streamId = args["streamId"] as? String,
                  let token = args["token"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing streamId or token", details: nil))
                return
            }
            startStreaming(streamId: streamId, token: token, result: result)

        case "stopStreaming":
            stopStreaming(result: result)

        case "resumeView":
            playerViewController?.resumePlayback()
            result(true)

        case "pauseView":
            playerViewController?.pausePlayback()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startStreaming(streamId: String, token: String, result: @escaping FlutterResult) {
        guard playerViewController != nil else {
            result(FlutterError(code: "NO_PLAYER", message: "PlayerViewController not initialized yet", details: nil))
            return
        }

        let wsUrl = "wss://sfu-do-streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)"
        guard let url = URL(string: wsUrl) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid WebSocket URL", details: nil))
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.timeoutInterval = 30

        webSocket = StarscreamWebSocket(request: request)
        webSocket?.delegate = self
        webSocket?.connect()
        print("🚀 WebSocket connecting...")
        result(true)
    }

    private func stopStreaming(result: @escaping FlutterResult) {
        print("⏹️ Stopping stream...")
        webSocket?.disconnect()
        webSocket = nil
        playerViewController?.stopPlayback()
        demuxer = nil
        result(true)
    }

    func setPlayerViewController(_ controller: Fmp4PlayerViewController) {
        self.playerViewController = controller
//        if let demuxer = self.demuxer {
//            controller.setDemuxer(demuxer)
//        }
    }
}

// MARK: - WebSocket Delegate

extension Fmp4StreamPlayerPlugin: Starscream.WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected:
            print("✅ WebSocket connected")
        case .disconnected(let reason, let code):
            print("❌ WebSocket disconnected: \(reason) code: \(code)")
        case .text(let text):
           if text.contains("videoConfig") && text.contains("audioConfig") {
                   DispatchQueue.main.async {
                       guard let playerVC = self.playerViewController else { return }
                       guard let streamConfig = playerVC.getStreamConfig(config: text) else { return }
                       playerVC.setupConfigFormat(text)
                       print("✅ Demuxer initialized with codec: \(streamConfig.videoConfig.codec)")
                   }
               }
        case .binary(let data):
            guard !data.isEmpty else { return }
            print("✅ binary data: \(data)")
            let cleanData = data.dropFirst()
            playerViewController?.decodeFrame(cleanData)
        case .error(let error):
            print("⚠️ WebSocket error: \(String(describing: error))")
        case .cancelled:
            print("🚫 WebSocket cancelled")
        default: break
        }
    }
}

// MARK: - Platform View Factory

class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var plugin: Fmp4StreamPlayerPlugin?

    init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
        self.messenger = messenger
        self.plugin = plugin
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let controller = Fmp4PlayerViewController(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
        plugin?.setPlayerViewController(controller)
        return controller
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Player View Controller

class Fmp4PlayerViewController: NSObject, FlutterPlatformView {
    private let containerView: TestView
    private var videoLayer: AVSampleBufferDisplayLayer!
    private var audioRenderer: AVSampleBufferAudioRenderer!
    private var synchronizer: AVSampleBufferRenderSynchronizer!

    private var demuxer = Demuxer(hevc: true)
    private var videoFormatDesc: CMVideoFormatDescription?
    private var audioFormatDesc: CMAudioFormatDescription?
    private var isPlaying = false
    private var audioTimestamp = CMTime.zero

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger) {
        containerView = TestView()
        containerView.backgroundColor = .black
        super.init()

        containerView.onSizeChanged = { [weak self]  in
            guard let self else {
                return
            }
            self.videoLayer.frame = self.containerView.frame
        }
        setupPlayer()
        setupAudioSession()
    }

    func view() -> UIView { containerView }

    func layoutPlayerLayer() {
        DispatchQueue.main.async {
            self.videoLayer.frame = self.containerView.bounds
        }
    }

    private func setupPlayer() {
        videoLayer = AVSampleBufferDisplayLayer()
        videoLayer.videoGravity = .resizeAspect
        containerView.layer.addSublayer(videoLayer)

        audioRenderer = AVSampleBufferAudioRenderer()
        synchronizer = AVSampleBufferRenderSynchronizer()
        synchronizer.addRenderer(videoLayer)
        synchronizer.addRenderer(audioRenderer)
        videoLayer.frame = containerView.bounds
        print("🎥 AVSampleBufferDisplayLayer setup completed")
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)
    }

    func setupConfigFormat(_ config: String) {
        guard let streamConfig = getStreamConfig(config: config) else { return }

        guard let videoDescData = Data(base64Encoded: streamConfig.videoConfig.description),
              let audioDescData = Data(base64Encoded: streamConfig.audioConfig.description) else {
            print("❌ Failed to decode base64 descriptions")
            return
        }
        let video_description = streamConfig.videoConfig.description
        let avccData = Data(base64Encoded: video_description)
        videoFormatDesc = createVideoFormatDescription(
                   videoDescData,
                   width: streamConfig.videoConfig.codedWidth,
                   height: streamConfig.videoConfig.codedHeight,
                   isHEVC: streamConfig.videoConfig.codec.lowercased().contains("hev")
               )
        audioFormatDesc = createAudioFormatDescription(audioDescData, streamConfig.audioConfig)
        print("🎛️ Format descriptions set: Video=\(videoFormatDesc != nil), Audio=\(audioFormatDesc != nil)")
    }

    func decodeFrame(_ data: Data) {
        let frames : ProcessResult = try! demuxer.processData(data: data)
            
            for frame in frames.videoFrames {
              let timeStamp = CMTime(value: CMTimeValue(frame.timestamp!), timescale: 90000);
              decodeVideoFrame(frame.data, timestamp: timeStamp)
            }
              
            for frame in frames.audioFrames {
              let timeStamp = CMTime(value: CMTimeValue(frame.timestamp!), timescale: 48000);
              decodeAudioFrame(frame.data, timestamp: timeStamp)
            }
    }

    private func createVideoFormatDescription(_ descData: Data, width: Int, height: Int, isHEVC: Bool) -> CMVideoFormatDescription? {
        let atomKey = isHEVC ? "hvcC" : "avcC"
                let codecType = isHEVC ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
                
                let extensions: CFDictionary = [
                    kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: [
                        atomKey: descData as CFData
                    ]
                ] as CFDictionary
                
                var formatDesc: CMVideoFormatDescription?
                let status = CMVideoFormatDescriptionCreate(
                    allocator: kCFAllocatorDefault,
                    codecType: codecType,
                    width: Int32(width),
                    height: Int32(height),
                    extensions: extensions,
                    formatDescriptionOut: &formatDesc
                )
                guard status == noErr else {
                    print("❌ Failed to create video format description: \(status)")
                    return nil
                }
                return formatDesc
     }

//    private func decodeVideoFrame(_ data: Data, timestamp: CMTime) {
//            guard let formatDesc = videoFormatDesc else {
//                     print("❌ Video format not configured")
//                     return
//                 }
//
//                 // Create block buffer
//                 var blockBuffer: CMBlockBuffer?
//                 var status = CMBlockBufferCreateWithMemoryBlock(
//                     allocator: kCFAllocatorDefault,
//                     memoryBlock: nil,
//                     blockLength: data.count,
//                     blockAllocator: kCFAllocatorDefault,
//                     customBlockSource: nil,
//                     offsetToData: 0,
//                     dataLength: data.count,
//                     flags: 0,
//                     blockBufferOut: &blockBuffer
//                 )
//
//                 guard status == noErr, let blockBuffer = blockBuffer else {
//                     print("❌ Failed to create video block buffer")
//                     return
//                 }
//
//                 // Copy data
//                 status = data.withUnsafeBytes { ptr in
//                     CMBlockBufferReplaceDataBytes(
//                         with: ptr.baseAddress!,
//                         blockBuffer: blockBuffer,
//                         offsetIntoDestination: 0,
//                         dataLength: data.count
//                     )
//                 }
//
//                 guard status == noErr else {
//                     print("❌ Failed to copy video data")
//                     return
//                 }
//                 // Create sample buffer
//                 var timing = CMSampleTimingInfo(
//                     duration: CMTime(value: 1, timescale: CMTimeScale(60)),
//                     presentationTimeStamp: timestamp,
//                     decodeTimeStamp: .invalid
//                 )
//               print("Timing Video: ",timestamp)
//                 var sampleBuffer: CMSampleBuffer?
//                 status = CMSampleBufferCreateReady(
//                     allocator: kCFAllocatorDefault,
//                     dataBuffer: blockBuffer,
//                     formatDescription: formatDesc,
//                     sampleCount: 1,
//                     sampleTimingEntryCount: 1,
//                     sampleTimingArray: &timing,
//                     sampleSizeEntryCount: 1,
//                     sampleSizeArray: [data.count],
//                     sampleBufferOut: &sampleBuffer
//                 )
//
//                 guard status == noErr, let sampleBuffer = sampleBuffer else {
//                     print("❌ Failed to create video sample buffer")
//                     return
//                 }
//
//                 // Enqueue to video layer
//               if videoLayer.isReadyForMoreMediaData {
//                 enqueueVideo(sampleBuffer)
//
//           //           Start playback if not started
//                     if !isPlaying {
//                         synchronizer.setRate(1.0, time: timestamp)
//                         isPlaying = true
//                         print("▶️ Playback started")
//                     }
//                 } else {
//                     print("⚠️ Video layer not ready")
//                 }
//        }
    private func decodeVideoFrame(_ data: Data, timestamp: CMTime) {
        guard let formatDesc = videoFormatDesc else {
            print("❌ Video format not configured")
            return
        }
        
        // Tạo block buffer
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let blockBuffer = blockBuffer else {
            print("❌ Failed to create video block buffer")
            return
        }
        
        // Copy data vào block buffer
        status = data.withUnsafeBytes { ptr in
            CMBlockBufferReplaceDataBytes(
                with: ptr.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: data.count
            )
        }
        guard status == noErr else {
            print("❌ Failed to copy video data")
            return
        }
        
        // Tạo sample buffer với timing đúng frame rate
        let frameRate = 30.0 // default fallback
        let duration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )
        
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [data.count],
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer = sampleBuffer else {
            print("❌ Failed to create video sample buffer")
            return
        }
        
        // Enqueue trên main thread
        DispatchQueue.main.async {
            if self.videoLayer.isReadyForMoreMediaData {
                self.videoLayer.enqueue(sampleBuffer)
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("▶️ Video frame enqueued at PTS: \(pts)")
                
                if !self.isPlaying {
                    self.synchronizer.setRate(1.0, time: pts)
                    self.isPlaying = true
                    print("▶️ Playback started")
                }
            } else {
                print("⚠️ Video layer not ready, retrying...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                    self.decodeVideoFrame(data, timestamp: timestamp)
                }
            }
        }
    }

        private func decodeAudioFrame(_ data: Data, timestamp: CMTime) {
            guard let formatDesc = audioFormatDesc else {
                return
            }

            // Remove ADTS header if present
            var audioData = data
            if isADTSHeader(data) {
                let headerSize = (data[1] & 0x01) == 0 ? 9 : 7
                audioData = data.subdata(in: headerSize..<data.count)
            }

            var blockBuffer: CMBlockBuffer?
            var status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: audioData.count,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: audioData.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            guard status == noErr, let blockBuffer = blockBuffer else {
                return
            }

            status = audioData.withUnsafeBytes { ptr in
                CMBlockBufferReplaceDataBytes(
                    with: ptr.baseAddress!,
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: audioData.count
                )
            }
            guard status == noErr else {
                return
            }

            // Calculate timestamp
            let currentTimestamp: CMTime
            if audioTimestamp == .zero {
                currentTimestamp = timestamp
            } else {
                currentTimestamp = CMTimeAdd(audioTimestamp, CMTime(value: 1024, timescale: 48000))
            }
            audioTimestamp = currentTimestamp

            var packetDesc = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(audioData.count)
            )

            var sampleBuffer: CMSampleBuffer?
            status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                formatDescription: formatDesc,
                sampleCount: 1,
                presentationTimeStamp: currentTimestamp,
                packetDescriptions: &packetDesc,
                sampleBufferOut: &sampleBuffer
            )
            guard status == noErr, let sampleBuffer = sampleBuffer else {
                return
            }

            enqueueAudio(sampleBuffer)
        }

    func getStreamConfig(config: String) -> StreamConfig? {
        do {
            let data = Data(config.utf8)
            let decoder = JSONDecoder()
            return try decoder.decode(StreamConfig.self, from: data)
        } catch {
            print("❌ JSON decode error: \(error)")
            return nil
        }
    }

    private func createAudioFormatDescription(_ descData: Data, _ audioConfig: StreamConfig.AudioConfig) -> CMAudioFormatDescription? {
            let extensions: CFDictionary = [
                kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: [
                    "asc": descData as CFData
                ]
            ] as CFDictionary

            var asbd = AudioStreamBasicDescription(
                mSampleRate: Float64(audioConfig.sampleRate),
                mFormatID: kAudioFormatMPEG4AAC,
                mFormatFlags: 0,
                mBytesPerPacket: 0,
                mFramesPerPacket: 1024,
                mBytesPerFrame: 0,
                mChannelsPerFrame: UInt32(audioConfig.numberOfChannels),
                mBitsPerChannel: 0,
                mReserved: 0
            )

            var formatDesc: CMAudioFormatDescription?
            let status = CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: &asbd,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: extensions,
                formatDescriptionOut: &formatDesc
            )
            guard status == noErr else {
                print("❌ Failed to create audio format description: \(status)")
                return nil
            }
            return formatDesc
        }

        private func isADTSHeader(_ data: Data) -> Bool {
            guard data.count >= 2 else { return false }
            return data[0] == 0xFF && (data[1] & 0xF0) == 0xF0
        }

    private func enqueueVideo(_ sb: CMSampleBuffer, retries: Int = 3) {
       
       print(videoLayer.isReadyForMoreMediaData)
       if videoLayer.isReadyForMoreMediaData {
           videoLayer.enqueue(sb)
         let pts = CMSampleBufferGetPresentationTimeStamp(sb)
           print("videoLayer.status rawValue:", videoLayer.status.rawValue)
             switch videoLayer.status {
             case .rendering:
                 print("[Video] Enqueued audio at PTS: \(pts). Status: rendering")
             case .failed:
                 print("[Video] Renderer failed: \(videoLayer.error?.localizedDescription ?? "Unknown")")
             default:
                 print("[Video] Enqueued audio at PTS: \(pts). Status: \(videoLayer.status)")
             }
         
       }  else {
           print("error")
       }
     }

        private func enqueueAudio(_ sampleBuffer: CMSampleBuffer) {
            if audioRenderer.isReadyForMoreMediaData {
                audioRenderer.enqueue(sampleBuffer)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                    self.enqueueAudio(sampleBuffer)
                }
            }
        }

     func pausePlayback() {
            synchronizer.rate = 0
            print("⏸️ Playback paused")
        }

        func resumePlayback() {
            synchronizer.rate = 1.0
            print("▶️ Playback resumed")
        }

        func stopPlayback() {
            print("⏹️ Stopping playback...")
            synchronizer.rate = 0
            videoLayer.flush()
            audioRenderer.flush()
            isPlaying = false
            audioTimestamp = .zero
        }

        deinit {
            stopPlayback()
        }
}

// MARK: - Models

struct StreamConfig: Codable {
    let type: String?
    let videoConfig: VideoConfig
    let audioConfig: AudioConfig

    struct VideoConfig: Codable {
        let codec: String
        let codedWidth: Int
        let codedHeight: Int
        let frameRate: Double
        let description: String
    }

    struct AudioConfig: Codable {
        let sampleRate: Int
        let numberOfChannels: Int
        let codec: String
        let description: String
    }
}


class TestView: UIView {

    var onSizeChanged: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onSizeChanged?()
    }
}
