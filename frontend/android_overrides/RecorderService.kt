package __PACKAGE__

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Audio recording while the app is open. Files go to the app's own storage. */
class RecorderService(private val ctx: Context) : NativeService {
    override val methods = setOf("record.start", "record.stop", "record.pause", "record.resume")

    private var recorder: MediaRecorder? = null
    private var path: String? = null

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "record.start" -> {
                if (ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    result.error("NO_PERMISSION", "Microphone permission is needed", null)
                    return
                }
                if (recorder != null) {
                    result.error("BUSY", "Already recording", null)
                    return
                }
                val dir = ctx.getExternalFilesDir(null) ?: ctx.filesDir
                val file = File(dir, "alex_rec_" + System.currentTimeMillis() + ".m4a")
                val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(ctx) else MediaRecorder()
                r.setAudioSource(MediaRecorder.AudioSource.MIC)
                r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                r.setOutputFile(file.absolutePath)
                r.prepare()
                r.start()
                recorder = r
                path = file.absolutePath
                result.success(file.absolutePath)
            }
            "record.pause" -> {
                recorder?.pause()
                result.success(recorder != null)
            }
            "record.resume" -> {
                recorder?.resume()
                result.success(recorder != null)
            }
            else -> {
                val r = recorder
                if (r == null) {
                    result.error("NOT_RECORDING", "Nothing is being recorded", null)
                    return
                }
                try {
                    r.stop()
                } catch (e: RuntimeException) {
                    // recording was too short to save
                }
                r.release()
                recorder = null
                result.success(path)
            }
        }
    }
}
