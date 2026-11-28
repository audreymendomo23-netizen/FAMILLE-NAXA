package cm.naxa.naxasecurity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID

internal data class FieldChoice(val op:String,val label:String)
internal fun nativeFieldChoices(mode:String,state:String,mine:Boolean,completed:Boolean=false):List<FieldChoice> = when(mode){
 "patrol"->when(state){"planned"->if(mine)listOf(FieldChoice("patrol_start","Démarrer")) else listOf(FieldChoice("patrol_cancel","Annuler"));"running"->if(mine)listOf(FieldChoice("patrol_check","Déclarer le checkpoint"),FieldChoice("patrol_submit","Soumettre")) else emptyList();"submitted"->if(!mine)listOf(FieldChoice("patrol_review","Examiner la ronde")) else emptyList();else->emptyList()}
 "attendance"->if(state=="pending_review"&&!mine)listOf(FieldChoice("attendance_reviewed","Examiner"),FieldChoice("attendance_rejected","Rejeter"))else emptyList()
 "safety"->if(!mine&&state=="reported")listOf(FieldChoice("safety_ack","Accuser réception interne"))else if(!mine&&state=="acknowledged")listOf(FieldChoice("safety_close","Clôturer le suivi"))else emptyList()
 "visitor","vehicle"->listOf(FieldChoice("entry","Consigner entrée"),FieldChoice("exit","Consigner sortie"))
 "shift"->when(state){"planned"->if(mine)listOf(FieldChoice("shift_accept","Accepter"))else listOf(FieldChoice("shift_cancel","Annuler"));"accepted"->if(mine)listOf(FieldChoice("shift_complete","Déclarer terminée"))else listOf(FieldChoice("shift_cancel","Annuler"));else->emptyList()}
 "maintenance"->when(state){"requested"->listOf(FieldChoice("maintenance_assign","Affecter le technicien"));"assigned"->if(mine)listOf(FieldChoice("maintenance_start","Démarrer"))else emptyList();"in_progress"->if(mine&&!completed)listOf(FieldChoice("maintenance_complete","Soumettre le compte rendu"))else if(!mine&&completed)listOf(FieldChoice("maintenance_review","Examiner et clôturer"))else emptyList();else->emptyList()}
 else->emptyList()
}
@Composable internal fun SecurityNativeField(screen:String){
 val mode=when(screen){"B4.13"->"attendance";"B4.14","B4.15","B4.17"->"patrol";"B4.24","B4.25"->"visitor";"B4.28","B4.29"->"vehicle";"B4.30","B4.33"->"safety";"B5.07","B5.08","B5.09","B5.10"->"shift";"B5.11","B5.12","B5.13","B5.16","B5.17","B5.18"->"maintenance";else->return}
 val native=LocalSecurityNative.current;val s=native.session?:return;val site=native.site?:return;val gen=native.generation;val scope=rememberCoroutineScope()
 var rows by remember(screen,gen){mutableStateOf<List<JSONObject>>(emptyList())};var details by remember(screen,gen){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,gen){mutableStateOf("")};var reason by remember(screen,gen){mutableStateOf("")};var agent by remember(screen,gen){mutableStateOf("")};var device by remember(screen,gen){mutableStateOf("")};var label by remember(screen,gen){mutableStateOf("")};var points by remember(screen,gen){mutableStateOf("")};var index by remember(screen,gen){mutableStateOf("1")};var start by remember(screen,gen){mutableStateOf("")};var end by remember(screen,gen){mutableStateOf("")};var cost by remember(screen,gen){mutableStateOf("0")};var status by remember(screen,gen){mutableStateOf("")};var busy by remember(screen,gen){mutableStateOf(false)};var pendingId by remember(screen,gen){mutableStateOf("")};var pendingSig by remember(screen,gen){mutableStateOf("")}
 val erp=mode in setOf("shift","maintenance")
 val resource=when(mode){"audit"->"sec_audit_timeline";"patrol"->"sec_patrols";"attendance"->"sec_attendance_drafts";"safety"->"sec_internal_safety";"visitor","vehicle"->"sec_service_register";"shift"->"sec_shifts";else->"sec_work_orders"}
 val row=rows.firstOrNull{it.optString("id")==selected};val detail=details.firstOrNull{it.optString("order_id")==selected}
 val mine=when(mode){"patrol","shift"->row?.optString("agent_id")==s.user;"maintenance"->detail?.optString("technician_id")==s.user;else->row?.optString("reporter_id")==s.user}
 fun perform(choice:String,target:String?){
  if(busy)return
  try{
   val payload=JSONObject();var op=choice
   when(choice){
    "patrol_create"->{payload.put("label",label.trim()).put("agent_id",agent.trim()).put("checkpoints",JSONArray(points.lines().map{it.trim()}.filter{it.isNotEmpty()}))}
    "shift_create"->{payload.put("label",label.trim()).put("agent_id",agent.trim()).put("starts_at",java.time.Instant.parse(start.trim()).toString()).put("ends_at",java.time.Instant.parse(end.trim()).toString())}
    "maintenance_assign"->{payload.put("technician_id",agent.trim()).put("device_id",device.trim()).put("scheduled_at",java.time.Instant.parse(start.trim()).toString())}
    "maintenance_complete"->{payload.put("diagnosis",reason.trim()).put("cost_fcfa",cost.toLong())}
    "attendance_reviewed","attendance_rejected"->{op="attendance";payload.put("next",choice.removePrefix("attendance_"))}
    "entry","exit"->{op="passage";payload.put("direction",choice)}
    "patrol_check"->payload.put("index",index.toInt())
   }
   if(!erp&&op!="patrol_create"){require(reason.isNotBlank());payload.put("reason",reason.trim())}
   val sig=op+":"+target+":"+payload.toString();if(pendingId.isBlank()||pendingSig!=sig){pendingId=UUID.randomUUID().toString();pendingSig=sig};val event=pendingId
   val body=JSONObject().put("p_event",event).put(if(erp)"p_op" else "p_operation",op).put("p_target",target?:JSONObject.NULL).put("p_detail",payload)
   busy=true;scope.launch{try{val v=SecurityNativeApi.action(s,site,if(erp)"sec_erp_action" else "sec_field_action",body);if(native.generation==gen){status="Opération confirmée : "+v.optString("state")+" — actualisez.";rows=emptyList();details=emptyList();selected="";pendingId="";reason=""}}catch(e:CancellationException){throw e}catch(_:Exception){if(native.generation==gen)status="Action refusée ou non confirmée."}finally{if(native.generation==gen)busy=false}}
  }catch(_:Exception){status="Vérifiez les champs et dates UTC (ISO 8601)."}
 }
 Text("Opérations métier — "+mode,style=MaterialTheme.typography.titleMedium)
 Text(if(mode=="safety")"Signalement interne uniquement. En cas de danger contactez directement les secours ; aucun départ de secours automatique." else "Déclarations et revues contrôlées par le serveur. Aucune ouverture physique ni certification matérielle.")
 Button(enabled=!busy,onClick={busy=true;scope.launch{try{val a=SecurityNativeApi.records(s,site,resource);val d=if(mode=="maintenance")SecurityNativeApi.records(s,site,"sec_maintenance_details")else emptyList();if(native.generation==gen){rows=a.filter{mode !in setOf("visitor","vehicle")||it.optString("kind")==mode};details=d;selected="";status="Registre chargé."}}catch(e:CancellationException){throw e}catch(_:Exception){if(native.generation==gen){rows=emptyList();details=emptyList();status="Lecture indisponible."}}finally{if(native.generation==gen)busy=false}}}){Text("Actualiser les opérations")}
 rows.forEach{r->if(mode=="audit"){Text(r.optString("source")+" · "+r.optString("operation")+" · "+r.optString("state")+" · "+r.optString("created_at"))}else{Text(r.optString("label",r.optString("subject",r.optString("reference",r.optString("action",r.optString("detail")))))+" · "+r.optString("state"));TextButton(enabled=!busy,onClick={selected=r.optString("id")}){Text("Sélectionner "+r.optString("id").take(8))}}}
 if((!erp&&mode!="audit")||mode=="maintenance")OutlinedTextField(reason,{reason=it},enabled=!busy,label={Text("Motif / diagnostic")},modifier=Modifier.fillMaxWidth())
 if(mode=="patrol"&&row?.optString("state")=="running"){Text(row.optJSONArray("checkpoints")?.toString().orEmpty());OutlinedTextField(index,{index=it},label={Text("Index du checkpoint")})}
 if(mode=="patrol"&&screen=="B4.15"||mode=="shift"){
  OutlinedTextField(label,{label=it},label={Text("Libellé")});OutlinedTextField(agent,{agent=it},label={Text("Identifiant agent")})
  if(mode=="patrol")OutlinedTextField(points,{points=it},label={Text("Checkpoints, un par ligne")})else{OutlinedTextField(start,{start=it},label={Text("Début UTC ISO 8601")});OutlinedTextField(end,{end=it},label={Text("Fin UTC ISO 8601")})}
  Button(enabled=!busy&&label.isNotBlank()&&agent.isNotBlank(),onClick={perform(if(mode=="patrol")"patrol_create" else "shift_create",null)}){Text(if(mode=="patrol")"Créer la ronde" else "Planifier la vacation")}
 }
 if(mode=="safety")Button(enabled=!busy&&reason.isNotBlank(),onClick={perform("safety_report",null)}){Text("Enregistrer le signalement interne")}
 if(mode=="maintenance"&&row?.optString("state")=="requested"){OutlinedTextField(agent,{agent=it},label={Text("Identifiant technicien")});OutlinedTextField(device,{device=it},label={Text("Identifiant appareil")});OutlinedTextField(start,{start=it},label={Text("Date UTC ISO 8601")})}
 if(mode=="maintenance"&&row?.optString("state")=="in_progress"&&mine){OutlinedTextField(cost,{cost=it},label={Text("Coût FCFA")})}
 if(row!=null)nativeFieldChoices(mode,row.optString("state"),mine,detail?.let{!it.isNull("completed_at")}==true).forEach{choice->Button(enabled=!busy,onClick={perform(choice.op,selected)}){Text(choice.label)}}
 Text(status)
}
