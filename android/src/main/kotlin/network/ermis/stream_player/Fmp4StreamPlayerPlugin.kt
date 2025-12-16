package network.ermis.stream_player

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import com.google.android.exoplayer2.ui.PlayerView

class Fmp4StreamPlayerPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        FMP4StreamPlayerManager.init(appContext)
        channel = MethodChannel(binding.binaryMessenger, "fmp4_stream_player")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "fmp4_stream_player/events")
        eventChannel.setStreamHandler(this)

        binding.platformViewRegistry.registerViewFactory(
            "fmp4_stream_player_view",
            Fmp4StreamPlayerFactory(appContext)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        FMP4StreamPlayerManager.setEventSink(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startStreaming" -> {
                val streamId = call.argument<String>("streamId") ?: ""
                val token = call.argument<String>("token") ?: ""
                if (streamId.isEmpty() || token.isEmpty()) {
                    result.error("INVALID_ARG", "streamId or token null", null)
                    return
                }
                FMP4StreamPlayerApi.startStreaming(
                    streamId,
                    token,
                    onSuccess = { workerUrl ->
                        // post về main thread
                        FMP4StreamPlayerManager.mainHandler.post {
                            android.util.Log.d("TAG", "onMethodCall workerUrl: $workerUrl")
                            FMP4StreamPlayerManager.startStream(workerUrl)  // <-- play trực tiếp
                            result.success(true)
                        }
                    },
                    onFailure = { message ->
                        // post về main thread
                        FMP4StreamPlayerManager.mainHandler.post {
                            android.util.Log.e("TAG", "startStreaming failed: $message")
                            result.error("STREAM_ERROR", message, null)
                        }
                    }
                )
            }

            "stopStreaming" -> {
                FMP4StreamPlayerManager.stopStream()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        FMP4StreamPlayerManager.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        FMP4StreamPlayerManager.setEventSink(null)
    }
}

class Fmp4StreamPlayerFactory(private val context: Context) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        return Fmp4StreamPlayerPlatformView(context ?: this.context)
    }
}

class Fmp4StreamPlayerPlatformView(context: Context) : PlatformView {

    private val playerView: PlayerView = PlayerView(context).apply {
        FMP4StreamPlayerManager.attachPlayerToView(this)
    }

    override fun getView(): android.view.View = playerView

    override fun dispose() {
    }
}
