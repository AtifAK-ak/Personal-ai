package __PACKAGE__

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Small key/value store (SharedPreferences) used by Flutter for settings. */
class PrefsService(ctx: Context) : NativeService {
    private val prefs = ctx.getSharedPreferences("alex_prefs", Context.MODE_PRIVATE)
    override val methods = setOf("prefs.get", "prefs.set")

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key.isNullOrEmpty()) {
            result.error("NO_KEY", "key required", null)
            return
        }
        if (call.method == "prefs.get") {
            result.success(prefs.getString(key, null))
        } else {
            prefs.edit().putString(key, call.argument<String>("value")).apply()
            result.success(true)
        }
    }
}
