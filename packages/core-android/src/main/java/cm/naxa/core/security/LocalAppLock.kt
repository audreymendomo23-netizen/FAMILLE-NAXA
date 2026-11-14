package cm.naxa.core.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec

/** Device-local gate only. The PIN never leaves the device and is never an Auth credential. */
class LocalAppLock(context: Context) {
    private val prefs = EncryptedSharedPreferences.create(
        context, "famille_local_lock",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_SIGN)
            .setDigests(KeyProperties.DIGEST_SHA256).setUserAuthenticationRequired(false).build())
        return generator.generateKey()
    }
    private fun digest(pin: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(key())
        return mac.doFinal(pin.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
    fun isConfigured(): Boolean = prefs.contains("pin_hmac")
    fun configure(pin: String) {
        require(pin.matches(Regex("\\d{4}"))) { "PIN must contain four digits" }
        prefs.edit().putString("pin_hmac", digest(pin)).putInt("failures", 0).putLong("locked_until", 0L).apply()
    }
    fun verify(pin: String, now: Long = System.currentTimeMillis()): Verification {
        val lockedUntil = prefs.getLong("locked_until", 0L)
        if (now < lockedUntil) return Verification.Locked(lockedUntil)
        val expected = prefs.getString("pin_hmac", null) ?: return Verification.NotConfigured
        if (pin.matches(Regex("\\d{4}")) && digest(pin) == expected) {
            prefs.edit().putInt("failures", 0).putLong("locked_until", 0L).apply()
            return Verification.Accepted
        }
        val failures = prefs.getInt("failures", 0) + 1
        val until = if (failures >= 5) now + 15 * 60 * 1000L else 0L
        prefs.edit().putInt("failures", if (until > 0) 0 else failures).putLong("locked_until", until).apply()
        return if (until > 0) Verification.Locked(until) else Verification.Rejected(5 - failures)
    }
    sealed interface Verification {
        data object Accepted : Verification
        data object NotConfigured : Verification
        data class Rejected(val attemptsRemaining: Int) : Verification
        data class Locked(val untilEpochMillis: Long) : Verification
    }
    companion object { private const val KEY_ALIAS = "famille.local.pin.hmac.v1" }
}
