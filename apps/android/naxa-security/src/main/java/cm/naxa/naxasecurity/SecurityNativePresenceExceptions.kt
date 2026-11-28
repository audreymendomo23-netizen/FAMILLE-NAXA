package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
import java.time.Instant
@Composable internal fun SecurityNativePresenceExceptions(screen:String){
 if(screen !in setOf("B4.08","B4.12","B4.13"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var shifts by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var shift by remember(screen,g){mutableStateOf("")};var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var kind by remember(screen,g){mutableStateOf("arrival")};var at by remember(screen,g){mutableStateOf("")};var reason by remember(screen,g){mutableStateOf("")};var review by remember(screen,g){mutableStateOf("")};var status by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)}
 val mine=shifts.firstOrNull{it.optString("id")==shift}?.optString("agent_id")==s.user
 fun run(op:String,id:String?=null,decision:String?=null){if(busy)return;busy=true;scope.launch{try{
 if(op=="load"){val v=SecurityNativeApi.records(s,site,"sec_shifts");if(n.generation==g){shifts=v;shift="";rows=emptyList();status="Vacations chargées."};return@launch}
 val p=JSONObject().put("p_op",op).put("p_shift",shift)
 if(op=="submit"){val d=JSONObject().put("kind",kind).put("observed_at",if(kind=="absence")JSONObject.NULL else Instant.parse(at.trim()).toString()).put("reason",reason.trim());val sig=shift+d.toString();val event=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to event;p.put("p_id",event).put("p_detail",d)}
 if(op=="review")p.put("p_id",id).put("p_detail",JSONObject().put("decision",decision).put("reason",review.trim()))
 val v=SecurityNativeApi.presenceException(s,site,p);if(n.generation==g){if(op=="list"){val a=v.getJSONArray("result");rows=(0 until a.length()).map{a.getJSONObject(it)}}else{check(v.getJSONObject("result").getString("id")==p.getString("p_id"));pending=null;rows=emptyList();reason="";review=""};status="Opération présence confirmée : "+op}
 }catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Opération refusée ou indisponible."}finally{if(n.generation==g)busy=false}}}
 Text("Pointage manuel et absence justifiée");Text("Déclaration par l’agent et examen distinct. Aucun GPS inventé.")
 Button(enabled=!busy,onClick={run("load")}){Text("Charger les vacations pour exception")}
 shifts.forEach{r->FilterChip(selected=shift==r.optString("id"),enabled=!busy,onClick={shift=r.getString("id");rows=emptyList();reason="";review=""},label={Text(r.optString("label"))})}
 if(shift.isNotBlank()){Button(enabled=!busy,onClick={run("list")}){Text("Charger les exceptions")}
 if(mine){listOf("arrival","departure","pause_start","pause_end","absence").forEach{k->FilterChip(selected=kind==k,enabled=!busy,onClick={kind=k},label={Text(k)})};if(kind!="absence")OutlinedTextField(at,{at=it},enabled=!busy,label={Text("Heure UTC ISO 8601 (ex. 2026-11-28T07:00:00Z)")});OutlinedTextField(reason,{reason=it.take(500)},enabled=!busy,label={Text("Justification")});Button(enabled=!busy&&reason.isNotBlank()&&(kind=="absence"||at.isNotBlank()),onClick={run("submit")}){Text("Soumettre la déclaration")}}
 else OutlinedTextField(review,{review=it.take(500)},enabled=!busy,label={Text("Motif de revue")})
 rows.forEach{r->Text(r.optString("kind")+" · "+r.optString("state"));Text(r.optString("reason"));if(!r.isNull("review_reason"))Text(r.optString("review_reason"));if(!mine&&r.optString("state")=="pending_review"){Button(enabled=!busy&&review.isNotBlank(),onClick={run("review",r.getString("id"),"approved")}){Text("Approuver")};Button(enabled=!busy&&review.isNotBlank(),onClick={run("review",r.getString("id"),"rejected")}){Text("Rejeter")}}}}
 Text(status)
}
