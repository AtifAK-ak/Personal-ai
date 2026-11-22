package __PACKAGE__

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** One-shot speech to text using the phone's own recognizer. Argument "locale", e.g. ur-PK. */
class SpeechService(private val activity: Activity) : NativeService {
    override val methods = setOf("speech.listen", "speech.stop")

    private var recognizer: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "speech.stop") {
            recognizer?.stopListening()
            result.success(true)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            result.error("NO_STT", "Speech recognition is not available on this phone", null)
            return
        }
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("NO_PERMISSION", "Microphone permission is needed", null)
            return
        }
        pending?.error("CANCELLED", "Replaced by a new request", null)
        pending = result
        recognizer?.destroy()
        val rec = SpeechRecognizer.createSpeechRecognizer(activity)
        recognizer = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}

            override fun onError(error: Int) {
                pending?.error("STT_ERROR", "I could not hear that (code $error)", null)
                pending = null
            }

            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                pending?.success(text)
                pending = null
            }
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, call.argument<String>("locale") ?: "en-US")
        rec.startListening(intent)
    }
}
