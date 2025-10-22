import Flutter
import UIKit
import AVKit

public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    var factory: Fmp4StreamPlayerFactory?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fmp4_stream_player", binaryMessenger: registrar.messenger())
        let instance = Fmp4StreamPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let factory = Fmp4StreamPlayerFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "fmp4_stream_player_view")
        instance.factory = factory
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String,
               let vc = UIApplication.shared.delegate?.window??.rootViewController {

                let playerItem = AVPlayerItem(url: URL(string: url)!)
                self.player = AVPlayer(playerItem: playerItem)
                self.playerViewController = AVPlayerViewController()
                self.playerViewController?.player = self.player
                vc.present(self.playerViewController!, animated: true) {
                    self.player?.play()
                }
                result("playing \(url)")
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "url is required", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}