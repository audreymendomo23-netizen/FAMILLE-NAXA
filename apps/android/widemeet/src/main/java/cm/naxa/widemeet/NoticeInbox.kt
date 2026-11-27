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
 val scope=rememberCoroutineScope();var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 suspend fun refresh(){val a=(gateway.request("notices",JSONObject(),session) as JSONObject).getJSONArray("items");items=(0 until a.length()).map{a.getJSONObject(it)}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId){busy=true;try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){
 Text(tr("Notifications","Notifications"),style=MaterialTheme.typography.titleMedium);TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Actualiser","Refresh"))}
 if(error)Text(tr("Notifications indisponibles.","Notifications unavailable."))else if(!busy&&items.isEmpty())Text(tr("Aucune notification.","No notifications."))
 for(x in items){val kind=x.getString("kind");val label=when(kind){"invitation"->tr("Invitation","Invitation");"meeting_reminder"->tr("Rappel de réunion","Meeting reminder");"minutes_published"->tr("Compte rendu publié","Minutes published");"task_assigned"->tr("Tâche attribuée","Task assigned");"task_overdue"->tr("Tâche en retard","Overdue task");"task_review"->tr("Tâche à valider","Task to review");"task_done"->tr("Tâche validée","Task approved");"subscription_expiring"->tr("Abonnement bientôt expiré","Subscription expiring");else->tr("Notification","Notification")}
 Text(label+(if(x.isNull("read_at"))" · "+tr("Nouveau","New")else ""));Text((if(x.isNull("title"))""else x.getString("title"))+" · "+x.optString("due").take(16))
 TextButton(enabled=!busy,onClick={work{gateway.request("notices",JSONObject().put("read",x.getString("k")),session);onOpen(kind)}}){Text(tr("Ouvrir","Open"))}
 if(x.isNull("read_at"))TextButton(enabled=!busy,onClick={work{gateway.request("notices",JSONObject().put("read",x.getString("k")),session);refresh()}}){Text(tr("Marquer comme lu","Mark as read"))}
 }
 }}
}
