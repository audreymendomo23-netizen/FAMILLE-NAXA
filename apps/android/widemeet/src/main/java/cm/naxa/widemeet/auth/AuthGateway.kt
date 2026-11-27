package cm.naxa.widemeet.auth
import android.content.Context
import android.os.SystemClock
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.util.UUID
import javax.crypto.Cipher

class AuthGateway(private val context:Context,private val base:String){
 private val lifecycle=Mutex()
 private val vault=SessionVault(context)
 private val unlock=LocalUnlock(context)
 private val biometric=BiometricUnlock(context)
 private var refreshSecret:String?=null
 private var remembered=false
 fun hasRememberedSession()=unlock.configured()
 fun canRefresh()=refreshSecret!=null
 fun clearLocalSession(){refreshSecret=null;remembered=false;unlock.clear()}
 private fun remember(s:Session){val secret=refreshSecret?:return;if(remembered)vault.save(VaultSession(s.accessToken,secret,s.deviceId),true)}
 private fun endpoint(action:String):URI{
  val u=URI(base)
  require(u.scheme=="https" && !u.host.isNullOrBlank() && u.userInfo==null && u.query==null && u.fragment==null && u.path.trimEnd('/').endsWith("/widemeet-auth"))
  require(action in setOf("login","logout","switch-workspace","request-recovery","change-password","identity","register","refresh","recovery-enroll","recover-key"))
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
 suspend fun login(identifier:String,password:String,keep:Boolean=false,pin:String=""):Session=withContext(Dispatchers.IO){lifecycle.withLock{
  require(identifier.isNotBlank()&&password.isNotBlank()&&password.length<=256&&(!keep||Regex("^[0-9]{4}$").matches(pin)))
  val j=request("login",JSONObject().put("app_id","WIDEMEET").put("identifier",identifier.trim()).put("password",password).put("installation_id",installation()).put("platform","android").put("remember_me",keep))
  val s=parse(j)
  clearLocalSession()
  if(!s.requirePasswordChange){
   val secret=j.getString("refresh_token");require(Regex("^[a-f0-9]{64}$").matches(secret));refreshSecret=secret
   if(keep){try{unlock.configure(pin);remembered=true;remember(s)}catch(e:Exception){clearLocalSession();runCatching{request("logout",JSONObject().put("app_id","WIDEMEET"),s.accessToken)};throw e}}
  }
  s
 }}
 private fun rotate(secret:String):Session{
  require(Regex("^[a-f0-9]{64}$").matches(secret))
  val j=request("refresh",JSONObject().put("app_id","WIDEMEET").put("installation_id",installation()).put("platform","android").put("refresh_token",secret))
  val s=parse(j);val replacement=j.getString("refresh_token")
  require(!s.requirePasswordChange&&Regex("^[a-f0-9]{64}$").matches(replacement)&&replacement!=secret)
  refreshSecret=replacement;remember(s);return s
 }
 suspend fun refresh(s:Session):Session=withContext(Dispatchers.IO){lifecycle.withLock{
  try{val next=rotate(refreshSecret?:error("no refresh"));require(next.memberId==s.memberId&&next.activeWorkspaceId==s.activeWorkspaceId);next}catch(e:Exception){clearLocalSession();throw e}
 }}
 suspend fun restoreWithPin(pin:String):Session=withContext(Dispatchers.IO){lifecycle.withLock{
  require(unlock.verify(pin)){"unlock_failed"}
  try{remembered=true;rotate(vault.loadRefreshToken()?:error("no saved session"))}catch(e:Exception){clearLocalSession();throw e}
 }}
 internal fun biometricAvailable()=unlock.configured()&&biometric.available()
 internal fun prepareBiometric()=if(unlock.configured())biometric.prepare() else null
 internal suspend fun restoreAfterBiometric(attempt:BiometricUnlock.Attempt,authenticated:Cipher?):Session=withContext(Dispatchers.IO){lifecycle.withLock{
  require(unlock.configured())
  val secret=biometric.complete(attempt,authenticated)
  require(secret==vault.loadRefreshToken()){ "biometric_session_changed" }
  try{remembered=true;rotate(secret)}catch(e:Exception){clearLocalSession();throw e}
 }}
 suspend fun requestRecovery(identifier:String):Unit=withContext(Dispatchers.IO){
  val normalized=identifier.trim().uppercase(java.util.Locale.ROOT)
  require(Regex("^WM-[A-Z0-9]{8,24}$").matches(normalized))
  val j=request("request-recovery",JSONObject().put("app_id","WIDEMEET").put("identifier",normalized).put("installation_id",installation()).put("platform","android"))
  require(j.optBoolean("accepted",false))
 }
 suspend fun enrollRecoveryKey(s:Session,password:String,supervised:Boolean=false):String=withContext(Dispatchers.IO){
  require(activeWorkspace(s,System.currentTimeMillis(),SystemClock.elapsedRealtime())!=null&&password.isNotEmpty()&&password.length<=256)
  val response=request("recovery-enroll",JSONObject().put("app_id","WIDEMEET").put("current_password",password).put("supervised",supervised),s.accessToken)
  response.getString("recovery_key").also{require(Regex("^[a-f0-9]{64}$").matches(it))}
 }
 suspend fun recoverWithKey(identifier:String,key:String,password:String,requestId:String,supervised:Boolean=false):Unit=withContext(Dispatchers.IO){lifecycle.withLock{
  val id=identifier.trim().uppercase(java.util.Locale.ROOT);val recovery=key.trim().lowercase(java.util.Locale.ROOT)
  require(Regex("^WM-[A-Z0-9]{8,24}$").matches(id)&&Regex("^[a-f0-9]{64}$").matches(recovery)&&password.length in 12..256&&UUID.fromString(requestId).toString()==requestId)
  val result=request("recover-key",JSONObject().put("app_id","WIDEMEET").put("identifier",id).put("recovery_key",recovery).put("new_password",password).put("request_id",requestId).put("installation_id",installation()).put("platform","android").put("supervised",supervised))
  require(result.optBoolean("recovered")&&result.optBoolean("reconnect"));clearLocalSession()
 }}
 suspend fun changePassword(s:Session,current:String,next:String,requestId:String):Unit=withContext(Dispatchers.IO){
  require(current.isNotBlank()&&next.length in 12..256&&current!=next)
  val result=request("change-password",JSONObject().put("app_id","WIDEMEET").put("current_password",current).put("new_password",next).put("request_id",requestId),s.accessToken)
  require(result.optBoolean("changed",false)&&result.optBoolean("reconnect",false));clearLocalSession()
 }
 suspend fun identity(s:Session,action:String,data:JSONObject=JSONObject()):JSONObject=withContext(Dispatchers.IO){
  require(activeWorkspace(s,System.currentTimeMillis(),SystemClock.elapsedRealtime())!=null)
  request("identity",JSONObject().put("app_id","WIDEMEET").put("action",action).put("data",data),s.accessToken)
 }
 suspend fun register(kind:String,display:String,workspace:String,password:String,requestId:String):String=withContext(Dispatchers.IO){
  require(kind in setOf("individual","enterprise")&&display.isNotBlank()&&workspace.isNotBlank()&&password.length in 12..256)
  val j=request("register",JSONObject().put("app_id","WIDEMEET").put("installation_id",installation()).put("request_id",requestId).put("kind",kind).put("display_name",display.trim()).put("workspace_name",workspace.trim()).put("password",password).put("accepted_terms",true).put("terms_version","wm-replay-draft-20261126").put("privacy_version","wm-replay-draft-20261126"))
  require(j.optString("kind")==kind)
  j.getString("login_id").also{require(Regex("^WM-[A-Z0-9]{8,24}$").matches(it))}
 }
 private fun parse(j:JSONObject):Session{
  val a=j.getJSONArray("workspaces")
  val ws=List(a.length()){i->val w=a.getJSONObject(i);Workspace(w.getString("id"),w.getString("kind"),w.getString("name"),w.getString("role"),w.getBoolean("enabled"))}
  val s=Session(j.getString("app_id"),j.getString("access_token"),j.getString("member_id"),j.getString("device_id"),j.getLong("expires_at"),j.getLong("server_now"),System.currentTimeMillis(),SystemClock.elapsedRealtime(),j.getBoolean("require_password_change"),j.getString("active_workspace_id"),ws)
  require(validSession(s));return s
 }
 suspend fun switchWorkspace(s:Session,id:String):Session=withContext(Dispatchers.IO){lifecycle.withLock{
  require(activeWorkspace(s,System.currentTimeMillis(),SystemClock.elapsedRealtime())!=null && s.workspaces.any{it.id==id&&it.enabled})
  val next=parse(request("switch-workspace",JSONObject().put("app_id","WIDEMEET").put("workspace_id",id),s.accessToken))
  require(next.memberId==s.memberId && next.activeWorkspaceId==id && next.expiresAt<=s.expiresAt)
  remember(next);next
 }}
 suspend fun logout(s:Session)=withContext(Dispatchers.IO){lifecycle.withLock{clearLocalSession();request("logout",JSONObject().put("app_id","WIDEMEET"),s.accessToken);Unit}}
}
