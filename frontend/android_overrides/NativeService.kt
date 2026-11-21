package __PACKAGE__

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** One Android capability. Add a new class + one line in MainActivity to extend ALEX. */
interface NativeService {
    val methods: Set<String>
    fun handle(call: MethodCall, result: MethodChannel.Result)
}

/** Maps channel method names to services. Unknown methods are rejected. */
class CommandRegistry(services: List<NativeService>) {
    private val map = HashMap<String, NativeService>()

    init {
        services.forEach { s -> s.methods.forEach { m -> map[m] = s } }
    }

    fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        val service = map[call.method]
        if (service == null) {
            result.notImplemented()
            return
        }
        try {
            service.handle(call, result)
        } catch (e: Exception) {
            result.error("NATIVE_ERROR", e.message, null)
        }
    }
}

class PingService : NativeService {
    override val methods = setOf("ping")

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        result.success("Kotlin bridge OK (Android API ${android.os.Build.VERSION.SDK_INT})")
    }
}
