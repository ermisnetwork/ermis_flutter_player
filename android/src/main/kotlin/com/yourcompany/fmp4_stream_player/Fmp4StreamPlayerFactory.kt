package com.yourcompany.fmp4_stream_player

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class Fmp4StreamPlayerFactory(
    private val context: Context
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    private var playerView: Fmp4StreamPlayerView? = null

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        playerView = Fmp4StreamPlayerView(this.context)
        return playerView!!
    }

    fun startStream(url: String) {
        playerView?.startStream(url)
    }
}