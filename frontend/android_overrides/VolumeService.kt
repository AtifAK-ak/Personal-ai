package __PACKAGE__

import android.content.Context
import android.media.AudioManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** Controls the media volume. Argument "action": up | down | mute | unmute | set. */
class VolumeService(private val ctx: Context) : NativeService {
    override val methods = setOf("volume")

    private val audio: AudioManager
        get() = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        val stream = AudioManager.STREAM_MUSIC
        val flags = AudioManager.FLAG_SHOW_UI
        when (call.argument<String>("action")) {
            "up" -> audio.adjustStreamVolume(stream, AudioManager.ADJUST_RAISE, flags)
            "down" -> audio.adjustStreamVolume(stream, AudioManager.ADJUST_LOWER, flags)
            "mute" -> audio.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, flags)
            "unmute" -> audio.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, flags)
            "set" -> {
                val percent = (call.argument<Int>("percent") ?: 0).coerceIn(0, 100)
                val max = audio.getStreamMaxVolume(stream)
                audio.setStreamVolume(stream, (max * percent / 100.0).roundToInt(), flags)
            }
            else -> {
                result.error("BAD_ACTION", "Unknown volume action", null)
                return
            }
        }
        val max = audio.getStreamMaxVolume(stream)
        result.success(if (max == 0) 0 else audio.getStreamVolume(stream) * 100 / max)
    }
}
