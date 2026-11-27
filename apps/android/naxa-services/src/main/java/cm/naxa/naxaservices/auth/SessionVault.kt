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
import java.util.UUID
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Stores refresh/access tokens only when the user explicitly enables
 * "Rester connecté". The AES key is non-exportable and lives in Android Keystore.
 * Passwords are never persisted.
 */
internal data class RememberedBinding(val generation:String,val memberId:String,val deviceId:String,val organizationId:String)
internal class RememberedSessionChanged : IllegalStateException("REMEMBERED_SESSION_CHANGED")

class SessionVault(private val context: Context) {
    private val preferences = context.getSharedPreferences("naxa_services_secure_session", Context.MODE_PRIVATE)

    fun save(session: AuthSession) = synchronized(vaultLock) {
        val previous=binding()
        val generation=if(previous?.memberId==session.account.memberId&&previous.deviceId==session.deviceId&&previous.organizationId==session.account.organizationId)previous.generation else UUID.randomUUID().toString()
        val editor=preferences.edit()
        if(previous?.generation!=generation || loadAccessToken()!=session.accessToken || loadRefreshToken()!=session.refreshToken)editor.remove("offline_snapshot")
        editor
            .putString("access", encrypt(session.accessToken))
            .putString("refresh", encrypt(session.refreshToken))
            .putString("member_id", session.account.memberId)
            .putString("organization_id", session.account.organizationId)
            .putString("device_id", encrypt(session.deviceId))
            .putString("generation",generation)
            .apply()
    }

    internal fun binding():RememberedBinding?=synchronized(vaultLock){
        val member=preferences.getString("member_id",null)?.takeIf{it.isNotBlank()}?:return@synchronized null
        val device=loadDeviceId()?.takeIf{it.isNotBlank()}?:return@synchronized null
        // Legacy remembered sessions without an organization binding must authenticate again.
        val org=preferences.getString("organization_id",null)?.takeIf{it.isNotBlank()}?:return@synchronized null
        if(loadRefreshToken().isNullOrBlank())return@synchronized null
        val generation=preferences.getString("generation",null)?:UUID.randomUUID().toString().also{preferences.edit().putString("generation",it).apply()}
        RememberedBinding(generation,member,device,org)
    }

    internal fun matchesOrganization(expected:RememberedBinding,orgId:String):Boolean = synchronized(vaultLock){
        orgId.isNotBlank() && binding()==expected && expected.organizationId==orgId
    }

    // One network refresh at a time across foreground, startup and WorkManager.
    // A login/logout during the network request invalidates its response.
    internal suspend fun refreshRemembered(expected:RememberedBinding,request:suspend (String)->AuthSession):AuthSession=refreshMutex.withLock{
        val token=synchronized(vaultLock){
            if(binding()!=expected)throw RememberedSessionChanged()
            loadRefreshToken()?:throw RememberedSessionChanged()
        }
        val next=try{request(token)}catch(failure:AuthApiException){
            synchronized(vaultLock){
                if(binding()!=expected||loadRefreshToken()!=token)throw RememberedSessionChanged()
                if(discardRememberedSession(failure.statusCode))clear()
            }
            throw failure
        }
        synchronized(vaultLock){
            if(binding()!=expected||loadRefreshToken()!=token)throw RememberedSessionChanged()
            if(next.account.memberId!=expected.memberId||next.deviceId!=expected.deviceId||next.account.organizationId!=expected.organizationId){
                clear();throw RememberedSessionChanged()
            }
            save(next)
            next
        }
    }

    fun loadRefreshToken(): String? = preferences.getString("refresh", null)?.let(::decrypt)

    fun loadAccessToken(): String? = preferences.getString("access", null)?.let(::decrypt)

    fun loadDeviceId(): String? = preferences.getString("device_id", null)?.let(::decrypt)

    private fun bootCount():Int = Settings.Global.getInt(context.contentResolver,"boot_count",-1)
    internal fun clearOfflineSnapshot(){synchronized(vaultLock){preferences.edit().remove("offline_snapshot").apply()}}
    internal fun invalidateOfflineSnapshot(expected:RememberedBinding):Boolean=synchronized(vaultLock){
        if(binding()!=expected)return@synchronized false
        clearOfflineSnapshot();true
    }
    internal fun saveOfflineSnapshot(session:AuthSession,access:JSONObject,expected:RememberedBinding?=binding()) {
        synchronized(vaultLock){
        if(expected==null||binding()!=expected||expected.memberId!=session.account.memberId||expected.deviceId!=session.deviceId||expected.organizationId!=session.account.organizationId)return
        if(loadRefreshToken()!=session.refreshToken||loadAccessToken()!=session.accessToken)return
        val wall=System.currentTimeMillis();val boot=bootCount()
        if(boot<0){clearOfflineSnapshot();return}
        val claims=runCatching{JSONObject(String(Base64.decode(session.accessToken.split(".")[1],Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING),Charsets.UTF_8))}.getOrNull()?:run{clearOfflineSnapshot();return}
        val iat=claims.optLong("iat",0)*1000L;val exp=claims.optLong("exp",0)*1000L
        if(iat<=0||iat>wall+120000||wall-iat>OfflineSessionPolicy.MAX_MS){clearOfflineSnapshot();return}
        val until=OfflineSessionPolicy.expiresAt(session,access,exp,wall,claims.optString("session_id"))?:run{clearOfflineSnapshot();return}
        val a=session.account;val sites=JSONArray()
        a.activeSites.forEach{s->sites.put(JSONObject().put("id",s.id).put("code",s.code).put("name",s.name).put("address",s.addressLabel).put("phone",s.phoneContact))}
        val payload=JSONObject().put("generation",expected.generation).put("access",session.accessToken).put("refresh",session.refreshToken).put("device",session.deviceId)
            .put("member",a.memberId).put("display",a.displayName).put("role",a.roleCode).put("org",a.organizationId)
            .put("org_name",a.organizationName).put("mode",a.businessMode).put("locale",a.defaultLocale).put("activity",a.activityProfile)
            .put("legal",JSONArray(a.acceptedLegalDocs.toList())).put("site_ids",JSONArray(a.activeSiteIds)).put("sites",sites)
            .put("offline_scope",access.optJSONObject("offline_scope"))
            .put("wall",wall).put("elapsed",SystemClock.elapsedRealtime()).put("boot",boot).put("until",until)
        preferences.edit().putString("offline_snapshot",encrypt(payload.toString())).apply()
        }
    }
    internal fun loadOfflineSnapshot():AuthSession? = synchronized(vaultLock){runCatching{
        val json=JSONObject(preferences.getString("offline_snapshot",null)?.let(::decrypt)?:return null)
        val binding=binding()?:return null
        if(json.optString("generation")!=binding.generation||json.optString("member")!=binding.memberId||json.optString("device")!=binding.deviceId||json.optString("org")!=binding.organizationId)return null
        val now=System.currentTimeMillis()
        if(!OfflineSessionPolicy.valid(json.getLong("wall"),json.getLong("elapsed"),json.getInt("boot"),json.getLong("until"),now,SystemClock.elapsedRealtime(),bootCount()))return null
        if(loadAccessToken()!=json.getString("access")||loadRefreshToken()!=json.getString("refresh")||loadDeviceId()!=json.getString("device"))return null
        fun strings(name:String):List<String>{val ar=json.getJSONArray(name);return (0 until ar.length()).map{ar.getString(it)}}
        val rows=json.getJSONArray("sites")
        val sites=(0 until rows.length()).map{val s=rows.getJSONObject(it);AuthSite(s.getString("id"),s.getString("code"),s.getString("name"),s.getString("address"),s.getString("phone"))}
        val account=AuthAccount(json.getString("member"),json.getString("display"),json.getString("role"),json.getString("org"),json.getString("org_name"),
                json.getString("mode"),json.getString("locale"),strings("site_ids"),sites,json.getString("activity"),strings("legal").toSet(),true,true)
        val jwtClaims=JSONObject(String(Base64.decode(json.getString("access").split(".")[1],Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING),Charsets.UTF_8))
        if(!OfflineSessionPolicy.scopeAllowed(account,json.optJSONObject("offline_scope"),jwtClaims.optString("session_id")))return null
        AuthSession(json.getString("access"),json.getString("refresh"),((json.getLong("until")-now)/1000).coerceAtLeast(1),false,account,json.getString("device"))
    }.getOrNull()}

    fun clear() = synchronized(vaultLock) {
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
        val vaultLock=Any()
        val refreshMutex=Mutex()
    }
}
