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
   "access","visitor","vehicle","assignment"->mapOf("reference" to s("reference"),"purpose" to s("purpose"),"duration_minutes" to s("duration").toDouble().toLong())
   "payment"->mapOf("reference" to s("reference"),"amount_fcfa" to s("amount").toDouble().toLong(),"channel" to s("channel"))
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
 suspend fun records(s:SecurityNativeSession,site:SecurityNativeSite,resource:String):List<JSONObject> = withContext(Dispatchers.IO){
  checkScope(s,site);require(resource in setOf("sec_incidents","sec_incident_notes","sec_support_cases","sec_support_messages","sec_attendance_drafts","sec_patrols","sec_patrol_checks","sec_work_orders","sec_passage_logs","sec_internal_safety","sec_field_events","sec_inbox"))
  val a=JSONArray(call(scoped(resource,site),s.token))
  (0 until a.length()).map{a.getJSONObject(it)}.filter{it.optString("organization_id")==site.organization&&it.optString("site_id")==site.id}
 }
 suspend fun action(s:SecurityNativeSession,site:SecurityNativeSite,rpc:String,body:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(rpc in setOf("sec_case_action","sec_support_action","sec_field_action","sec_read_inbox"))
  val p=JSONObject(body.toString()).put("p_org",site.organization).put("p_site",site.id)
  val v=JSONObject(call("/rest/v1/rpc/"+rpc,s.token,p))
  check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id)
  if(rpc=="sec_read_inbox"){check(v.optString("id")==p.optString("p_id")&&v.optString("user_id")==s.user&&!v.isNull("read_at"))}
  else {check(v.optString("event_id")==p.optString("p_event")&&v.optString("actor_id")==s.user)
   if(rpc=="sec_field_action"){check(v.optString("operation")==p.optString("p_operation")&&(p.isNull("p_target")||v.optString("target_id")==p.optString("p_target")))}
   else check(v.optString("operation")==p.optString("p_op")&&v.optString("case_id")==p.optString("p_case"))}
  v
 }
 suspend fun report(s:SecurityNativeSession,site:SecurityNativeSite,days:Int,multi:Boolean=false):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(days in setOf(1,7,30,90,365));val now=java.time.Instant.now()
  val p=JSONObject().put("p_org",site.organization).put("p_start",now.minusSeconds(days*86400L).toString()).put("p_end",now.toString());if(!multi)p.put("p_site",site.id)
  val v=JSONObject(call("/rest/v1/rpc/"+(if(multi)"sec_org_report" else "sec_site_report"),s.token,p));check(v.optString("organization_id")==site.organization&&!v.isNull("generated_at"));if(multi){val a=v.getJSONArray("sites");check((0 until a.length()).all{j->val row=a.getJSONObject(j);row.optString("organization_id")==site.organization&&s.sites.any{it.id==row.optString("site_id")}})}else check(v.optString("site_id")==site.id);v
 }
 suspend fun submitAttendance(s:SecurityNativeSession,site:SecurityNativeSite,action:String,lat:Double,lon:Double,accuracy:Float,observed:Long,id:String):Boolean=withContext(Dispatchers.IO){
  checkScope(s,site);require(action in setOf("arrival","departure")&&lat in -90.0..90.0&&lon in -180.0..180.0&&accuracy>0&&accuracy<=100&&System.currentTimeMillis()-observed in 0L..120000L)
  val rid=SecurityNativeContract.uuid(id);val p=JSONObject().put("organization_id",site.organization).put("site_id",site.id).put("reporter_id",s.user).put("request_id",rid).put("action",action).put("lat",lat).put("lon",lon).put("accuracy_m",accuracy.toDouble()).put("observed_at",java.time.Instant.ofEpochMilli(observed).toString()).put("source","android").put("mock_reported",false)
  val a=try{JSONArray(call("/rest/v1/sec_attendance_drafts",s.token,p))}catch(e:Exception){JSONArray(call(scoped("sec_attendance_drafts",site,"&request_id=eq."+rid),s.token))}
  (0 until a.length()).any{val v=a.getJSONObject(it);v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("reporter_id")==s.user&&v.optString("request_id")==rid&&v.optString("action")==action&&v.optString("source")=="android"&&v.optString("state") in setOf("pending_review","reviewed","rejected")&&v.optDouble("lat")==lat&&v.optDouble("lon")==lon&&v.optDouble("accuracy_m")==accuracy.toDouble()&&v.opt("mock_reported")==false&&runCatching{java.time.Instant.parse(v.optString("observed_at")).toEpochMilli()==observed}.getOrDefault(false)}
 }
 suspend fun logout(s:SecurityNativeSession)=withContext(Dispatchers.IO){call("/auth/v1/logout?scope=local",s.token,JSONObject());Unit}
}
