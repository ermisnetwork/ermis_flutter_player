package network.ermis.stream_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.ui.PlayerView
import com.google.android.exoplayer2.upstream.DataSource
import com.google.android.exoplayer2.upstream.DataSpec
import com.google.android.exoplayer2.upstream.TransferListener
import okhttp3.*
import okio.ByteString
import java.io.IOException
import java.io.PipedInputStream
import java.io.PipedOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit

object FMP4StreamPlayerManager {

    private lateinit var context: Context
    val mainHandler = Handler(Looper.getMainLooper())

    private var _player: ExoPlayer? = null
    val player: ExoPlayer get() = _player!!

    // Tối ưu buffer 4MB
    private val pipedOutputStream = PipedOutputStream()
    private val pipedInputStream = PipedInputStream(pipedOutputStream, 1024 * 1024)

    private var webSocket: WebSocket? = null
    private var workerUrl: String? = null
    var isStreaming = false

    private var lastAudioPts: Long = 0
    private var lastVideoPts: Long = 0

    fun init(ctx: Context) {
        context = ctx
        if (_player == null) {
            _player = ExoPlayer.Builder(context).build()
        }
    }

    fun attachPlayerToView(playerView: PlayerView) {
        playerView.player = player
    }

    fun startStream(url: String) {
        if (isStreaming) stopStream()

        workerUrl = url
        val input = pipedInputStream ?: run {
            return
        }

        val dataSourceFactory = DataSource.Factory { FMP4DataSource(input) }
        val mediaSource = com.google.android.exoplayer2.source.ProgressiveMediaSource.Factory(dataSourceFactory)
            .createMediaSource(MediaItem.fromUri("fmp4://stream"))

        player.setMediaSource(mediaSource)
        player.prepare()
        player.playWhenReady = true

        openWebSocket(url)
        isStreaming = true
    }

    private fun openWebSocket(url: String) {
        if (webSocket != null) return

        val client = OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .build()

        val request = Request.Builder()
            .url(url)
            .addHeader("Sec-WebSocket-Protocol", "fmp4")
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                try {
                    val data = bytes.toByteArray()
                    val fmp4Data = if (data.isNotEmpty()) data.copyOfRange(1, data.size) else data

                    val fixedFragment = fixFragmentTimestamps(fmp4Data)
                    pipedOutputStream?.let {
                        try {
                            it.write(fixedFragment)
                            it.flush()
                        } catch (e: IOException) {

                        }
                    }
                } catch (e: IOException) {
                    e.printStackTrace()
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                t.printStackTrace()
                this@FMP4StreamPlayerManager.webSocket = null
                if (isStreaming && workerUrl != null) {
                    mainHandler.postDelayed({ openWebSocket(workerUrl!!) }, 1000)
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                this@FMP4StreamPlayerManager.webSocket = null
            }
        })
    }

    fun stopStream() {
        isStreaming = false
        webSocket?.close(1000, "User stopped")
        webSocket = null
        workerUrl = null
        player.stop()
    }

    private fun fixFragmentTimestamps(data: ByteArray): ByteArray {
        val out = data.copyOf()
        var offset = 0
        while (offset < out.size - 8) {
            val size = readUint32(out, offset).toInt()
            val type = String(out, offset + 4, 4)
            if (type == "tfdt") {
                val version = out[offset + 8].toInt()
                if (version == 1) {
                    var pts = readUint64(out, offset + 12)
                    if (pts < lastVideoPts) pts = lastVideoPts + 3000
                    lastVideoPts = pts
                    writeUint64(out, offset + 12, pts)
                } else {
                    var pts = readUint32(out, offset + 12)
                    if (pts < lastAudioPts) pts = lastAudioPts + 1024
                    lastAudioPts = pts
                    writeUint32(out, offset + 12, pts.toInt())
                }
            }
            offset += size
        }
        return out
    }

    private fun readUint32(data: ByteArray, offset: Int): Long {
        return ByteBuffer.wrap(data, offset, 4).int.toLong() and 0xFFFFFFFFL
    }

    private fun writeUint32(data: ByteArray, offset: Int, value: Int) {
        val buf = ByteBuffer.allocate(4).putInt(value)
        System.arraycopy(buf.array(), 0, data, offset, 4)
    }

    private fun readUint64(data: ByteArray, offset: Int): Long {
        return ByteBuffer.wrap(data, offset, 8).long
    }

    private fun writeUint64(data: ByteArray, offset: Int, value: Long) {
        val buf = ByteBuffer.allocate(8).putLong(value)
        System.arraycopy(buf.array(), 0, data, offset, 8)
    }
}

class FMP4DataSource(private val inputStream: PipedInputStream) : DataSource {
    private var bytesRemaining = Long.MAX_VALUE

    override fun open(dataSpec: DataSpec): Long = bytesRemaining

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (bytesRemaining == 0L) return -1
        val bytesRead = inputStream.read(buffer, offset, length)
        if (bytesRead > 0) bytesRemaining -= bytesRead
        return bytesRead
    }

    override fun close() {}
    override fun addTransferListener(transferListener: TransferListener) {}
    override fun getUri(): Uri? = Uri.parse("fmp4://stream")
}