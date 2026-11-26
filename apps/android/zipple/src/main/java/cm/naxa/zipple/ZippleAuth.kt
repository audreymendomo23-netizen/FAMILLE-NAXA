package cm.naxa.zipple
import org.json.JSONObject
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class Site(val id:String,val name:String)
data class Session(val token:String,val member:String,val organization:String,val name:String,val role:String,val sites:List<Site>,val expiresAt:Long) {
    fun permits(site:String)=expiresAt>System.currentTimeMillis() && sites.any { it.id==site }
}
object Scope {
    fun valid(app:String,member:String,org:String,role:String,sites:List<String>,expiry:Long,now:Long):Boolean =
        app=="ZIPPLE" && member.isNotBlank() && org.isNotBlank() && role in setOf("promoteur","manager","staff") && sites.isNotEmpty() && sites.all { it.isNotBlank() } && sites.distinct().size==sites.size && expiry>now
}
class ZippleAuth(private val endpoint:String) {
    suspend fun login(identifier:String,password:String):Session=withContext(Dispatchers.IO) {
        require(identifier.isNotBlank()&&password.isNotBlank())
        require(endpoint.startsWith("https://")){"API ZIPPLE non configurée"}
        val url=URL(endpoint.trimEnd('/')+"/login")
        require(url.protocol=="https" && url.userInfo==null)
        val conn=url.openConnection() as HttpsURLConnection
        try {
            conn.instanceFollowRedirects=false
            conn.requestMethod="POST";conn.connectTimeout=10000;conn.readTimeout=10000;conn.doOutput=true
            conn.setRequestProperty("Content-Type","application/json")
            val body=JSONObject().put("identifier",identifier.trim()).put("password",password).put("app_id","ZIPPLE")
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            check(conn.responseCode==200){"Connexion refusée"}
            val j=JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val array=j.getJSONArray("sites")
            val sites=(0 until array.length()).map { val x=array.getJSONObject(it);Site(x.getString("id"),x.getString("name")) }
            val expiry=j.getLong("expires_at")
            val member=j.getString("member_id"); val org=j.getString("organization_id");val role=j.getString("role")
            require(Scope.valid(j.getString("app_id"),member,org,role,sites.map{it.id},expiry,System.currentTimeMillis()))
            val token=j.getString("access_token");require(token.length>=20)
            Session(token,member,org,j.getString("organization_name"),role,sites,expiry)
        } finally {conn.disconnect()}
    }
}
