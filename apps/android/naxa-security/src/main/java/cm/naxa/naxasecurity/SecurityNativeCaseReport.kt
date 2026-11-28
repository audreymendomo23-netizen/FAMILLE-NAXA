package cm.naxa.naxasecurity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import org.json.JSONObject
import java.util.UUID

internal fun securityReportCsv(v:JSONObject):String {
 fun quote(raw:String):String {val s=if(raw.trimStart().firstOrNull() in listOf('=','+','-','@'))"'"+raw else raw;return "\""+s.replace("\"","\"\"")+"\""}
 val rows=mutableListOf("indicateur,valeur")
 fun add(prefix:String,value:Any?){when(value){is JSONObject->value.keys().asSequence().sorted().forEach{k->add(if(prefix.isBlank())k else prefix+"."+k,value.get(k))};is org.json.JSONArray->(0 until value.length()).forEach{i->add(prefix+"."+i,value.get(i))};else->rows.add(quote(prefix)+","+quote(value.toString()))}};add("",v)
 return rows.joinToString("\r\n")
}
@Composable internal fun SecurityNativeCaseReport(screen:String){
 val cases=screen in setOf("B3.28","B3.29","B3.30");val reports=screen in setOf("B3.01","B3.02","B5.01","B5.28","B5.29","B5.30","B5.31","B5.32","B5.33");val support=screen in setOf("B6.04","B6.07","B6.12","B6.13","B6.14")
 if(!cases&&!reports&&!support)return
 val state=LocalSecurityNative.current;val s=state.session?:return;val site=state.site?:return;val generation=state.generation;val scope=rememberCoroutineScope();val context=LocalContext.current
 var rows by remember(screen,generation){mutableStateOf<List<JSONObject>>(emptyList())};var notes by remember(screen,generation){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,generation){mutableStateOf("")};var note by remember(screen,generation){mutableStateOf("")};var target by remember(screen,generation){mutableStateOf("")};var evidence by remember(screen,generation){mutableStateOf("")};var status by remember(screen,generation){mutableStateOf("")};var busy by remember(screen,generation){mutableStateOf(false)};var period by remember(screen,generation){mutableIntStateOf(7)};var report by remember(screen,generation){mutableStateOf<JSONObject?>(null)};var pendingId by remember(screen,generation){mutableStateOf("")};var pendingSig by remember(screen,generation){mutableStateOf("")}
 val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")){uri->val data=report;if(uri!=null&&data!=null&&state.generation==generation){scope.launch{try{val text=securityReportCsv(data);withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(text.toByteArray(Charsets.UTF_8))}?:error("output unavailable")};if(state.generation==generation)status="Export CSV enregistré."}catch(e:CancellationException){throw e}catch(_:Exception){if(state.generation==generation)status="Export non confirmé."}}}}
 val current=rows.firstOrNull{it.optString("id")==selected}
 fun runAction(op:String,detail:JSONObject){if(busy||selected.isBlank())return;val idTarget=selected;val sig=idTarget+op+detail.toString();if(pendingId.isBlank()||pendingSig!=sig){pendingId=UUID.randomUUID().toString();pendingSig=sig};val id=pendingId;busy=true;scope.launch{try{
  val body=JSONObject().put("p_case",idTarget).put("p_event",id).put("p_op",op).put("p_detail",detail);val v=SecurityNativeApi.action(s,site,if(cases)"sec_case_action" else "sec_support_action",body)
  if(state.generation==generation){status="Action confirmée : "+v.optString("state")+" — actualisez.";rows=emptyList();notes=emptyList();pendingId="";note=""}
 }catch(e:CancellationException){throw e}catch(_:Exception){if(state.generation==generation)status="Action refusée ou non confirmée."}finally{if(state.generation==generation)busy=false}}}
 Text(if(cases)"Dossiers incidents" else if(support)"Dossiers Livecare" else "Rapports serveur",style=MaterialTheme.typography.titleMedium)
 if(reports)listOf(1,7,30,90,365).forEach{d->FilterChip(selected=period==d,enabled=!busy,onClick={period=d;report=null},label={Text("$d jours")})}
 Button(enabled=!busy,onClick={busy=true;scope.launch{try{
  if(reports){val v=SecurityNativeApi.report(s,site,period,screen in setOf("B3.02","B5.31"));if(state.generation==generation)report=v}
  else{val a=SecurityNativeApi.records(s,site,if(cases)"sec_incidents" else "sec_support_cases");val b=SecurityNativeApi.records(s,site,if(cases)"sec_incident_notes" else "sec_support_messages");if(state.generation==generation){rows=a;notes=b}}
  if(state.generation==generation)status="Données autorisées chargées."
 }catch(e:CancellationException){throw e}catch(_:Exception){if(state.generation==generation){rows=emptyList();notes=emptyList();report=null;status="Lecture refusée ou indisponible."}}finally{if(state.generation==generation)busy=false}}}){Text("Actualiser les données")}
 report?.let{v->Text(securityReportCsv(v));Button(enabled=!busy,onClick={export.launch("security-site-report.csv")}){Text("Exporter CSV")}}
 rows.forEach{r->Text(r.optString(if(cases)"subject" else "category")+" · "+r.optString("state"));TextButton(enabled=!busy,onClick={selected=r.optString("id")}){Text("Ouvrir "+r.optString("id").take(8))}}
 if(current!=null){
  notes.filter{it.optString(if(cases)"incident_id" else "request_id")==selected}.forEach{Text(it.optString(if(cases)"note" else "body"))}
  val st=current.optString("state")
  OutlinedTextField(note,{note=it},enabled=!busy,label={Text(if(cases)"Note" else if(current.optString("requester_id")==s.user)"Réponse client" else "Réponse agent")},modifier=Modifier.fillMaxWidth())
  if(cases){
   Button(enabled=!busy&&note.isNotBlank(),onClick={runAction("comment",JSONObject().put("note",note.trim()))}){Text("Ajouter une note")}
   OutlinedTextField(evidence,{evidence=it},label={Text("Identifiant de preuve personnelle")});Button(enabled=!busy&&evidence.isNotBlank()&&note.isNotBlank(),onClick={runAction("evidence",JSONObject().put("note",note.trim()).put("evidence_id",evidence.trim()))}){Text("Lier la preuve")}
   val next=mapOf("new" to listOf("review"),"review" to listOf("confirmed"),"assigned" to listOf("in_progress"),"in_progress" to listOf("waiting_information","waiting_third_party","resolved"),"waiting_information" to listOf("in_progress"),"waiting_third_party" to listOf("in_progress"),"resolved" to listOf("closed"),"closed" to listOf("reopened"),"reopened" to listOf("review"))
   if(current.optString("priority")!="P1")next[st].orEmpty().forEach{n->Button(enabled=!busy&&note.isNotBlank(),onClick={runAction("transition",JSONObject().put("note",note.trim()).put("next",n))}){Text("Transition : "+n)}}
   if(st in setOf("confirmed","assigned","in_progress","waiting_information","waiting_third_party")){OutlinedTextField(target,{target=it},label={Text("Identifiant responsable")});Button(enabled=!busy&&target.isNotBlank()&&note.isNotBlank(),onClick={runAction("assignment",JSONObject().put("note",note.trim()).put("assignee_id",target.trim()))}){Text("Affecter")}}
  }else{
   val customer=current.optString("requester_id")==s.user;val agent=current.optString("agent_id")==s.user
   if(!customer&&st=="open")Button(enabled=!busy,onClick={runAction("claim",JSONObject())}){Text("Prendre en charge")}
   if(agent&&st in setOf("assigned","waiting_customer")){Button(enabled=!busy&&note.isNotBlank(),onClick={runAction("reply",JSONObject().put("body",note.trim()))}){Text("Répondre")};listOf("escalate","resolve").forEach{op->Button(enabled=!busy,onClick={runAction(op,JSONObject())}){Text(op)}}}
   if(customer&&st in setOf("open","assigned","waiting_customer"))Button(enabled=!busy&&note.isNotBlank(),onClick={runAction("customer_reply",JSONObject().put("body",note.trim()))}){Text("Envoyer ma réponse")}
   if(customer&&st=="resolved"){Button(enabled=!busy,onClick={runAction("reopen",JSONObject())}){Text("Rouvrir")};(1..5).forEach{n->TextButton(enabled=!busy,onClick={runAction("close",JSONObject().put("rating",n))}){Text("Clôturer avec note "+n)}}}
  }
 }
 Text(status)
}
