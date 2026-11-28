package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable internal fun SecurityNativeVisitorLifecycle(screen:String){
 if(screen !in setOf("B4.24","B4.25","B4.26"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var history by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,g){mutableStateOf("")};var next by remember(screen,g){mutableStateOf<String?>(null)};var can by remember(screen,g){mutableStateOf(false)};var reason by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)}
 fun run(op:String,after:String?=null){if(busy)return;busy=true;scope.launch{try{val p=JSONObject().put("p_op",op);if(after!=null)p.put("p_after",after);if(op!="list")p.put("p_register",selected);if(op=="cancel"){val sig=selected+":"+reason.trim();val id=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to id;p.put("p_event",id).put("p_reason",reason.trim())};val v=SecurityNativeApi.visitorLifecycle(s,site,p);if(n.generation==g){when(op){"list"->{val a=v.getJSONArray("rows");rows=(0 until a.length()).map{a.getJSONObject(it)};next=if(v.isNull("next"))null else v.getString("next");can=v.optBoolean("can_cancel");selected="";history=emptyList()};"history"->{check(v.optString("register_id")==selected);val a=v.getJSONArray("rows");history=(0 until a.length()).map{a.getJSONObject(it)}};else->{check(v.optString("register_id")==selected&&v.optString("event_id")==p.getString("p_event")&&v.optString("state")=="cancelled");rows=emptyList();history=emptyList();selected="";reason="";pending=null}};status=if(op=="cancel")"Visite annulée — actualisez." else "Registre visiteurs confirmé."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Opération refusée ou non confirmée."}finally{if(n.generation==g)busy=false}}}
 Text("Registre et historique des visiteurs");Text("État du registre manuel ; aucune commande physique. Annulation sans obstruction de la sortie.")
 Button(enabled=!busy,onClick={run("list")}){Text("Actualiser les visiteurs")}
 rows.forEach{r->FilterChip(selected=selected==r.optString("id"),enabled=!busy,onClick={selected=r.getString("id");history=emptyList();reason=""},label={Text(r.optString("reference")+" · "+r.optString("state"))})}
 next?.let{x->Button(enabled=!busy,onClick={run("list",x)}){Text("Page suivante")}}
 rows.firstOrNull{it.optString("id")==selected}?.let{r->Text("Échéance : "+r.optString("expires_at"));Button(enabled=!busy,onClick={run("history")}){Text("Charger l’historique du visiteur")};history.forEach{h->Text(h.optString("direction")+" · "+h.optString("created_at"))};if(can&&r.isNull("cancelled_at")){OutlinedTextField(reason,{reason=it.take(500)},enabled=!busy,label={Text("Motif d’annulation")});Button(enabled=!busy&&reason.isNotBlank(),onClick={run("cancel")}){Text("Annuler la visite et ses codes")}}}
 Text(status)
}
