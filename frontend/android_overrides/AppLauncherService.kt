package __PACKAGE__

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Opens an installed app by its visible name. No hardcoded list of apps. */
class AppLauncherService(private val ctx: Context) : NativeService {
    override val methods = setOf("app.open")

    private val aliases = mapOf(
        "insta" to "instagram",
        "fb" to "facebook",
        "yt" to "youtube",
        "play store" to "play store",
        "maps" to "maps"
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        val requested = call.argument<String>("name")?.trim()?.lowercase() ?: ""
        if (requested.isEmpty()) {
            result.error("NO_NAME", "App name required", null)
            return
        }
        val wanted = aliases[requested] ?: requested
        val pm = ctx.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = pm.queryIntentActivities(launcher, 0)
        val match = apps.firstOrNull { it.loadLabel(pm).toString().lowercase() == wanted }
            ?: apps.firstOrNull { it.loadLabel(pm).toString().lowercase().contains(wanted) }
        if (match == null) {
            result.error("APP_NOT_FOUND", "No installed app matches \"$requested\"", null)
            return
        }
        val intent = pm.getLaunchIntentForPackage(match.activityInfo.packageName)
        if (intent == null) {
            result.error("CANNOT_LAUNCH", "This app cannot be opened", null)
            return
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(intent)
        result.success(match.loadLabel(pm).toString())
    }
}
