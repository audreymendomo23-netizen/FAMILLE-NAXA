package cm.naxa.bootik

import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

data class BootikSite(val id:String,val name:String)
data class BootikSession(val token:String,val member:String,val organization:String,val role:String,val sites:List<BootikSite>,val expiresAt:Long) {
 fun permits(site:String,now:Long=System.currentTimeMillis())=expiresAt>now && sites.any{it.id==site}
}
object BootikAccess {
 fun valid(app:String,member:String,org:String,role:String,sites:List<String>,expiry:Long,now:Long)=
 app=="BOOTIK" && member.isNotBlank() && org.isNotBlank() && role in setOf("promoteur","manager","staff") && sites.isNotEmpty() && sites.all{it.isNotBlank()} && sites.distinct().size==sites.size && expiry>now
}
class BootikApi(private val endpoint:String) {
 private suspend fun request(action:String,body:JSONObject,token:String?=null):JSONObject=withContext(Dispatchers.IO){
  require(endpoint.startsWith("https://")){"API BOOTIK non configurée"}
  val url=URL(endpoint.trimEnd('/')+"/"+action)
  require(url.protocol=="https" && url.userInfo==null && url.query==null && url.ref==null)
  val conn=url.openConnection() as HttpsURLConnection
  try {
   conn.instanceFollowRedirects=false;conn.requestMethod="POST";conn.connectTimeout=10000;conn.readTimeout=10000;conn.doOutput=true
   conn.setRequestProperty("Content-Type","application/json");conn.setRequestProperty("Cache-Control","no-store")
   token?.let{conn.setRequestProperty("Authorization","Bearer "+it)}
   body.put("app_id","BOOTIK")
   conn.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
   check(conn.responseCode in 200..299){"Requête refusée"}
   if(conn.responseCode==204) JSONObject() else JSONObject(conn.inputStream.bufferedReader().use{it.readText()})
  } finally {conn.disconnect()}
 }
 suspend fun login(identifier:String,password:String):BootikSession {
  require(identifier.isNotBlank()&&password.isNotBlank())
  val j=request("login",JSONObject().put("identifier",identifier.trim()).put("password",password))
  val sites=j.getJSONArray("sites");val list=(0 until sites.length()).map{val s=sites.getJSONObject(it);BootikSite(s.getString("id"),s.getString("name"))}
  val member=j.getString("member_id");val org=j.getString("organization_id");val role=j.getString("role");val expires=j.getLong("expires_at");val token=j.getString("access_token")
  require(BootikAccess.valid(j.getString("app_id"),member,org,role,list.map{it.id},expires,System.currentTimeMillis())&&token.length>=20)
  return BootikSession(token,member,org,role,list,expires)
 }
 suspend fun recovery(identifier:String){require(identifier.isNotBlank());request("recovery",JSONObject().put("identifier",identifier.trim()))}
 suspend fun logout(session:BootikSession){request("logout",JSONObject(),session.token)}
 suspend fun operation(session:BootikSession,site:String,action:String,payload:JSONObject):JSONObject{
  require(session.permits(site)&&action in setOf("entitlement","trial","sale","support","support-cancel","catalog"))
  val response=request("operation",JSONObject().put("site_id",site).put("action",action).put("payload",payload),session.token)
  require(response.getString("app_id")=="BOOTIK"&&response.getString("organization_id")==session.organization&&response.getString("site_id")==site&&response.getString("action")==action&&response.getString("state")=="acknowledged")
  return response.getJSONObject("result")
 }
}
