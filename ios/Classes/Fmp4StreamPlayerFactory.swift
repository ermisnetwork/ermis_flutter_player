import Flutter
import UIKit

class Fmp4StreamPlayerFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger
  private var lastView: Fmp4StreamPlayerView?

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let view = Fmp4StreamPlayerView(frame: frame, viewId: viewId, messenger: messenger)
    lastView = view
    return view
  }

  // Called from method channel
  func startStream(url: String) {
    DispatchQueue.main.async { [weak self] in
      self?.lastView?.startStream(url)
    }
  }

  func stop() {
    DispatchQueue.main.async { [weak self] in
      self?.lastView?.stop()
    }
  }
}