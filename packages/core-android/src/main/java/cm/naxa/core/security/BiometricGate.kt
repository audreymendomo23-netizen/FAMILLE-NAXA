package cm.naxa.core.security

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/** Optional biometric unlock; callers must keep the PIN fallback available. */
object BiometricGate {
    fun available(activity: FragmentActivity): Boolean =
        BiometricManager.from(activity).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
    fun prompt(activity: FragmentActivity, onSuccess: () -> Unit, onFailure: (String) -> Unit) {
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) { onSuccess() }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) { onFailure(errString.toString()) }
            override fun onAuthenticationFailed() { onFailure("Biometric verification failed") }
        })
        prompt.authenticate(BiometricPrompt.PromptInfo.Builder()
            .setTitle("Famille NAXA")
            .setSubtitle("Unlock this device")
            .setNegativeButtonText("Use local PIN")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build())
    }
}
