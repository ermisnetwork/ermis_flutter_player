package com.yourcompany.fmp4_stream_player

import android.content.Context
import android.view.View
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.ui.PlayerView
import io.flutter.plugin.platform.PlatformView
import android.net.Uri
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.upstream.DataSource
import com.google.android.exoplayer2.upstream.DataSpec
import com.google.android.exoplayer2.upstream.TransferListener
import okhttp3.*
import okio.ByteString
import java.io.IOException
import java.io.PipedInputStream
import java.io.PipedOutputStream

class Fmp4StreamPlayerView(context: Context) : PlatformView {
    private val playerView: PlayerView
    private val player: ExoPlayer
    private val pipedOutputStream = PipedOutputStream()
    private val pipedInputStream = PipedInputStream(pipedOutputStream, 1024 * 1024)

    init {
        player = ExoPlayer.Builder(context).build()
        playerView = PlayerView(context)
        playerView.player = player
    }

    fun startStream(url: String) {
        val dataSourceFactory = DataSource.Factory { FMP4DataSource() }
        val mediaSource = ProgressiveMediaSource.Factory(dataSourceFactory)
            .createMediaSource(MediaItem.fromUri("fmp4://stream"))

        player.setMediaSource(mediaSource)
        player.prepare()
        player.play()

        openWebSocket(url)
    }

    private fun openWebSocket(streamUrl: String) {
        val client = OkHttpClient.Builder()
            .readTimeout(0, java.util.concurrent.TimeUnit.MILLISECONDS)
            .build()

        val request = Request.Builder()
            .url(streamUrl)
            .addHeader("Sec-WebSocket-Protocol", "fmp4")
            .build()

        client.newWebSocket(request, object : WebSocketListener() {
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

    override fun getView(): View = playerView

    override fun dispose() {
        player.release()
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