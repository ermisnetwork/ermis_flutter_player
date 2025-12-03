// // import Flutter
// // import UIKit
// // import AVFoundation
// // import Starscream
// //
// // typealias StarscreamWebSocket = Starscream.WebSocket
// //
// // public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
// //     private var demuxer: Demuxer?
// //     private var webSocket: StarscreamWebSocket?
// //     private var playerViewController: Fmp4PlayerViewController?
// //
// //     public static func register(with registrar: FlutterPluginRegistrar) {
// //         let channel = FlutterMethodChannel(name: "fmp4_stream_player", binaryMessenger: registrar.messenger())
// //         let instance = Fmp4StreamPlayerPlugin()
// //         registrar.addMethodCallDelegate(instance, channel: channel)
// //
// //         let factory = Fmp4StreamPlayerViewFactory(messenger: registrar.messenger(), plugin: instance)
// //         registrar.register(factory, withId: "fmp4_stream_player_view")
// //     }
// //
// //     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
// //         switch call.method {
// //         case "startStreaming":
// //             guard let args = call.arguments as? [String: Any],
// //                   let streamId = args["streamId"] as? String,
// //                   let token = args["token"] as? String else {
// //                 result(FlutterError(code: "INVALID_ARGS", message: "Missing streamId or token", details: nil))
// //                 return
// //             }
// //             startStreaming(streamId: streamId, token: token, result: result)
// //
// //         case "stopStreaming":
// //             stopStreaming(result: result)
// //
// //         case "resumeView":
// //             playerViewController?.resumePlayback()
// //             result(true)
// //
// //         case "pauseView":
// //             playerViewController?.pausePlayback()
// //             result(true)
// //
// //         default:
// //             result(FlutterMethodNotImplemented)
// //         }
// //     }
// //
// //     private func startStreaming(streamId: String, token: String, result: @escaping FlutterResult) {
// //         let wsUrl = "wss://streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)"
// //         guard let url = URL(string: wsUrl) else {
// //             result(FlutterError(code: "INVALID_URL", message: "Invalid WebSocket URL", details: nil))
// //             return
// //         }
// //
// //         var request = URLRequest(url: url)
// //         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
// //         request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")
// //         request.timeoutInterval = 30
// //
// //         webSocket = StarscreamWebSocket(request: request)
// //         webSocket?.delegate = self
// //         webSocket?.connect()
// //         print("🚀 WebSocket connecting...")
// //         result(true)
// //     }
// //
// //     private func stopStreaming(result: @escaping FlutterResult) {
// //         print("⏹️ Stopping stream...")
// //         webSocket?.disconnect()
// //         webSocket = nil
// //         playerViewController?.stopPlayback()
// //         result(true)
// //     }
// //
// //     func setPlayerViewController(_ controller: Fmp4PlayerViewController) {
// //         self.playerViewController = controller
// //     }
// // }
// //
// // // MARK: - WebSocket Delegate
// //
// // extension Fmp4StreamPlayerPlugin: Starscream.WebSocketDelegate {
// //     public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
// //         switch event {
// //         case .connected:
// //             print("✅ WebSocket connected")
// //         case .disconnected(let reason, let code):
// //             print("❌ WebSocket disconnected: \(reason) code: \(code)")
// //         case .text(let text):
// //             if text.contains("videoConfig") && text.contains("audioConfig") {
// //                 print("📝 Received decoder config")
// //                 playerViewController?.setupConfigFormat(text)
// //             } else if text.contains("TotalViewerCount") {
// //                 if let data = text.data(using: .utf8),
// //                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
// //                    let viewers = json["total_viewers"] as? Int {
// //                     print("👥 Total viewers: \(viewers)")
// //                 }
// //             }
// //         case .binary(let data):
// //             guard !data.isEmpty else { return }
// //             let cleanData = data.dropFirst()
// //             playerViewController?.decodeFrame(cleanData)
// //         case .error(let error):
// //             print("⚠️ WebSocket error: \(String(describing: error))")
// //         case .cancelled:
// //             print("🚫 WebSocket cancelled")
// //         default: break
// //         }
// //     }
// // }
// //
// // // MARK: - Platform View Factory
// //
// // class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
// //     private let messenger: FlutterBinaryMessenger
// //     private weak var plugin: Fmp4StreamPlayerPlugin?
// //
// //     init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
// //         self.messenger = messenger
// //         self.plugin = plugin
// //     }
// //
// //     func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
// //         let controller = Fmp4PlayerViewController(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
// //         plugin?.setPlayerViewController(controller)
// //         return controller
// //     }
// //
// //     func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
// //         return FlutterStandardMessageCodec.sharedInstance()
// //     }
// // }
// //
// // // MARK: - Player View Controller
// //
// // class Fmp4PlayerViewController: NSObject, FlutterPlatformView {
// //     private let containerView: UIView
// //     private var videoLayer: AVSampleBufferDisplayLayer!
// //     private var audioRenderer: AVSampleBufferAudioRenderer!
// //     private var synchronizer: AVSampleBufferRenderSynchronizer!
// //
// //     private var demuxer = Demuxer(hevc: true)
// //     private var videoFormatDesc: CMVideoFormatDescription?
// //     private var audioFormatDesc: CMAudioFormatDescription?
// //     private var isPlaying = false
// //     private var audioTimestamp = CMTime.zero
// //     private var videoWidth: Int = 1920
// //     private var videoHeight: Int = 1080
// //
// //     init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger) {
// //         containerView = UIView(frame: frame)
// //         containerView.backgroundColor = .black
// //         super.init()
// //         setupPlayer()
// //         setupAudioSession()
// //     }
// //
// //     func view() -> UIView {
// //         containerView
// //     }
// //
// //     private func setupPlayer() {
// //         videoLayer = AVSampleBufferDisplayLayer()
// //         videoLayer.frame = containerView.bounds
// //         videoLayer.videoGravity = .resizeAspect
// //         containerView.layer.addSublayer(videoLayer)
// //
// //         audioRenderer = AVSampleBufferAudioRenderer()
// //         synchronizer = AVSampleBufferRenderSynchronizer()
// //         synchronizer.addRenderer(videoLayer)
// //         synchronizer.addRenderer(audioRenderer)
// //         print("🎥 AVSampleBufferDisplayLayer setup completed")
// //     }
// //
// //     private func setupAudioSession() {
// //         let audioSession = AVAudioSession.sharedInstance()
// //         try? audioSession.setCategory(.playback, mode: .default)
// //         try? audioSession.setActive(true)
// //     }
// //
// //     func setupConfigFormat(_ config: String) {
// //         guard let streamConfig = getStreamConfig(config: config) else {
// //             print("❌ Failed to parse stream config")
// //             return
// //         }
// //
// //         guard let videoDescData = Data(base64Encoded: streamConfig.videoConfig.description),
// //               let audioDescData = Data(base64Encoded: streamConfig.audioConfig.description) else {
// //             print("❌ Failed to decode base64 descriptions")
// //             return
// //         }
// //
// //         // CRITICAL: Lấy width/height từ config
// //         videoWidth = streamConfig.videoConfig.codedWidth
// //         videoHeight = streamConfig.videoConfig.codedHeight
// //
// //         print("🎛️ Setting up formats")
// //         print("📹 Video: \(streamConfig.videoConfig.codec) \(videoWidth)x\(videoHeight) @ \(streamConfig.videoConfig.frameRate)fps")
// //         print("🔊 Audio: \(streamConfig.audioConfig.codec) \(streamConfig.audioConfig.sampleRate)Hz")
// //
// //         videoFormatDesc = createVideoFormatDescription(videoDescData)
// //         audioFormatDesc = createAudioFormatDescription(audioDescData, streamConfig.audioConfig)
// //
// //         if videoFormatDesc != nil {
// //             print("✅ Video format description created: \(videoWidth)x\(videoHeight)")
// //         } else {
// //             print("❌ Failed to create video format description")
// //         }
// //
// //         if audioFormatDesc != nil {
// //             print("✅ Audio format description created")
// //         } else {
// //             print("❌ Failed to create audio format description")
// //         }
// //     }
// //
// //     func decodeFrame(_ data: Data) {
// //         let frames = try! demuxer.processData(data: data)
// //
// //         if !frames.videoFrames.isEmpty {
// //             print("🎬 Decoded \(frames.videoFrames.count) video, \(frames.audioFrames.count) audio frames")
// //         }
// //
// //         for frame in frames.videoFrames {
// //             let timestamp = CMTime(value: Int64(frame.timestamp ?? 0), timescale: 90000)
// //             decodeVideoFrame(frame.data, timestamp: timestamp, isKeyframe: frame.isKeyframe)
// //         }
// //
// //         for frame in frames.audioFrames {
// //             let timestamp = CMTime(value: Int64(frame.timestamp ?? 0), timescale: 48000)
// //             decodeAudioFrame(frame.data, timestamp: timestamp)
// //         }
// //     }
// //
// //     private func createVideoFormatDescription(_ avcCData: Data) -> CMVideoFormatDescription? {
// //         let extensions: CFDictionary = [
// //             kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: [
// //                 "avcC": avcCData as CFData
// //             ]
// //         ] as CFDictionary
// //
// //         var formatDesc: CMVideoFormatDescription?
// //         let status = CMVideoFormatDescriptionCreate(
// //             allocator: kCFAllocatorDefault,
// //             codecType: kCMVideoCodecType_H264,
// //             width: Int32(videoWidth),      // FIX: Dùng từ config
// //             height: Int32(videoHeight),    // FIX: Dùng từ config
// //             extensions: extensions,
// //             formatDescriptionOut: &formatDesc
// //         )
// //
// //         guard status == noErr else {
// //             print("❌ Failed to create video format description: \(status)")
// //             return nil
// //         }
// //
// //         return formatDesc
// //     }
// //
// //     private func decodeVideoFrame(_ data: Data, timestamp: CMTime, isKeyframe: Bool) {
// //         guard let formatDesc = videoFormatDesc else {
// //             print("⚠️ Video format not configured")
// //             return
// //         }
// //
// //         var blockBuffer: CMBlockBuffer?
// //         var status = CMBlockBufferCreateWithMemoryBlock(
// //             allocator: kCFAllocatorDefault,
// //             memoryBlock: nil,
// //             blockLength: data.count,
// //             blockAllocator: kCFAllocatorDefault,
// //             customBlockSource: nil,
// //             offsetToData: 0,
// //             dataLength: data.count,
// //             flags: 0,
// //             blockBufferOut: &blockBuffer
// //         )
// //         guard status == noErr, let blockBuffer = blockBuffer else {
// //             print("❌ Failed to create video block buffer: \(status)")
// //             return
// //         }
// //
// //         status = data.withUnsafeBytes { ptr in
// //             CMBlockBufferReplaceDataBytes(
// //                 with: ptr.baseAddress!,
// //                 blockBuffer: blockBuffer,
// //                 offsetIntoDestination: 0,
// //                 dataLength: data.count
// //             )
// //         }
// //         guard status == noErr else {
// //             print("❌ Failed to replace video data: \(status)")
// //             return
// //         }
// //
// //         var timing = CMSampleTimingInfo(
// //             duration: CMTime(value: 1, timescale: 30),
// //             presentationTimeStamp: timestamp,
// //             decodeTimeStamp: .invalid
// //         )
// //
// //         var sampleBuffer: CMSampleBuffer?
// //         status = CMSampleBufferCreateReady(
// //             allocator: kCFAllocatorDefault,
// //             dataBuffer: blockBuffer,
// //             formatDescription: formatDesc,
// //             sampleCount: 1,
// //             sampleTimingEntryCount: 1,
// //             sampleTimingArray: &timing,
// //             sampleSizeEntryCount: 1,
// //             sampleSizeArray: [data.count],
// //             sampleBufferOut: &sampleBuffer
// //         )
// //         guard status == noErr, let sampleBuffer = sampleBuffer else {
// //             print("❌ Failed to create video sample buffer: \(status)")
// //             return
// //         }
// //
// //         // Mark keyframe
// //         if isKeyframe {
// //             if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? NSMutableArray {
// //                 let dict = attachments[0] as! NSMutableDictionary
// //                 dict[kCMSampleAttachmentKey_DependsOnOthers] = false
// //                 dict[kCMSampleAttachmentKey_IsDependedOnByOthers] = true
// //             }
// //         }
// //
// //         enqueueVideo(sampleBuffer, isKeyframe: isKeyframe)
// //     }
// //
// //     private func decodeAudioFrame(_ data: Data, timestamp: CMTime) {
// //         guard let formatDesc = audioFormatDesc else { return }
// //
// //         var audioData = data
// //         if isADTSHeader(data) {
// //             let headerSize = (data[1] & 0x01) == 0 ? 9 : 7
// //             audioData = data.subdata(in: headerSize..<data.count)
// //         }
// //
// //         var blockBuffer: CMBlockBuffer?
// //         var status = CMBlockBufferCreateWithMemoryBlock(
// //             allocator: kCFAllocatorDefault,
// //             memoryBlock: nil,
// //             blockLength: audioData.count,
// //             blockAllocator: kCFAllocatorDefault,
// //             customBlockSource: nil,
// //             offsetToData: 0,
// //             dataLength: audioData.count,
// //             flags: 0,
// //             blockBufferOut: &blockBuffer
// //         )
// //         guard status == noErr, let blockBuffer = blockBuffer else { return }
// //
// //         status = audioData.withUnsafeBytes { ptr in
// //             CMBlockBufferReplaceDataBytes(
// //                 with: ptr.baseAddress!,
// //                 blockBuffer: blockBuffer,
// //                 offsetIntoDestination: 0,
// //                 dataLength: audioData.count
// //             )
// //         }
// //         guard status == noErr else { return }
// //
// //         let currentTimestamp: CMTime
// //         if audioTimestamp == .zero {
// //             currentTimestamp = timestamp
// //         } else {
// //             currentTimestamp = CMTimeAdd(audioTimestamp, CMTime(value: 1024, timescale: 48000))
// //         }
// //         audioTimestamp = currentTimestamp
// //
// //         var packetDesc = AudioStreamPacketDescription(
// //             mStartOffset: 0,
// //             mVariableFramesInPacket: 0,
// //             mDataByteSize: UInt32(audioData.count)
// //         )
// //
// //         var sampleBuffer: CMSampleBuffer?
// //         status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
// //             allocator: kCFAllocatorDefault,
// //             dataBuffer: blockBuffer,
// //             formatDescription: formatDesc,
// //             sampleCount: 1,
// //             presentationTimeStamp: currentTimestamp,
// //             packetDescriptions: &packetDesc,
// //             sampleBufferOut: &sampleBuffer
// //         )
// //         guard status == noErr, let sampleBuffer = sampleBuffer else { return }
// //
// //         enqueueAudio(sampleBuffer)
// //     }
// //
// //     func getStreamConfig(config: String) -> StreamConfig? {
// //         do {
// //             return try JSONDecoder().decode(StreamConfig.self, from: Data(config.utf8))
// //         } catch {
// //             print("❌ JSON decode error: \(error)")
// //             return nil
// //         }
// //     }
// //
// //     private func createAudioFormatDescription(_ descData: Data, _ audioConfig: StreamConfig.AudioConfig) -> CMAudioFormatDescription? {
// //         let extensions: CFDictionary = [
// //             kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: [
// //                 "asc": descData as CFData
// //             ]
// //         ] as CFDictionary
// //
// //         var asbd = AudioStreamBasicDescription(
// //             mSampleRate: Float64(audioConfig.sampleRate),
// //             mFormatID: kAudioFormatMPEG4AAC,
// //             mFormatFlags: 0,
// //             mBytesPerPacket: 0,
// //             mFramesPerPacket: 1024,
// //             mBytesPerFrame: 0,
// //             mChannelsPerFrame: UInt32(audioConfig.numberOfChannels),
// //             mBitsPerChannel: 0,
// //             mReserved: 0
// //         )
// //
// //         var formatDesc: CMAudioFormatDescription?
// //         let status = CMAudioFormatDescriptionCreate(
// //             allocator: kCFAllocatorDefault,
// //             asbd: &asbd,
// //             layoutSize: 0,
// //             layout: nil,
// //             magicCookieSize: 0,
// //             magicCookie: nil,
// //             extensions: extensions,
// //             formatDescriptionOut: &formatDesc
// //         )
// //         guard status == noErr else {
// //             print("❌ Failed to create audio format description: \(status)")
// //             return nil
// //         }
// //         return formatDesc
// //     }
// //
// //     private func isADTSHeader(_ data: Data) -> Bool {
// //         guard data.count >= 2 else { return false }
// //         return data[0] == 0xFF && (data[1] & 0xF0) == 0xF0
// //     }
// //
// //     private func enqueueVideo(_ sampleBuffer: CMSampleBuffer, isKeyframe: Bool) {
// //         guard videoLayer.isReadyForMoreMediaData else {
// //             DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
// //                 self.enqueueVideo(sampleBuffer, isKeyframe: isKeyframe)
// //             }
// //             return
// //         }
// //
// //         videoLayer.enqueue(sampleBuffer)
// //         let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
// //         let icon = isKeyframe ? "🔑" : "📹"
// //         print("\(icon) Video enqueued at PTS: \(pts.seconds)s")
// //
// //         if !isPlaying {
// //             // Start playback ngay lập tức
// //             synchronizer.setRate(1.0, time: pts)
// //             isPlaying = true
// //             print("▶️ Playback started at \(pts.seconds)s")
// //         }
// //
// //         // Check layer status
// //         if videoLayer.status == .failed {
// //             print("❌ Video layer failed: \(videoLayer.error?.localizedDescription ?? "Unknown")")
// //         }
// //     }
// //
// //     private func enqueueAudio(_ sampleBuffer: CMSampleBuffer) {
// //         if audioRenderer.isReadyForMoreMediaData {
// //             audioRenderer.enqueue(sampleBuffer)
// //         } else {
// //             DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
// //                 self.enqueueAudio(sampleBuffer)
// //             }
// //         }
// //     }
// //
// //     func pausePlayback() {
// //         synchronizer.rate = 0
// //         print("⏸️ Playback paused")
// //     }
// //
// //     func resumePlayback() {
// //         synchronizer.rate = 1.0
// //         print("▶️ Playback resumed")
// //     }
// //
// //     func stopPlayback() {
// //         print("⏹️ Stopping playback...")
// //         synchronizer.rate = 0
// //         videoLayer.flush()
// //         audioRenderer.flush()
// //         isPlaying = false
// //         audioTimestamp = .zero
// //     }
// //
// //     deinit {
// //         stopPlayback()
// //     }
// // }
// //
// // // MARK: - Models
// //
// // struct StreamConfig: Codable {
// //     let type: String?
// //     let videoConfig: VideoConfig
// //     let audioConfig: AudioConfig
// //
// //     struct VideoConfig: Codable {
// //         let codec: String
// //         let codedWidth: Int
// //         let codedHeight: Int
// //         let frameRate: Double
// //         let description: String
// //     }
// //
// //     struct AudioConfig: Codable {
// //         let sampleRate: Int
// //         let numberOfChannels: Int
// //         let codec: String
// //         let description: String
// //     }
// // }
// import Flutter
// import UIKit
// import AVFoundation
// import Starscream
// import Swifter
//
// typealias StarscreamWebSocket = Starscream.WebSocket
//
// public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
//     private var webSocket: StarscreamWebSocket?
//     private var playerViewController: Fmp4PlayerViewController?
//
//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let channel = FlutterMethodChannel(name: "fmp4_stream_player", binaryMessenger: registrar.messenger())
//         let instance = Fmp4StreamPlayerPlugin()
//         registrar.addMethodCallDelegate(instance, channel: channel)
//
//         let factory = Fmp4StreamPlayerViewFactory(messenger: registrar.messenger(), plugin: instance)
//         registrar.register(factory, withId: "fmp4_stream_player_view")
//     }
//
//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//         case "startStreaming":
//             guard let args = call.arguments as? [String: Any],
//                   let streamId = args["streamId"] as? String,
//                   let token = args["token"] as? String else {
//                 result(FlutterError(code: "INVALID_ARGS", message: "Missing streamId or token", details: nil))
//                 return
//             }
//             startStreaming(streamId: streamId, token: token, result: result)
//
//         case "stopStreaming":
//             stopStreaming(result: result)
//
//         case "resumeView":
//             playerViewController?.resumePlayback()
//             result(true)
//
//         case "pauseView":
//             playerViewController?.pausePlayback()
//             result(true)
//
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
//
//     private func startStreaming(streamId: String, token: String, result: @escaping FlutterResult) {
//         playerViewController?.startStreaming(streamId: streamId, token: token)
//         result(true)
//     }
//
//     private func stopStreaming(result: @escaping FlutterResult) {
//         playerViewController?.stopStreaming()
//         webSocket?.disconnect()
//         webSocket = nil
//         result(true)
//     }
//
//     func setPlayerViewController(_ controller: Fmp4PlayerViewController) {
//         self.playerViewController = controller
//     }
// }
//
// MARK: - Platform View Factory

// class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
//     private let messenger: FlutterBinaryMessenger
//     private weak var plugin: Fmp4StreamPlayerPlugin?
//
//     init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
//         self.messenger = messenger
//         self.plugin = plugin
//     }
//
//     func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
//         let controller = Fmp4PlayerViewController(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
//         plugin?.setPlayerViewController(controller)
//         return controller
//     }
//
//     func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
//         return FlutterStandardMessageCodec.sharedInstance()
//     }
// }
//
// // MARK: - Player View Controller with HLS Proxy
//
// class Fmp4PlayerViewController: NSObject, FlutterPlatformView {
//     private let containerView: UIView
//     private var playerLayer: AVPlayerLayer!
//     private var player: AVPlayer?
//
//     private var webSocket: StarscreamWebSocket?
//     private var proxyServer: HttpServer?
//     private let tmpDir = FileManager.default.temporaryDirectory
//     private var hlsDir: URL!
//
//     private var segmentBuffer: [Data] = []
//     private var segmentCount = 0
//     private var lastPushTime = CACurrentMediaTime()
//     private let segmentDuration: Double = 1.1
//     private var isStreamEnded = false
//     private var isPlayerStarted = false
//
//     init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger) {
//         containerView = UIView(frame: frame)
//         containerView.backgroundColor = .black
//
//         super.init()
//
//         setupHLSDirectory()
//         setupProxyServer()
//         setupPlayer()
//     }
//
//     func view() -> UIView {
//         containerView
//     }
//
//     private func setupHLSDirectory() {
//         hlsDir = tmpDir.appendingPathComponent("hls_\(UUID().uuidString)")
//         try? FileManager.default.createDirectory(at: hlsDir, withIntermediateDirectories: true)
//         print("📁 HLS directory: \(hlsDir.path)")
//     }
//
//     private func setupProxyServer() {
//         proxyServer = HttpServer()
//
//         // Serve HLS files
//         proxyServer?["/:path"] = shareFilesFromDirectory(hlsDir.path)
//
//         do {
//             try proxyServer?.start(8080)
//             print("🌐 Proxy server started on port 8080")
//         } catch {
//             print("❌ Failed to start proxy server: \(error)")
//         }
//     }
//
//     private func setupPlayer() {
//         player = AVPlayer()
//         playerLayer = AVPlayerLayer(player: player)
//         playerLayer.frame = containerView.bounds
//         playerLayer.videoGravity = .resizeAspect
//         containerView.layer.addSublayer(playerLayer)
//
//         print("🎥 AVPlayer setup completed")
//     }
//
//     func startStreaming(streamId: String, token: String) {
//         let wsUrl = "wss://sfu-do-streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)"
//
//         guard let url = URL(string: wsUrl) else {
//             print("❌ Invalid WebSocket URL")
//             return
//         }
//
//         var request = URLRequest(url: url)
//         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//         request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")
//         request.timeoutInterval = 30
//
//         webSocket = StarscreamWebSocket(request: request)
//         webSocket?.delegate = self
//         webSocket?.connect()
//
//         print("🚀 WebSocket connecting...")
//     }
//
//     private func handleBinaryData(_ data: Data) {
//         let cleanData = data.dropFirst() // Remove 0x01 header
//
//         // Check if init segment (ftyp box)
//         if isInitSegment(cleanData) {
//             saveInitSegment(cleanData)
//             return
//         }
//
//         // Append to buffer
//         segmentBuffer.append(Data(cleanData))
//
//         // Write segment periodically
//         let now = CACurrentMediaTime()
//         if now - lastPushTime > segmentDuration {
//             writeBufferToSegment()
//             updatePlaylist()
//             lastPushTime = now
//
//             // Start player after first segment
//             if segmentCount == 1 && !isPlayerStarted {
//                 startPlayer()
//             }
//         }
//     }
//
//     private func isInitSegment(_ data: Data) -> Bool {
//         guard data.count > 8 else { return false }
//         let ftypRange = 4..<8
//         if let ftyp = String(data: data.subdata(in: ftypRange), encoding: .ascii) {
//             return ftyp == "ftyp"
//         }
//         return false
//     }
//
//     private func saveInitSegment(_ data: Data) {
//         let initUrl = hlsDir.appendingPathComponent("init.mp4")
//         do {
//             try data.write(to: initUrl)
//             print("💾 Saved init segment: \(data.count) bytes")
//         } catch {
//             print("❌ Failed to save init segment: \(error)")
//         }
//     }
//
//     private func writeBufferToSegment() {
//         guard !segmentBuffer.isEmpty else { return }
//
//         var segmentData = Data()
//         segmentBuffer.forEach { segmentData.append($0) }
//
//         let segmentName = "segment-\(segmentCount).m4s"
//         let segmentUrl = hlsDir.appendingPathComponent(segmentName)
//
//         do {
//             try segmentData.write(to: segmentUrl)
//             print("💾 Saved segment \(segmentCount): \(segmentData.count) bytes")
//             segmentBuffer.removeAll()
//             segmentCount += 1
//         } catch {
//             print("❌ Failed to save segment: \(error)")
//         }
//     }
//
//     private func updatePlaylist() {
//         var playlist = "#EXTM3U\n"
//         playlist += "#EXT-X-VERSION:7\n"
//         playlist += "#EXT-X-TARGETDURATION:3\n"
//
//         // Keep only last 5 segments
//         let startSegment = max(0, segmentCount - 5)
//         playlist += "#EXT-X-MEDIA-SEQUENCE:\(startSegment)\n"
//
//         // Init segment
//         playlist += "#EXT-X-MAP:URI=\"init.mp4\"\n"
//
//         // Media segments
//         for i in startSegment..<segmentCount {
//             playlist += "#EXTINF:\(segmentDuration),\n"
//             playlist += "segment-\(i).m4s\n"
//         }
//
//         if isStreamEnded {
//             playlist += "#EXT-X-ENDLIST\n"
//         }
//
//         let playlistUrl = hlsDir.appendingPathComponent("playlist.m3u8")
//         do {
//             try playlist.write(to: playlistUrl, atomically: true, encoding: .utf8)
//             print("📝 Updated playlist: \(segmentCount) segments")
//         } catch {
//             print("❌ Failed to write playlist: \(error)")
//         }
//     }
//
//     private func startPlayer() {
//         isPlayerStarted = true
//
//         let playlistURL = URL(string: "http://localhost:8080/playlist.m3u8")!
//         print("▶️ Starting player with URL: \(playlistURL)")
//
//         let asset = AVURLAsset(url: playlistURL)
//         let playerItem = AVPlayerItem(asset: asset)
//         playerItem.preferredForwardBufferDuration = 1.0
//         playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
//
//         player?.replaceCurrentItem(with: playerItem)
//         player?.automaticallyWaitsToMinimizeStalling = false
//
//         // Start playback after a short delay
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             self.player?.play()
//             print("▶️ Playback started")
//         }
//     }
//
//     func pausePlayback() {
//         player?.pause()
//         print("⏸️ Playback paused")
//     }
//
//     func resumePlayback() {
//         player?.play()
//         print("▶️ Playback resumed")
//     }
//
//     func stopStreaming() {
//         print("⏹️ Stopping stream...")
//         isStreamEnded = true
//         updatePlaylist()
//
//         webSocket?.disconnect()
//         webSocket = nil
//
//         player?.pause()
//         player?.replaceCurrentItem(with: nil)
//
//         // Cleanup
//         proxyServer?.stop()
//         try? FileManager.default.removeItem(at: hlsDir)
//
//         isPlayerStarted = false
//         segmentCount = 0
//         segmentBuffer.removeAll()
//     }
//
//     deinit {
//         stopStreaming()
//     }
// }
//
// // MARK: - WebSocket Delegate
//
// extension Fmp4PlayerViewController: Starscream.WebSocketDelegate {
//     func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
//         switch event {
//         case .connected:
//             print("✅ WebSocket connected")
//
//         case .disconnected(let reason, let code):
//             print("❌ WebSocket disconnected: \(reason) code: \(code)")
//
//         case .text(let text):
//             if text.contains("TotalViewerCount") {
//                 if let data = text.data(using: .utf8),
//                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                    let viewers = json["total_viewers"] as? Int {
//                     print("👥 Total viewers: \(viewers)")
//                 }
//             }
//
//         case .binary(let data):
//             guard !data.isEmpty else { return }
//             handleBinaryData(data)
//
//         case .error(let error):
//             print("⚠️ WebSocket error: \(String(describing: error))")
//
//         case .cancelled:
//             print("🚫 WebSocket cancelled")
//
//         default:
//             break
//         }
//     }
// }
// import Flutter
// import UIKit
// import AVFoundation
// import Starscream
// import Swifter
//
// public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
//     private var playerViewController: Fmp4PlayerViewController?
//
//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let channel = FlutterMethodChannel(name: "fmp4_stream_player",
//                                            binaryMessenger: registrar.messenger())
//         let instance = Fmp4StreamPlayerPlugin()
//         registrar.addMethodCallDelegate(instance, channel: channel)
//
//         let factory = Fmp4StreamPlayerViewFactory(messenger: registrar.messenger(),
//                                                   plugin: instance)
//         registrar.register(factory, withId: "fmp4_stream_player_view")
//     }
//
//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//
//         case "playUrl":
//             guard let args = call.arguments as? [String: Any],
//                   let urlString = args["url"] as? String else {
//                 result(FlutterError(code: "INVALID_ARGS",
//                                     message: "Missing url",
//                                     details: nil))
//                 return
//             }
//             playUrl(urlString: urlString, result: result)
//
//         case "stop":
//             playerViewController?.stop()
//             result(true)
//
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
//
//     private func playUrl(urlString: String, result: @escaping FlutterResult) {
//         playerViewController?.playUrl(urlString: urlString)
//         result(true)
//     }
//
//     func setPlayerViewController(_ controller: Fmp4PlayerViewController) {
//         self.playerViewController = controller
//     }
// }
//
//
// class Fmp4PlayerViewController: UIViewController {
//
//     private var playerLayer: AVPlayerLayer!
//     private var player: AVPlayer?
//
//     private var webSocket: StarscreamWebSocket?
//     private var proxyServer: HttpServer?
//
//     private let tmpDir = FileManager.default.temporaryDirectory
//     private var hlsDir: URL!
//
//     private var segmentBuffer: [Data] = []
//     private var segmentCount = 0
//     private var lastPushTime = CACurrentMediaTime()
//     private let segmentDuration: Double = 1.1
//     private var isStreamEnded = false
//     private var isPlayerStarted = false
//
//     override func viewDidLoad() {
//         super.viewDidLoad()
//         view.backgroundColor = .black
//
//         setupHLSDirectory()
//         setupProxyServer()
//         setupPlayer()
//     }
//
//     override func viewDidLayoutSubviews() {
//         super.viewDidLayoutSubviews()
//         playerLayer?.frame = view.bounds
//     }
//
//     // MARK: - Setup
//     private func setupHLSDirectory() {
//         hlsDir = tmpDir.appendingPathComponent("hls_\(UUID().uuidString)")
//         try? FileManager.default.createDirectory(at: hlsDir, withIntermediateDirectories: true)
//         print("📁 HLS directory: \(hlsDir.path)")
//     }
//
//     private func setupProxyServer() {
//         proxyServer = HttpServer()
//         proxyServer?["/:path"] = shareFilesFromDirectory(hlsDir.path)
//
//         do {
//             try proxyServer?.start(8080)
//             print("🌐 Proxy server started on 8080")
//         } catch {
//             print("❌ Proxy start error: \(error)")
//         }
//     }
//
//     private func setupPlayer() {
//         player = AVPlayer()
//
//         playerLayer = AVPlayerLayer(player: player)
//         playerLayer.videoGravity = .resizeAspect
//         playerLayer.frame = view.bounds
//
//         view.layer.addSublayer(playerLayer)
//
//         print("🎥 AVPlayer ready")
//     }
//
//     // MARK: - Streaming
//     func startStreaming(streamId: String, token: String) {
//         let wsUrl = "wss://sfu-do-streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)"
//
//         var req = URLRequest(url: URL(string: wsUrl)!)
//         req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//         req.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")
//         req.timeoutInterval = 15
//
//         webSocket = StarscreamWebSocket(request: req)
//         webSocket?.delegate = self
//         webSocket?.connect()
//
//         print("🚀 WebSocket connecting…")
//     }
//
//     private func handleBinaryData(_ raw: Data) {
//         let data = raw.dropFirst()
//
//         if isInitSegment(data) {
//             saveInitSegment(data)
//             return
//         }
//
//         segmentBuffer.append(Data(data))
//
//         let now = CACurrentMediaTime()
//         if now - lastPushTime > segmentDuration {
//             writeBufferToSegment()
//             updatePlaylist()
//             lastPushTime = now
//
//             if segmentCount == 1 && !isPlayerStarted {
//                 startPlayer()
//             }
//         }
//     }
//
//     private func isInitSegment(_ d: Data) -> Bool {
//         guard d.count > 8 else { return false }
//         return String(data: d[4..<8], encoding: .ascii) == "ftyp"
//     }
//
//     private func saveInitSegment(_ d: Data) {
//         let file = hlsDir.appendingPathComponent("init.mp4")
//         try? d.write(to: file)
//         print("💾 Init segment saved (\(d.count) bytes)")
//     }
//
//     private func writeBufferToSegment() {
//         guard !segmentBuffer.isEmpty else { return }
//
//         var final = Data()
//         segmentBuffer.forEach { final.append($0) }
//
//         let name = "segment-\(segmentCount).m4s"
//         let url = hlsDir.appendingPathComponent(name)
//
//         try? final.write(to: url)
//         print("💾 Segment \(segmentCount) saved")
//
//         segmentBuffer.removeAll()
//         segmentCount += 1
//     }
//
//     private func updatePlaylist() {
//         var m3u = """
//         #EXTM3U
//         #EXT-X-VERSION:7
//         #EXT-X-TARGETDURATION:3
//         #EXT-X-MEDIA-SEQUENCE:\(max(0, segmentCount - 5))
//         #EXT-X-MAP:URI="init.mp4"
//         """
//
//         for i in max(0, segmentCount - 5)..<segmentCount {
//             m3u += "\n#EXTINF:\(segmentDuration),\nsegment-\(i).m4s"
//         }
//
//         if isStreamEnded { m3u += "\n#EXT-X-ENDLIST" }
//
//         try? m3u.write(to: hlsDir.appendingPathComponent("playlist.m3u8"),
//                        atomically: true,
//                        encoding: .utf8)
//
//         print("📝 Playlist updated")
//     }
//
//     private func startPlayer() {
//         isPlayerStarted = true
//
//         let url = URL(string: "http://localhost:8080/playlist.m3u8")!
//         let asset = AVURLAsset(url: url)
//
//         let item = AVPlayerItem(asset: asset)
//         item.preferredForwardBufferDuration = 0.5
//         item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
//
//         player?.replaceCurrentItem(with: item)
//
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//             self.player?.play()
//         }
//
//         print("▶️ HLS playback started")
//     }
//
//     // MARK: Controls
//     func pausePlayback() { player?.pause() }
//     func resumePlayback() { player?.play() }
//
//     func stopStreaming() {
//         print("⏹️ stop streaming")
//
//         isStreamEnded = true
//         updatePlaylist()
//
//         webSocket?.disconnect()
//         webSocket = nil
//
//         player?.pause()
//         player?.replaceCurrentItem(with: nil)
//
//         proxyServer?.stop()
//         try? FileManager.default.removeItem(at: hlsDir)
//
//         isPlayerStarted = false
//         segmentCount = 0
//         segmentBuffer.removeAll()
//     }
//
//     deinit {
//         stopStreaming()
//         print("🧹 deinit Fmp4PlayerViewController")
//     }
// }
//
// public class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
//     private var messenger: FlutterBinaryMessenger
//     private weak var plugin: Fmp4StreamPlayerPlugin?
//
//     // Sử dụng codec chuẩn để nhận args từ Flutter nếu cần
//     public init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
//         self.messenger = messenger
//         self.plugin = plugin
//         super.init()
//     }
//
//     // Codec
//     public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
//         return FlutterStandardMessageCodec.sharedInstance()
//     }
//
//     // Tạo platform view
//     public func create(withFrame frame: CGRect,
//                        viewIdentifier viewId: Int64,
//                        arguments args: Any?) -> FlutterPlatformView {
//         return Fmp4StreamPlayerPlatformView(frame: frame,
//                                             viewId: viewId,
//                                             args: args,
//                                             messenger: messenger,
//                                             plugin: plugin)
//     }
// }
//
// // Platform view trả về một UIView cho Flutter hiển thị
// class Fmp4StreamPlayerPlatformView: NSObject, FlutterPlatformView {
//     private var containerView: UIView
//     private var controller: Fmp4PlayerViewController
//     private weak var plugin: Fmp4StreamPlayerPlugin?
//
//     init(frame: CGRect,
//          viewId: Int64,
//          args: Any?,
//          messenger: FlutterBinaryMessenger,
//          plugin: Fmp4StreamPlayerPlugin?) {
//
//         self.containerView = UIView(frame: frame)
//         self.plugin = plugin
//
//         // Giữ strong reference
//         self.controller = Fmp4PlayerViewController()
//
//         super.init()
//
//         // nhúng controller vào root để lifecycle hoạt động
//         if let root = UIApplication.shared.windows.first?.rootViewController {
//             root.addChild(controller)
//             controller.didMove(toParent: root)
//         }
//
//         controller.view.frame = containerView.bounds
//         controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//         containerView.addSubview(controller.view)
//
//         // báo plugin
//         plugin?.setPlayerViewController(controller)
//     }
//
//     func view() -> UIView {
//         return containerView
//     }
// }



import Flutter
import UIKit
import AVFoundation
import Swifter

// ---------------------
// MARK: - Plugin
// ---------------------
public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
    private var playerLib: NativeFmp4PlayerLib?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fmp4_stream_player",
                                           binaryMessenger: registrar.messenger())
        let instance = Fmp4StreamPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let factory = Fmp4StreamPlayerViewFactory(messenger: registrar.messenger(),
                                                  plugin: instance)
        registrar.register(factory, withId: "fmp4_stream_player_view")
    }

    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startStreaming":
            guard let args = call.arguments as? [String: Any],
                  let streamId = args["streamId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing streamId", details: nil))
                return
            }
            NativeFmp4PlayerLib.streamId = streamId
            if #available(iOS 16.0, *) {
                playerLib?.startStreaming()
            } else {
                // Fallback on earlier versions
                print("error===============>")
            }
            result(true)

        case "stopStreaming":
            playerLib?.stopStreaming()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func setPlayerLib(_ lib: NativeFmp4PlayerLib) {
        self.playerLib = lib
    }
}

// ---------------------
// MARK: - Platform View Factory + Platform View
// ---------------------
public class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private weak var plugin: Fmp4StreamPlayerPlugin?

    public init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
        self.messenger = messenger
        self.plugin = plugin
        super.init()
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    public func create(withFrame frame: CGRect,
                       viewIdentifier viewId: Int64,
                       arguments args: Any?) -> FlutterPlatformView {
        return Fmp4StreamPlayerPlatformView(frame: frame,
                                            viewId: viewId,
                                            messenger: messenger,
                                            plugin: plugin)
    }
}

public class Fmp4StreamPlayerPlatformView: NSObject, FlutterPlatformView {
    private var containerView: UIView
    private var playerLib: NativeFmp4PlayerLib
    private weak var plugin: Fmp4StreamPlayerPlugin?

    init(frame: CGRect,
         viewId: Int64,
         messenger: FlutterBinaryMessenger,
         plugin: Fmp4StreamPlayerPlugin?) {

        self.containerView = UIView(frame: frame)
        self.playerLib = NativeFmp4PlayerLib()
        self.plugin = plugin
        super.init()

        // gắn AVPlayer vào view
        Fmp4AVPlayerView.AttachToView(containerView)
        plugin?.setPlayerLib(playerLib)
    }

    public func view() -> UIView {
        return containerView
    }
}

// ---------------------
// MARK: - AVPlayer Layer Helper
// ---------------------
@objcMembers
public class Fmp4AVPlayerView: UIView {
    private static var playerLayer: AVPlayerLayer?

    public static func AttachPlayerToLayer(avplayer: AVPlayer) {
        guard let rootView = getRootView() else { return }
        let layer = AVPlayerLayer(player: avplayer)
        layer.frame = rootView.bounds
        layer.videoGravity = .resizeAspect
        DispatchQueue.main.async {
            playerLayer?.player = avplayer
            layer.addSublayer(self.playerLayer!)
           }
    }

    public static func AttachToView(_ view: UIView) {
        playerLayer?.removeFromSuperlayer()
        let layer = AVPlayerLayer()
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        playerLayer = layer
    }

    private static func getRootView() -> UIView? {
        var rootView: UIView?
        if Thread.isMainThread {
            rootView = fetchRootView()
        } else {
            DispatchQueue.main.sync {
                rootView = fetchRootView()
            }
        }
        return rootView
    }

    private static func fetchRootView() -> UIView? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?.rootViewController?.view
        } else {
            return UIApplication.shared.keyWindow?.rootViewController?.view
        }
    }
}

// ---------------------
// MARK: - Native FMP4 Player
// ---------------------
@objcMembers
public class NativeFmp4PlayerLib: NSObject {
    public static var streamId : String?
    private var url : URL?
    private var socketSession : URLSession?
    private var socketTask : URLSessionWebSocketTask?
    private static var player : AVPlayer?
    private let SEGMENT_DURATION : Double = 1.1
    private var LastPushSegmentTime = CACurrentMediaTime()
    private var hlsDir : URL
    private var segmentCount = 0
    private var endStream = false
    private var connectStream = false
    private var SegmentBuffer : [Data]
    private var initSegment : Data?
    private var proxyServer : HttpServer?

    override init() {
        self.socketSession = nil
        self.socketTask = nil
        self.hlsDir = FileManager.default.temporaryDirectory.appendingPathComponent("hls_\(UUID().uuidString)")
        self.SegmentBuffer = []
        self.proxyServer = HttpServer()
        super.init()
    }

    
    @available(iOS 16.0, *)
    public func startStreaming() {
        try? FileManager.default.createDirectory(at: hlsDir, withIntermediateDirectories: true)
        proxyServer?["/:path"] = shareFilesFromDirectory(hlsDir.path())
        try? proxyServer?.start(8080)

        guard let streamId = NativeFmp4PlayerLib.streamId else { return }
        url = URL(string: "wss://sfu-do-streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)")
        var request = URLRequest(url: url!)
        request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        self.socketSession = URLSession(configuration: .default)
        self.socketTask = socketSession?.webSocketTask(with: request)
        readMessage()
    }

    public func stopStreaming() {
        socketTask?.cancel(with: .goingAway, reason: nil)
        endStream = true
    }

    private func isInitSegment(_ data: Data) -> Bool {
        return data.count > 8 && String(data: data.subdata(in: 5..<9), encoding: .ascii) == "ftyp"
    }

    private func appendBuffer(_ buffer: Data) {
        if isInitSegment(buffer) {
            let initUrl = hlsDir.appendingPathComponent("init.mp4")
            try? buffer.write(to: initUrl)
            return
        }

        SegmentBuffer.append(buffer)
        let now = CACurrentMediaTime()
        if now - LastPushSegmentTime > SEGMENT_DURATION {
            WriteBufferToSegment()
            LastPushSegmentTime = now
        }
    }

    private func WriteBufferToSegment() {
        var segmentData = Data()
        let segmentName = "segment-\(segmentCount).m4s"
    
        print("------------------WriteBufferToSegment")
        let segmentURL = hlsDir.appendingPathComponent(segmentName)
        SegmentBuffer.forEach { segmentData.append($0) }
        try? segmentData.write(to: segmentURL)
        SegmentBuffer.removeAll()
        segmentCount += 1
    }

    private func startPlayer() {
        connectStream = true
        let playlistURL = URL(string: "http://localhost:8080/playlist.m3u8")!
        let asset = AVURLAsset(url: playlistURL)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 1.0
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        NativeFmp4PlayerLib.player = AVPlayer(playerItem: playerItem)
        NativeFmp4PlayerLib.player?.automaticallyWaitsToMinimizeStalling = false
        Fmp4AVPlayerView.AttachPlayerToLayer(avplayer: NativeFmp4PlayerLib.player!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("------------------startPlayer")
            NativeFmp4PlayerLib.player?.play()
        }
    }

    @available(iOS 16.0, *)
    private func readMessage() {
        socketTask?.resume()
        socketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error): print("WebSocket fail: \(error)")
            case .success(let message):
                switch message {
                case .data(let data):
                    guard !data.isEmpty else { break }
//                    self.appendBuffer(data.dropFirst())
//                    self.updatePlaylist()
                    self.sendFrameToAVPlayer(data.dropFirst())
                case .string(_): break
                @unknown default: break
                }
            }
            self.readMessage()
        }
    }
    
    @available(iOS 16.0, *)
      private func sendFrameToAVPlayer(_ data: Data) {
        appendBuffer(data)
        var playlist = "#EXTM3U\n"
        playlist.append("#EXT-X-VERSION:7\n")
        playlist.append("#EXT-X-TARGETDURATION:3\n")
        
        // Keep only last 5 segments
        let startSegment = max(0, segmentCount - 5)
        playlist.append("#EXT-X-MEDIA-SEQUENCE:\(startSegment)\n")

        playlist.append("#EXT-X-MAP:URI=\"init.mp4\"\n")
        
        for i in max(0, segmentCount - 5)..<segmentCount {
          playlist.append("#EXTINF:\(Double(round(1000*1.100)/1000)),\n")
          playlist.append("/segment-\(i).m4s\n")
        }
        if endStream {
          playlist.append("#EXT-X-ENDLIST")
        }
        
        let playlistUrl = hlsDir.appendingPathComponent("playlist.m3u8")
        try? playlist.write(toFile: playlistUrl.path(), atomically: true, encoding: .utf8)
        if(segmentCount == 1 && !connectStream) {
          startPlayer()
        }
      }

    private func updatePlaylist() {
        var playlist = "#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:3\n"
        let startSegment = max(0, segmentCount - 5)
        playlist.append("#EXT-X-MEDIA-SEQUENCE:\(startSegment)\n")
        playlist.append("#EXT-X-MAP:URI=\"init.mp4\"\n")
        for i in startSegment..<segmentCount {
            playlist.append("#EXTINF:\(SEGMENT_DURATION),\n")
            playlist.append("/segment-\(i).m4s\n")
        }
        if endStream {
            playlist.append("#EXT-X-ENDLIST")
        }

        let playlistUrl = hlsDir.appendingPathComponent("playlist.m3u8")
        print("--------------->")
        
        try? playlist.write(to: playlistUrl, atomically: true, encoding: .utf8)
        
        if segmentCount == 1 && !connectStream {
            startPlayer()
        }
    }
}
