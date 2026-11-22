package __PACKAGE__

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.provider.MediaStore
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Battery, settings panels, media keys, camera app, maps and web search. */
class DeviceService(private val ctx: Context) : NativeService {
    override val methods = setOf(
        "device.battery", "device.panel", "media.key", "camera.open", "maps.open", "web.search"
    )

    private fun launch(intent: Intent, result: MethodChannel.Result, okValue: Any) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            ctx.startActivity(intent)
            result.success(okValue)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_APP", "No app on this phone can do that", null)
        }
    }

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "device.battery" -> {
                val i = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                val status = i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
                val percent = if (level < 0 || scale <= 0) -1 else level * 100 / scale
                result.success(hashMapOf<String, Any>("percent" to percent, "charging" to charging))
            }
            "device.panel" -> {
                val action = when (call.argument<String>("name")) {
                    "wifi" -> Settings.ACTION_WIFI_SETTINGS
                    "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                    "mobile" -> Settings.ACTION_WIRELESS_SETTINGS
                    "display" -> Settings.ACTION_DISPLAY_SETTINGS
                    "sound" -> Settings.ACTION_SOUND_SETTINGS
                    else -> Settings.ACTION_SETTINGS
                }
                launch(Intent(action), result, true)
            }
            "media.key" -> {
                val code = when (call.argument<String>("action")) {
                    "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                    "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                    "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                    "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                    "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
                    else -> -1
                }
                if (code == -1) {
                    result.error("BAD_ACTION", "Unknown media action", null)
                    return
                }
                val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
                result.success(true)
            }
            "camera.open" -> launch(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA), result, true)
            "maps.open" -> {
                val q = Uri.encode(call.argument<String>("query") ?: "")
                val navigate = call.argument<Boolean>("navigate") ?: false
                val uri = if (navigate) Uri.parse("google.navigation:q=$q") else Uri.parse("geo:0,0?q=$q")
                launch(Intent(Intent.ACTION_VIEW, uri), result, true)
            }
            "web.search" -> {
                val q = Uri.encode(call.argument<String>("query") ?: "")
                launch(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$q")), result, true)
            }
        }
    }
}
