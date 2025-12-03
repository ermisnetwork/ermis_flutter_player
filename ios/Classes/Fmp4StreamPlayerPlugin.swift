import Flutter
import UIKit
import AVFoundation
import Starscream

public class Fmp4StreamPlayerPlugin: NSObject, FlutterPlugin {
    private var demuxer: Demuxer?
    private var webSocket: WebSocket?
    private var playerViewController: Fmp4PlayerViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "fmp4_stream_player",
            binaryMessenger: registrar.messenger()
        )
        let instance = Fmp4StreamPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register platform view
        let factory = Fmp4StreamPlayerViewFactory(
            messenger: registrar.messenger(),
            plugin: instance
        )
        registrar.register(factory, withId: "fmp4_stream_player_view")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startStreaming":
            guard let args = call.arguments as? [String: Any],
                  let streamId = args["streamId"] as? String,
                  let token = args["token"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing streamId or token",
                    details: nil
                ))
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

    // MARK: - Streaming Methods

    private func startStreaming(streamId: String, token: String, result: @escaping FlutterResult) {
        // Initialize demuxer - Đây là class từ file ermis_fmp4_demuxer_binding.swift
        demuxer = Demuxer(hevc: true)

        // WebSocket URL
        let wsUrl = "wss://sfu-do-streaming.ermis.network/stream-gate/software/Ermis-streaming/\(streamId)"

        guard var request = URLRequest(url: URL(string: wsUrl)!) else {
            result(FlutterError(
                code: "INVALID_URL",
                message: "Invalid WebSocket URL",
                details: nil
            ))
            return
        }

        // Add authorization header
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        // Create WebSocket
        webSocket = WebSocket(request: request)
        webSocket?.delegate = self
        webSocket?.connect()

        print("🚀 Starting WebSocket connection to: \(wsUrl)")
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
    }
}

// MARK: - WebSocket Delegate

extension Fmp4StreamPlayerPlugin: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("✅ WebSocket connected")
            print("Headers: \(headers)")

        case .disconnected(let reason, let code):
            print("❌ WebSocket disconnected: \(reason) code: \(code)")

        case .text(let text):
            print("📝 Received text: \(text)")
            // Parse control messages
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleControlMessage(json)
            }

        case .binary(let data):
            print("📦 Received binary data: \(data.count) bytes")
            processStreamData(data)

        case .error(let error):
            print("⚠️ WebSocket error: \(String(describing: error))")

        case .cancelled:
            print("🚫 WebSocket cancelled")

        case .viabilityChanged(let isViable):
            print("🔄 WebSocket viability changed: \(isViable)")

        case .reconnectSuggested(let suggested):
            print("🔄 WebSocket reconnect suggested: \(suggested)")

        case .ping, .pong:
            break
        }
    }

    private func handleControlMessage(_ json: [String: Any]) {
        if let type = json["type"] as? String {
            switch type {
            case "TotalViewerCount":
                if let viewers = json["total_viewers"] as? Int {
                    print("👥 Total viewers: \(viewers)")
                }
            default:
                print("📨 Control message type: \(type)")
            }
        }
    }

    private func processStreamData(_ data: Data) {
        guard let demuxer = demuxer else {
            print("❌ Demuxer not initialized")
            return
        }

        // Convert Data to [UInt8] for Rust demuxer
        // Demuxer.processData() expects Data type (from UniFFI binding)
        let processResult = demuxer.processData(data: data)

        print("🎬 Processed: \(processResult.videoFrames.count) video, \(processResult.audioFrames.count) audio frames")

        // Send to player
        playerViewController?.processFrames(processResult)
    }
}

// MARK: - Platform View Factory

class Fmp4StreamPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var plugin: Fmp4StreamPlayerPlugin?

    init(messenger: FlutterBinaryMessenger, plugin: Fmp4StreamPlayerPlugin) {
        self.messenger = messenger
        self.plugin = plugin
        super.init()
    }

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
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var isWriting = false
    private let processQueue = DispatchQueue(label: "com.ermis.fmp4.process", qos: .userInteractive)
    private var startTime: CMTime?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        playerView = UIView(frame: frame)
        playerView.backgroundColor = .black

        super.init()

        setupPlayer()
    }

    func view() -> UIView {
        return playerView
    }

    private func setupPlayer() {
        // Setup AVPlayer
        player = AVPlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = playerView.bounds
        playerLayer?.videoGravity = .resizeAspect

        if let playerLayer = playerLayer {
            playerView.layer.addSublayer(playerLayer)
        }

        print("🎥 AVPlayer setup completed")
    }

    private func setupAssetWriter() {
        guard assetWriter == nil else { return }

        let tempDir = FileManager.default.temporaryDirectory
        outputURL = tempDir.appendingPathComponent("livestream_\(UUID().uuidString).mp4")

        guard let outputURL = outputURL else {
            print("❌ Failed to create output URL")
            return
        }

        do {
            // Remove existing file
            try? FileManager.default.removeItem(at: outputURL)

            // Create asset writer
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            // Video input settings for HEVC
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 5000000,
                    AVVideoMaxKeyFrameIntervalKey: 60
                ]
            ]

            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true

            if let input = videoInput, let writer = assetWriter, writer.canAdd(input) {
                writer.add(input)
            }

            // Start writing
            if assetWriter?.startWriting() == true {
                startTime = CMTime.zero
                assetWriter?.startSession(atSourceTime: startTime!)
                isWriting = true
                print("✅ Asset writer started at: \(outputURL.path)")
            }

        } catch {
            print("❌ Error setting up asset writer: \(error)")
        }
    }

    func processFrames(_ result: ProcessResult) {
        processQueue.async { [weak self] in
            guard let self = self else { return }

            // Setup writer on first frame
            if !self.isWriting {
                self.setupAssetWriter()
            }

            // Process video frames
            for frame in result.videoFrames {
                self.processVideoFrame(frame)
            }

            // Update player periodically
            if result.videoFrames.count > 0 {
                self.updatePlayer()
            }
        }
    }

    private func processVideoFrame(_ frame: Frame) {
        guard isWriting,
              let input = videoInput,
              input.isReadyForMoreMediaData else {
            print("⚠️ Video input not ready")
            return
        }

        // Frame data từ Rust demuxer đã là NAL units
        if let sampleBuffer = createSampleBuffer(from: frame) {
            if input.append(sampleBuffer) {
                print("✅ Video frame appended: ts=\(frame.timestamp ?? 0)ms, key=\(frame.isKeyframe), size=\(frame.data.count)")
            } else {
                print("❌ Failed to append video frame")
            }
        }
    }

    private func createSampleBuffer(from frame: Frame) -> CMSampleBuffer? {
        // Create block buffer from frame data
        var blockBuffer: CMBlockBuffer?
        let frameData = frame.data
        let dataPointer = (frameData as NSData).bytes.bindMemory(to: UInt8.self, capacity: frameData.count)

        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: frameData.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: frameData.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == kCMBlockBufferNoErr, let blockBuffer = blockBuffer else {
            print("❌ Failed to create block buffer: \(status)")
            return nil
        }

        status = CMBlockBufferReplaceDataBytes(
            with: dataPointer,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: frameData.count
        )

        guard status == kCMBlockBufferNoErr else {
            print("❌ Failed to replace data bytes: \(status)")
            return nil
        }

        // Create format description for HEVC
        var formatDescription: CMFormatDescription?
        status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_HEVC,
            width: 1920,
            height: 1080,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDescription = formatDescription else {
            print("❌ Failed to create format description: \(status)")
            return nil
        }

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        let timestamp = CMTime(value: Int64(frame.timestamp ?? 0), timescale: 1000)
        let duration = CMTime(value: Int64(frame.duration ?? 33), timescale: 1000)

        var timingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )

        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sampleBuffer = sampleBuffer else {
            print("❌ Failed to create sample buffer: \(status)")
            return nil
        }

        // Mark keyframe
        if frame.isKeyframe,
           let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? NSMutableArray {
            let dict = attachments[0] as! NSMutableDictionary
            dict[kCMSampleAttachmentKey_DependsOnOthers] = false
            dict[kCMSampleAttachmentKey_IsDependedOnByOthers] = true
        }

        return sampleBuffer
    }

    private func updatePlayer() {
        guard let outputURL = outputURL,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create player item if needed
            if self.player?.currentItem == nil {
                let asset = AVURLAsset(url: outputURL)
                let playerItem = AVPlayerItem(asset: asset)
                self.player?.replaceCurrentItem(with: playerItem)
                self.player?.play()
                print("▶️ Started playback from: \(outputURL.lastPathComponent)")
            }
        }
    }

    func pausePlayback() {
        player?.pause()
        print("⏸️ Playback paused")
    }

    func resumePlayback() {
        player?.play()
        print("▶️ Playback resumed")
    }

    func stopPlayback() {
        print("⏹️ Stopping playback...")
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            self?.isWriting = false
            print("✅ Asset writer finished")

            if let outputURL = self?.outputURL {
                try? FileManager.default.removeItem(at: outputURL)
                print("🗑️ Cleaned up temp file")
            }
        }
    }

    deinit {
        stopPlayback()
    }
}