package cm.naxa.naxaservices

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

internal object LocalAccessPinGatePolicy {
    fun requiresUnlock(authenticatedMemberId: String?, unlockedMemberId: String?): Boolean =
        !authenticatedMemberId.isNullOrBlank() && authenticatedMemberId != unlockedMemberId
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
    private val preferences = context.getSharedPreferences("naxa_services_local_access_v1", Context.MODE_PRIVATE)
    private val random = SecureRandom()

    @Synchronized fun isConfigured(memberId: String): Boolean {
        if (memberId.isBlank()) return false
        val p = prefix(memberId)
        return preferences.contains(p + "verifier") || preferences.contains(p + "salt")
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
        val payload = listOf("naxa-services-local-pin-v1", memberId, Base64.encodeToString(salt, Base64.NO_WRAP), pin).joinToString("|")
        return mac.doFinal(payload.toByteArray(StandardCharsets.UTF_8))
    }
    private fun prefix(memberId: String) = "member:" + digest(memberId) + ":"
    private fun alias(memberId: String) = "naxa-services-pin-v1-" + digest(memberId).take(32)
    private fun digest(value: String) = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it.toInt() and 0xff) }
}

@Composable
internal fun LocalAccessPinGate(
    memberId: String,
    displayName: String,
    isSetup: Boolean,
    authApi: AuthApi,
    manager: LocalAccessPinManager,
    rememberSession: Boolean,
    onUnlocked: () -> Unit,
    onReauthenticated: (AuthSession) -> Unit
) {
    BackHandler(enabled = true) {}
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var mode by rememberSaveable(memberId, isSetup) { mutableStateOf(if (isSetup) "setup" else "unlock") }
    var pin by rememberSaveable(memberId, isSetup) { mutableStateOf("") }
    var confirm by rememberSaveable(memberId, isSetup) { mutableStateOf("") }
    var loginId by rememberSaveable(memberId) { mutableStateOf("") }
    var password by rememberSaveable(memberId) { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var retryAt by rememberSaveable(memberId) { mutableLongStateOf(0L) }
    var clock by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(retryAt) {
        while (retryAt > clock) { delay(1_000L); clock = System.currentTimeMillis() }
    }
    val blockedSeconds = ((retryAt - clock + 999L) / 1_000L).coerceAtLeast(0L).toInt()
    fun digits(value: String) = value.filter { it in '0'..'9' }.take(4)

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(Modifier.fillMaxSize().padding(26.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text("NAXA SERVICES", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black)
            Spacer(Modifier.height(14.dp))
            Text(stringResource(R.string.local_pin_title), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(
                when (mode) {
                    "setup" -> stringResource(R.string.local_pin_setup_explainer)
                    "reauth" -> stringResource(R.string.local_pin_reauth_explainer)
                    else -> stringResource(R.string.local_pin_unlock_explainer)
                },
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(8.dp))
            Text(displayName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(20.dp))
            if (mode == "reauth") {
                Text(stringResource(R.string.local_pin_reauth_title), fontWeight = FontWeight.Bold)
                OutlinedTextField(loginId, { loginId = it.uppercase().take(64) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.local_pin_reauth_identifier)) }, singleLine = true)
                OutlinedTextField(password, { password = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.local_pin_reauth_password)) }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
                if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                Button(
                    onClick = {
                        scope.launch {
                            busy = true
                            error = null
                            runCatching { authApi.login(loginId, password, rememberSession) }
                                .onSuccess { fresh ->
                                    if (fresh.account.memberId != memberId) {
                                        runCatching { authApi.logout(fresh.accessToken) }
                                        error = context.getString(R.string.local_pin_reauth_account_mismatch)
                                    } else {
                                        val reset = withContext(Dispatchers.IO) { manager.resetAfterValidatedLogin(memberId) }
                                        if (reset) { password = ""; onReauthenticated(fresh) }
                                        else error = context.getString(R.string.local_pin_storage_error)
                                    }
                                }
                                .onFailure { error = context.getString(R.string.local_pin_reauth_failed) }
                            busy = false
                        }
                    },
                    enabled = !busy && loginId.isNotBlank() && password.isNotBlank(),
                    modifier = Modifier.fillMaxWidth()
                ) { Text(if (busy) "…" else stringResource(R.string.local_pin_reauth_submit)) }
                OutlinedButton(onClick = { mode = "unlock"; error = null }, enabled = !busy) {
                    Text(stringResource(R.string.local_pin_reauth_back))
                }
            } else {
                OutlinedTextField(pin, { pin = digits(it); error = null }, Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.local_pin_entry)) }, visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), singleLine = true)
                if (mode == "setup") {
                    OutlinedTextField(confirm, { confirm = digits(it); error = null }, Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.local_pin_confirmation)) }, visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), singleLine = true)
                }
                if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                if (blockedSeconds > 0) Text(context.getString(R.string.local_pin_blocked, blockedSeconds), color = MaterialTheme.colorScheme.error)
                Button(
                    onClick = {
                        when {
                            !LocalAccessPinPolicy.isValid(pin) -> error = context.getString(R.string.local_pin_four_digits)
                            mode == "setup" && pin != confirm -> error = context.getString(R.string.local_pin_mismatch)
                            else -> scope.launch {
                                busy = true
                                error = null
                                if (mode == "setup") {
                                    val result = withContext(Dispatchers.IO) { manager.enroll(memberId, pin) }
                                    when (result.code) {
                                        LocalAccessPinCode.SUCCESS -> onUnlocked()
                                        LocalAccessPinCode.ALREADY_CONFIGURED -> { mode = "unlock"; pin = "" }
                                        else -> error = context.getString(R.string.local_pin_storage_error)
                                    }
                                } else {
                                    val result = withContext(Dispatchers.IO) { manager.verify(memberId, pin) }
                                    when (result.code) {
                                        LocalAccessPinCode.SUCCESS -> onUnlocked()
                                        LocalAccessPinCode.INVALID -> { error = context.getString(R.string.local_pin_invalid_attempts, result.attemptsRemaining); pin = "" }
                                        LocalAccessPinCode.LOCKED -> { retryAt = result.retryAtMillis; clock = System.currentTimeMillis(); pin = "" }
                                        LocalAccessPinCode.NOT_CONFIGURED -> mode = "setup"
                                        LocalAccessPinCode.INVALID_FORMAT -> error = context.getString(R.string.local_pin_four_digits)
                                        else -> error = context.getString(R.string.local_pin_storage_error)
                                    }
                                }
                                busy = false
                            }
                        }
                    },
                    enabled = !busy && pin.length == 4 && blockedSeconds == 0,
                    modifier = Modifier.fillMaxWidth()
                ) { Text(if (busy) "…" else if (mode == "setup") stringResource(R.string.local_pin_create) else stringResource(R.string.local_pin_unlock)) }
                if (mode == "unlock") {
                    OutlinedButton(onClick = { mode = "reauth"; pin = ""; error = null }, enabled = !busy) {
                        Text(stringResource(R.string.local_pin_forgot))
                    }
                }
            }
        }
    }
}

@Composable
internal fun LocalAccessPinSettingsCard(memberId: String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val manager = remember(context) { LocalAccessPinManager(context) }
    var expanded by rememberSaveable(memberId) { mutableStateOf(false) }
    var current by rememberSaveable(memberId) { mutableStateOf("") }
    var next by rememberSaveable(memberId) { mutableStateOf("") }
    var confirm by rememberSaveable(memberId) { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var success by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = { expanded = !expanded; message = null }) { Text(stringResource(R.string.local_pin_change_open)) }
        if (expanded) {
            Text(stringResource(R.string.local_pin_change_title), fontWeight = FontWeight.SemiBold)
            OutlinedTextField(current, { current = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.local_pin_current)) }, visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), singleLine = true)
            OutlinedTextField(next, { next = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.local_pin_new)) }, visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), singleLine = true)
            OutlinedTextField(confirm, { confirm = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.local_pin_confirm_new)) }, visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), singleLine = true)
            if (!message.isNullOrBlank()) Text(message!!, color = if (success) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
            Button(
                onClick = {
                    when {
                        !LocalAccessPinPolicy.isValid(next) -> message = context.getString(R.string.local_pin_four_digits)
                        next != confirm -> message = context.getString(R.string.local_pin_mismatch)
                        else -> scope.launch {
                            busy = true
                            success = false
                            val result = withContext(Dispatchers.IO) { manager.changePin(memberId, current, next) }
                            if (result.code == LocalAccessPinCode.SUCCESS) {
                                success = true
                                message = context.getString(R.string.local_pin_change_saved)
                                current = ""; next = ""; confirm = ""; expanded = false
                            } else message = context.getString(R.string.local_pin_change_failed)
                            busy = false
                        }
                    }
                },
                enabled = !busy && current.length == 4 && next.length == 4 && confirm.length == 4,
                modifier = Modifier.fillMaxWidth()
            ) { Text(stringResource(R.string.local_pin_change_submit)) }
            OutlinedButton(onClick = { expanded = false; current = ""; next = ""; confirm = ""; message = null }, enabled = !busy) {
                Text(stringResource(R.string.local_pin_change_cancel))
            }
        }
        if (!message.isNullOrBlank() && !expanded) Text(message!!, color = if (success) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
    }
}
