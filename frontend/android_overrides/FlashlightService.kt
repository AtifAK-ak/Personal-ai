package __PACKAGE__

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlashlightService(private val ctx: Context) : NativeService {
    override val methods = setOf("flashlight")

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        val on = call.argument<Boolean>("on") ?: false
        val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = cm.cameraIdList.firstOrNull {
            cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
        if (id == null) {
            result.error("NO_FLASHLIGHT", "This device has no flashlight", null)
            return
        }
        cm.setTorchMode(id, on)
        result.success(on)
    }
}
