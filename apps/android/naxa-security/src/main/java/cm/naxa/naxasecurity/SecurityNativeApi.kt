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
   return c.inputStream.bufferedReader().use{reader->val b=CharArray(4096);val out=StringBuilder();while(true){val n=reader.read(b);if(n<0)break;check(out.length+n<=(if(path=="/rest/v1/rpc/sec_audit_export")8_000_000 else 2_000_000));out.append(b,0,n)};out.toString()}
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
  checkScope(s,site);require(resource in setOf("sec_incidents","sec_incident_notes","sec_support_cases","sec_support_messages","sec_attendance_drafts","sec_patrols","sec_patrol_checks","sec_work_orders","sec_passage_logs","sec_internal_safety","sec_field_events","sec_inbox","sec_service_register","sec_shifts","sec_maintenance_details","sec_visit_passes","sec_audit_timeline","sec_activity_notifications","sec_business_catalog","sec_alarm_events"))
  val order=when(resource){"sec_alarm_events"->"&order=observed_at.desc";"sec_incidents"->"&order=occurred_at.desc";"sec_incident_notes","sec_support_cases","sec_support_messages","sec_attendance_drafts","sec_patrols","sec_patrol_checks","sec_work_orders","sec_passage_logs","sec_internal_safety","sec_field_events","sec_inbox","sec_audit_timeline","sec_activity_notifications"->"&order=created_at.desc";else->""};val a=JSONArray(call(scoped(resource,site,order),s.token))
  (0 until a.length()).map{a.getJSONObject(it)}.filter{it.optString("organization_id")==site.organization&&it.optString("site_id")==site.id}
 }
 suspend fun action(s:SecurityNativeSession,site:SecurityNativeSite,rpc:String,body:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(rpc in setOf("sec_case_action","sec_support_action","sec_field_action","sec_read_inbox","sec_erp_action","sec_read_activity","sec_set_activity_channel"))
  val p=JSONObject(body.toString()).put("p_org",site.organization).put("p_site",site.id)
  val v=JSONObject(call("/rest/v1/rpc/"+rpc,s.token,p))
  check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id)
  if(rpc in setOf("sec_read_inbox","sec_read_activity")){check(v.optString("id")==p.optString("p_id")&&v.optString("user_id")==s.user&&!v.isNull("read_at"))}
  else if(rpc=="sec_set_activity_channel"){check(v.optString("user_id")==s.user&&v.optString("channel")==p.optString("p_channel")&&v.has("enabled")&&!v.isNull("enabled")&&v.getBoolean("enabled")==p.getBoolean("p_enabled"))}
  else {check(v.optString("event_id")==p.optString("p_event")&&v.optString("actor_id")==s.user)
   if(rpc=="sec_field_action"){check(v.optString("operation")==p.optString("p_operation")&&(p.isNull("p_target")||v.optString("target_id")==p.optString("p_target")))}
   else if(rpc=="sec_erp_action"){check(v.optString("operation")==p.optString("p_op")&&(p.isNull("p_target")||v.optString("target_id")==p.optString("p_target")))}
   else check(v.optString("operation")==p.optString("p_op")&&v.optString("case_id")==p.optString("p_case"))}
  v
 }
 suspend fun activityChannels(s:SecurityNativeSession,site:SecurityNativeSite):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val v=JSONObject(call("/rest/v1/rpc/sec_activity_channels",s.token,JSONObject().put("p_org",site.organization).put("p_site",site.id)));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("user_id")==s.user);val a=v.getJSONObject("channels");check(listOf("fcm","web_push","sms","whatsapp","email").all{a.opt(it) is Boolean});a
 }
 suspend fun deviceInventory(s:SecurityNativeSession,site:SecurityNativeSite,after:String?):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val p=JSONObject().put("p_org",site.organization).put("p_site",site.id);if(after!=null)p.put("p_after",SecurityNativeContract.uuid(after));val v=JSONObject(call("/rest/v1/rpc/sec_device_inventory",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.opt("physical_action")==false);v.getJSONArray("devices");v
 }
 suspend fun deviceProvision(s:SecurityNativeSession,site:SecurityNativeSite,id:String,op:String,detail:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(op in setOf("register","bind","revoke"));val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_event",SecurityNativeContract.uuid(id)).put("p_op",op).put("p_detail",detail);val v=JSONObject(call("/rest/v1/rpc/sec_device_provision",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("event_id")==id&&v.optString("operation")==op&&v.opt("physical_action")==false&&v.opt("transport_configured")==false&&v.optString("device_id")==if(op=="register")id else detail.optString("device_id"));v
 }
 suspend fun presenceReport(s:SecurityNativeSession,site:SecurityNativeSite,shift:String):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val v=JSONObject(call("/rest/v1/rpc/sec_presence_report",s.token,JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_shift",SecurityNativeContract.uuid(shift))));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("shift_id")==shift&&v.opt("physical_presence_certified")==false);v
 }
 suspend fun tracker(s:SecurityNativeSession,site:SecurityNativeSite,history:Boolean,body:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val p=JSONObject(body.toString()).put("p_org",site.organization).put("p_site",site.id);val v=JSONObject(call("/rest/v1/rpc/"+if(history)"sec_tracker_history" else "sec_tracker_manage",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id);if(history){check(v.optString("device_id")==p.optString("p_device")&&v.opt("position_authenticated")==false);v.getJSONArray("rows");v.getJSONArray("zones")}else{check(v.optString("actor_id")==s.user&&v.opt("asset_only")==true);v.getJSONArray("trackers")};v
 }
 suspend fun billingStatus(s:SecurityNativeSession,site:SecurityNativeSite):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val v=JSONObject(call("/rest/v1/rpc/sec_billing_status",s.token,JSONObject().put("p_org",site.organization).put("p_site",site.id)));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.opt("local_protection_unchanged")==true);v.getJSONArray("history");v
 }
 suspend fun allocateSubscription(s:SecurityNativeSession,site:SecurityNativeSite,id:String,target:String,plan:String,period:String):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(plan in setOf("Essentiel","Business","Professional")&&period in setOf("monthly","annual"));val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_event",SecurityNativeContract.uuid(id)).put("p_operation","subscription").put("p_target",SecurityNativeContract.uuid(target)).put("p_detail",JSONObject().put("plan",plan).put("period",period));val v=JSONObject(call("/rest/v1/rpc/sec_service_action",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("event_id")==id&&v.optString("target_id")==target&&v.optString("operation")=="subscription"&&v.optString("state")=="allocated"&&v.optString("plan")==plan);check(java.time.Instant.parse(v.getString("ends_at")).isAfter(java.time.Instant.parse(v.getString("starts_at"))));v
 }
 suspend fun evidenceShare(s:SecurityNativeSession,site:SecurityNativeSite,body:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val p=JSONObject(body.toString()).put("p_org",site.organization).put("p_site",site.id);val v=JSONObject(call("/rest/v1/rpc/sec_evidence_share",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("operation")==p.optString("p_op"));v.getJSONObject("result")
 }
 suspend fun evidenceShareDownload(s:SecurityNativeSession,site:SecurityNativeSite,id:String):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val v=JSONObject(call("/rest/v1/rpc/sec_evidence_share_download",s.token,JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_id",SecurityNativeContract.uuid(id))));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("share_id")==id);v
 }
 suspend fun alarmAction(s:SecurityNativeSession,site:SecurityNativeSite,event:String,alarm:String,op:String,reason:String):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(op in setOf("ack","escalate","review"));val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_event",SecurityNativeContract.uuid(event)).put("p_alarm",SecurityNativeContract.uuid(alarm)).put("p_op",op).put("p_reason",reason);val v=JSONObject(call("/rest/v1/rpc/sec_alarm_action",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("event_id")==event&&v.optString("alarm_id")==alarm&&v.optString("operation")==op&&v.opt("physical_action")==false);v
 }
 suspend fun mediaManage(s:SecurityNativeSession,site:SecurityNativeSite,grant:String?=null):JSONArray=withContext(Dispatchers.IO){
  checkScope(s,site);val p=JSONObject().put("p_org",site.organization).put("p_site",site.id);if(grant!=null)p.put("p_grant",SecurityNativeContract.uuid(grant)).put("p_revoke",true);val v=JSONObject(call("/rest/v1/rpc/sec_media_manage",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.opt("physical_action")==false);v.getJSONArray("grants")
 }
 suspend fun mediaOpen(s:SecurityNativeSession,site:SecurityNativeSite,id:String,device:String,media:String):SecurityMediaPlayback=withContext(Dispatchers.IO){
  checkScope(s,site);val v=JSONObject(call("/rest/v1/rpc/sec_media_open",s.token,JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_grant",SecurityNativeContract.uuid(id))));check(v.optString("id")==id&&v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("user_id")==s.user&&v.optString("device_id")==device&&v.optString("media")==media&&v.isNull("revoked_at"));val expiry=java.time.Instant.parse(v.getString("expires_at")).toEpochMilli();val now=System.currentTimeMillis();check(expiry>now&&expiry-now<=300000);val url=v.getString("playback_url");check(validSecurityMediaUrl(url,BuildConfig.SECURITY_MEDIA_ORIGIN));SecurityMediaPlayback(url,expiry,media)
 }
 suspend fun control(s:SecurityNativeSession,site:SecurityNativeSite,environment:Boolean,body:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);val p=JSONObject(body.toString()).put("p_org",site.organization).put("p_site",site.id);val v=JSONObject(call("/rest/v1/rpc/"+if(environment)"sec_environment_policy" else "sec_control_snapshot",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.opt("physical_action")==false);if(environment){check(v.optString("actor_id")==s.user);v.getJSONArray("thresholds")}else check(v.optString("generated_at").isNotBlank());v
 }
 suspend fun visitPass(s:SecurityNativeSession,site:SecurityNativeSite,event:String,op:String,target:String,detail:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(op in setOf("issue","consume","revoke"));val id=SecurityNativeContract.uuid(event);val t=SecurityNativeContract.uuid(target);val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_event",id).put("p_op",op).put("p_target",t).put("p_detail",detail)
  val v=JSONObject(call("/rest/v1/rpc/sec_visit_pass",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("event_id")==id&&v.optString("operation")==op&&v.opt("physical_access")==false&&v.optString(if(op=="issue")"register_id" else "pass_id")==t&&v.optString("state")==when(op){"issue"->"issued";"consume"->"checked";else->"revoked"});SecurityNativeContract.uuid(v.getString("pass_id"));v
 }
 suspend fun catalogAction(s:SecurityNativeSession,site:SecurityNativeSite,id:String,op:String,target:String?,detail:JSONObject):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(op in setOf("create","archive","stock_move"));val event=SecurityNativeContract.uuid(id);val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_event",event).put("p_op",op).put("p_target",target?:JSONObject.NULL).put("p_detail",detail)
  val v=JSONObject(call("/rest/v1/rpc/sec_catalog_action",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("actor_id")==s.user&&v.optString("event_id")==event&&v.optString("operation")==op&&v.optString("target_id")== (target?:event)&&v.opt("physical_access")==false);v
 }
 suspend fun auditPage(s:SecurityNativeSession,site:SecurityNativeSite,source:String,before:JSONObject?):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(source in setOf("all","field","service","erp","support","fire_ack","admin","access","catalog"))
  val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_source",source).put("p_before",before?:JSONObject.NULL)
  val v=JSONObject(call("/rest/v1/rpc/sec_audit_page",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("source")==source)
  val a=v.getJSONArray("rows");check(a.length()<=100&&(0 until a.length()).all{j->val x=a.getJSONObject(j);x.optString("organization_id")==site.organization&&x.optString("site_id")==site.id&&(source=="all"||x.optString("source")==source)});v
 }
 suspend fun auditRetention(s:SecurityNativeSession,site:SecurityNativeSite,days:Int?,hold:Boolean?):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require((days==null)==(hold==null)&&(days==null||days in 1..3650))
  val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_days",days?:JSONObject.NULL).put("p_hold",hold?:JSONObject.NULL)
  val v=JSONObject(call("/rest/v1/rpc/sec_audit_retention",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optBoolean("preview_only"));v
 }
 suspend fun auditExport(s:SecurityNativeSession,site:SecurityNativeSite,source:String,days:Int):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(source in setOf("all","field","service","erp","support","fire_ack","admin","access")&&days in setOf(1,7,30,90,365));val end=java.time.Instant.now()
  val p=JSONObject().put("p_org",site.organization).put("p_site",site.id).put("p_source",source).put("p_start",end.minusSeconds(days*86400L).toString()).put("p_end",end.toString())
  val v=JSONObject(call("/rest/v1/rpc/sec_audit_export",s.token,p));check(v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("source")==source&&v.optString("export_id").isNotBlank())
  val a=v.getJSONArray("rows");check(a.length()==v.getInt("count")&&a.length()<=10000&&(0 until a.length()).all{j->val x=a.getJSONObject(j);x.optString("organization_id")==site.organization&&x.optString("site_id")==site.id&&(source=="all"||x.optString("source")==source)});v
 }
 suspend fun report(s:SecurityNativeSession,site:SecurityNativeSite,days:Int,multi:Boolean=false):JSONObject=withContext(Dispatchers.IO){
  checkScope(s,site);require(days in setOf(1,7,30,90,365));val now=java.time.Instant.now()
  val p=JSONObject().put("p_org",site.organization).put("p_start",now.minusSeconds(days*86400L).toString()).put("p_end",now.toString());if(!multi)p.put("p_site",site.id)
  val v=JSONObject(call("/rest/v1/rpc/"+(if(multi)"sec_org_report" else "sec_site_report"),s.token,p));check(v.optString("organization_id")==site.organization&&!v.isNull("generated_at"));if(multi){val a=v.getJSONArray("sites");check((0 until a.length()).all{j->val row=a.getJSONObject(j);row.optString("organization_id")==site.organization&&s.sites.any{it.id==row.optString("site_id")}})}else check(v.optString("site_id")==site.id);v
 }
 suspend fun submitAttendance(s:SecurityNativeSession,site:SecurityNativeSite,action:String,lat:Double,lon:Double,accuracy:Float,observed:Long,id:String):Boolean=withContext(Dispatchers.IO){
  checkScope(s,site);require(action in setOf("arrival","departure","pause_start","pause_end")&&lat in -90.0..90.0&&lon in -180.0..180.0&&accuracy>0&&accuracy<=100&&System.currentTimeMillis()-observed in 0L..120000L)
  val rid=SecurityNativeContract.uuid(id);val p=JSONObject().put("organization_id",site.organization).put("site_id",site.id).put("reporter_id",s.user).put("request_id",rid).put("action",action).put("lat",lat).put("lon",lon).put("accuracy_m",accuracy.toDouble()).put("observed_at",java.time.Instant.ofEpochMilli(observed).toString()).put("source","android").put("mock_reported",false)
  val a=try{JSONArray(call("/rest/v1/sec_attendance_drafts",s.token,p))}catch(e:Exception){JSONArray(call(scoped("sec_attendance_drafts",site,"&request_id=eq."+rid),s.token))}
  (0 until a.length()).any{val v=a.getJSONObject(it);v.optString("organization_id")==site.organization&&v.optString("site_id")==site.id&&v.optString("reporter_id")==s.user&&v.optString("request_id")==rid&&v.optString("action")==action&&v.optString("source")=="android"&&v.optString("state") in setOf("pending_review","reviewed","rejected")&&v.optDouble("lat")==lat&&v.optDouble("lon")==lon&&v.optDouble("accuracy_m")==accuracy.toDouble()&&v.opt("mock_reported")==false&&runCatching{java.time.Instant.parse(v.optString("observed_at")).toEpochMilli()==observed}.getOrDefault(false)}
 }
 suspend fun logout(s:SecurityNativeSession)=withContext(Dispatchers.IO){call("/auth/v1/logout?scope=local",s.token,JSONObject());Unit}
}
