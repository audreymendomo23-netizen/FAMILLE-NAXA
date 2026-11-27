package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
private fun centerRows(x:JSONObject):List<JSONObject>{val a=x.getJSONArray("items");return (0 until a.length()).map{a.getJSONObject(it)}}
@Composable fun WorkspaceChat(english:Boolean,gateway:AuthGateway,session:Session,onBack:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())};var peer by remember{mutableStateOf<JSONObject?>(null)};var messages by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var contactQuery by remember{mutableStateOf("")};var query by remember{mutableStateOf("")};var body by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var pending by remember{mutableStateOf<JSONObject?>(null)}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.identity(session,"center-"+action,data)
 suspend fun refresh(){try{contacts=centerRows(req("contacts",JSONObject().put("query",contactQuery)))}catch(e:CancellationException){throw e}catch(e:Exception){contacts=emptyList();throw e}}
 suspend fun thread(id:String,q:String=""){try{messages=centerRows(req("thread",JSONObject().put("peer_id",id).put("query",q)))}catch(e:CancellationException){throw e}catch(e:Exception){peer=null;messages=emptyList();contacts=emptyList();body="";pending=null;throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId){work{refresh()}}
 LaunchedEffect(peer?.optString("member_id"),query,busy,session.deviceId){val id=peer?.optString("member_id")?:return@LaunchedEffect;if(busy||pending!=null)return@LaunchedEffect;while(true){delay(5000);if(busy||pending!=null)return@LaunchedEffect;try{val data=centerRows(req("thread",JSONObject().put("peer_id",id).put("query",query)));if(!busy&&peer?.optString("member_id")==id)messages=data}catch(e:CancellationException){throw e}catch(e:Exception){peer=null;contacts=emptyList();messages=emptyList();body="";error=true;return@LaunchedEffect}}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 TextButton(onClick=onBack){Text(tr("Retour aux discussions de réunion","Back to meeting discussions"))}
 Text(tr("Messages entre membres actifs de votre entreprise.","Messages between active members of your company."))
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error)Text(tr("Accès ou action non confirmé.","Access or action unconfirmed."),color=MaterialTheme.colorScheme.error)
 val c=peer
 if(c==null){OutlinedTextField(contactQuery,{contactQuery=it.take(100)},label={Text(tr("Rechercher un contact","Search contacts"))},modifier=Modifier.fillMaxWidth());TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Rechercher","Search"))};TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Actualiser les contacts","Refresh contacts"))}
 for(x in contacts)TextButton(enabled=!busy,onClick={work{thread(x.getString("member_id"));peer=x;query="";body="";pending=null}}){Text(x.getString("display_name")+(if(x.optInt("unread")>0)" · "+x.optInt("unread")+" "+tr("non lus","unread") else ""))}
 if(!busy&&contacts.isEmpty())Text(tr("Aucun contact disponible.","No contacts available."))
 }else{
 val id=c.getString("member_id")
 TextButton(enabled=!busy&&pending==null,onClick={work{peer=null;messages=emptyList();body="";refresh()}}){Text(tr("Retour aux contacts","Back to contacts"))}
 Text(c.getString("display_name"),style=MaterialTheme.typography.titleMedium)
 OutlinedTextField(query,{query=it.take(100)},label={Text(tr("Rechercher dans les messages","Search messages"))},modifier=Modifier.fillMaxWidth())
 TextButton(enabled=!busy&&pending==null,onClick={work{thread(id,query)}}){Text(tr("Rechercher","Search"))}
 Text(tr("200 derniers résultats au maximum.","Up to 200 latest results."))
 for(m in messages){val mine=m.getString("sender_id")==session.memberId;Text(if(mine)tr("Moi","Me")else c.getString("display_name"),style=MaterialTheme.typography.labelLarge);Text(m.getString("body"));Text(m.optString("created_at")+(if(!m.isNull("read_at"))" · "+tr("Consultation déclarée","Marked seen")else ""),style=MaterialTheme.typography.bodySmall);if(!mine&&m.isNull("read_at"))TextButton(enabled=!busy&&pending==null,onClick={work{req("seen",JSONObject().put("peer_id",id).put("message_id",m.getString("id")));thread(id,query)}}){Text(tr("Marquer comme lu","Mark seen"))}}
 OutlinedTextField(body,{body=it.take(2000)},enabled=!busy&&pending==null,label={Text(tr("Votre message","Your message"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&body.isNotBlank(),onClick={work{val p=pending?:JSONObject().put("peer_id",id).put("message_id",UUID.randomUUID().toString()).put("body",body.trim()).also{pending=it};req("send",p);pending=null;body="";query="";thread(id);refresh()}}){Text(tr("Envoyer","Send"))}
 }
 }}
}
@Composable fun WorkspaceStatistics(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 var days by remember{mutableStateOf("30")};var data by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 LaunchedEffect(days,session){data=null;busy=true;error=false;try{val request=JSONObject();val rolling=days.toIntOrNull();if(rolling!=null)request.put("days",rolling)else request.put("period",days);data=gateway.identity(session,"center-statistics",request)}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Bilan consolidé Premium","Premium consolidated summary"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Période écoulée","Past period"));for(n in listOf(7,30,90,365))Row{RadioButton(selected=days==n.toString(),onClick={days=n.toString()});Text("$n "+tr("jours","days"),Modifier.padding(top=12.dp))};for((k,label) in listOf("daily" to tr("Aujourd’hui","Today"),"weekly" to tr("Cette semaine","This week"),"monthly" to tr("Ce mois","This month"),"quarterly" to tr("Ce trimestre","This quarter"),"yearly" to tr("Cette année","This year")))Row{RadioButton(selected=days==k,onClick={days=k});Text(label,Modifier.padding(top=12.dp))}
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Bilan consolidé non accessible avec vos droits actuels.","Consolidated summary unavailable with current permissions."))
 data?.let{d->Text(if(d.optString("scope")=="enterprise")tr("Toutes les réunions de votre entreprise","All meetings in your company")else tr("Réunions que vous organisez","Meetings you organize"));for((k,label) in listOf("total" to "Total","scheduled" to tr("Programmées","Scheduled"),"open" to tr("Ouvertes","Open"),"paused" to tr("En pause","Paused"),"ended" to tr("Terminées","Ended"),"cancelled" to tr("Annulées","Cancelled"),"duration_minutes" to tr("Minutes planifiées hors annulations","Planned minutes excluding cancellations"),"polls_closed" to tr("Votes clôturés explicitement","Explicitly closed polls"),"polls_effectively_closed" to tr("Votes effectivement clôturés","Effectively closed polls"),"tasks_done" to tr("Tâches approuvées","Approved tasks"),"tasks_assigned" to tr("Tâches à faire","Assigned tasks"),"tasks_submitted" to tr("Tâches à valider","Tasks for review"),"tasks_cancelled" to tr("Tâches annulées","Cancelled tasks"),"tasks_overdue" to tr("Tâches en retard","Overdue tasks"),"invitees" to tr("Invitations","Invitations"),"accepted_invites" to tr("Invitations acceptées","Accepted invitations"),"rooms_with_observations" to tr("Réunions avec observations SFU","Meetings with SFU samples")))Text(label+": "+d.getLong(k));Text(tr("Réunions par organisateur","Meetings by organizer"));d.optJSONArray("by_organizer")?.let{arr->for(i in 0 until arr.length()){val x=arr.getJSONObject(i);Text(x.optString("organizer")+" : "+x.optInt("meetings")+" · "+tr("terminées","ended")+" "+x.optInt("ended"));LinearProgressIndicator(progress={ (x.optInt("meetings").toFloat()/maxOf(1,d.optInt("total"))).coerceIn(0f,1f) },modifier=Modifier.fillMaxWidth())}};Text(tr("Tâches par responsable","Tasks by assignee"));d.optJSONArray("by_assignee")?.let{arr->for(i in 0 until arr.length()){val x=arr.getJSONObject(i);Text(x.optString("assignee")+" : "+x.optInt("done")+"/"+x.optInt("total")+" · "+tr("en retard","overdue")+" "+x.optInt("overdue"));LinearProgressIndicator(progress={ (x.optInt("done").toFloat()/maxOf(1,x.optInt("total"))).coerceIn(0f,1f) },modifier=Modifier.fillMaxWidth())}};Text(tr("Selon la date programmée (Africa/Douala), sans mesure de présence humaine.","Based on scheduled date (Africa/Douala), not human attendance."))}
 }}
}
