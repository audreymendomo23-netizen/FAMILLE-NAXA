package cm.naxa.naxaservices.auth

import android.os.Build
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

data class AuthSite(
    val id: String,
    val code: String,
    val name: String,
    val addressLabel: String,
    val phoneContact: String
)

data class AuthAccount(
    val memberId: String,
    val displayName: String,
    val roleCode: String,
    val organizationId: String,
    val organizationName: String,
    val businessMode: String,
    val defaultLocale: String,
    val activeSiteIds: List<String>,
    val activeSites: List<AuthSite>,
    val activityProfile: String? = null,
    val acceptedLegalDocs: Set<String> = emptySet(),
    val discoveryCompleted: Boolean = false,
    val tourCompleted: Boolean = false
)

data class AuthSession(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long,
    val requirePasswordChange: Boolean,
    val account: AuthAccount
)

data class ProvisionScope(
    val siteId: String,
    val workstationId: String? = null
)

data class ProvisionedAccess(
    val loginId: String,
    val temporaryPassword: String,
    val displayName: String,
    val roleCode: String
)

data class RecoveryRequestItem(
    val id: String,
    val requestedAt: String,
    val displayName: String,
    val loginId: String,
    val roleCode: String,
    val note: String
)

data class RecoveryReset(
    val loginId: String,
    val temporaryPassword: String
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

    suspend fun refresh(refreshToken: String, rememberDevice: Boolean): AuthSession =
        requestSession(
            JSONObject()
                .put("action", "refresh")
                .put("app_code", "naxa-services")
                .put("refresh_token", refreshToken)
                .put("remember_device", rememberDevice)
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


    suspend fun updateOrganizationProfile(
        accessToken: String,
        displayName: String,
        businessMode: String,
        defaultLocale: String
    ) {
        require(displayName.trim().isNotEmpty()) { "Le nom de l’organisation est obligatoire." }
        require(businessMode in setOf("solo", "single_site_multi_workstation", "multi_site_network")) {
            "Modèle d’exploitation invalide."
        }
        require(defaultLocale in setOf("fr", "en")) { "Langue non prise en charge." }
        request(
            JSONObject()
                .put("action", "update_organization_profile")
                .put("app_code", "naxa-services")
                .put("display_name", displayName.trim())
                .put("business_mode", businessMode)
                .put("default_locale", defaultLocale),
            accessToken
        )
    }

    suspend fun setOrganizationActivityProfile(accessToken: String, activityProfile: String): String {
        require(NaxaActivityCatalog.find(activityProfile) != null) { "Profil d’activité non reconnu." }
        val result = request(
            JSONObject()
                .put("action", "set_activity_profile")
                .put("app_code", "naxa-services")
                .put("activity_profile", activityProfile),
            accessToken
        )
        return result.optString("activity_profile").takeIf { it.isNotBlank() } ?: activityProfile
    }

    suspend fun acceptLegalDocument(accessToken: String, documentType: String, version: String, locale: String) {
        require(documentType in setOf("terms", "privacy") && version.matches(Regex("^\\d{4}-\\d{2}-v\\d+$")) && locale in setOf("fr", "en")) {
            "Référence de document légal invalide."
        }
        request(
            JSONObject()
                .put("action", "accept_legal_document")
                .put("app_code", "naxa-services")
                .put("document_type", documentType)
                .put("document_version", version)
                .put("locale", locale),
            accessToken
        )
    }

    suspend fun completeOnboardingStep(accessToken: String, step: String) {
        require(step in setOf("discovery", "tour")) { "Étape d’intégration invalide." }
        request(
            JSONObject()
                .put("action", "complete_onboarding_step")
                .put("app_code", "naxa-services")
                .put("step", step),
            accessToken
        )
    }

    suspend fun provisionMember(
        accessToken: String,
        displayName: String,
        roleCode: String,
        scopes: List<ProvisionScope>,
        contactPhone: String = ""
    ): ProvisionedAccess {
        val normalizedScopes = scopes.distinctBy { it.siteId + ":" + (it.workstationId ?: "") }
        require(normalizedScopes.isNotEmpty() && normalizedScopes.size <= 20) {
            "Sélectionne entre 1 et 20 périmètres de point de vente."
        }
        val scopeArray = JSONArray()
        normalizedScopes.forEach { item ->
            require(item.siteId.isNotBlank()) { "Un point de vente sélectionné est invalide." }
            val scope = JSONObject()
                .put("scope_type", if (item.workstationId.isNullOrBlank()) "site" else "workstation")
                .put("site_id", item.siteId)
            if (!item.workstationId.isNullOrBlank()) scope.put("workstation_id", item.workstationId)
            scopeArray.put(scope)
        }
        val result = request(
            JSONObject()
                .put("action", "provision_member")
                .put("app_code", "naxa-services")
                .put("display_name", displayName.trim())
                .put("role_code", roleCode)
                .put("contact_phone", contactPhone.trim())
                .put("scopes", scopeArray),
            accessToken
        )
        return ProvisionedAccess(
            loginId = result.optString("login_id"),
            temporaryPassword = result.optString("temporary_password"),
            displayName = result.optString("display_name"),
            roleCode = result.optString("role_code")
        ).also {
            if (it.loginId.isBlank() || it.temporaryPassword.isBlank()) {
                throw AuthApiException("Réponse de création incomplète.")
            }
        }
    }

    suspend fun listRecoveryRequests(accessToken: String): List<RecoveryRequestItem> {
        val result = request(
            JSONObject()
                .put("action", "list_recovery_requests")
                .put("app_code", "naxa-services"),
            accessToken
        )
        val rows = result.optJSONArray("requests") ?: JSONArray()
        return buildList {
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                add(
                    RecoveryRequestItem(
                        id = row.optString("id"),
                        requestedAt = row.optString("requested_at"),
                        displayName = row.optString("display_name"),
                        loginId = row.optString("login_id"),
                        roleCode = row.optString("role_code"),
                        note = row.optString("request_note")
                    )
                )
            }
        }
    }

    suspend fun completeRecovery(
        accessToken: String,
        requestId: String,
        verificationMethod: String,
        verificationNote: String
    ): RecoveryReset {
        val result = request(
            JSONObject()
                .put("action", "complete_recovery")
                .put("app_code", "naxa-services")
                .put("recovery_request_id", requestId)
                .put("identity_check_method", verificationMethod.trim())
                .put("identity_check_note", verificationNote.trim()),
            accessToken
        )
        return RecoveryReset(
            loginId = result.optString("login_id"),
            temporaryPassword = result.optString("temporary_password")
        ).also {
            if (it.loginId.isBlank() || it.temporaryPassword.isBlank()) {
                throw AuthApiException("Réponse de réinitialisation incomplète.")
            }
        }
    }

    suspend fun revokeDevice(accessToken: String, installationId: String, accountId: String? = null) {
        val body = JSONObject()
            .put("action", "revoke_device")
            .put("app_code", "naxa-services")
            .put("installation_id", installationId)
        if (!accountId.isNullOrBlank()) body.put("account_id", accountId)
        request(body, accessToken)
    }

    suspend fun changePassword(session: AuthSession, currentPassword: String, newPassword: String): AuthSession =
        requestSession(
            JSONObject()
                .put("action", "change_password")
                .put("app_code", "naxa-services")
                .put("current_password", currentPassword)
                .put("new_password", newPassword)
                .put("refresh_token", session.refreshToken)
                .put("device", devicePayload()),
            session.accessToken
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
        val siteMetadata = mutableMapOf<String, AuthSite>()
        val activeSitesArray = account.optJSONArray("active_sites")
        if (activeSitesArray != null) {
            for (i in 0 until activeSitesArray.length()) {
                val item = activeSitesArray.optJSONObject(i) ?: continue
                val id = item.optString("id")
                if (id.isNotBlank() && id in siteIds) {
                    siteMetadata[id] = AuthSite(
                        id = id,
                        code = item.optString("code"),
                        name = item.optString("name").ifBlank { "Point de vente" },
                        addressLabel = item.optString("address_label"),
                        phoneContact = item.optString("phone_contact")
                    )
                }
            }
        }
        val activeSites = siteIds.map { id ->
            siteMetadata[id] ?: AuthSite(id, "", "Point de vente", "", "")
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
                organizationName = account.optString("organization_name").ifBlank { account.optString("display_name") },
                businessMode = account.optString("business_mode").takeIf { it in setOf("solo", "single_site_multi_workstation", "multi_site_network") } ?: "solo",
                defaultLocale = account.optString("default_locale").takeIf { it in setOf("fr", "en") } ?: "fr",
                activeSiteIds = siteIds,
                activeSites = activeSites,
                activityProfile = account.optString("activity_profile").takeIf { it.isNotBlank() },
                acceptedLegalDocs = buildSet {
                    val legal = account.optJSONArray("accepted_legal_documents") ?: JSONArray()
                    for (i in 0 until legal.length()) add(legal.optString(i))
                },
                discoveryCompleted = account.optBoolean("discovery_completed", false),
                tourCompleted = account.optBoolean("tour_completed", false)
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
