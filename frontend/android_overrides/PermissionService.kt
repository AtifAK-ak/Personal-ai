package __PACKAGE__

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Runtime permissions. Nothing is requested unless Flutter asks for it. */
class PermissionService(private val activity: Activity) : NativeService {
    override val methods = setOf("permission.status", "permission.request", "permission.openSettings")

    private val pending = HashMap<Int, MethodChannel.Result>()
    private var nextCode = 4200

    private fun resolve(name: String?): String? = when (name) {
        "microphone" -> "android.permission.RECORD_AUDIO"
        "camera" -> "android.permission.CAMERA"
        "contacts" -> "android.permission.READ_CONTACTS"
        "notifications" -> "android.permission.POST_NOTIFICATIONS"
        else -> null
    }

    private fun granted(permission: String): Boolean {
        if (permission.endsWith("POST_NOTIFICATIONS") && Build.VERSION.SDK_INT < 33) return true
        return activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "permission.openSettings") {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + activity.packageName)
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            result.success(true)
            return
        }
        val permission = resolve(call.argument<String>("name"))
        if (permission == null) {
            result.error("UNKNOWN_PERMISSION", "Unknown permission", null)
            return
        }
        if (call.method == "permission.status" || granted(permission)) {
            result.success(granted(permission))
            return
        }
        val code = nextCode++
        pending[code] = result
        activity.requestPermissions(arrayOf(permission), code)
    }

    fun onResult(requestCode: Int, grantResults: IntArray) {
        val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending.remove(requestCode)?.success(ok)
    }
}
