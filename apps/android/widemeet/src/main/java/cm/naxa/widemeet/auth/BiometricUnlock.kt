package cm.naxa.widemeet.auth

import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

/** Separate optional biometric envelope. The public key can wrap a rotated refresh
 * token; its non-exportable private key needs a strong biometric for EACH unwrap.
 * The PIN route remains independent. Never treat an unbound callback as proof. */
internal class BiometricUnlock(private val context: Context) {
    private val prefs = context.getSharedPreferences("widemeet-biometric-v2", Context.MODE_PRIVATE)
    private val alias = "widemeet-biometric-refresh-v2"
    private val oaep = OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT)
    private fun store() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun strongAvailable() = Build.VERSION.SDK_INT >= 30 &&
        context.getSystemService(BiometricManager::class.java)?.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS

    internal class Attempt internal constructor(val cipher: Cipher, internal val wrapped: ByteArray)

    fun save(refresh: String) {
        if (!strongAvailable()) { clear(); return }
        // Optional capability: a device lacking suitable hardware continues with PIN.
        runCatching {
            val ks = store()
            val cert = ks.getCertificate(alias)
            val publicKey = cert?.publicKey ?: KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore").apply {
                initialize(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_DECRYPT)
                    .setKeySize(2048)
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                    .setUserAuthenticationRequired(true)
                    .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                    .setInvalidatedByBiometricEnrollment(true)
                    .build())
            }.generateKeyPair().public
            // Use a normal public-key provider, not the authentication-bound private key.
            val externalPublic = KeyFactory.getInstance("RSA")
                .generatePublic(X509EncodedKeySpec(publicKey.encoded))
            val cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding")
            cipher.init(Cipher.ENCRYPT_MODE, externalPublic, oaep)
            check(prefs.edit().putString("wrapped", Base64.encodeToString(
                cipher.doFinal(refresh.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)).commit())
        }.onFailure { clear() }
    }

    fun available(): Boolean = strongAvailable() && prefs.contains("wrapped")

    fun prepare(): Attempt? = runCatching {
        if (!available()) return null
        val wrapped = Base64.decode(prefs.getString("wrapped", null) ?: return null, Base64.NO_WRAP)
        val privateKey = store().getKey(alias, null) ?: return null
        val cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding")
        cipher.init(Cipher.DECRYPT_MODE, privateKey, oaep)
        Attempt(cipher, wrapped)
    }.getOrNull()

    fun complete(attempt: Attempt, authenticated: Cipher?): String {
        require(authenticated === attempt.cipher) { "biometric_crypto_required" }
        require(available()) { "biometric_unavailable" }
        val current = Base64.decode(prefs.getString("wrapped", null) ?: error("biometric_missing"), Base64.NO_WRAP)
        require(java.security.MessageDigest.isEqual(current, attempt.wrapped)) { "biometric_session_changed" }
        // Keystore enforces authentication at doFinal, including on a forged UI callback.
        return String(attempt.cipher.doFinal(attempt.wrapped), Charsets.UTF_8)
    }

    fun clear() {
        prefs.edit().clear().commit()
        runCatching { store().deleteEntry(alias) }
    }
}
