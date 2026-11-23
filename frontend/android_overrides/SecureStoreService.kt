package __PACKAGE__

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypted storage for secrets (API keys, tokens). AES-256-GCM with a key that lives
 * in the Android Keystore and never leaves the secure hardware/system service.
 */
class SecureStoreService(ctx: Context) : NativeService {
    override val methods = setOf("secure.get", "secure.set")

    private val prefs = ctx.getSharedPreferences("alex_secure", Context.MODE_PRIVATE)
    private val alias = "alex_secure_key"

    private fun secretKey(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        val existing = ks.getKey(alias, null) as? SecretKey
        if (existing != null) return existing
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val iv = cipher.iv
        val data = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(iv + data, Base64.NO_WRAP)
    }

    private fun decrypt(stored: String): String? {
        return try {
            val bytes = Base64.decode(stored, Base64.NO_WRAP)
            val iv = bytes.copyOfRange(0, 12)
            val data = bytes.copyOfRange(12, bytes.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(data), Charsets.UTF_8)
        } catch (e: Exception) {
            null
        }
    }

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("key")
        if (name.isNullOrEmpty()) {
            result.error("NO_KEY", "key required", null)
            return
        }
        if (call.method == "secure.get") {
            val stored = prefs.getString(name, null)
            result.success(if (stored == null) null else decrypt(stored))
            return
        }
        val value = call.argument<String>("value") ?: ""
        if (value.isEmpty()) {
            prefs.edit().remove(name).apply()
        } else {
            prefs.edit().putString(name, encrypt(value)).apply()
        }
        result.success(true)
    }
}
