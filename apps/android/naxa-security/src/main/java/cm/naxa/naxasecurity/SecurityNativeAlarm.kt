package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable internal fun SecurityNativeAlarm(screen:String){
 if(screen !in setOf("B3.03","B3.04","B3.05","B3.06","B3.07","B3.08","B3.09"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,g){mutableStateOf("")};var reason by remember(screen,g){mutableStateOf("")};var status by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)}
 val row=rows.firstOrNull{it.optString("id")==selected}
 fun act(op:String){if(busy||row==null||reason.isBlank())return;busy=true;scope.launch{try{val sig=op+selected+reason.trim();val event=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to event;val v=SecurityNativeApi.alarmAction(s,site,event,selected,op,reason.trim());check(v.optString("source_state")==row.optString("source_state"));if(n.generation==g){rows=rows.map{if(it.optString("id")==selected)JSONObject(it.toString()).put("triage_state",v.getString("triage_state")) else it};pending=null;reason="";status="Suivi interne confirmé : "+v.optString("triage_state")}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Action refusée ou non confirmée."}finally{if(n.generation==g)busy=false}}}
 Text("Alarmes — intrusion et sabotage");Text("Revue interne uniquement : aucune désactivation physique, aucune confirmation de sécurité.")
 Button(enabled=!busy,onClick={busy=true;scope.launch{try{val v=SecurityNativeApi.records(s,site,"sec_alarm_events");if(n.generation==g){rows=v.filter{(screen!="B3.07"||it.optString("source_state")=="intrusion")&&(screen!="B3.08"||it.optString("source_state")=="sabotage")};selected="";status="Événements source chargés."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){rows=emptyList();status="Lecture indisponible."}}finally{if(n.generation==g)busy=false}}}){Text("Actualiser les alarmes")}
 rows.forEach{r->Text(r.optString("source_state")+" · "+r.optString("triage_state")+" · "+r.optString("observed_at"));TextButton(enabled=!busy,onClick={selected=r.optString("id")}){Text("Sélectionner "+r.optString("id").take(8))}}
 if(row!=null&&row.optString("triage_state")!="reviewed"){OutlinedTextField(reason,{reason=it},label={Text("Motif de traitement")});val actions=when(row.optString("triage_state")){"new"->listOf("ack" to "Accuser réception","escalate" to "Escalader en interne");"acknowledged"->listOf("escalate" to "Escalader en interne","review" to "Terminer la revue interne");else->listOf("review" to "Terminer la revue interne")};actions.forEach{(op,label)->Button(enabled=!busy&&reason.isNotBlank(),onClick={act(op)}){Text(label)}}}
 Text(status)
}
