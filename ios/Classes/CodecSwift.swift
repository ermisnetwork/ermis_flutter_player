import Flutter
import UIKit
import AVFoundation
import Starscream

typealias StarscreamWebSocket = Starscream.WebSocket


public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
    private weak var playerViewController: Fmp4PlayerViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method channel (global for plugin)
        let channel = FlutterMethodChannel(
            name: "fmp4_stream_player",
            binaryMessenger: registrar.messenger()
        )

        let instance = Fmp4StreamPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Platform view factory (id: fmp4_stream_player_view)
        let factory = Fmp4StreamPlayerViewFactory(messenger: registrar.messenger(), plugin: instance)
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
            let token = args["token"] as? String

            // Configure codec URL + token. You can implement either static wrapper or instance method.
            // If you implemented CodecSwift.shared.setUrlForId(_:token:), call it. Otherwise use static attachId.
            if let setUrlSelector = CodecSwift.shared as CodecSwift? {
                // Prefer instance setter if you added it
                if let _ = (CodecSwift.shared as AnyObject).setValue(nil, forKey: "") as Void? {
                    // no-op, keep to silence unused branch
                }
            }

            // Try to call instance method setUrlForId if exists, else fallback to static attachId
            if CodecSwift.shared.responds(to: Selector(("setUrlForId:token:"))) {
                // If you added func setUrlForId(_:token:), it will be used.
                CodecSwift.shared.perform(Selector(("setUrlForId:token:")), with: streamId, with: token)
            } else {
                // Fallback to existing static API
                CodecSwift.attachId(Id: streamId)
                // If you need token in header, ensure CodecSwift has a way to store it (e.g., shared.authToken)
                if let token = token {
                    // try to set authToken property if exists
                    if CodecSwift.shared.responds(to: Selector(("setAuthToken:"))) {
                        CodecSwift.shared.perform(Selector(("setAuthToken:")), with: token)
                    } else {
                        // If no property, please add support in CodecSwift to accept token
                        print("⚠️ Warning: CodecSwift has no API to accept token - please add setUrlForId(_:token:) or authToken property")
                    }
                }
            }

            // Start websocket on main thread
            DispatchQueue.main.async {
                CodecSwift.shared.startWebSocket()
            }

            print("🚀 startStreaming requested for id: \(streamId)")
            result(true)

        case "stopStreaming":
            DispatchQueue.main.async {
                CodecSwift.shared.stopWebSocket()
                // flush view layers if any
                self.playerViewController?.stopPlayback()
            }
            result(true)

        case "pauseView":
            // Pause render synchronizer if exposed
            if let _ = Optional(()) {
                CodecSwift.synchro.setRate(0.0, time: CMTime.invalid)
            }
            result(true)

        case "resumeView":
            if let _ = Optional(()) {
                CodecSwift.synchro.setRate(1.0, time: CMTime.invalid)
            }
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Called from factory when view controller created
    func setPlayerViewController(_ controller: Fmp4PlayerViewController) {
        self.playerViewController = controller
    }
}

// MARK: - Platform View Factory

class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: (FlutterBinaryMessenger & NSObjectProtocol)
    private weak var plugin: Fmp4StreamPlayerPlugin?

    init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
        self.messenger = messenger
        self.plugin = plugin
        super.init()
    }

    // Create the platform view
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let controller = Fmp4PlayerViewController(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
        plugin?.setPlayerViewController(controller)
        return controller
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Player View Controller

class Fmp4PlayerViewController: NSObject, FlutterPlatformView {
    private let playerView: UIView
    private var videoLayer: AVSampleBufferDisplayLayer?
    private var audioRenderer: AVSampleBufferAudioRenderer?
    private var isAttached = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        playerView = UIView(frame: frame)
        playerView.backgroundColor = .black
        super.init()
        setupPlayerLayers()
    }

    func view() -> UIView {
        return playerView
    }

    private func setupPlayerLayers() {
        // Video layer
        let vlayer = AVSampleBufferDisplayLayer()
        vlayer.videoGravity = .resizeAspect
        vlayer.frame = playerView.bounds
        vlayer.contentsScale = UIScreen.main.scale
        vlayer.isOpaque = true
        playerView.layer.addSublayer(vlayer)
        self.videoLayer = vlayer

        // Audio renderer
        let arender = AVSampleBufferAudioRenderer()
        self.audioRenderer = arender

        // Attach to CodecSwift (static method in your CodecSwift)
        // Make sure CodecSwift.attachPlayer expects AVSampleBufferDisplayLayer & AVSampleBufferAudioRenderer
        CodecSwift.attachPlayer(videoplayer: vlayer, audioplayers: arender)

        // Optionally ensure audio session active
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("⚠️ AVAudioSession setup error: \(error)")
        }

        isAttached = true
    }

    // Keep the layer frames in sync when layout changes (call from Flutter if needed)
    func updateFrame(_ frame: CGRect) {
        DispatchQueue.main.async {
            self.playerView.frame = frame
            self.videoLayer?.frame = self.playerView.bounds
            self.videoLayer?.position = CGPoint(x: self.playerView.bounds.midX, y: self.playerView.bounds.midY)
        }
    }

    // Pause playback (set synchro rate 0)
    func pausePlayback() {
        if let _ = Optional(()) {
            CodecSwift.synchro.setRate(0.0, time: CMTime.invalid)
        }
        print("⏸️ Playback paused (synchro rate -> 0)")
    }

    func resumePlayback() {
        if let _ = Optional(()) {
            CodecSwift.synchro.setRate(1.0, time: CMTime.invalid)
        }
        print("▶️ Playback resumed (synchro rate -> 1)")
    }

    func stopPlayback() {
        // Flush layers and stop audio renderer
        DispatchQueue.main.async {
            self.videoLayer?.flush()
            self.audioRenderer?.flush()
        }
        print("⏹️ Playback stopped and layers flushed")
    }

    deinit {
        stopPlayback()
    }
}
