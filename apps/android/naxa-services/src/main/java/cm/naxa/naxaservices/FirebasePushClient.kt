package cm.naxa.naxaservices

import android.content.Context
import androidx.core.content.edit
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.concurrent.TimeUnit

data class PushRegistrationSnapshot(
    val enabled: Boolean = false,
    val token: String? = null,
    val registeredMemberId: String? = null,
    val registeredSessionKey: String? = null,
    val errorMessage: String? = null,
    val retryNonce: Int = 0
)

internal object PushTokenRegistry {
    private const val PREFS = "naxa_services_push_preferences"
    private const val KEY_ENABLED = "remote_push_enabled"
    private val mutableState = MutableStateFlow(PushRegistrationSnapshot())
    val state: StateFlow<PushRegistrationSnapshot> = mutableState

    fun initialize(context: Context) {
        val enabled = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)
        mutableState.value = PushRegistrationSnapshot(enabled = enabled, retryNonce = mutableState.value.retryNonce + 1)
    }

    fun enable(context: Context, token: String) {
        require(token.length in 30..4096 && !token.any(Char::isWhitespace)) { "INVALID_FCM_TOKEN" }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putBoolean(KEY_ENABLED, true) }
        mutableState.value = PushRegistrationSnapshot(
            enabled = true,
            token = token,
            retryNonce = mutableState.value.retryNonce + 1
        )
    }

    fun updateToken(context: Context, token: String) {
        if (!context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)) return
        mutableState.value = mutableState.value.copy(
            enabled = true,
            token = token,
            registeredMemberId = null,
            registeredSessionKey = null,
            errorMessage = null,
            retryNonce = mutableState.value.retryNonce + 1
        )
    }

    fun onTokenRefresh(context: Context, token: String) = updateToken(context, token)

    fun disable(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putBoolean(KEY_ENABLED, false) }
        mutableState.value = PushRegistrationSnapshot(retryNonce = mutableState.value.retryNonce + 1)
    }

    fun markRegistered(memberId: String, sessionKey: String) {
        mutableState.value = mutableState.value.copy(
            registeredMemberId = memberId,
            registeredSessionKey = sessionKey,
            errorMessage = null
        )
    }

    fun markUnregistered() {
        mutableState.value = mutableState.value.copy(registeredMemberId = null, registeredSessionKey = null)
    }

    fun markFailed(message: String) {
        mutableState.value = mutableState.value.copy(errorMessage = message.take(180))
    }

    fun retry() {
        mutableState.value = mutableState.value.copy(
            registeredMemberId = null,
            registeredSessionKey = null,
            errorMessage = null,
            retryNonce = mutableState.value.retryNonce + 1
        )
    }
}

internal object FirebasePushClient {
    private fun configuredOptions(): FirebaseOptions? {
        val apiKey = BuildConfig.FIREBASE_API_KEY.trim()
        val appId = BuildConfig.FIREBASE_APP_ID.trim()
        val projectId = BuildConfig.FIREBASE_PROJECT_ID.trim()
        val senderId = BuildConfig.FIREBASE_SENDER_ID.trim()
        if (apiKey.isBlank() || appId.isBlank() || projectId.isBlank() || senderId.isBlank()) return null
        return FirebaseOptions.Builder()
            .setApiKey(apiKey)
            .setApplicationId(appId)
            .setProjectId(projectId)
            .setGcmSenderId(senderId)
            .build()
    }

    fun initialize(context: Context): Boolean {
        if (FirebaseApp.getApps(context).any { it.name == FirebaseApp.DEFAULT_APP_NAME }) return true
        val options = configuredOptions() ?: return false
        return runCatching { FirebaseApp.initializeApp(context, options) != null }.getOrDefault(false)
    }

    fun isConfigured(context: Context): Boolean = initialize(context)

    suspend fun fetchToken(context: Context): String = withContext(Dispatchers.IO) {
        if (!initialize(context)) throw IllegalStateException("FIREBASE_NOT_CONFIGURED")
        val app = FirebaseApp.getApps(context).firstOrNull { it.name == FirebaseApp.DEFAULT_APP_NAME }
            ?: throw IllegalStateException("FIREBASE_DEFAULT_APP_UNAVAILABLE")
        val token = Tasks.await(FirebaseMessaging.getInstance(app).token, 20, TimeUnit.SECONDS)
        require(token.isNotBlank()) { "FCM_EMPTY_TOKEN" }
        token
    }
}

