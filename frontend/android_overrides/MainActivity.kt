package __PACKAGE__

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Kotlin native layer. Channel "alex/native"; see docs/NATIVE_CHANNEL.md. */
class MainActivity : FlutterActivity() {
    private var permissions: PermissionService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val perms = PermissionService(this)
        permissions = perms
        val ctx = applicationContext
        val registry = CommandRegistry(
            listOf(
                PingService(),
                FlashlightService(ctx),
                VolumeService(ctx),
                AppLauncherService(ctx),
                PrefsService(ctx),
                perms
            )
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alex/native")
            .setMethodCallHandler { call, result -> registry.dispatch(call, result) }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        this.permissions?.onResult(requestCode, grantResults)
    }
}
