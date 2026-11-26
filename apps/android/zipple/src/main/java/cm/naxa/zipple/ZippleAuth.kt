package cm.naxa.zipple
import org.json.JSONObject
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class Site(val id:String,val name:String)
data class Session(val token:String,val member:String,val organization:String,val name:String,val role:String,val sites:List<Site>,val expiresAt:Long,val refreshToken:String?=null) {
    fun permits(site:String)=expiresAt>System.currentTimeMillis() && sites.any { it.id==site }
}
object Scope {
    fun valid(app:String,member:String,org:String,role:String,sites:List<String>,expiry:Long,now:Long):Boolean =
        app=="ZIPPLE" && member.isNotBlank() && org.isNotBlank() && role in setOf("promoteur","manager","staff") && sites.isNotEmpty() && sites.all { it.isNotBlank() } && sites.distinct().size==sites.size && expiry>now
}
class ZippleAuth(private val endpoint:String) {
    suspend fun login(identifier:String,password:String,remember:Boolean=false):Session {
        require(identifier.isNotBlank()&&password.isNotBlank())
        return parse(request("login",JSONObject().put("identifier",identifier.trim()).put("password",password).put("remember_device",remember)))
    }
    suspend fun refresh(token:String):Session {
        require(token.length>=20)
        return parse(request("refresh",JSONObject().put("refresh_token",token)))
    }
    suspend fun recovery(identifier:String){
        require(identifier.isNotBlank())
        request("recovery",JSONObject().put("identifier",identifier.trim()))
    }
    suspend fun logout(token:String){request("logout",JSONObject(),token)}
    suspend fun sync(session:Session,event:OfflineEvent):String {
        require(session.permits(event.siteId)&&session.organization==event.organizationId&&session.member==event.memberId&&event.appId=="ZIPPLE")
        val receipt=request("sync",JSONObject().put("event_id",event.eventId).put("organization_id",event.organizationId).put("member_id",event.memberId).put("site_id",event.siteId).put("sequence",event.deviceSequence).put("aggregate_type",event.aggregateType).put("payload",JSONObject(event.payloadJson)),session.token)
        return ReceiptPolicy.verify(event.eventId,event.organizationId,event.siteId,receipt.optString("event_id"),receipt.optString("organization_id"),receipt.optString("site_id"),receipt.optString("app_id"),receipt.optString("state"))
    }
    private fun parse(j:JSONObject):Session{
        val array=j.getJSONArray("sites")
        val sites=(0 until array.length()).map { val x=array.getJSONObject(it);Site(x.getString("id"),x.getString("name")) }
        val expiry=j.getLong("expires_at")
        val member=j.getString("member_id"); val org=j.getString("organization_id");val role=j.getString("role")
        require(Scope.valid(j.getString("app_id"),member,org,role,sites.map{it.id},expiry,System.currentTimeMillis()))
        val token=j.getString("access_token");require(token.length>=20)
        val refresh=j.optString("refresh_token").takeIf{it.length>=20}
        return Session(token,member,org,j.getString("organization_name"),role,sites,expiry,refresh)
    }
    private suspend fun request(action:String,body:JSONObject,bearer:String?=null):JSONObject=withContext(Dispatchers.IO){
        require(endpoint.startsWith("https://")){"API ZIPPLE non configurée"}
        val url=URL(endpoint.trimEnd('/')+"/"+action)
        require(url.protocol=="https" && url.userInfo==null)
        val conn=url.openConnection() as HttpsURLConnection
        try {
            conn.instanceFollowRedirects=false
            conn.requestMethod="POST";conn.connectTimeout=10000;conn.readTimeout=10000;conn.doOutput=true
            conn.setRequestProperty("Content-Type","application/json")
            bearer?.let{conn.setRequestProperty("Authorization","Bearer "+it)}
            body.put("app_id","ZIPPLE")
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            check(conn.responseCode in 200..299){"Requête refusée"}
            if(conn.responseCode==204) JSONObject() else JSONObject(conn.inputStream.bufferedReader().use { it.readText() }.ifBlank{"{}"})
        } finally {conn.disconnect()}
    }
}
