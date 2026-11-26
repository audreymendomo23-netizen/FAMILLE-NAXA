package cm.naxa.bootik
// Adapted from NAXA Services LocalAccessPin.kt, member-scoped Keystore HMAC.
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
internal object LocalAccessPinGatePolicy {
    fun requiresUnlock(authenticatedMemberId: String?, unlockedMemberId: String?): Boolean =
        authenticatedMemberId != null && authenticatedMemberId != unlockedMemberId
}

internal object LocalAccessPinPolicy {
    const val PIN_LENGTH = 4
    const val MAX_ATTEMPTS_PER_WINDOW = 5
    private val backoffMillis = longArrayOf(30_000L, 60_000L, 300_000L, 900_000L, 3_600_000L)
    fun isValid(pin: String): Boolean = pin.length == PIN_LENGTH && pin.all { it in '0'..'9' }
    fun lockoutDurationMillis(failures: Int): Long {
        if (failures <= 0 || failures % MAX_ATTEMPTS_PER_WINDOW != 0) return 0L
        val tier = failures / MAX_ATTEMPTS_PER_WINDOW - 1
        return backoffMillis[tier.coerceIn(0, backoffMillis.lastIndex)]
    }
    fun attemptsRemaining(failures: Int): Int = MAX_ATTEMPTS_PER_WINDOW - failures % MAX_ATTEMPTS_PER_WINDOW
}

internal enum class LocalAccessPinCode {
    SUCCESS, INVALID, LOCKED, NOT_CONFIGURED, INVALID_FORMAT, STORAGE_ERROR, ALREADY_CONFIGURED
}
internal data class LocalAccessPinResult(
    val code: LocalAccessPinCode,
    val retryAtMillis: Long = 0L,
    val attemptsRemaining: Int = 0
)

/** A per-member HMAC verifier; the PIN is never persisted and the key never leaves Android Keystore. */
internal class LocalAccessPinManager(context: Context) {
    private val preferences = context.getSharedPreferences("bootik_local_access_v1", Context.MODE_PRIVATE)
    private val random = SecureRandom()

    @Synchronized fun isConfigured(memberId: String): Boolean {
        if (memberId.isBlank()) return false
        val p = prefix(memberId)
        return preferences.contains(p + "verifier") || preferences.contains(p + "salt")
    }

    /** Never bypass a PIN lockout using a different local unlock mechanism. */
    @Synchronized fun canUseBiometric(memberId: String, nowMillis: Long = System.currentTimeMillis()): Boolean {
        if (!isConfigured(memberId)) return false
        return runCatching {
            val p = prefix(memberId)
            preferences.contains(p + "verifier") && preferences.contains(p + "salt") &&
                preferences.getLong(p + "locked_until", 0L) <= nowMillis &&
                keyFor(memberId, false) != null
        }.getOrDefault(false)
    }

    @Synchronized fun enroll(memberId: String, pin: String): LocalAccessPinResult {
        if (memberId.isBlank() || !LocalAccessPinPolicy.isValid(pin)) return LocalAccessPinResult(LocalAccessPinCode.INVALID_FORMAT)
        if (isConfigured(memberId)) return LocalAccessPinResult(LocalAccessPinCode.ALREADY_CONFIGURED)
        return runCatching {
            val salt = ByteArray(32).also(random::nextBytes)
            val key = keyFor(memberId, true) ?: return LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
            val hash = verifier(key, memberId, salt, pin)
            val p = prefix(memberId)
            val saved = preferences.edit()
                .putString(p + "salt", Base64.encodeToString(salt, Base64.NO_WRAP))
                .putString(p + "verifier", Base64.encodeToString(hash, Base64.NO_WRAP))
                .putInt(p + "failures", 0).putLong(p + "locked_until", 0L).commit()
            LocalAccessPinResult(if (saved) LocalAccessPinCode.SUCCESS else LocalAccessPinCode.STORAGE_ERROR)
        }.getOrElse { LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR) }
    }

    @Synchronized fun verify(memberId: String, pin: String, nowMillis: Long = System.currentTimeMillis()): LocalAccessPinResult {
        if (memberId.isBlank() || !LocalAccessPinPolicy.isValid(pin)) return LocalAccessPinResult(LocalAccessPinCode.INVALID_FORMAT)
        val p = prefix(memberId)
        if (!isConfigured(memberId)) return LocalAccessPinResult(LocalAccessPinCode.NOT_CONFIGURED)
        val retryAt = preferences.getLong(p + "locked_until", 0L)
        if (retryAt > nowMillis) return LocalAccessPinResult(LocalAccessPinCode.LOCKED, retryAt)
        return runCatching {
            val saltText = preferences.getString(p + "salt", null) ?: return LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
            val hashText = preferences.getString(p + "verifier", null) ?: return LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
            val salt = Base64.decode(saltText, Base64.NO_WRAP)
            val expected = Base64.decode(hashText, Base64.NO_WRAP)
            if (salt.size != 32 || expected.size != 32) return LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
            val key = keyFor(memberId, false) ?: return LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
            val actual = verifier(key, memberId, salt, pin)
            if (MessageDigest.isEqual(expected, actual)) {
                val reset = preferences.edit().putInt(p + "failures", 0).putLong(p + "locked_until", 0L).commit()
                return LocalAccessPinResult(if (reset) LocalAccessPinCode.SUCCESS else LocalAccessPinCode.STORAGE_ERROR)
            }
            val failures = (preferences.getInt(p + "failures", 0).coerceAtLeast(0) + 1).coerceAtMost(1_000_000)
            val duration = LocalAccessPinPolicy.lockoutDurationMillis(failures)
            val nextRetry = if (duration > 0L) nowMillis + duration else 0L
            val saved = preferences.edit().putInt(p + "failures", failures).putLong(p + "locked_until", nextRetry).commit()
            when {
                !saved -> LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
                duration > 0L -> LocalAccessPinResult(LocalAccessPinCode.LOCKED, nextRetry)
                else -> LocalAccessPinResult(LocalAccessPinCode.INVALID, attemptsRemaining = LocalAccessPinPolicy.attemptsRemaining(failures))
            }
        }.getOrElse { LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR) }
    }

    @Synchronized fun changePin(memberId: String, current: String, next: String): LocalAccessPinResult {
        if (!LocalAccessPinPolicy.isValid(next)) return LocalAccessPinResult(LocalAccessPinCode.INVALID_FORMAT)
        val checked = verify(memberId, current)
        if (checked.code != LocalAccessPinCode.SUCCESS) return checked
        return runCatching {
            val salt = ByteArray(32).also(random::nextBytes)
            val key = keyFor(memberId, false) ?: return LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR)
            val p = prefix(memberId)
            val hash = verifier(key, memberId, salt, next)
            val saved = preferences.edit()
                .putString(p + "salt", Base64.encodeToString(salt, Base64.NO_WRAP))
                .putString(p + "verifier", Base64.encodeToString(hash, Base64.NO_WRAP))
                .putInt(p + "failures", 0).putLong(p + "locked_until", 0L).commit()
            LocalAccessPinResult(if (saved) LocalAccessPinCode.SUCCESS else LocalAccessPinCode.STORAGE_ERROR)
        }.getOrElse { LocalAccessPinResult(LocalAccessPinCode.STORAGE_ERROR) }
    }

    /** Only called after AuthApi.login has authenticated this exact member. */
    @Synchronized fun resetAfterValidatedLogin(memberId: String): Boolean {
        if (memberId.isBlank()) return false
        return runCatching {
            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            store.deleteEntry(alias(memberId))
            val p = prefix(memberId)
            preferences.edit().remove(p + "salt").remove(p + "verifier")
                .remove(p + "failures").remove(p + "locked_until").commit()
        }.getOrDefault(false)
    }

    private fun keyFor(memberId: String, create: Boolean): SecretKey? {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val name = alias(memberId)
        (store.getKey(name, null) as? SecretKey)?.let { return it }
        if (!create) return null
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(name, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
                .setDigests(KeyProperties.DIGEST_SHA256).build()
        )
        return generator.generateKey()
    }

    private fun verifier(key: SecretKey, memberId: String, salt: ByteArray, pin: String): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(key)
        val payload = listOf("bootik-local-pin-v1", memberId, Base64.encodeToString(salt, Base64.NO_WRAP), pin).joinToString("|")
        return mac.doFinal(payload.toByteArray(StandardCharsets.UTF_8))
    }
    private fun prefix(memberId: String) = "member:" + digest(memberId) + ":"
    private fun alias(memberId: String) = "bootik-pin-v1-" + digest(memberId).take(32)
    private fun digest(value: String) = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it.toInt() and 0xff) }
}

