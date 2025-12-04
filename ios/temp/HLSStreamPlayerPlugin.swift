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
// public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
//     private var playerLib: NativeFmp4PlayerLib?
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
//
//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//         case "startStreaming":
//             guard let args = call.arguments as? [String: Any],
//                   let streamId = args["streamId"] as? String else {
//                 result(FlutterError(code: "INVALID_ARGS", message: "Missing streamId", details: nil))
//                 return
//             }
//             NativeFmp4PlayerLib.streamId = streamId
//
//             if #available(iOS 16.0, *) {
//                 playerLib?.startStreaming()
//             } else {
//                 // Fallback on earlier versions
//                 print("error===============>")
//             }
//             result(true)
//
//         case "stopStreaming":
//             playerLib?.stopStreaming()
//             result(true)
//
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
//
//     func setPlayerLib(_ lib: NativeFmp4PlayerLib) {
//         self.playerLib = lib
//     }
// }
//
// // ---------------------
// // MARK: - Platform View Factory + Platform View
// // ---------------------
// public class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
//     private var messenger: FlutterBinaryMessenger
//     private weak var plugin: Fmp4StreamPlayerPlugin?
//
//     public init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
//         self.messenger = messenger
//         self.plugin = plugin
//         super.init()
//     }
//
//     public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
//         return FlutterStandardMessageCodec.sharedInstance()
//     }
//
//     public func create(withFrame frame: CGRect,
//                        viewIdentifier viewId: Int64,
//                        arguments args: Any?) -> FlutterPlatformView {
//         return Fmp4StreamPlayerPlatformView(frame: frame,
//                                             viewId: viewId,
//                                             messenger: messenger,
//                                             plugin: plugin)
//     }
// }
//
// public class Fmp4StreamPlayerPlatformView: NSObject, FlutterPlatformView {
//     private var containerView: UIView
//     private var playerLib: NativeFmp4PlayerLib
//     private weak var plugin: Fmp4StreamPlayerPlugin?
//
//     init(frame: CGRect,
//          viewId: Int64,
//          messenger: FlutterBinaryMessenger,
//          plugin: Fmp4StreamPlayerPlugin?) {
//
//         self.containerView = UIView(frame: frame)
//         self.playerLib = NativeFmp4PlayerLib()
//         self.plugin = plugin
//         super.init()
//
//         // gắn AVPlayer vào view
//         Fmp4AVPlayerView.AttachToView(containerView)
//         plugin?.setPlayerLib(playerLib)
//     }
//
//     public func view() -> UIView {
//         return containerView
//     }
// }
//
// // ---------------------
// // MARK: - AVPlayer Layer Helper
// // ---------------------
// @objcMembers
// public class Fmp4AVPlayerView: UIView {
//     private static var playerLayer: AVPlayerLayer?
//
//     public static func AttachPlayerToLayer(avplayer: AVPlayer) {
//         guard let rootView = getRootView() else { return }
//         let layer = AVPlayerLayer(player: avplayer)
//         layer.frame = rootView.bounds
//         layer.videoGravity = .resizeAspect
//         DispatchQueue.main.async {
//             playerLayer?.player = avplayer
//         }
//     }
//
//     public static func AttachToView(_ view: UIView) {
//         playerLayer?.removeFromSuperlayer()
//         let layer = AVPlayerLayer()
//         layer.frame = view.bounds
//         layer.videoGravity = .resizeAspect
//         view.layer.addSublayer(layer)
//         playerLayer = layer
//     }
//
//     private static func getRootView() -> UIView? {
//         var rootView: UIView?
//         if Thread.isMainThread {
//             rootView = fetchRootView()
//         } else {
//             DispatchQueue.main.sync {
//                 rootView = fetchRootView()
//             }
//         }
//         return rootView
//     }
//
//     private static func fetchRootView() -> UIView? {
//         if #available(iOS 13.0, *) {
//             return UIApplication.shared.connectedScenes
//                 .compactMap { $0 as? UIWindowScene }
//                 .flatMap { $0.windows }
//                 .first(where: { $0.isKeyWindow })?.rootViewController?.view
//         } else {
//             return UIApplication.shared.keyWindow?.rootViewController?.view
//         }
//     }
// }
//
// // ---------------------
// // MARK: - Native FMP4 Player
// // ---------------------
// @objcMembers
// public class NativeFmp4PlayerLib: NSObject {
//     public static var streamId : String?
//     private var url : URL?
//     private var socketSession : URLSession?
//     private var socketTask : URLSessionWebSocketTask?
//     private static var player : AVPlayer?
//     private let SEGMENT_DURATION : Double = 1.1
//     private var LastPushSegmentTime = CACurrentMediaTime()
//     private var hlsDir : URL
//     private var segmentCount = 0
//     private var endStream = false
//     private var connectStream = false
//     private var SegmentBuffer : [Data]
//     private var initSegment : Data?
//     private var proxyServer : HttpServer?
//
//     override init() {
//         self.socketSession = nil
//         self.socketTask = nil
//         self.hlsDir = FileManager.default.temporaryDirectory.appendingPathComponent("hls_\(UUID().uuidString)")
//         self.SegmentBuffer = []
//         self.proxyServer = HttpServer()
//         super.init()
//     }
//
//
//     @available(iOS 16.0, *)
//     public func startStreaming() {
//         try? FileManager.default.createDirectory(at: hlsDir, withIntermediateDirectories: true)
//         proxyServer?["/:path"] = shareFilesFromDirectory(hlsDir.path())
//
//         do {
//                 try proxyServer?.start(8080)
//                 print("✅ HTTP Server started on port 8080")
//             } catch {
//                 print("❌ Failed to start server: \(error)")
//             }
//
//         guard let streamId = NativeFmp4PlayerLib.streamId else { return }
//         url = URL(string: "wss://sfu-do-streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)")!
//         print("------> \(url)")
//         var request = URLRequest(url: url!)
//         request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")
//
//         self.socketSession = URLSession(configuration: .default)
//         self.socketTask = socketSession?.webSocketTask(with: request)
//         readMessage()
//     }
//
//     public func stopStreaming() {
//         socketTask?.cancel(with: .goingAway, reason: nil)
//         endStream = true
//     }
//
//     private func isInitSegment(_ data: Data) -> Bool {
//         // FMP4 init segment structure:
//         // [4 bytes size][4 bytes type "ftyp"]...
//         guard data.count > 8 else { return false }
//
//         // Read the box type at bytes 4-7 (0-indexed)
//         let boxTypeData = data.subdata(in: 4..<8)
//         let boxType = String(data: boxTypeData, encoding: .ascii) ?? ""
//
//         print("🔍 Checking init segment - Box type: '\(boxType)', size: \(data.count)")
//
//         // Init segment starts with ftyp box
//         return boxType == "ftyp"
//     }
//
//     private func appendBuffer(_ buffer: Data) {
//         SegmentBuffer.append(buffer)
//         let now = CACurrentMediaTime()
//
//         let totalSize = SegmentBuffer.reduce(0) { $0 + $1.count }
//         print("📊 Buffer: \(SegmentBuffer.count) chunks, \(totalSize) bytes")
//
//         // Write segment based on time or size
//         if now - LastPushSegmentTime > SEGMENT_DURATION || totalSize > 200000 {
//             WriteBufferToSegment()
//             LastPushSegmentTime = now
//         }
//     }
//
//     private func WriteBufferToSegment() {
//         guard !SegmentBuffer.isEmpty else {
//             print("⚠️ Buffer is empty, skip writing")
//             return
//         }
//
//         var segmentData = Data()
//         SegmentBuffer.forEach { segmentData.append($0) }
//
//         // ✅ Validate segment structure
//         if segmentData.count > 8 {
//             let boxType = String(data: segmentData.subdata(in: 4..<8), encoding: .ascii) ?? "????"
//             print("🔍 Segment \(segmentCount) first box: '\(boxType)'")
//
//             // Media segments should start with moof or styp
//             if boxType != "moof" && boxType != "styp" {
//                 print("⚠️ WARNING: Media segment doesn't start with moof/styp!")
//             }
//         }
//
//         let segmentURL = hlsDir.appendingPathComponent("segment-\(segmentCount).m4s")
//
//         do {
//             try segmentData.write(to: segmentURL)
//             print("✅ Segment \(segmentCount) saved: \(segmentData.count) bytes from \(SegmentBuffer.count) chunks")
//             SegmentBuffer.removeAll()
//             segmentCount += 1
//         } catch {
//             print("❌ Failed to write segment \(segmentCount): \(error)")
//         }
//     }
//
//     private func startPlayer() {
//         guard !connectStream else { return }
//         connectStream = true
//         let playlistURL = URL(string: "http://localhost:8080/playlist.m3u8")!
//         print("🎬 Starting player with playlist: \(playlistURL)")
//         DispatchQueue.main.async { [weak self] in
//                 guard let self = self else { return }
//
//                 // ✅ Config đặc biệt cho FMP4 live stream
//                         let asset = AVURLAsset(url: playlistURL, options: [
//                             AVURLAssetPreferPreciseDurationAndTimingKey: false,
//                             "AVURLAssetOutOfBandMIMETypeKey": "application/vnd.apple.mpegurl"
//                         ])
//
//                 let playerItem = AVPlayerItem(asset: asset)
//
//                 // ✅ Config quan trọng cho live streaming
//                 playerItem.preferredForwardBufferDuration = 3.0  // Buffer 2 giây
//                 playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
//
//                 NativeFmp4PlayerLib.player = AVPlayer(playerItem: playerItem)
//                 NativeFmp4PlayerLib.player?.automaticallyWaitsToMinimizeStalling = false
//                 NativeFmp4PlayerLib.player?.allowsExternalPlayback = false
//                  // ✅ Force video output
//                         if #available(iOS 11.0, *) {
//                             NativeFmp4PlayerLib.player?.preventsDisplaySleepDuringVideoPlayback = true
//                         }
//                 // ✅ Observe status để debug
//                 // Observe status
//                        playerItem.addObserver(self,
//                                              forKeyPath: "status",
//                                              options: [.new, .initial],
//                                              context: nil)
//
//                        // ✅ Observe tracks
//                        playerItem.addObserver(self,
//                                              forKeyPath: "tracks",
//                                              options: [.new],
//                                              context: nil)
//
//                 Fmp4AVPlayerView.AttachPlayerToLayer(avplayer: NativeFmp4PlayerLib.player!)
//
//                 // Đợi một chút để playlist update
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                     print("▶️ Player.play()")
//                     NativeFmp4PlayerLib.player?.play()
//                     NativeFmp4PlayerLib.player?.rate = 1.0
//                     // Debug video output
//                                 DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                                     self.debugPlayerState()
//                                 }
//                 }
//             }
//     }
//
//     private func debugPlayerState() {
//         guard let player = NativeFmp4PlayerLib.player else { return }
//         guard let item = player.currentItem else { return }
//
//         print("🎮 Player State:")
//         print("  - Rate: \(player.rate)")
//         print("  - Status: \(item.status.rawValue)")
//         print("  - Tracks: \(item.tracks.count)")
//
//         for (index, track) in item.tracks.enumerated() {
//             print("  - Track \(index): \(track.assetTrack?.mediaType.rawValue ?? "unknown")")
//         }
//
//         if let error = item.error {
//             print("  - Error: \(error.localizedDescription)")
//         }
//
//         // Check if video is being rendered
//         print("  - Duration: \(item.duration.seconds)")
//         print("  - Buffered: \(item.loadedTimeRanges)")
//     }
//
//    @available(iOS 16.0, *)
//    private func readMessage() {
//        socketTask?.resume()
//        print("🔵 WebSocket started, waiting for messages...")
//
//        socketTask?.receive { [weak self] result in
//            guard let self = self else { return }
//            switch result {
//            case .failure(let error):
//                print("❌ WebSocket fail: \(error)")
//            case .success(let message):
//                switch message {
//                case .data(let data):
//                    guard !data.isEmpty else { break }
//                    print("✅ Received data: \(data.count) bytes")
//                    self.sendFrameToAVPlayer(data.dropFirst())
//                case .string(let text):
//                    print("📝 Received string: \(text)")
//                @unknown default: break
//                }
//            }
//            self.readMessage()
//        }
//    }
//
//    private func analyzeInitSegment(_ data: Data) {
//       print("🔍 Analyzing init segment (\(data.count) bytes)...")
//
//           // Check for moov box (movie header)
//           let dataStr = String(data: data, encoding: .ascii) ?? ""
//
//           if dataStr.contains("moov") {
//               print("✅ Found moov box")
//           } else {
//               print("⚠️ No moov box found")
//           }
//
//           // Check for video track (vide)
//           if dataStr.contains("vide") {
//               print("✅ Found video track")
//           } else {
//               print("⚠️ No video track found")
//           }
//
//           // Check for audio track (soun)
//           if dataStr.contains("soun") {
//               print("✅ Found audio track")
//           } else {
//               print("⚠️ No audio track found")
//           }
//
//           // Check codec info
//           if dataStr.contains("avc1") {
//               print("✅ Video codec: H.264 (avc1)")
//           }
//           if dataStr.contains("mp4a") {
//               print("✅ Audio codec: AAC (mp4a)")
//           }
//    }
//
//     @available(iOS 16.0, *)
//       private func sendFrameToAVPlayer(_ data: Data) {
//       // ✅ Check init segment TRƯỚC KHI append buffer
//          if isInitSegment(data) {
//              initSegment = data
//              let initUrl = hlsDir.appendingPathComponent("init.mp4")
//
//              do {
//                  try data.write(to: initUrl)
//                  print("✅ Init segment saved to init.mp4: \(data.count) bytes")
//
//                  // Analyze init segment
//                  analyzeInitSegment(data)
//              } catch {
//                  print("❌ Failed to save init segment: \(error)")
//              }
//
//              // ✅ RETURN - không append vào buffer
//              return
//          }
//
//          // ✅ Log media segment info
//          if data.count > 8 {
//              let boxTypeData = data.subdata(in: 4..<8)
//              let boxType = String(data: boxTypeData, encoding: .ascii) ?? "????"
//              print("📦 Media segment - Box type: '\(boxType)', size: \(data.count) bytes")
//          }
//
//          // Append to buffer
//          appendBuffer(data)
//
//          // Create playlist
//          var playlist = "#EXTM3U\n"
//          playlist.append("#EXT-X-VERSION:7\n")
//          playlist.append("#EXT-X-TARGETDURATION:2\n")
//          playlist.append("#EXT-X-INDEPENDENT-SEGMENTS\n")
//
//          let startSegment = max(0, segmentCount - 8)
//          playlist.append("#EXT-X-MEDIA-SEQUENCE:\(startSegment)\n")
//
//          // ✅ CRITICAL: Init segment MUST exist
//          if initSegment != nil {
//              playlist.append("#EXT-X-MAP:URI=\"init.mp4\"\n")
//              print("✅ Playlist has init.mp4 map")
//          } else {
//              print("⚠️ WARNING: No init segment yet! Player will fail!")
//              return  // ✅ Không tạo playlist nếu chưa có init
//          }
//
//          // Add segments
//          for i in startSegment..<segmentCount {
//              playlist.append("#EXTINF:1.100,\n")
//              playlist.append("segment-\(i).m4s\n")
//          }
//
//          if endStream {
//              playlist.append("#EXT-X-ENDLIST\n")
//          }
//
//          let playlistUrl = hlsDir.appendingPathComponent("playlist.m3u8")
//
//          do {
//              try playlist.write(toFile: playlistUrl.path(), atomically: true, encoding: .utf8)
//              print("📝 Playlist updated with \(segmentCount) segments")
//
//              // Debug first few playlists
//              if segmentCount <= 3 {
//                  print("📄 Playlist content:\n\(playlist)")
//              }
//          } catch {
//              print("❌ Failed to write playlist: \(error)")
//          }
//
//          // Start player when ready
//          if segmentCount >= 3 && !connectStream && initSegment != nil {
//              print("🎬 Ready to start player with \(segmentCount) segments and init.mp4")
//              startPlayer()
//          }
//       }
//
//     private func updatePlaylist() {
//         var playlist = "#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:3\n"
//         let startSegment = max(0, segmentCount - 5)
//         playlist.append("#EXT-X-MEDIA-SEQUENCE:\(startSegment)\n")
//         playlist.append("#EXT-X-MAP:URI=\"init.mp4\"\n")
//         for i in startSegment..<segmentCount {
//             playlist.append("#EXTINF:\(SEGMENT_DURATION),\n")
//             playlist.append("/segment-\(i).m4s\n")
//         }
//         if endStream {
//             playlist.append("#EXT-X-ENDLIST")
//         }
//
//         let playlistUrl = hlsDir.appendingPathComponent("playlist.m3u8")
//         print("--------------->")
//
//         try? playlist.write(to: playlistUrl, atomically: true, encoding: .utf8)
//
//         if segmentCount == 1 && !connectStream {
//             startPlayer()
//         }
//     }
//
//     override public func observeValue(forKeyPath keyPath: String?,
//                                      of object: Any?,
//                                      change: [NSKeyValueChangeKey : Any]?,
//                                      context: UnsafeMutableRawPointer?) {
//         if keyPath == "status" {
//             if let playerItem = object as? AVPlayerItem {
//                 switch playerItem.status {
//                 case .readyToPlay:
//                     print("✅ PlayerItem ready to play")
//                     debugPlayerState()
//                 case .failed:
//                     print("❌ PlayerItem failed: \(playerItem.error?.localizedDescription ?? "unknown")")
//                     if let error = playerItem.error as NSError? {
//                         print("   Error code: \(error.code)")
//                         print("   Error domain: \(error.domain)")
//                     }
//                 case .unknown:
//                     print("⚠️ PlayerItem status unknown")
//                 @unknown default:
//                     break
//                 }
//             }
//         } else if keyPath == "tracks" {
//             if let playerItem = object as? AVPlayerItem {
//                 print("🎵 Tracks updated: \(playerItem.tracks.count) tracks")
//                 for track in playerItem.tracks {
//                     if let assetTrack = track.assetTrack {
//                         print("   - \(assetTrack.mediaType.rawValue)")
//                         if assetTrack.mediaType == .video {
//                             print("     Video size: \(assetTrack.naturalSize)")
//                             print("     Video enabled: \(track.isEnabled)")
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }

import Flutter
import UIKit
import AVFoundation
import Swifter

// ---------------------
// MARK: - Plugin
// ---------------------
public class HLSStreamPlayerPlugin: NSObject, FlutterPlugin {
    private var playerLib: NativeFmp4PlayerLib?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fmp4_stream_player",
                                           binaryMessenger: registrar.messenger())
        let instance = HLSStreamPlayerPlugin()
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
                result(true)
            } else {
                result(FlutterError(code: "UNSUPPORTED_OS", message: "iOS 16+ required", details: nil))
            }

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
    private weak var plugin: HLSStreamPlayerPlugin?

    public init(messenger: FlutterBinaryMessenger, plugin: HLSStreamPlayerPlugin) {
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
    private weak var plugin: HLSStreamPlayerPlugin?

    init(frame: CGRect,
         viewId: Int64,
         messenger: FlutterBinaryMessenger,
         plugin: HLSStreamPlayerPlugin?) {

        self.containerView = UIView(frame: frame)
        self.playerLib = NativeFmp4PlayerLib()
        self.plugin = plugin
        super.init()

        // Gắn AVPlayerLayer vào view đúng cách
        Fmp4AVPlayerView.attachToView(containerView)
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

    // Gắn player vào layer hiện có (nếu đã add) hoặc tạo mới và add vào root view
    public static func attachPlayerToLayer(avplayer: AVPlayer) {
        DispatchQueue.main.async {
            if let layer = playerLayer {
                layer.player = avplayer
            } else if let rootView = getRootView() {
                let layer = AVPlayerLayer(player: avplayer)
                layer.frame = rootView.bounds
                layer.videoGravity = .resizeAspect
                rootView.layer.addSublayer(layer)
                playerLayer = layer
            } else {
                // Fallback: tạo layer tạm (không add) - nhưng log để debug
                let layer = AVPlayerLayer(player: avplayer)
                layer.videoGravity = .resizeAspect
                playerLayer = layer
                print("⚠️ attachPlayerToLayer: couldn't find rootView to add layer")
            }
        }
    }

    // Đảm bảo view có một playerLayer con để render
    public static func attachToView(_ view: UIView) {
        DispatchQueue.main.async {
            // Remove old layer from its superlayer (nếu có)
            playerLayer?.removeFromSuperlayer()
            let layer = AVPlayerLayer()
            layer.frame = view.bounds
            layer.videoGravity = .resizeAspect
            view.layer.addSublayer(layer)
            playerLayer = layer
        }
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
// MARK: - Native FMP4 Player (Optimized)
// ---------------------
@objcMembers
public class NativeFmp4PlayerLib: NSObject {
    public static var streamId : String?
    private var url : URL?
    private var socketSession : URLSession?
    private var socketTask : URLSessionWebSocketTask?
    private static var player : AVPlayer?
    private let SEGMENT_DURATION : Double = 1.1
    private var lastPushSegmentTime = CACurrentMediaTime()
    private var hlsDir : URL
    private var segmentCount = 0
    private var endStream = false
    private var connectStream = false
    private var segmentBuffer : [Data]
    private var initSegment : Data?
    private var proxyServer : HttpServer?
    private let segmentsToKeep = 8
    private let playlistQueue = DispatchQueue(label: "fmp4.playlist.queue")
    private var isObserving = false

    override init() {
        self.socketSession = nil
        self.socketTask = nil
        self.hlsDir = FileManager.default.temporaryDirectory.appendingPathComponent("hls_\(UUID().uuidString)")
        self.segmentBuffer = []
        self.proxyServer = HttpServer()
        super.init()
    }

    deinit {
        stopStreaming()
    }

    @available(iOS 16.0, *)
    public func startStreaming() {
        // Create dir
        try? FileManager.default.createDirectory(at: hlsDir, withIntermediateDirectories: true)

        // Setup HTTP server with Range support
        setupLocalHttpServer()

        guard let streamId = NativeFmp4PlayerLib.streamId else {
            print("❌ Missing streamId")
            return
        }

        // Build WebSocket URL
        url = URL(string: "wss://streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)")
        guard let url = url else {
            print("❌ Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.addValue("fmp4", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        self.socketSession = URLSession(configuration: .default)
        self.socketTask = socketSession?.webSocketTask(with: request)
        readMessage()
    }

    public func stopStreaming() {
        endStream = true
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        socketSession = nil

        // Stop player
        DispatchQueue.main.async {
            if let player = NativeFmp4PlayerLib.player {
                player.pause()
                if self.isObserving {
                    player.currentItem?.removeObserver(self, forKeyPath: "status", context: nil)
                    player.currentItem?.removeObserver(self, forKeyPath: "tracks", context: nil)
                    self.isObserving = false
                }
            }
            NativeFmp4PlayerLib.player = nil
        }
    }

    // MARK: - WebSocket receive
    @available(iOS 16.0, *)
    private func readMessage() {
        socketTask?.resume()
        print("🔵 WebSocket started, waiting for messages...")

        socketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("❌ WebSocket fail: \(error.localizedDescription)")
                // Optionally retry logic here
            case .success(let message):
                switch message {
                case .data(let data):
                    guard !data.isEmpty else { break }
                    print("✅ Received data: \(data.count) bytes")
                    // IMPORTANT: do not drop bytes arbitrarily. If your server puts a custom header byte,
                    // uncomment and adapt the following line:
                    // let payload = data.dropFirst() // only if you know the first byte is not part of fmp4
                    let payload = data
                    self.handleIncomingPayload(payload)
                case .string(let text):
                    print("📝 Received string: \(text)")
                @unknown default:
                    break
                }
            }
            if !self.endStream {
                self.readMessage()
            }
        }
    }

    // MARK: - Payload handling (init / media)
    private func handleIncomingPayload(_ data: Data) {
        // Detect init segment
        if isInitSegment(data) {
            handleInitSegment(data)
            return
        }

        // Otherwise treat as media segment; try to locate leading moof if necessary
        var mediaData = data
        if !startsWithBox(mediaData, names: ["moof","styp"]) {
            // try to find 'moof' or 'styp' offset inside data
            if let offset = findBoxOffset(mediaData, boxNames: ["moof","styp"]) {
                mediaData = mediaData.subdata(in: offset..<mediaData.count)
                print("🔧 Adjusted media segment to start at offset \(offset)")
            } else {
                // append anyway (maybe upstream already splits differently)
                print("⚠️ media chunk doesn't start with moof/styp and no offset found")
            }
        }

        appendBuffer(mediaData)
    }

    private func handleInitSegment(_ data: Data) {
        initSegment = data
        let initUrl = hlsDir.appendingPathComponent("init.mp4")
        do {
            try data.write(to: initUrl)
            print("✅ Init saved: \(initUrl.path) \(data.count) bytes")
            analyzeInitSegment(data)
            // after init saved, update playlist if we have segments
            playlistQueue.async {
                self.updatePlaylistAndMaybeStartPlayer()
            }
        } catch {
            print("❌ Failed to write init: \(error)")
        }
    }

    // MARK: - Buffering & writing segments
    private func appendBuffer(_ buffer: Data) {
        playlistQueue.async {
            self.segmentBuffer.append(buffer)
            let now = CACurrentMediaTime()

            let totalSize = self.segmentBuffer.reduce(0) { $0 + $1.count }
            print("📊 Buffer: \(self.segmentBuffer.count) chunks, \(totalSize) bytes")

            if now - self.lastPushSegmentTime > self.SEGMENT_DURATION || totalSize > 200_000 {
                self.writeBufferToSegment()
                self.lastPushSegmentTime = now
            }
        }
    }

    private func writeBufferToSegment() {
        guard !segmentBuffer.isEmpty else {
            print("⚠️ Buffer empty, skip write")
            return
        }

        var segmentData = Data()
        segmentBuffer.forEach { segmentData.append($0) }

        // Ensure segment starts with moof or styp - if not try to find valid start
        if !startsWithBox(segmentData, names: ["moof","styp"]) {
            if let offset = findBoxOffset(segmentData, boxNames: ["moof","styp"]) {
                segmentData = segmentData.subdata(in: offset..<segmentData.count)
                print("🔧 Trimmed segment to moof/styp at offset \(offset)")
            } else {
                print("⚠️ Segment does not start with moof/styp - writing as-is (may fail)")
            }
        }

        let filename = "segment-\(segmentCount).m4s"
        let segmentURL = hlsDir.appendingPathComponent(filename)

        do {
            try segmentData.write(to: segmentURL)
            print("✅ Wrote segment \(segmentCount): \(segmentData.count) bytes")
            segmentBuffer.removeAll()
            segmentCount += 1

            // Maintain sliding window by deleting old segments
            cleanupOldSegments()

            // Update playlist after writing
            playlistQueue.async {
                self.updatePlaylistAndMaybeStartPlayer()
            }
        } catch {
            print("❌ Failed write segment: \(error)")
        }
    }

    private func cleanupOldSegments() {
        // Keep last `segmentsToKeep` segments
        let keepFrom = max(0, segmentCount - segmentsToKeep)
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: hlsDir, includingPropertiesForKeys: nil)
            for file in files {
                let name = file.lastPathComponent
                if name.hasPrefix("segment-"), let idx = Int(name.replacingOccurrences(of: "segment-", with: "").replacingOccurrences(of: ".m4s", with: "")) {
                    if idx < keepFrom {
                        try? fileManager.removeItem(at: file)
                        print("🧹 Removed old segment: \(name)")
                    }
                }
            }
        } catch {
            // ignore
        }
    }

    // MARK: - Playlist generation & player start
    private func updatePlaylistAndMaybeStartPlayer() {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:7\n"
        playlist += "#EXT-X-TARGETDURATION:\(Int(ceil(SEGMENT_DURATION)))\n"
        playlist += "#EXT-X-MEDIA-SEQUENCE:\(max(0, segmentCount - segmentsToKeep))\n"
        playlist += "#EXT-X-INDEPENDENT-SEGMENTS\n"

        // Require init segment
        guard initSegment != nil else {
            print("⚠️ No init yet - skip playlist write")
            return
        }
        playlist += "#EXT-X-MAP:URI=\"init.mp4\"\n"

        let start = max(0, segmentCount - segmentsToKeep)
        for i in start..<segmentCount {
            playlist += String(format: "#EXTINF:%.3f,\n", SEGMENT_DURATION)
            playlist += "segment-\(i).m4s\n"
        }

        if endStream {
            playlist += "#EXT-X-ENDLIST\n"
        }

        let playlistUrl = hlsDir.appendingPathComponent("playlist.m3u8")
        do {
            try playlist.write(to: playlistUrl, atomically: true, encoding: .utf8)
            print("📝 Playlist updated (segments: \(segmentCount))")
        } catch {
            print("❌ Failed write playlist: \(error)")
        }

        // Start player when we have at least a couple segments AND not started
        if segmentCount >= 2 && !connectStream {
            print("🎬 Starting player (ready).")
            startPlayer()
        }
    }

    private func startPlayer() {
        guard !connectStream else { return }
        connectStream = true

        let playlistURL = URL(string: "http://127.0.0.1:8080/playlist.m3u8")!
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let asset = AVURLAsset(url: playlistURL, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false,
                "AVURLAssetOutOfBandMIMETypeKey": "application/vnd.apple.mpegurl"
            ])

            let playerItem = AVPlayerItem(asset: asset)
            playerItem.preferredForwardBufferDuration = 3.0
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

            NativeFmp4PlayerLib.player = AVPlayer(playerItem: playerItem)
            NativeFmp4PlayerLib.player?.automaticallyWaitsToMinimizeStalling = false
            NativeFmp4PlayerLib.player?.allowsExternalPlayback = false

            if #available(iOS 11.0, *) {
                NativeFmp4PlayerLib.player?.preventsDisplaySleepDuringVideoPlayback = true
            }

            // Observe for debug status and tracks
            if !self.isObserving {
                playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
                playerItem.addObserver(self, forKeyPath: "tracks", options: [.new], context: nil)
                self.isObserving = true
            }

            // Attach to our player layer (which was added to platform view)
            Fmp4AVPlayerView.attachPlayerToLayer(avplayer: NativeFmp4PlayerLib.player!)

            // Small delay to let playlist settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("▶️ Player.play()")
                NativeFmp4PlayerLib.player?.play()
                NativeFmp4PlayerLib.player?.rate = 1.0

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.debugPlayerState()
                }
            }
        }
    }

    private func debugPlayerState() {
        guard let player = NativeFmp4PlayerLib.player else { return }
        guard let item = player.currentItem else { return }

        print("🎮 Player State:")
        print("  - Rate: \(player.rate)")
        print("  - Status: \(item.status.rawValue)")
        print("  - Tracks: \(item.tracks.count)")

        for (index, track) in item.tracks.enumerated() {
            print("  - Track \(index): \(track.assetTrack?.mediaType.rawValue ?? "unknown")")
        }

        if let error = item.error {
            print("  - Error: \(error.localizedDescription)")
        }

        print("  - Duration: \(item.duration.seconds)")
        print("  - Buffered: \(item.loadedTimeRanges)")
    }

    // MARK: - Init segment detection & analysis
    private func isInitSegment(_ data: Data) -> Bool {
        guard data.count > 8 else { return false }
        let boxTypeData = data.subdata(in: 4..<8)
        let boxType = String(data: boxTypeData, encoding: .ascii) ?? ""
        return boxType == "ftyp" || boxType == "styp"
    }

    private func analyzeInitSegment(_ data: Data) {
        print("🔍 Analyzing init (\(data.count) bytes)")
        if let str = String(data: data, encoding: .ascii) {
            if str.contains("moov") { print("✅ Found moov") } else { print("⚠️ No moov") }
            if str.contains("vide") { print("✅ Found video track") } else { print("⚠️ No video track") }
            if str.contains("soun") { print("✅ Found audio track") } else { print("⚠️ No audio track") }
            if str.contains("avc1") { print("✅ Video codec H.264 detected (avc1)") }
            if str.contains("mp4a") { print("✅ Audio codec AAC detected (mp4a)") }
        } else {
            print("⚠️ init not ASCII-readable")
        }
    }

    // MARK: - Helper: detect box starts & offsets
    private func startsWithBox(_ data: Data, names: [String]) -> Bool {
        guard data.count > 8 else { return false }
        let boxTypeData = data.subdata(in: 4..<8)
        let boxType = String(data: boxTypeData, encoding: .ascii) ?? ""
        return names.contains(boxType)
    }

    private func findBoxOffset(_ data: Data, boxNames: [String]) -> Int? {
        // Naive search for ASCII box name in data (could be optimized)
        for i in 0..<(data.count - 4) {
            let end = i + 4
            if end <= data.count {
                let sub = data.subdata(in: i..<end)
                if let name = String(data: sub, encoding: .ascii), boxNames.contains(name) {
                    // backtrack to start of box (size is 4 bytes before)
                    let start = max(0, i - 4)
                    return start
                }
            }
        }
        return nil
    }

    // MARK: - HTTP Server (Swifter) with Range support
    private func setupLocalHttpServer() {
        proxyServer = HttpServer()
        guard let server = proxyServer else { return }

        server["/:path"] = { request in
            // Serve files from hlsDir with Range support
            guard let rawPath = request.params[":path"] else {
                return HttpResponse.notFound
            }
            let fileUrl = self.hlsDir.appendingPathComponent(rawPath)
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: fileUrl.path) else {
                return HttpResponse.notFound
            }

            // Read file data
            guard let handle = try? FileHandle(forReadingFrom: fileUrl) else {
                return HttpResponse.internalServerError
            }

            let attributes = try? fileManager.attributesOfItem(atPath: fileUrl.path)
            let fileSize = attributes?[.size] as? UInt64 ?? 0

            // Range header handling
            if let rangeHeader = request.headers["range"] {
                // Expected form: bytes=start-end
                let cleaned = rangeHeader.replacingOccurrences(of: "bytes=", with: "")
                let parts = cleaned.split(separator: "-").map { String($0) }
                let start = UInt64(parts.first ?? "0") ?? 0
                let end = parts.count > 1 && !parts[1].isEmpty ? (UInt64(parts[1]) ?? (fileSize - 1)) : (fileSize - 1)

                if start > end || end >= fileSize {
                    return HttpResponse.raw(416, "Requested Range Not Satisfiable", ["Content-Range":"bytes */\(fileSize)"]) { writer in
                        try writer.write([UInt8]())
                    }
                }

                let length = Int(end - start + 1)
                do {
                    try handle.seek(toOffset: start)
                    let data = handle.readData(ofLength: length)
                    handle.closeFile()
                    let headers = ["Content-Type": self.mimeType(for: fileUrl.path),
                                   "Content-Length": "\(data.count)",
                                   "Accept-Ranges": "bytes",
                                   "Content-Range": "bytes \(start)-\(end)/\(fileSize)"]
                    return HttpResponse.raw(206, "Partial Content", headers) { writer in
                        try writer.write(Array(data))
                    }
                } catch {
                    handle.closeFile()
                    return HttpResponse.internalServerError
                }
            } else {
                // Full file
                let data = try? Data(contentsOf: fileUrl)
                handle.closeFile()
                if let data = data {
                    let headers = ["Content-Type": self.mimeType(for: fileUrl.path),
                                   "Content-Length": "\(data.count)",
                                   "Accept-Ranges": "bytes"]
                    return HttpResponse.raw(200, "OK", headers) { writer in
                        try writer.write(Array(data))
                    }
                } else {
                    return HttpResponse.internalServerError
                }
            }
        }

        // Start server
        do {
            try server.start(8080, forceIPv4: true)
            print("✅ HTTP Server started on port 8080 at \(hlsDir.path)")
        } catch {
            print("❌ Failed to start server: \(error.localizedDescription)")
        }
    }

    private func mimeType(for path: String) -> String {
        if path.hasSuffix(".m3u8") { return "application/vnd.apple.mpegurl" }
        if path.hasSuffix(".m4s") { return "video/iso.segment" }
        if path.hasSuffix(".mp4") { return "video/mp4" }
        return "application/octet-stream"
    }

    // Observe item events
    override public func observeValue(forKeyPath keyPath: String?,
                                     of object: Any?,
                                     change: [NSKeyValueChangeKey : Any]?,
                                     context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ PlayerItem readyToPlay")
                    debugPlayerState()
                case .failed:
                    print("❌ PlayerItem failed: \(playerItem.error?.localizedDescription ?? "unknown")")
                    if let error = playerItem.error as NSError? {
                        print("   Error code: \(error.code)")
                        print("   Error domain: \(error.domain)")
                    }
                case .unknown:
                    print("⚠️ PlayerItem status unknown")
                @unknown default:
                    break
                }
            }
        } else if keyPath == "tracks" {
            if let playerItem = object as? AVPlayerItem {
                print("🎵 Tracks updated: \(playerItem.tracks.count) tracks")
                for track in playerItem.tracks {
                    if let assetTrack = track.assetTrack {
                        print("   - \(assetTrack.mediaType.rawValue)")
                        if assetTrack.mediaType == .video {
                            print("     Video size: \(assetTrack.naturalSize)")
                            print("     Video enabled: \(track.isEnabled)")
                        }
                    }
                }
            }
        }
    }
}
