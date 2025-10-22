import Foundation
import Flutter
import UIKit
import AVFoundation
import AVKit

class Fmp4StreamPlayerView: NSObject, FlutterPlatformView {
  private let containerView: UIView
  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private let resourceLoader: FMP4ResourceLoader
  private var wsManager: FMP4WebSocketManager?

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    self.containerView = UIView(frame: frame)
    self.resourceLoader = FMP4ResourceLoader()
    super.init()
    setupPlayer()
    // auto-resize
    containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  private func setupPlayer() {
    // custom scheme URL - the resource loader delegate will serve data for this URL
    guard let url = URL(string: "fmp4://stream") else { return }
    let asset = AVURLAsset(url: url)
    // set delegate BEFORE creating AVPlayerItem
    asset.resourceLoader.setDelegate(resourceLoader, queue: DispatchQueue(label: "fmp4.resource.loader.queue"))
    let item = AVPlayerItem(asset: asset)
    self.player = AVPlayer(playerItem: item)
    self.playerLayer = AVPlayerLayer(player: player)
    self.playerLayer?.videoGravity = .resizeAspect
    self.playerLayer?.frame = containerView.bounds
    if let pl = self.playerLayer {
      containerView.layer.addSublayer(pl)
    }

    // update layer's frame when containerView layout changes
    containerView.layoutIfNeeded()
  }

  func startStream(_ url: String) {
    // stop old
    wsManager?.stop()
    // create new WS manager and hook it to resource loader
    wsManager = FMP4WebSocketManager(loader: resourceLoader)
    wsManager?.start(urlString: url)
    // start playback
    player?.play()
  }

  func stop() {
    wsManager?.stop()
    player?.pause()
    resourceLoader.reset()
  }

  func view() -> UIView {
    return containerView
  }

  deinit {
    wsManager?.stop()
    player?.pause()
  }
}