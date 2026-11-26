package cm.naxa.widemeet.auth
import android.content.Context
import android.os.SystemClock
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.util.UUID

class AuthGateway(private val context:Context,private val base:String){
 private fun endpoint(action:String):URI{
  val u=URI(base)
  require(u.scheme=="https" && !u.host.isNullOrBlank() && u.userInfo==null && u.query==null && u.fragment==null && u.path.trimEnd('/').endsWith("/widemeet-auth"))
  require(action in setOf("login","logout"))
  return URI(base.trimEnd('/')+"/"+action)
 }
 private fun installation():String{
  val p=context.getSharedPreferences("widemeet-installation",Context.MODE_PRIVATE)
  val old=p.getString("id",null)
  if(old!=null&&runCatching{UUID.fromString(old).toString()==old}.getOrDefault(false))return old
  return UUID.randomUUID().toString().also{p.edit().putString("id",it).apply()}
 }
 private fun request(action:String,body:JSONObject,token:String?=null):JSONObject{
  val c=endpoint(action).toURL().openConnection() as HttpURLConnection
  try{
   c.requestMethod="POST";c.instanceFollowRedirects=false;c.connectTimeout=15000;c.readTimeout=15000;c.useCaches=false;c.doOutput=true
   c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("Cache-Control","no-store")
   if(token!=null)c.setRequestProperty("Authorization","Bearer "+token)
   c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
   require(c.responseCode in 200..299){"request_rejected"}
   if(c.responseCode==204)return JSONObject()
   val raw=c.inputStream.bufferedReader().use{it.readText()};require(raw.length<=131072);return JSONObject(raw)
  }finally{c.disconnect()}
 }
 suspend fun login(identifier:String,password:String):Session=withContext(Dispatchers.IO){
  require(identifier.isNotBlank()&&password.isNotBlank()&&password.length<=256)
  val j=request("login",JSONObject().put("app_id","WIDEMEET").put("identifier",identifier.trim()).put("password",password).put("installation_id",installation()).put("platform","android"))
  val a=j.getJSONArray("workspaces")
  val ws=List(a.length()){i->val w=a.getJSONObject(i);Workspace(w.getString("id"),w.getString("kind"),w.getString("name"),w.getString("role"),w.getBoolean("enabled"))}
  val s=Session(j.getString("app_id"),j.getString("access_token"),j.getString("member_id"),j.getString("device_id"),j.getLong("expires_at"),j.getLong("server_now"),System.currentTimeMillis(),SystemClock.elapsedRealtime(),j.getBoolean("require_password_change"),j.getString("active_workspace_id"),ws)
  require(validSession(s));s
 }
 suspend fun logout(s:Session)=withContext(Dispatchers.IO){request("logout",JSONObject().put("app_id","WIDEMEET"),s.accessToken);Unit}
}
