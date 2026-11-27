package cm.naxa.naxasecurity

import org.json.JSONObject
import org.json.JSONArray
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL
import java.net.HttpURLConnection
import java.util.UUID

internal data class SecurityNativeSite(val id:String,val organization:String,val name:String)
internal class SecurityNativeSession(val token:String,val user:String,val expiresAt:Long,val sites:List<SecurityNativeSite>)
internal object SecurityNativeContract {
 val persistent=setOf("media","access","alarm","visitor","vehicle","sos","compatibility","assignment","payment","support","notification","language","admin","evidence","backup","partner")
 fun payload(m:SecurityModule,input:Map<String,String>):Map<String,Any> {
  require(m.kind in persistent)
  SecurityModuleRules.evaluate(m,input)
  fun s(k:String)=input.getValue(k).trim()
  return when(m.kind){
   "media"->mapOf("reference" to s("device"),"purpose" to s("purpose"),"consent" to s("consent"),"media" to if(m.id=="NS-02")"video" else "audio")
   "access","visitor","vehicle","assignment"->mapOf("reference" to s("reference"),"purpose" to s("purpose"),"duration_minutes" to s("duration").toLong())
   "payment"->mapOf("reference" to s("reference"),"amount_fcfa" to s("amount").toLong(),"channel" to s("channel"))
   "evidence"->mapOf("reference" to s("reference"),"digest" to s("digest").lowercase())
   else->input.mapValues{it.value.trim()}
  }
 }
 fun uuid(value:String):String {require(Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").matches(value));return UUID.fromString(value).toString()}
 fun usable(expires:Long,now:Long)=expires>now
}
internal object SecurityNativeApi {
 private const val HOST="https://idupfjbkwjcavyisxteo.supabase.co"
 val configured:Boolean get()=BuildConfig.SECURITY_PUBLISHABLE_KEY.startsWith("sb_publishable_")
 private fun call(path:String,token:String?=null,body:JSONObject?=null):String{
  check(configured);require(path.startsWith("/auth/v1/")||path.startsWith("/rest/v1/"))
  val c=URL(HOST+path).openConnection() as HttpURLConnection
  try{
   c.instanceFollowRedirects=false;c.connectTimeout=15000;c.readTimeout=15000;c.useCaches=false
   c.setRequestProperty("apikey",BuildConfig.SECURITY_PUBLISHABLE_KEY)
   if(token!=null)c.setRequestProperty("Authorization","Bearer "+token)
   c.setRequestProperty("Accept","application/json");c.setRequestProperty("Prefer","return=representation")
   if(body!=null){c.requestMethod="POST";c.doOutput=true;c.setRequestProperty("Content-Type","application/json");c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}}
   if(c.responseCode !in 200..299)throw IllegalStateException("SECURITY_HTTP_"+c.responseCode)
   return c.inputStream.bufferedReader().use{reader->val b=CharArray(4096);val out=StringBuilder();while(true){val n=reader.read(b);if(n<0)break;check(out.length+n<=2_000_000);out.append(b,0,n)};out.toString()}
  }finally{c.disconnect()}
 }
 suspend fun login(email:String,password:String):SecurityNativeSession=withContext(Dispatchers.IO){
  val obj=JSONObject(call("/auth/v1/token?grant_type=password",body=JSONObject().put("email",email.trim()).put("password",password)))
  val token=obj.getString("access_token");check(token.isNotBlank());val user=SecurityNativeContract.uuid(obj.getJSONObject("user").getString("id"));val seconds=obj.getLong("expires_in");require(seconds in 1..86400)
  val a=JSONArray(call("/rest/v1/sec_sites?select=id,organization_id,name&limit=100",token))
  val sites=(0 until a.length()).map{val x=a.getJSONObject(it);SecurityNativeSite(SecurityNativeContract.uuid(x.getString("id")),SecurityNativeContract.uuid(x.getString("organization_id")),x.getString("name"))};check(sites.isNotEmpty())
  SecurityNativeSession(token,user,System.currentTimeMillis()+seconds*1000,sites)
 }
 private fun checkScope(s:SecurityNativeSession,site:SecurityNativeSite){check(SecurityNativeContract.usable(s.expiresAt,System.currentTimeMillis())&&site in s.sites)}
 private fun scoped(resource:String,site:SecurityNativeSite,extra:String="")="/rest/v1/"+resource+"?organization_id=eq."+site.organization+"&site_id=eq."+site.id+"&select=*&limit=100"+extra
 suspend fun submit(s:SecurityNativeSession,site:SecurityNativeSite,m:SecurityModule,input:Map<String,String>,id:String):Boolean=withContext(Dispatchers.IO){
  checkScope(s,site);val rid=SecurityNativeContract.uuid(id);val payload=JSONObject(SecurityNativeContract.payload(m,input));val body=JSONObject().put("organization_id",site.organization).put("site_id",site.id).put("reporter_id",s.user).put("request_id",rid).put("kind",m.kind).put("payload",payload)
  val rows=try{JSONArray(call("/rest/v1/sec_module_requests",s.token,body))}catch(e:Exception){JSONArray(call(scoped("sec_module_requests",site,"&request_id=eq."+rid),s.token))}
  fun matches(x:JSONObject):Boolean {val p=x.optJSONObject("payload")?:return false;return x.optString("request_id")==rid&&x.optString("reporter_id")==s.user&&x.optString("organization_id")==site.organization&&x.optString("site_id")==site.id&&x.optString("kind")==m.kind&&x.optString("state") in setOf("requested","reviewed","declined")&&p.length()==payload.length()&&payload.keys().asSequence().all{k->p.opt(k).toString()==payload.opt(k).toString()}}
  (0 until rows.length()).any{matches(rows.getJSONObject(it))}
 }
 suspend fun read(s:SecurityNativeSession,site:SecurityNativeSite,kind:String):List<String> = withContext(Dispatchers.IO){
  checkScope(s,site);require(kind in setOf("overview","report","audit"))
  val a=JSONArray(call(scoped(if(kind=="audit")"sec_module_requests" else "sec_incidents",site),s.token))
  val rows=(0 until a.length()).map{a.getJSONObject(it)}.filter{it.optString("organization_id")==site.organization&&it.optString("site_id")==site.id&&(kind!="audit"||it.optString("reporter_id")==s.user)}
  if(kind=="audit")rows.map{it.optString("kind")+" · "+it.optString("state")+" · "+it.optString("created_at")}
  else listOf("Incidents chargés : "+rows.size,"Clôturés : "+rows.count{it.optString("state")=="closed"},"Ouverts : "+rows.count{it.optString("state")!="closed"})
 }
 suspend fun logout(s:SecurityNativeSession)=withContext(Dispatchers.IO){call("/auth/v1/logout?scope=local",s.token,JSONObject());Unit}
}
