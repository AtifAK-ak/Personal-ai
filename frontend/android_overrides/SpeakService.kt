package __PACKAGE__

import android.content.Context
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

/** Speaks with the phone's voice (tts.speak) or plays MP3 bytes from the backend (audio.play). */
class SpeakService(private val ctx: Context) : NativeService {
    override val methods = setOf("tts.speak", "audio.play", "audio.stop")

    private var tts: TextToSpeech? = null
    private var ready = false
    private var after: (() -> Unit)? = null
    private var player: MediaPlayer? = null

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "tts.speak" -> {
                speak(call.argument<String>("text") ?: "", call.argument<String>("lang") ?: "en-US")
                result.success(true)
            }
            "audio.play" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("NO_AUDIO", "No audio data", null)
                    return
                }
                play(bytes)
                result.success(true)
            }
            else -> {
                stopAll()
                result.success(true)
            }
        }
    }

    private fun speak(text: String, lang: String) {
        if (text.isBlank()) return
        val run: () -> Unit = {
            val t = tts
            if (t != null) {
                t.language = Locale.forLanguageTag(lang)
                t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "alex")
            }
        }
        if (ready) {
            run()
            return
        }
        after = run
        if (tts == null) {
            tts = TextToSpeech(ctx) { status ->
                ready = status == TextToSpeech.SUCCESS
                if (ready) after?.invoke()
                after = null
            }
        }
    }

    private fun play(bytes: ByteArray) {
        stopAll()
        val file = File(ctx.cacheDir, "alex_tts.mp3")
        file.writeBytes(bytes)
        val mp = MediaPlayer()
        mp.setDataSource(file.absolutePath)
        mp.setOnCompletionListener {
            it.release()
            if (player === it) player = null
        }
        mp.prepare()
        mp.start()
        player = mp
    }

    private fun stopAll() {
        tts?.stop()
        player?.let {
            try {
                it.stop()
            } catch (e: IllegalStateException) {
            }
            it.release()
        }
        player = null
    }
}
