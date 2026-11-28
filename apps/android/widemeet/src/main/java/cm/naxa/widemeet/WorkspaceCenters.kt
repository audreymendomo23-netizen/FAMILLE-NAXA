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
 var groups by remember{mutableStateOf(false)}
 if(groups)GroupChat(english,gateway,session){groups=false}else PrivateWorkspaceChat(english,gateway,session,onBack){groups=true}
}
@Composable private fun PrivateWorkspaceChat(english:Boolean,gateway:AuthGateway,session:Session,onBack:()->Unit,onGroups:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())};var peer by remember{mutableStateOf<JSONObject?>(null)};var messages by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var contactQuery by remember{mutableStateOf("")};var query by remember{mutableStateOf("")};var body by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var pending by remember{mutableStateOf<JSONObject?>(null)};var applied by remember{mutableStateOf("")};var before by remember{mutableStateOf<String?>(null)};var next by remember{mutableStateOf<String?>(null)};var replyTo by remember{mutableStateOf<JSONObject?>(null)}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.identity(session,"center-"+action,data)
 suspend fun refresh(){try{contacts=centerRows(req("contacts",JSONObject().put("query",contactQuery)))}catch(e:CancellationException){throw e}catch(e:Exception){contacts=emptyList();throw e}}
 suspend fun thread(id:String,q:String="",cursor:String?=null){try{val payload=JSONObject().put("peer_id",id).put("query",q).put("page_size",50);if(cursor!=null)payload.put("before_id",cursor);val v=req("thread",payload);messages=centerRows(v);applied=q;before=cursor;next=if(v.isNull("next_before"))null else v.optString("next_before").ifBlank{null}}catch(e:CancellationException){throw e}catch(e:Exception){peer=null;messages=emptyList();contacts=emptyList();body="";pending=null;before=null;next=null;throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId){work{refresh()}}
 LaunchedEffect(peer?.optString("member_id"),applied,before,busy,session.accessToken){val id=peer?.optString("member_id")?:return@LaunchedEffect;if(busy)return@LaunchedEffect;while(true){delay(5000);if(busy)return@LaunchedEffect;try{val payload=JSONObject().put("peer_id",id).put("query",applied).put("page_size",50);before?.let{payload.put("before_id",it)};val v=req("thread",payload);if(!busy&&peer?.optString("member_id")==id){messages=centerRows(v);next=if(v.isNull("next_before"))null else v.optString("next_before").ifBlank{null}}}catch(e:CancellationException){throw e}catch(e:Exception){contacts=emptyList();messages=emptyList();peer=null;before=null;next=null;error=true;return@LaunchedEffect}}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 TextButton(onClick=onBack){Text(tr("Retour aux discussions de réunion","Back to meeting discussions"))}
 TextButton(enabled=!busy&&pending==null,onClick=onGroups){Text(tr("Groupes de discussion","Group chats"))}
 Text(tr("Messages entre membres actifs de votre entreprise.","Messages between active members of your company."))
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error)Text(tr("Accès ou action non confirmé.","Access or action unconfirmed."),color=MaterialTheme.colorScheme.error)
 val c=peer
 if(c==null){OutlinedTextField(contactQuery,{contactQuery=it.take(100)},label={Text(tr("Rechercher un contact","Search contacts"))},modifier=Modifier.fillMaxWidth());TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Rechercher","Search"))};TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Actualiser les contacts","Refresh contacts"))}
 for(x in contacts)TextButton(enabled=!busy,onClick={work{thread(x.getString("member_id"));peer=x;query="";body="";replyTo=null;pending=null}}){Text(x.getString("display_name")+(if(x.optInt("unread")>0)" · "+x.optInt("unread")+" "+tr("non lus","unread") else ""))}
 if(!busy&&contacts.isEmpty())Text(tr("Aucun contact disponible.","No contacts available."))
 }else{
 val id=c.getString("member_id")
 TextButton(enabled=!busy&&pending==null,onClick={work{peer=null;messages=emptyList();body="";refresh()}}){Text(tr("Retour aux contacts","Back to contacts"))}
 if(pending!=null)TextButton(enabled=!busy,onClick={work{pending=null;peer=null;messages=emptyList();body="";refresh()}}){Text(tr("Abandonner la tentative locale (envoi non confirmé)","Discard local retry (send unconfirmed)"))}
 Text(c.getString("display_name"),style=MaterialTheme.typography.titleMedium)
 OutlinedTextField(query,{query=it.take(100)},label={Text(tr("Rechercher dans les messages","Search messages"))},modifier=Modifier.fillMaxWidth())
 TextButton(enabled=!busy&&pending==null,onClick={work{thread(id,query)}}){Text(tr("Rechercher","Search"))}
 Text(tr("Page de messages : ","Message page: ")+messages.size)
 if(before!=null)TextButton(enabled=!busy&&pending==null,onClick={work{thread(id,applied)}}){Text(tr("Messages récents","Latest messages"))}
 next?.let{cursor->TextButton(enabled=!busy&&pending==null,onClick={work{thread(id,applied,cursor)}}){Text(tr("Messages précédents","Older messages"))}}
 for(m in messages){val mine=m.getString("sender_id")==session.memberId;Text(if(mine)tr("Moi","Me")else c.getString("display_name"),style=MaterialTheme.typography.labelLarge);if(!m.isNull("reply_to"))Text(tr("En réponse à : ","In reply to: ")+m.optString("reply_excerpt",tr("Message indisponible","Message unavailable")),style=MaterialTheme.typography.bodySmall);Text(m.getString("body"));TextButton(enabled=!busy&&pending==null,onClick={replyTo=m}){Text(tr("Répondre à ce message","Reply to this message"))};Text(m.optString("created_at")+(if(!m.isNull("read_at"))" · "+tr("Consultation déclarée","Marked seen")else ""),style=MaterialTheme.typography.bodySmall);if(!mine&&m.isNull("read_at"))TextButton(enabled=!busy&&pending==null,onClick={work{req("seen",JSONObject().put("peer_id",id).put("message_id",m.getString("id")));thread(id,applied,before)}}){Text(tr("Marquer comme lu","Mark seen"))}}
 replyTo?.let{x->Text(tr("Réponse à : ","Reply to: ")+x.optString("body").take(180));TextButton(enabled=!busy&&pending==null,onClick={replyTo=null}){Text(tr("Annuler la réponse","Cancel reply"))}}
 OutlinedTextField(body,{body=it.take(2000)},enabled=!busy&&pending==null,label={Text(tr("Votre message","Your message"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&body.isNotBlank(),onClick={work{val p=pending?:JSONObject().put("peer_id",id).put("message_id",UUID.randomUUID().toString()).put("body",body.trim()).also{p->replyTo?.let{p.put("reply_to",it.getString("id"))};pending=p};req("send",p);pending=null;replyTo=null;body="";query="";thread(id);refresh()}}){Text(tr("Envoyer","Send"))}
 if(BuildConfig.WIDEMEET_CHAT_MEDIA_ENABLED)key(id){ChatMediaPanel(english,gateway,session,peerId=id)}
 }
 }}
}
@Composable private fun PeriodicReports(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var data by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 suspend fun request(action:String,payload:JSONObject){busy=true;error=false;try{data=gateway.identity(session,"center-periodic-"+action,payload)}catch(e:CancellationException){throw e}catch(e:Exception){data=null;error=true}finally{busy=false}}
 LaunchedEffect(Unit){request("list",JSONObject())}
 Text(tr("Bilans automatiques","Automatic summaries"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Périodes calendaires Africa/Douala, chiffres au moment de la génération.","Africa/Douala calendar periods, figures at generation."))
 TextButton(enabled=!busy,onClick={scope.launch{request("list",JSONObject())}}){Text(tr("Actualiser l’historique","Refresh history"))}
 if(error)Text(tr("Bilans indisponibles ou accès refusé.","Reports unavailable or access denied."))
 val frequencies=listOf("daily" to tr("Quotidien","Daily"),"weekly" to tr("Hebdomadaire","Weekly"),"monthly" to tr("Mensuel","Monthly"),"quarterly" to tr("Trimestriel","Quarterly"),"yearly" to tr("Annuel","Yearly"))
 data?.let{d->
 val prefs=d.getJSONArray("preferences")
 for((k,label) in frequencies){val enabled=(0 until prefs.length()).any{i->prefs.getJSONObject(i).optString("cadence")==k&&prefs.getJSONObject(i).optBoolean("enabled")};Row{Checkbox(checked=enabled,enabled=!busy,onCheckedChange={checked->scope.launch{request("save",JSONObject().put("cadence",k).put("enabled",checked))}});Text(label,Modifier.padding(top=12.dp))}}
 val reports=d.getJSONArray("items");Text(tr("Historique privé","Private history"),style=MaterialTheme.typography.titleSmall)
 if(reports.length()==0)Text(tr("Aucun bilan généré pour le moment.","No generated summaries yet."))
 for(i in 0 until reports.length()){val x=reports.getJSONObject(i);val m=x.getJSONObject("metrics");Text((frequencies.firstOrNull{it.first==x.optString("cadence")}?.second?:"")+" · "+x.optString("period_start")+" → "+x.optString("period_end"));for((k,label) in listOf("total" to tr("Réunions","Meetings"),"ended" to tr("Terminées","Ended"),"cancelled" to tr("Annulées","Cancelled"),"duration_minutes" to tr("Minutes planifiées","Planned minutes"),"polls_closed" to tr("Votes clôturés explicitement","Explicitly closed polls"),"tasks_done" to tr("Tâches approuvées","Approved tasks")))Text(label+": "+m.optLong(k))}
 }
}
@Composable fun WorkspaceStatistics(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 var days by remember{mutableStateOf("30")};var refreshSeq by remember{mutableIntStateOf(0)};var data by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 LaunchedEffect(days,session.deviceId,session.accessToken,refreshSeq){data=null;busy=true;error=false;try{val request=JSONObject();val rolling=days.toIntOrNull();if(rolling!=null)request.put("days",rolling)else request.put("period",days);data=gateway.identity(session,"center-statistics",request)}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Bilan consolidé Premium","Premium consolidated summary"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Période écoulée","Past period"));for(n in listOf(7,30,90,365))Row{RadioButton(selected=days==n.toString(),onClick={days=n.toString()});Text("$n "+tr("jours","days"),Modifier.padding(top=12.dp))};for((k,label) in listOf("daily" to tr("Aujourd’hui","Today"),"weekly" to tr("Cette semaine","This week"),"monthly" to tr("Ce mois","This month"),"quarterly" to tr("Ce trimestre","This quarter"),"yearly" to tr("Cette année","This year")))Row{RadioButton(selected=days==k,onClick={days=k});Text(label,Modifier.padding(top=12.dp))}
 TextButton(enabled=!busy,onClick={refreshSeq++}){Text(tr("Actualiser le bilan","Refresh summary"))}
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Bilan consolidé non accessible avec vos droits actuels.","Consolidated summary unavailable with current permissions."))
 data?.let{d->Text(if(d.optString("scope")=="enterprise")tr("Toutes les réunions de votre entreprise","All meetings in your company")else tr("Réunions que vous organisez","Meetings you organize"));for((k,label) in listOf("total" to "Total","scheduled" to tr("Programmées","Scheduled"),"open" to tr("Ouvertes","Open"),"paused" to tr("En pause","Paused"),"ended" to tr("Terminées","Ended"),"cancelled" to tr("Annulées","Cancelled"),"duration_minutes" to tr("Minutes planifiées hors annulations","Planned minutes excluding cancellations"),"polls_closed" to tr("Votes clôturés explicitement","Explicitly closed polls"),"polls_effectively_closed" to tr("Votes effectivement clôturés","Effectively closed polls"),"tasks_done" to tr("Tâches approuvées","Approved tasks"),"tasks_assigned" to tr("Tâches à faire","Assigned tasks"),"tasks_submitted" to tr("Tâches à valider","Tasks for review"),"tasks_cancelled" to tr("Tâches annulées","Cancelled tasks"),"tasks_overdue" to tr("Tâches en retard","Overdue tasks"),"invitees" to tr("Invitations","Invitations"),"accepted_invites" to tr("Invitations acceptées","Accepted invitations"),"rooms_with_observations" to tr("Réunions avec suivi de connexion","Meetings with connection records")))Text(label+": "+d.getLong(k));Text(tr("Réunions par organisateur","Meetings by organizer"));d.optJSONArray("by_organizer")?.let{arr->for(i in 0 until arr.length()){val x=arr.getJSONObject(i);Text(x.optString("organizer")+" : "+x.optInt("meetings")+" · "+tr("terminées","ended")+" "+x.optInt("ended"));LinearProgressIndicator(progress={ (x.optInt("meetings").toFloat()/maxOf(1,d.optInt("total"))).coerceIn(0f,1f) },modifier=Modifier.fillMaxWidth())}};Text(tr("Tâches par responsable","Tasks by assignee"));d.optJSONArray("by_assignee")?.let{arr->for(i in 0 until arr.length()){val x=arr.getJSONObject(i);Text(x.optString("assignee")+" : "+x.optInt("done")+"/"+x.optInt("total")+" · "+tr("en retard","overdue")+" "+x.optInt("overdue"));LinearProgressIndicator(progress={ (x.optInt("done").toFloat()/maxOf(1,x.optInt("total"))).coerceIn(0f,1f) },modifier=Modifier.fillMaxWidth())}};Text(tr("Tâches par équipe (rattachement actuel)","Tasks by team (current assignment)"));d.optJSONArray("by_team")?.let{arr->for(i in 0 until arr.length()){val x=arr.getJSONObject(i);Text(x.optString("manager")+" : "+x.optInt("done")+"/"+x.optInt("total")+" · "+tr("en retard","overdue")+" "+x.optInt("overdue"))}};Text(tr("Selon la date programmée (Africa/Douala), sans mesure de présence humaine.","Based on scheduled date (Africa/Douala), not human attendance."))}
 key(session.accessToken){PeriodicReports(english,gateway,session)}
 }}
}
