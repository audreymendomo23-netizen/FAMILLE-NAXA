package cm.naxa.services.beneficiary

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.util.UUID

internal object BeneficiaryApi {
    private fun configuration(): Pair<String,String> {
        val endpoint=BuildConfig.AUTH_ENDPOINT.trim()
        val uri=Uri.parse(endpoint)
        val project=BuildConfig.PROJECT_REF.trim()
        require(project.matches(Regex("^[a-z0-9]{20}$")) && project == BuildConfig.FAMILY_PROJECT_REF.trim() &&
            project != "ykgjfindlgseegmznaog" && uri.scheme=="https" &&
            endpoint == "https://"+project+".supabase.co/functions/v1/naxa-services-auth") {
            "Configuration NAXA SERVICES dédiée requise."
        }
        val key=BuildConfig.ANON_KEY.trim()
        val publicKey = if (key.startsWith("sb_publishable_")) true else runCatching {
            val part=key.split(".").getOrNull(1) ?: error("Clé invalide")
            val decoded=android.util.Base64.decode(part,android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
            val claims=JSONObject(String(decoded,Charsets.UTF_8))
            claims.optString("role")=="anon" && claims.optString("ref")==project
        }.getOrDefault(false)
        require(publicKey) { "Clé publique non configurée." }
        return endpoint to key
    }
    fun login(context:Context,email:String,password:String) {
        clear(context)
        val (endpoint,key)=configuration()
        val base=endpoint.removeSuffix("/functions/v1/naxa-services-auth")
        SecureVault.put(context,"supabase_url",base)
        SecureVault.put(context,"supabase_anon_key",key)
        SupabaseSession.login(context,base,key,email,password)
    }
    fun clear(context:Context) {
        for(k in listOf("consent","device","channel","supabase_access_token","supabase_refresh_token","supabase_expires_at","supabase_user_id","supabase_url","supabase_anon_key","last_status"))
            SecureVault.remove(context,k)
    }
    private fun call(context:Context,action:String,device:String,body:JSONObject=JSONObject()):JSONObject {
        UUID.fromString(device)
        val (endpoint,key)=configuration()
        val token=SupabaseSession.getAccessToken(context)
        return HttpClient.post(endpoint,token,key,body.put("app_code","naxa-services").put("action",action).put("device_id",device))
    }
    fun verify(context:Context,device:String):String {
        val result=call(context,"subscription_admin_device_status",device).optJSONObject("device_status")
            ?: error("Appareil non enrôlé.")
        val channel=result.optString("channel")
        require(channel in setOf("mtn_momo","orange_money")) { "Canal non autorisé." }
        return channel
    }
    fun review(context:Context,device:String)=call(context,"subscription_admin_review_list",device).optJSONArray("review_result")
        ?: error("Réponse de revue incomplète.")
    fun reject(context:Context,device:String,candidate:String,reason:String) {
        UUID.fromString(candidate)
        require(reason in setOf("wrong_amount","wrong_payer","wrong_destination","ambiguous_reference","outside_window","other"))
        val result=call(context,"subscription_admin_review_reject",device,JSONObject().put("candidate_id",candidate).put("reason_code",reason)).optJSONObject("review_result")
        check(result?.optString("status")=="rejected") { "Rejet non confirmé." }
    }
    fun capture(context:Context,device:String,origin:String,sms:String,received:Long) {
        val result=call(context,"subscription_admin_capture",device,JSONObject()
            .put("capture_source","sms_receiver").put("sender_origin_id",origin)
            .put("captured_at",java.time.Instant.ofEpochMilli(received).toString()).put("sms",sms))
        check(result.optJSONObject("capture_result")!=null) { "Réponse de capture incomplète." }
    }
    fun sessionReference(context:Context):String {
        val token=SupabaseSession.getAccessToken(context)
        val payload=token.split(".").getOrNull(1) ?: error("Session invalide.")
        val decoded=android.util.Base64.decode(payload,android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
        return JSONObject(String(decoded,Charsets.UTF_8)).optString("session_id")
    }
}
