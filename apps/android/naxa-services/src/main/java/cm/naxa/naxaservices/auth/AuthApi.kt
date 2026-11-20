package cm.naxa.naxaservices.auth

import android.os.Build
import android.provider.Settings
import android.content.Context
import cm.naxa.naxaservices.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

data class AuthAccount(
    val memberId: String,
    val displayName: String,
    val roleCode: String,
    val organizationId: String,
    val activeSiteIds: List<String>
)

data class AuthSession(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long,
    val requirePasswordChange: Boolean,
    val account: AuthAccount
)

class AuthApi(private val context: Context) {
    private val endpoint: String get() = BuildConfig.AUTH_FUNCTION_URL.trim()
    private val anonKey: String get() = BuildConfig.SUPABASE_ANON_KEY.trim()

    suspend fun login(identifier: String, password: String, rememberDevice: Boolean): AuthSession =
        requestSession(
            JSONObject()
                .put("action", "login")
                .put("app_code", "naxa-services")
                .put("identifier", identifier.trim().uppercase())
                .put("password", password)
                .put("remember_device", rememberDevice)
                .put("device", devicePayload())
        )

    suspend fun refresh(refreshToken: String): AuthSession =
        requestSession(
            JSONObject()
                .put("action", "refresh")
                .put("app_code", "naxa-services")
                .put("refresh_token", refreshToken)
                .put("device", devicePayload())
        )

    suspend fun requestRecovery(identifier: String, note: String) {
        request(
            JSONObject()
                .put("action", "request_recovery")
                .put("app_code", "naxa-services")
                .put("identifier", identifier.trim().uppercase())
                .put("request_note", note.trim())
                .put("device", devicePayload())
        )
    }

    suspend fun changePassword(accessToken: String, currentPassword: String, newPassword: String): AuthSession =
        requestSession(
            JSONObject()
                .put("action", "change_password")
                .put("app_code", "naxa-services")
                .put("current_password", currentPassword)
                .put("new_password", newPassword)
                .put("device", devicePayload()),
            accessToken
        )

    suspend fun logout(accessToken: String) {
        request(
            JSONObject()
                .put("action", "logout")
                .put("app_code", "naxa-services")
                .put("device", devicePayload()),
            accessToken
        )
    }

    private suspend fun requestSession(body: JSONObject, bearer: String? = null): AuthSession {
        val json = request(body, bearer)
        val account = json.optJSONObject("account")
            ?: throw AuthApiException("Réponse Auth invalide : compte absent.")
        val siteIds = mutableListOf<String>()
        val siteArray: JSONArray? = account.optJSONArray("active_site_ids")
        if (siteArray != null) {
            for (i in 0 until siteArray.length()) siteIds += siteArray.optString(i)
        }
        return AuthSession(
            accessToken = json.optString("access_token"),
            refreshToken = json.optString("refresh_token"),
            expiresIn = json.optLong("expires_in", 3600L),
            requirePasswordChange = json.optBoolean("require_password_change", false),
            account = AuthAccount(
                memberId = account.optString("member_id"),
                displayName = account.optString("display_name"),
                roleCode = account.optString("role_code"),
                organizationId = account.optString("organization_id"),
                activeSiteIds = siteIds
            )
        ).also {
            if (it.accessToken.isBlank() || it.refreshToken.isBlank()) {
                throw AuthApiException("La session reçue est incomplète.")
            }
        }
    }

    private suspend fun request(body: JSONObject, bearer: String? = null): JSONObject = withContext(Dispatchers.IO) {
        if (endpoint.isBlank() || anonKey.isBlank()) {
            throw AuthApiException("Le service d'authentification NAXA Services n'est pas encore configuré.")
        }
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 12000
                readTimeout = 15000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("apikey", anonKey)
                setRequestProperty("Authorization", "Bearer " + (bearer ?: anonKey))
            }
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val responseText = stream?.use { input ->
                BufferedReader(InputStreamReader(input, Charsets.UTF_8)).readText()
            }.orEmpty()
            val response = runCatching { JSONObject(responseText) }.getOrElse { JSONObject() }
            if (status !in 200..299) {
                val message = response.optString("message").ifBlank {
                    if (status == 429) "Trop de tentatives. Réessaie plus tard."
                    else "Connexion indisponible. Vérifie le réseau ou contacte le responsable."
                }
                throw AuthApiException(message, status)
            }
            response
        } catch (e: AuthApiException) {
            throw e
        } catch (e: Exception) {
            throw AuthApiException("Impossible de joindre le service. Vérifie la connexion Internet.")
        } finally {
            connection?.disconnect()
        }
    }

    private fun devicePayload(): JSONObject {
        val androidId = runCatching {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        }.getOrNull().orEmpty()
        val devicePrefs = context.getSharedPreferences("naxa_services_device", Context.MODE_PRIVATE)
        val installationId = devicePrefs.getString("installation_id", null) ?: UUID.randomUUID().toString().also {
            devicePrefs.edit().putString("installation_id", it).apply()
        }
        return JSONObject()
            .put("installation_id", installationId)
            .put("label", Build.MODEL.orEmpty().take(80))
            .put("platform", "android")
    }
}

class AuthApiException(message: String, val statusCode: Int? = null) : Exception(message)
