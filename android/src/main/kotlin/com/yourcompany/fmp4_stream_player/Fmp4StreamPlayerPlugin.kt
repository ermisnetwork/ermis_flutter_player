package com.yourcompany.fmp4_stream_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.upstream.DataSource
import com.google.android.exoplayer2.upstream.DataSpec
import com.google.android.exoplayer2.upstream.TransferListener
import okhttp3.*
import okio.ByteString
import java.io.IOException
import java.io.PipedInputStream
import java.io.PipedOutputStream
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class FMP4StreamPlayer(private val context: Context) {
  private var player: ExoPlayer? = null
  private var webSocket: WebSocket? = null
  private val pipedOutputStream = PipedOutputStream()
  private val pipedInputStream = PipedInputStream(pipedOutputStream, 1024 * 1024)
  private val mainHandler = Handler(Looper.getMainLooper())

  fun initPlayer() {
    player = ExoPlayer.Builder(context).build()
  }

  fun getPlayer(): ExoPlayer? = player

  fun startStreaming(streamUrl: String) {
    val dataSourceFactory = DataSource.Factory { FMP4DataSource() }
    val mediaSource = ProgressiveMediaSource.Factory(dataSourceFactory)
      .createMediaSource(MediaItem.fromUri("fmp4://stream"))

    player?.apply {
      setMediaSource(mediaSource)
      prepare()
      playWhenReady = true
    }

    val client = OkHttpClient.Builder()
      .readTimeout(0, java.util.concurrent.TimeUnit.MILLISECONDS)
      .build()

    val request = Request.Builder()
      .url(streamUrl)
      .addHeader("Sec-WebSocket-Protocol", "fmp4")
      .build()

    webSocket = client.newWebSocket(request, object : WebSocketListener() {
      override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        try {
          val data = bytes.toByteArray()
          val fmp4Data = data.copyOfRange(1, data.size)
          pipedOutputStream.write(fmp4Data)
          pipedOutputStream.flush()
        } catch (e: IOException) {
          e.printStackTrace()
        }
      }

      override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        println("WebSocket error: ${t.message}")
      }
    })
  }

  fun stop() {
    webSocket?.close(1000, "User stopped")
    pipedOutputStream.close()
    pipedInputStream.close()
    player?.release()
  }

  inner class FMP4DataSource : DataSource {
    private var bytesRemaining = Long.MAX_VALUE

    override fun open(dataSpec: DataSpec): Long = bytesRemaining

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
      if (bytesRemaining == 0L) return -1
      val bytesRead = pipedInputStream.read(buffer, offset, length)
      if (bytesRead > 0) {
        bytesRemaining -= bytesRead
      }
      return bytesRead
    }

    override fun close() {}
    override fun addTransferListener(transferListener: TransferListener) {}
    override fun getUri(): Uri? = Uri.parse("fmp4://stream")
  }
}

class Fmp4StreamPlayerPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel
  private var factory: Fmp4StreamPlayerFactory? = null


  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "fmp4_stream_player")
    channel.setMethodCallHandler(this)

    factory = Fmp4StreamPlayerFactory(context)
    binding.platformViewRegistry.registerViewFactory(
      "fmp4_stream_player_view",
      factory!!
    )
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "startStreaming" -> {
        val url = call.argument<String>("url") ?: ""
        factory?.startStream(url)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}