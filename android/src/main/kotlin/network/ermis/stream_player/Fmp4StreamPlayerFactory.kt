import android.content.Context
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import android.view.View
import com.google.android.exoplayer2.ui.PlayerView

class Fmp4StreamPlayerFactory(private val context: Context) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        return Fmp4StreamPlayerPlatformView(this.context)
    }
}

class Fmp4StreamPlayerPlatformView(private val context: Context) : PlatformView {
    private val playerView = PlayerView(context)

    override fun getView(): View = playerView

    override fun dispose() {}
}