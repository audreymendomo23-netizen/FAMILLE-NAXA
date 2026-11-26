package cm.naxa.naxaservices.auth

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
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
    private val preferences = context.getSharedPreferences("naxa_services_secure_session", Context.MODE_PRIVATE)

    fun save(session: AuthSession) {
        preferences.edit()
            .putString("access", encrypt(session.accessToken))
            .putString("refresh", encrypt(session.refreshToken))
            .putString("member_id", session.account.memberId)
            .putString("device_id", encrypt(session.deviceId))
            .apply()
    }

    fun loadRefreshToken(): String? = preferences.getString("refresh", null)?.let(::decrypt)

    fun loadAccessToken(): String? = preferences.getString("access", null)?.let(::decrypt)

    fun loadDeviceId(): String? = preferences.getString("device_id", null)?.let(::decrypt)

    private fun bootCount():Int = Settings.Global.getInt(context.contentResolver,"boot_count",-1)
    internal fun clearOfflineSnapshot(){preferences.edit().remove("offline_snapshot").apply()}
    internal fun saveOfflineSnapshot(session:AuthSession,access:JSONObject) {
        if(loadRefreshToken()!=session.refreshToken||loadAccessToken()!=session.accessToken)return
        val wall=System.currentTimeMillis();val boot=bootCount()
        if(boot<0)return
        val claims=runCatching{JSONObject(String(Base64.decode(session.accessToken.split(".")[1],Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING),Charsets.UTF_8))}.getOrNull()?:return
        val iat=claims.optLong("iat",0)*1000L;val exp=claims.optLong("exp",0)*1000L
        if(iat<=0||iat>wall+120000||wall-iat>OfflineSessionPolicy.MAX_MS)return
        val until=OfflineSessionPolicy.expiresAt(session,access,exp,wall)?:run{clearOfflineSnapshot();return}
        val a=session.account;val sites=JSONArray()
        a.activeSites.forEach{s->sites.put(JSONObject().put("id",s.id).put("code",s.code).put("name",s.name).put("address",s.addressLabel).put("phone",s.phoneContact))}
        val payload=JSONObject().put("access",session.accessToken).put("refresh",session.refreshToken).put("device",session.deviceId)
            .put("member",a.memberId).put("display",a.displayName).put("role",a.roleCode).put("org",a.organizationId)
            .put("org_name",a.organizationName).put("mode",a.businessMode).put("locale",a.defaultLocale).put("activity",a.activityProfile)
            .put("legal",JSONArray(a.acceptedLegalDocs.toList())).put("site_ids",JSONArray(a.activeSiteIds)).put("sites",sites)
            .put("wall",wall).put("elapsed",SystemClock.elapsedRealtime()).put("boot",boot).put("until",until)
        preferences.edit().putString("offline_snapshot",encrypt(payload.toString())).apply()
    }
    internal fun loadOfflineSnapshot():AuthSession? = runCatching{
        val json=JSONObject(preferences.getString("offline_snapshot",null)?.let(::decrypt)?:return null)
        val now=System.currentTimeMillis()
        if(!OfflineSessionPolicy.valid(json.getLong("wall"),json.getLong("elapsed"),json.getInt("boot"),json.getLong("until"),now,SystemClock.elapsedRealtime(),bootCount()))return null
        if(loadAccessToken()!=json.getString("access")||loadRefreshToken()!=json.getString("refresh")||loadDeviceId()!=json.getString("device"))return null
        fun strings(name:String):List<String>{val ar=json.getJSONArray(name);return (0 until ar.length()).map{ar.getString(it)}}
        val rows=json.getJSONArray("sites")
        val sites=(0 until rows.length()).map{val s=rows.getJSONObject(it);AuthSite(s.getString("id"),s.getString("code"),s.getString("name"),s.getString("address"),s.getString("phone"))}
        AuthSession(json.getString("access"),json.getString("refresh"),((json.getLong("until")-now)/1000).coerceAtLeast(1),false,
            AuthAccount(json.getString("member"),json.getString("display"),json.getString("role"),json.getString("org"),json.getString("org_name"),
                json.getString("mode"),json.getString("locale"),strings("site_ids"),sites,json.getString("activity"),strings("legal").toSet(),true,true),
            json.getString("device"))
    }.getOrNull()

    fun clear() {
        preferences.edit().clear().apply()
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
        const val KEY_ALIAS = "naxa-services-session-v1"
    }
}
