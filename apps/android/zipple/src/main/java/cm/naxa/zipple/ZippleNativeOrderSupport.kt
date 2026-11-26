package cm.naxa.zipple
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import org.json.JSONArray
import java.time.LocalDate
import java.time.ZoneId
@Composable
internal fun ZippleNativeOrderSupport(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val scope=rememberCoroutineScope()
 var tickets by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var pendingOnly by remember{mutableStateOf(true)}
 var loaded by remember{mutableStateOf(false)}
 var drafts by remember{mutableStateOf<Map<String,String>>(emptyMap())}
 var busy by remember{mutableStateOf(false)}
 var status by remember{mutableStateOf("")}
 suspend fun load(){val a=api.call(session,site,"order_support_snapshot") as? JSONArray?:error("No result");tickets=(0 until a.length()).mapNotNull{a.optJSONObject(it)};loaded=true}
 fun run(block:suspend ()->Unit){if(busy)return;busy=true;scope.launch{try{block();status=""}catch(c:CancellationException){throw c}catch(_:Exception){status=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 LaunchedEffect(session.token,site){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){status=tr("Assistance indisponible","Assistance unavailable")}}
 Text(tr("Assistance commandes","Order assistance"))
 Button(enabled=!busy,onClick={run{load()}}){Text(tr("Actualiser","Refresh"))}
 if(loaded){Text(tr("Demandes sans réponse (liste chargée)","Unanswered requests (loaded list)")+": "+tickets.count{it.isNull("replied_at")});FilterChip(selected=pendingOnly,onClick={pendingOnly=!pendingOnly},label={Text(tr("Sans réponse uniquement","Unanswered only"))});if(tickets.none{!pendingOnly||it.isNull("replied_at")})Text(tr("Aucune demande dans cette vue.","No requests in this view."))}
 tickets.filter{!pendingOnly||it.isNull("replied_at")}.forEach{x->val id=x.optString("order_id");Text("#"+x.optString("number")+" · "+x.optString("message"));if(!x.isNull("reply"))Text(x.optString("reply"))else{
 OutlinedTextField(value=drafts[id]?:"",onValueChange={if(it.length<=500)drafts=drafts+(id to it)},label={Text(tr("Réponse","Reply"))})
 Button(enabled=!busy&&(drafts[id]?:"").trim().length>=3,onClick={run{api.call(session,site,"order_support_reply",JSONObject().put("order_id",id).put("reply",drafts[id]?.trim()));load();pendingOnly=false}}){Text(tr("Envoyer la réponse","Send reply"))}
 }}
 if(status.isNotBlank())Text(status)
}
@Composable
internal fun ZippleNativeServicePerformance(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val today=LocalDate.now(ZoneId.of("Africa/Douala"))
 var start by remember{mutableStateOf(today.withDayOfMonth(1).toString())}
 var end by remember{mutableStateOf(today.toString())}
 var result by remember{mutableStateOf<JSONObject?>(null)}
 var error by remember{mutableStateOf("")}
 var busy by remember{mutableStateOf(false)}
 val scope=rememberCoroutineScope()
 Text(tr("Performance du service","Service performance"))
 OutlinedTextField(value=start,onValueChange={start=it;result=null},label={Text(tr("Début AAAA-MM-JJ","Start YYYY-MM-DD"))})
 OutlinedTextField(value=end,onValueChange={end=it;result=null},label={Text(tr("Fin AAAA-MM-JJ","End YYYY-MM-DD"))})
 Button(enabled=!busy,onClick={busy=true;error="";scope.launch{try{result=api.call(session,site,"pilotage",JSONObject().put("start",start).put("end",end)) as? JSONObject}catch(c:CancellationException){throw c}catch(_:Exception){error=tr("Période ou opération non confirmée","Period or operation unconfirmed")}finally{busy=false}}}){Text(tr("Calculer","Calculate"))}
 result?.let{r->Text(tr("Satisfaction par poste","Satisfaction by station"));Text(tr("Notes de 4 ou 5 sur 5. Moins de 10 avis : échantillon insuffisant.","Ratings of 4 or 5 out of 5. Fewer than 10 reviews: insufficient sample."));if(r.rows("post_feedback").isEmpty())Text(tr("Aucun avis par poste.","No station reviews."));r.rows("post_feedback").forEach{x->Text(x.optString("post")+" · "+x.optString("average_rating")+"/5 · "+x.optInt("review_count")+" "+tr("avis","reviews")+" · "+x.optString("satisfaction_pct")+"%");if(!x.optBoolean("sufficient_sample"))Text(tr("Échantillon insuffisant","Insufficient sample"))};r.rows("service_team").forEach{x->Text(x.optString("login_id")+" · "+x.optInt("completed_orders")+" "+tr("commandes servies (participation)","served orders (participation)")+" · "+x.optInt("handed_lines")+" "+tr("lignes remises","lines handed over"))};Text(tr("Les volumes ne constituent pas un classement.","Counts are not a ranking."))}
 if(error.isNotBlank())Text(error)
}
