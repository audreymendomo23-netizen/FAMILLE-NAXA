package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun ZippleNativeOfflineReview(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={f,e->if(en)e else f};val context=LocalContext.current;val scope=rememberCoroutineScope();val dao=remember(context){OfflineQueueDb.get(context).events()}
 var rows by remember{mutableStateOf<List<JSONObject>>(emptyList())};var blocked by remember{mutableStateOf<List<OfflineEvent>>(emptyList())};var reasons by remember{mutableStateOf<Map<String,String>>(emptyMap())};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 suspend fun load(){blocked=dao.blockedEvents(session.organization,session.member,site);rows=(api.call(session,site,"erp_review_snapshot") as JSONObject).rows("events")}
 fun run(block:suspend()->Unit){if(busy||!session.permits(site))return;busy=true;msg="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){msg=tr("Vérification non confirmée.","Review not confirmed.")}finally{busy=false}}}
 LaunchedEffect(session.token,site){run{load()}}
 Text(tr("Revue des opérations hors connexion","Offline operation review"))
 Text(tr("Une opération refusée reste dans l’historique. Vérifiez les données avant de recréer une opération.","Rejected operations remain in history. Verify data before creating a replacement."))
 OutlinedButton(enabled=!busy,onClick={run{load()}}){Text(tr("Actualiser les conflits","Refresh conflicts"))}
 rows.forEach{row->val id=row.getString("event_id");val reviewed=!row.isNull("reviewed_at");val event=blocked.find{it.eventId==id};val why=reasons[id].orEmpty()
  key(id){Text(when(row.optString("action")){"count_lot"->tr("Comptage de stock","Stock count");"produce"->tr("Production","Production");"lot_receive"->tr("Réception de lot","Batch receipt");else->tr("Dépense","Expense")}+" · "+row.optString("created_at"))
  val p=row.optJSONObject("payload");if(p!=null)Text(p.keys().asSequence().filter{!it.endsWith("_id")}.map{p.optString(it)}.joinToString(" · "))
  if(reviewed)Text(tr("Revue enregistrée","Review recorded")+" : "+row.optString("review_reason"))else OutlinedTextField(why,{v->reasons=reasons+(id to v.take(500))},label={Text(tr("Motif de l’abandon","Discard reason"))})
  if(!reviewed||event!=null)Button(enabled=!busy&&(reviewed||why.trim().length>=5),onClick={run{
   val receipt=api.call(session,site,"erp_review_discard",JSONObject().put("event_id",id).put("reason",if(reviewed)row.getString("review_reason")else why.trim())) as JSONObject
   require(receipt.getString("app_id")=="ZIPPLE"&&receipt.getString("event_id")==id&&receipt.getString("organization_id")==session.organization&&receipt.getString("site_id")==site&&receipt.getString("member_id")==session.member&&receipt.getString("state")=="reviewed")
   require(ZippleSyncSession.current===session&&session.permits(site));if(event!=null){require(receipt.getString("original_state")==event.state);require(dao.applyReview(id,session.organization,session.member,site,event.state)==1)}
   load();ZippleSyncSession.schedule(context);msg=tr("Revue confirmée.","Review confirmed.")
  }}){Text(tr("Abandonner après vérification","Discard after review"))}}
 }
 if(blocked.any{e->rows.none{it.optString("event_id")==e.eventId}})Text(tr("Conflit local non rapproché : actualisez.","Unmatched local conflict: refresh."))
 if(msg.isNotBlank())Text(msg)
}
