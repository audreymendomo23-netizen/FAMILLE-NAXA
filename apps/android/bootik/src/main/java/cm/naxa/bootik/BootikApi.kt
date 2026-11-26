package cm.naxa.bootik

import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

data class BootikSite(val id:String,val name:String)
data class BootikSession(val token:String,val member:String,val organization:String,val role:String,val sites:List<BootikSite>,val expiresAt:Long,val refreshToken:String?=null) {
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
 suspend fun login(identifier:String,password:String,remember:Boolean=false):BootikSession {
  require(identifier.isNotBlank()&&password.isNotBlank())
  return parse(request("login",JSONObject().put("identifier",identifier.trim()).put("password",password).put("remember_device",remember)))
 }
 suspend fun refresh(token:String):BootikSession {require(token.length>=20);return parse(request("refresh",JSONObject().put("refresh_token",token)))}
 private fun parse(j:JSONObject):BootikSession {
  val sites=j.getJSONArray("sites");val list=(0 until sites.length()).map{val s=sites.getJSONObject(it);BootikSite(s.getString("id"),s.getString("name"))}
  val member=j.getString("member_id");val org=j.getString("organization_id");val role=j.getString("role");val expires=j.getLong("expires_at");val token=j.getString("access_token")
  require(BootikAccess.valid(j.getString("app_id"),member,org,role,list.map{it.id},expires,System.currentTimeMillis())&&token.length>=20)
  return BootikSession(token,member,org,role,list,expires,j.optString("refresh_token").takeIf{it.length>=20})
 }
 suspend fun recovery(identifier:String){require(identifier.isNotBlank());request("recovery",JSONObject().put("identifier",identifier.trim()))}
 suspend fun logout(session:BootikSession){request("logout",JSONObject().put("refresh_token",session.refreshToken),session.token)}
 suspend fun forget(token:String){request("logout",JSONObject().put("refresh_token",token))}
 suspend fun operation(session:BootikSession,site:String,action:String,payload:JSONObject):JSONObject{
  require(session.permits(site)&&action in setOf("entitlement","trial","sale","support","support-cancel","catalog","payment-intent","payment-current","payment-status","payment-debit","team","activities","master-create","partners","dashboard","count-batch","transfer-ship","transfer-receive","transfers","stock-template","stock-import-preview","stock-import-apply","stock-setup","stock-health","purchases","purchase-create","purchase-receive","purchase-pay"))
  val response=request("operation",JSONObject().put("site_id",site).put("action",action).put("payload",payload),session.token)
  require(response.getString("app_id")=="BOOTIK"&&response.getString("organization_id")==session.organization&&response.getString("member_id")==session.member&&response.getString("site_id")==site&&response.getString("action")==action&&response.getString("state")=="acknowledged")
  return response.getJSONObject("result")
 }

 suspend fun fetchCatalog(session:BootikSession,site:String):org.json.JSONArray{
  val all=org.json.JSONArray();val seen=HashSet<String>();var cursor:String?=null
  repeat(200){
   val result=operation(session,site,"catalog",JSONObject().apply{cursor?.let{put("cursor",it)}})
   val rows=result.getJSONArray("items");require(rows.length()<=500)
   for(i in 0 until rows.length()){val item=rows.getJSONObject(i);require(seen.add(item.getString("balance_id")));all.put(item)}
   if(result.has("next_cursor")&&result.isNull("next_cursor"))return all
   val next=result.getString("next_cursor");require(rows.length()>0&&next==rows.getJSONObject(rows.length()-1).getString("balance_id")&&next!=cursor);cursor=next
  };error("Catalogue trop volumineux")
 }
 suspend fun syncSale(session:BootikSession,site:String,event:BootikScopedEvent):String{
  require(session.permits(site)&&event.organizationId==session.organization&&event.memberId==session.member&&event.siteId==site&&event.state=="queued")
  val payload=JSONObject(event.payload);require(payload.getString("idempotency_key")==event.eventId)
  val stock=payload.has("stock_kind");val grouped=!stock&&payload.has("item_id");val action=if(stock)"sync-stock" else if(grouped)"sync-item-sale" else "sync-sale"
  if(stock)require(payload.getString("stock_kind") in setOf("receipt","loss","count")&&session.role!="staff")
  val j=request("operation",JSONObject().put("site_id",site).put("action",action).put("payload",payload),session.token)
  val state=j.getString("state")
  require(BootikReceiptPolicy.valid(j.getString("app_id"),j.getString("organization_id"),j.getString("member_id"),j.getString("site_id"),j.getString("event_id"),j.getString("action"),state,event,action))
  if(state=="acknowledged")require(j.getJSONObject("result").getString(if(stock)"stock_event_id" else if(grouped)"sale_group_id" else "sale_id").isNotBlank())
  return state
 }
}
