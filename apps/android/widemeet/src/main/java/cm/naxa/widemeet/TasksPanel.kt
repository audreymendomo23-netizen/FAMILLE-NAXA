package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID

private fun taskRows(a:JSONArray?):List<JSONObject> = if(a==null)emptyList() else (0 until a.length()).mapNotNull{a.optJSONObject(it)}
@Composable fun TasksPanel(english:Boolean,gateway:RoomGateway,session:Session,roomId:String?=null,versionId:String?=null,recipients:JSONArray?=null){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var title by remember{mutableStateOf("")};var due by remember{mutableStateOf("")};var assignee by remember{mutableStateOf("")}
 var evidence by remember{mutableStateOf<Map<String,String>>(emptyMap())};var pending by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var query by remember{mutableStateOf("")};var filter by remember{mutableStateOf("all")}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.request("tasks",JSONObject().put("action",action).put("data",data),session) as JSONObject
 suspend fun refresh(){try{items=taskRows(req("list").getJSONArray("items"))}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block();refresh()}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId,roomId,versionId){busy=true;try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();error=true}finally{busy=false}}
 fun mutate(x:JSONObject,action:String){work{val id=x.getString("id");req(action,JSONObject().put("id",id).put("expected_revision",x.getInt("revision")).apply{if(action=="submit")put("evidence",evidence[id]?.trim())});evidence=evidence-id}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Décisions et tâches","Decisions and tasks"),style=MaterialTheme.typography.titleLarge)
 if(error)Text(tr("Action non confirmée. Réessayez ou actualisez.","Action not confirmed. Retry or refresh."),color=MaterialTheme.colorScheme.error)
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 TextButton(enabled=!busy,onClick={work{}}){Text(tr("Actualiser","Refresh"))}
 if(roomId!=null&&versionId!=null){
 Text(tr("Affecter une tâche issue du compte rendu","Assign a task from the minutes"))
 OutlinedTextField(title,{title=it.take(200)},enabled=!busy&&pending==null,label={Text(tr("Action","Action"))},modifier=Modifier.fillMaxWidth())
 Text(tr("Responsable","Assignee"))
 for(m in taskRows(recipients)){val id=m.getString("member_id");Row{RadioButton(assignee==id,{assignee=id},enabled=!busy&&pending==null);Text(m.optString("display_name"),Modifier.padding(top=12.dp))}}
 OutlinedTextField(due,{due=it.take(16)},enabled=!busy&&pending==null,label={Text(tr("Échéance (AAAA-MM-JJTHH:mm)","Due date (YYYY-MM-DDTHH:mm)"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&title.isNotBlank()&&assignee.isNotEmpty()&&due.isNotBlank(),onClick={work{val d=pending?:JSONObject().put("id",UUID.randomUUID().toString()).put("room_id",roomId).put("version_id",versionId).put("assignee_id",assignee).put("title",title.trim()).put("due_at",LocalDateTime.parse(due).atZone(ZoneId.systemDefault()).toInstant().toString()).also{pending=it};req("create",d);pending=null;title="";due="";assignee=""}}){Text(tr("Affecter","Assign"))}
 }
 val scoped=items.filter{roomId==null||it.optString("room_id")==roomId}
 OutlinedTextField(query,{query=it.take(100)},label={Text(tr("Rechercher une tâche","Search tasks"))},modifier=Modifier.fillMaxWidth())
 var filterOpen by remember{mutableStateOf(false)}
 val filters=listOf("all" to tr("Toutes","All"),"assigned" to tr("À faire","Assigned"),"submitted" to tr("À valider","Submitted"),"done" to tr("Terminées","Done"),"cancelled" to tr("Annulées","Cancelled"))
 Box{TextButton(onClick={filterOpen=true}){Text(tr("État : ","Status: ")+(filters.firstOrNull{it.first==filter}?.second?:""))};DropdownMenu(expanded=filterOpen,onDismissRequest={filterOpen=false}){for((k,label) in filters){DropdownMenuItem(text={Text(label)},onClick={filter=k;filterOpen=false})}}}
 val visible=scoped.filter{x->(filter=="all"||x.optString("state")==filter)&&listOf("title","meeting_title","assignee_name").any{x.optString(it).contains(query.trim(),ignoreCase=true)}}
 Text(visible.size.toString()+" / "+scoped.size+" "+tr("tâches","tasks"))
 for(x in visible){
 val id=x.getString("id");val state=x.optString("state")
 Text(x.optString("title"),style=MaterialTheme.typography.titleMedium)
 Text(x.optString("meeting_title")+" · "+x.optString("assignee_name")+" · "+x.optString("due_at").take(16)+" · "+when(state){"assigned"->tr("À faire","Assigned");"submitted"->tr("À valider","Submitted");"done"->tr("Terminée","Done");"cancelled"->tr("Annulée","Cancelled");else->tr("Indisponible","Unavailable")})
 if(x.optBoolean("overdue"))Text(tr("Échéance dépassée","Overdue"),color=MaterialTheme.colorScheme.error)
 var showHistory by remember(id){mutableStateOf(false)}
 if(taskRows(x.optJSONArray("history")).isNotEmpty()){TextButton(onClick={showHistory=!showHistory}){Text(tr("Historique","History"))};if(showHistory)for(h in taskRows(x.optJSONArray("history")))Text(h.optString("at").take(16)+" · "+when(h.optString("state")){"assigned"->tr("À faire","Assigned");"submitted"->tr("À valider","Submitted");"done"->tr("Terminée","Done");"cancelled"->tr("Annulée","Cancelled");else->tr("Indisponible","Unavailable")})}
 if(!x.isNull("evidence"))Text(x.getString("evidence"))
 if(x.optString("assignee_id")==session.memberId&&state=="assigned"){
 OutlinedTextField(evidence[id]?:"",{evidence=evidence+(id to it.take(2000))},label={Text(tr("Preuve de réalisation","Completion evidence"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&!evidence[id].isNullOrBlank(),onClick={mutate(x,"submit")}){Text(tr("Soumettre","Submit"))}}
 if(x.optBoolean("can_manage")&&state=="submitted"){TextButton(enabled=!busy,onClick={mutate(x,"approve")}){Text(tr("Valider","Approve"))};TextButton(enabled=!busy,onClick={mutate(x,"return")}){Text(tr("Retour pour correction","Return for correction"))}}
 if(x.optBoolean("can_manage")&&state in setOf("assigned","submitted"))TextButton(enabled=!busy,onClick={mutate(x,"cancel")}){Text(tr("Annuler","Cancel"))}
 }
 if(!busy&&visible.isEmpty())Text(tr("Aucune tâche dans cette vue.","No tasks in this view."))
 }}
}
