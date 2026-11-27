package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable fun NoticeInbox(english:Boolean,gateway:RoomGateway,session:Session,onOpen:(String)->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope();var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var filter by remember{mutableStateOf("all")}
 suspend fun refresh(){val a=(gateway.request("notices",JSONObject(),session) as JSONObject).getJSONArray("items");items=(0 until a.length()).map{a.getJSONObject(it)}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId,session.accessToken){busy=true;items=emptyList();try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){
 Text(tr("Notifications","Notifications"),style=MaterialTheme.typography.titleMedium);TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Actualiser","Refresh"))}
 val visible=items.filter{filter=="all"||(if(filter=="unread")it.isNull("read_at") else !it.isNull("read_at"))}
 if(error)Text(tr("Notifications indisponibles.","Notifications unavailable."))else{Text(tr("Non lues : ","Unread: ")+items.count{it.isNull("read_at")}+" / "+items.size);Row(horizontalArrangement=Arrangement.spacedBy(4.dp)){for((k,label) in listOf("all" to tr("Toutes","All"),"unread" to tr("Non lues","Unread"),"read" to tr("Lues","Read"))){FilterChip(selected=filter==k,onClick={filter=k},label={Text(label)})}};if(!busy&&visible.isEmpty())Text(tr("Aucune notification dans cette vue.","No notifications in this view."))}
 for(x in visible){val kind=x.getString("kind");val label=when(kind){"invitation"->tr("Invitation","Invitation");"meeting_reminder"->tr("Rappel de réunion","Meeting reminder");"minutes_published"->tr("Compte rendu publié","Minutes published");"task_assigned"->tr("Tâche attribuée","Task assigned");"task_overdue"->tr("Tâche en retard","Overdue task");"task_review"->tr("Tâche à valider","Task to review");"task_done"->tr("Tâche validée","Task approved");"periodic_report"->tr("Nouveau bilan périodique","New periodic summary");"subscription_expiring"->tr("Abonnement bientôt expiré","Subscription expiring");else->tr("Notification","Notification")}
 Text(label+(if(x.isNull("read_at"))" · "+tr("Nouveau","New")else ""));Text((if(x.isNull("title"))""else x.getString("title"))+" · "+x.optString("due").take(16))
 TextButton(enabled=!busy,onClick={work{val ack=gateway.request("notices",JSONObject().put("read",x.getString("k")),session) as JSONObject;check(ack.optBoolean("read"));refresh();val confirmed=items.firstOrNull{it.optString("k")==x.getString("k")&&!it.isNull("read_at")}?:throw IllegalStateException("unconfirmed notice");onOpen(confirmed.getString("kind"))}}){Text(tr("Ouvrir","Open"))}
 if(x.isNull("read_at"))TextButton(enabled=!busy,onClick={work{val ack=gateway.request("notices",JSONObject().put("read",x.getString("k")),session) as JSONObject;check(ack.optBoolean("read"));refresh()}}){Text(tr("Marquer comme lu","Mark as read"))}
 }
 }}
}
