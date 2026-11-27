package cm.naxa.widemeet.auth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URI

class RoomGateway(private val authBase:String){
 private fun endpoint(action:String):URI{
  val u=URI(authBase)
  require(u.scheme=="https"&&!u.host.isNullOrBlank()&&u.userInfo==null&&u.query==null&&u.fragment==null&&u.path.trimEnd('/').endsWith("/widemeet-auth"))
  require(action in setOf("list","contacts","pass-list","read","create","command","media-grant","minutes","tasks","series-create","series-cancel"))
  return URI(u.scheme,u.authority,u.path.trimEnd('/').removeSuffix("/widemeet-auth")+"/widemeet-room/"+action,null,null)
 }
 suspend fun request(action:String,body:JSONObject,session:Session):Any=withContext(Dispatchers.IO){
  require(Regex("^[a-f0-9]{64}$").matches(session.accessToken))
  val c=endpoint(action).toURL().openConnection() as HttpURLConnection
  try{
   c.requestMethod="POST";c.instanceFollowRedirects=false;c.connectTimeout=15000;c.readTimeout=15000;c.useCaches=false;c.doOutput=true
   c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("Cache-Control","no-store");c.setRequestProperty("Authorization","Bearer "+session.accessToken)
   body.put("app_id","WIDEMEET");c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
   require(c.responseCode in 200..299){"request_rejected"}
   val raw=c.inputStream.bufferedReader().use{it.readText()};require(raw.length<=1048576)
   if(action in setOf("list","contacts","pass-list"))JSONArray(raw) else JSONObject(raw)
  }finally{c.disconnect()}
 }
}
