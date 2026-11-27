package cm.naxa.widemeet.auth

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Stores refresh/access tokens only when the user explicitly enables
 * "Rester connecté". The AES key is non-exportable and lives in Android Keystore.
 * Passwords are never persisted.
 */
class SessionVault(private val context: Context) {
    private val preferences = context.getSharedPreferences("widemeet_secure_session", Context.MODE_PRIVATE)

    fun save(session: VaultSession, rememberMe: Boolean) {
        if (!rememberMe) { clear(); return }
        require(session.accessToken.isNotBlank() && session.refreshToken.isNotBlank() && session.deviceId.isNotBlank())
        check(preferences.edit()
            .putString("access", encrypt(session.accessToken))
            .putString("refresh", encrypt(session.refreshToken))
            .putString("device_id", encrypt(session.deviceId))
            .commit())
        BiometricUnlock(context).save(session.refreshToken)
    }

    fun loadRefreshToken(): String? = preferences.getString("refresh", null)?.let(::decrypt)

    fun loadAccessToken(): String? = preferences.getString("access", null)?.let(::decrypt)

    fun loadDeviceId(): String? = preferences.getString("device_id", null)?.let(::decrypt)

    fun clear() {
        BiometricUnlock(context).clear()
        if (!preferences.edit().clear().commit()) {
            runCatching { KeyStore.getInstance("AndroidKeyStore").apply { load(null); deleteEntry(KEY_ALIAS) } }
        }
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = cipher.iv + encrypted
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String? = runCatching {
        val payload = Base64.decode(value, Base64.NO_WRAP)
        val iv = payload.copyOfRange(0, 12)
        val encrypted = payload.copyOfRange(12, payload.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
        String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }.getOrNull()

    private fun getOrCreateKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build()
        )
        return generator.generateKey()
    }

    private companion object {
        const val KEY_ALIAS = "widemeet-session-v1"
    }
}
