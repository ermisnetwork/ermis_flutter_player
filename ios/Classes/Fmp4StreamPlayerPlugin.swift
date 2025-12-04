
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
        let wsUrl = "wss://streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)"
        guard let url = URL(string: wsUrl) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid WebSocket URL", details: nil))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")
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
        result(true)
    }

    func setPlayerViewController(_ controller: Fmp4PlayerViewController) {
        self.playerViewController = controller
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
                print("📝 Received decoder config")
                playerViewController?.setupConfigFormat(text)
            } else if text.contains("TotalViewerCount") {
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let viewers = json["total_viewers"] as? Int {
                    print("👥 Total viewers: \(viewers)")
                }
            }
        case .binary(let data):
            guard !data.isEmpty else { return }
            let cleanData = data.dropFirst()
            let prefix = cleanData.prefix(5)  // Lấy 16 byte đầu
               print("Binary frame (\(cleanData.count) bytes):", prefix.map { String(format: "%02X", $0) }.joined(separator: " "))
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
    private let containerView: UIView
    private var videoLayer: AVSampleBufferDisplayLayer!
    private var audioRenderer: AVSampleBufferAudioRenderer!
    private var synchronizer: AVSampleBufferRenderSynchronizer!

    private var demuxer = Demuxer(hevc: true)
    private var videoFormatDesc: CMVideoFormatDescription?
    private var audioFormatDesc: CMAudioFormatDescription?
    private var isPlaying = false
    private var audioTimestamp = CMTime.zero
    private var videoWidth: Int = 1920
    private var videoHeight: Int = 1080

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger) {
        containerView = UIView(frame: frame)
        containerView.backgroundColor = .black
        super.init()
        setupPlayer()
        setupAudioSession()
    }

    func view() -> UIView { containerView }

    private func setupPlayer() {
        videoLayer = AVSampleBufferDisplayLayer()
        videoLayer.frame = containerView.bounds
        videoLayer.videoGravity = .resizeAspect
        containerView.layer.addSublayer(videoLayer)
    
        audioRenderer = AVSampleBufferAudioRenderer()
        synchronizer = AVSampleBufferRenderSynchronizer()
        synchronizer.addRenderer(videoLayer)
        synchronizer.addRenderer(audioRenderer)
        print("🎥 AVSampleBufferDisplayLayer setup completed")
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)
    }
 func setupConfigFormat(_ config : String) {
    let streamconfig = getStreamConfig(config: config)
    guard streamconfig != nil else {
      return
    }
    let video_description = streamconfig?.videoConfig.description
    let audio_description = streamconfig?.audioConfig.description

    let accData = Data(base64Encoded: audio_description!)
    let avccData = Data(base64Encoded: video_description!)
    audioFormatDesc = createAudioFormatDescription(accData!, streamconfig!.audioConfig);
    videoFormatDesc = createVideoFormatDescription(avccData!)
  }

    func decodeFrame(_ data: Data) {
        let frames = try! demuxer.processData(data: data)

        if !frames.videoFrames.isEmpty || !frames.audioFrames.isEmpty {
            print("🎬 Demux \(frames.videoFrames.count) video, \(frames.audioFrames.count) audio frames")
        }

        for frame in frames.videoFrames {
            let timestamp = CMTime(value: Int64(frame.timestamp ?? 0), timescale: 90000)
            decodeVideoFrame(frame.data, timestamp: timestamp, isKeyframe: frame.isKeyframe)
        }

        for frame in frames.audioFrames {
            let timestamp = CMTime(value: Int64(frame.timestamp ?? 0), timescale: 48000)
            decodeAudioFrame(frame.data, timestamp: timestamp)
        }
    }
 private func createVideoFormatDescription(_ avcCData: Data) -> CMVideoFormatDescription? {
      let avcCNSData = avcCData as CFData

      let extensions: CFDictionary = [
          kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: [
              "avcC": avcCNSData
          ]
      ] as CFDictionary

      var formatDesc: CMVideoFormatDescription?

      let status = CMVideoFormatDescriptionCreate(
          allocator: kCFAllocatorDefault,
          codecType: kCMVideoCodecType_H264,
          width: 1280,
          height: 720,
          extensions: extensions,
          formatDescriptionOut: &formatDesc
      )

      guard status == noErr else {
        print("error")
        return nil
      }
      return formatDesc!
  }

//     private func decodeVideoFrame(_ data: Data, timestamp: CMTime, isKeyframe: Bool) {
//         guard let formatDesc = videoFormatDesc else {
//             print("⚠️ Video format not configured")
//             return
//         }
//
//
// // Create block buffer
//         var blockBuffer: CMBlockBuffer?
//         var status = CMBlockBufferCreateWithMemoryBlock(
//             allocator: kCFAllocatorDefault,
//             memoryBlock: nil,
//             blockLength: data.count,
//             blockAllocator: kCFAllocatorDefault,
//             customBlockSource: nil,
//             offsetToData: 0,
//             dataLength: data.count,
//             flags: 0,
//             blockBufferOut: &blockBuffer
//         )
//         guard status == noErr, let blockBuffer = blockBuffer else {
//             print("❌ Failed to create video block buffer: \(status)")
//             return
//         }
//
//  // Copy data
//         status = data.withUnsafeBytes { ptr in
//             CMBlockBufferReplaceDataBytes(
//                 with: ptr.baseAddress!,
//                 blockBuffer: blockBuffer,
//                 offsetIntoDestination: 0,
//                 dataLength: data.count
//             )
//         }
//         guard status == noErr else {
//             print("❌ Failed to replace video data: \(status)")
//             return
//         }
//
//         var timing = CMSampleTimingInfo(
//             duration: CMTime(value: 1, timescale: 60),
//             presentationTimeStamp: timestamp,
//             decodeTimeStamp: .invalid
//         )
//          print("Timing Video: ",timestamp)
//         var sampleBuffer: CMSampleBuffer?
//         status = CMSampleBufferCreateReady(
//             allocator: kCFAllocatorDefault,
//             dataBuffer: blockBuffer,
//             formatDescription: formatDesc,
//             sampleCount: 1,
//             sampleTimingEntryCount: 1,
//             sampleTimingArray: &timing,
//             sampleSizeEntryCount: 1,
//             sampleSizeArray: [data.count],
//             sampleBufferOut: &sampleBuffer
//         )
//         guard status == noErr, let sampleBuffer = sampleBuffer else {
//             print("❌ Failed to create video sample buffer: \(status)")
//             return
//         }
//
// if videoLayer.isReadyForMoreMediaData {
//       enqueueVideo(sampleBuffer)
//
// //           Start playback if not started
//           if !isPlaying {
//               synchronizer.setRate(1.0, time: timestamp)
//               isPlaying = true
//               print("▶️ Playback started")
//           }
//       } else {
//           print("⚠️ Video layer not ready")
//       }
//     }
private func decodeVideoFrame(_ data: Data, timestamp: CMTime, isKeyframe: Bool) {
    guard let formatDesc = videoFormatDesc else {
        print("⚠️ Video format not configured")
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
        print("❌ Failed to create video block buffer: \(status)")
        return
    }

    status = data.withUnsafeBytes { ptr in
        CMBlockBufferReplaceDataBytes(
            with: ptr.baseAddress!,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: data.count
        )
    }
    guard status == noErr else {
        print("❌ Failed to replace video data: \(status)")
        return
    }

    // Tính duration chính xác dựa vào frameRate
    let duration = CMTime(value: 1, timescale: CMTimeScale(videoFormatDesc!.videoFrameRate()))

    var timing = CMSampleTimingInfo(
        duration: duration,
        presentationTimeStamp: timestamp,
        decodeTimeStamp: isKeyframe ? timestamp : .invalid
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
        print("❌ Failed to create video sample buffer: \(status)")
        return
    }

    // Enqueue video
    enqueueVideo(sampleBuffer, isKeyframe: isKeyframe)
}

    private func decodeAudioFrame(_ data: Data, timestamp: CMTime) {
        guard let formatDesc = audioFormatDesc else { return }

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
        guard status == noErr, let blockBuffer = blockBuffer else { return }

        status = audioData.withUnsafeBytes { ptr in
            CMBlockBufferReplaceDataBytes(
                with: ptr.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: audioData.count
            )
        }
        guard status == noErr else { return }

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
        guard status == noErr, let sampleBuffer = sampleBuffer else { return }

        enqueueAudio(sampleBuffer)
    }

    func getStreamConfig(config: String) -> StreamConfig? {
        do {
            return try JSONDecoder().decode(StreamConfig.self, from: Data(config.utf8))
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
    
//    private func enqueueVideo(_ sb: CMSampleBuffer, retries: Int = 3) {
//
//        print(videoLayer!.isReadyForMoreMediaData)
//        if videoLayer!.isReadyForMoreMediaData {
//            videoLayer!.enqueue(sb)
//          let pts = CMSampleBufferGetPresentationTimeStamp(sb)
//              switch videoLayer!.status {
//              case .rendering:
//                  print("[Video] Enqueued audio at PTS: \(pts). Status: rendering")
//              case .failed:
//                  print("[Video] Renderer failed: \(videoLayer.error?.localizedDescription ?? "Unknown")")
//              default:
//                  print("[Video] Enqueued audio at PTS: \(pts). Status: \(videoLayer!.status)")
//              }
//
//        }  else {
//            print("error")
//        }
//      }
    private func enqueueVideo(_ sb: CMSampleBuffer, isKeyframe: Bool) {
        guard videoLayer.isReadyForMoreMediaData else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                self.enqueueVideo(sb, isKeyframe: isKeyframe)
            }
            return
        }

        videoLayer.enqueue(sb)
        let pts = CMSampleBufferGetPresentationTimeStamp(sb)
        print("[Video] Enqueued frame at PTS: \(pts), key=\(isKeyframe)")

        if !isPlaying && isKeyframe {
            // Start playback từ keyframe đầu
            synchronizer.setRate(1.0, time: pts)
            isPlaying = true
            print("▶️ Playback started")
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


extension CMVideoFormatDescription {
    func videoFrameRate() -> Float64 {
        let extensions = CMFormatDescriptionGetExtensions(self) as? [String: Any]
        if let sampleDescription = extensions?[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] as? [String: Any],
           let avcCData = sampleDescription["avcC"] as? Data {
            // Mặc định return 30 fps nếu không parse
            return 30.0
        }
        return 30.0
    }
}
