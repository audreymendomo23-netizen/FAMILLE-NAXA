package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.time.LocalDateTime
import java.time.ZoneId

private fun rows(a:JSONArray?):List<JSONObject> = if(a==null)emptyList() else (0 until a.length()).mapNotNull{a.optJSONObject(it)}

@Composable fun RoomPanel(english:Boolean,gateway:RoomGateway,session:Session,workspace:Workspace,initialCreate:Boolean=false){
 fun tr(fr:String,en:String)=if(english)en else fr
 val hostRole=workspace.role in setOf("owner","promoteur","manager")
 val scope=rememberCoroutineScope()
 var list by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var room by remember{mutableStateOf<JSONObject?>(null)}
 var mode by remember{mutableStateOf(if(initialCreate&&hostRole)"create" else "list")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var title by remember{mutableStateOf("")};var description by remember{mutableStateOf("")};var date by remember{mutableStateOf("")};var duration by remember{mutableStateOf("30")}
 var invited by remember{mutableStateOf<Set<String>>(emptySet())};var chat by remember{mutableStateOf("")};var poll by remember{mutableStateOf("")}
 var extension by remember{mutableStateOf("15")};var surveyQuestion by remember{mutableStateOf("")};var surveyOptions by remember{mutableStateOf("")};var surveyMultiple by remember{mutableStateOf(false)};var surveyQuorum by remember{mutableStateOf("50")};var surveyThreshold by remember{mutableStateOf("50")};var surveySelections by remember{mutableStateOf<Map<String,Set<Int>>>(emptyMap())}
 suspend fun refresh(){busy=true;error=false;try{list=rows(gateway.request("list",JSONObject(),session) as JSONArray);if(hostRole)contacts=rows(gateway.request("contacts",JSONObject(),session) as JSONArray)}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;list=emptyList();contacts=emptyList()}finally{busy=false}}
 LaunchedEffect(session.deviceId){refresh()}
 // Refresh only the selected authorized room. Cancels during writes, selection or session change.
 LaunchedEffect(session.deviceId,mode,room?.optString("id"),room?.optString("status"),busy){
  val id=room?.optString("id")?:return@LaunchedEffect
  if(mode!="room"||busy||room?.optString("status")=="ended")return@LaunchedEffect
  while(true){
   delay(3000)
   try{
    val next=gateway.request("read",JSONObject().put("room_id",id),session) as JSONObject
    require(next.optString("id")==id&&next.has("revision"))
    val current=room
    if(current?.optString("id")!=id||busy)return@LaunchedEffect
    if(next.getLong("revision")>=current.getLong("revision"))room=next
    error=false
   }catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){
    if(room?.optString("id")==id){room=null;mode="list";error=true}
    return@LaunchedEffect
   }
  }
 }
 fun execute(action:String,body:JSONObject){if(busy)return;busy=true;error=false;scope.launch{try{val next=gateway.request(action,body,session) as JSONObject;require(next.has("id")&&next.has("revision"));room=next;mode="room";chat="";poll=""}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;if(action=="command")room=null}finally{busy=false}}}
 fun command(action:String,value:Any?=null,target:String?=null){val r=room?:return;execute("command",JSONObject().put("room_id",r.getString("id")).put("request_id",UUID.randomUUID().toString()).put("expected_revision",r.getLong("revision")).put("action",action).put("value",value?:JSONObject.NULL).put("target",target?:JSONObject.NULL))}
 fun displayName(id:String)=if(id==session.memberId)tr("Moi","Me") else contacts.firstOrNull{it.optString("member_id")==id}?.optString("display_name")?:tr("Participant","Participant")
 fun stateLabel(s:String)=when(s){"scheduled"->tr("Programmée","Scheduled");"open"->tr("Ouverte","Open");"paused"->tr("En pause","Paused");"ended"->tr("Terminée","Ended");else->tr("Indisponible","Unavailable")}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){
 TextButton(enabled=!busy,onClick={mode="list";room=null;scope.launch{refresh()}}){Text(tr("Agenda","Calendar"))}
 if(hostRole)TextButton(enabled=!busy,onClick={mode="create";room=null}){Text(tr("Nouvelle réunion","New meeting"))}
 }
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Action non confirmée. Actualisez et réessayez.","Action not confirmed. Refresh and try again."),color=MaterialTheme.colorScheme.error)
 if(mode=="create"&&hostRole){
 OutlinedTextField(title,{title=it.take(120)},label={Text(tr("Titre","Title"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(description,{description=it.take(2000)},label={Text(tr("Description","Description"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(date,{date=it.take(16)},label={Text(tr("Date (AAAA-MM-JJTHH:mm, facultatif)","Date (YYYY-MM-DDTHH:mm, optional)"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(duration,{duration=it.take(3)},label={Text(tr("Durée en minutes","Duration in minutes"))},modifier=Modifier.fillMaxWidth())
 Text(tr("Invités","Invitees"))
 contacts.forEach{c->val id=c.optString("member_id");Row{Checkbox(id in invited,{checked->invited=if(checked)invited+id else invited-id});Text(c.optString("display_name"),modifier=Modifier.padding(top=12.dp))}}
 Button(enabled=!busy&&title.isNotBlank()&&(duration.toIntOrNull()?:0) in 5..480,onClick={val whenMs=runCatching{if(date.isBlank())System.currentTimeMillis() else LocalDateTime.parse(date).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()}.getOrNull();if(whenMs==null){error=true}else execute("create",JSONObject().put("room_id",UUID.randomUUID().toString()).put("title",title).put("description",description).put("scheduled_ms",whenMs).put("duration_minutes",duration.toInt()).put("invitees",JSONArray(invited.toList())))}){Text(tr("Créer","Create"))}
 }else if(mode=="list"){
 list.forEach{r->TextButton(enabled=!busy,onClick={execute("read",JSONObject().put("room_id",r.optString("id")))}){Text(r.optString("title",tr("Réunion","Meeting"))+" — "+stateLabel(r.optString("status")))}}
 if(!busy&&!error&&list.isEmpty())Text(tr("Aucune réunion dans cet espace.","No meetings in this workspace."))
 }else{val r=room
 if(r!=null){val status=r.optString("status");val isHost=r.optString("hostId")==session.memberId&&hostRole
 Text(r.optString("title"),style=MaterialTheme.typography.titleLarge);Text(r.optString("description"));Text(stateLabel(status))
 TextButton(enabled=!busy,onClick={execute("read",JSONObject().put("room_id",r.getString("id")))}){Text(tr("Actualiser","Refresh"))}
 if(!isHost&&status in setOf("scheduled","open")){listOf("accepted" to tr("Accepter","Accept"),"maybe" to tr("Peut-être","Maybe"),"declined" to tr("Décliner","Decline")).forEach{(v,l)->TextButton(enabled=!busy,onClick={command("respond",v)}){Text(l)}}}
 if(isHost&&status in setOf("open","paused")){OutlinedTextField(extension,{extension=it.take(3)},label={Text(tr("Prolongation (minutes)","Extension (minutes)"))},modifier=Modifier.fillMaxWidth());Button(enabled=!busy&&(extension.toIntOrNull()?:0) in 1..480,onClick={command("extend",extension.toInt())}){Text(tr("Prolonger","Extend"))}}
 if(isHost){if(status=="scheduled")Button(enabled=!busy,onClick={command("start")}){Text(tr("Ouvrir la salle","Open room"))};if(status=="open")Button(enabled=!busy,onClick={command("pause")}){Text(tr("Mettre en pause","Pause"))};if(status=="paused")Button(enabled=!busy,onClick={command("resume")}){Text(tr("Reprendre","Resume"))};if(status!="ended")TextButton(enabled=!busy,onClick={command("end")}){Text(tr("Terminer","End"))}}
 if(status=="open"&&r.optString("response")=="accepted"){
 if(BuildConfig.WIDEMEET_MEDIA_ENABLED){key(session.deviceId,r.getString("id")){NativeMediaPanel(english,gateway,session,r.getString("id"),rows(r.optJSONArray("participants")).any{it.optString("memberId")==session.memberId&&it.optBoolean("mic")},rows(r.optJSONArray("participants")).any{it.optString("memberId")==session.memberId&&it.optBoolean("screen")})}}else Text(tr("Audio et vidéo indisponibles pour le moment.","Audio and video are currently unavailable."))
 TextButton(enabled=!busy,onClick={command("hand",true)}){Text(tr("Lever la main","Raise hand"))}
 TextButton(enabled=!busy,onClick={command("hand",false)}){Text(tr("Baisser la main","Lower hand"))}
 TextButton(enabled=!busy,onClick={command("reaction","clap")}){Text(tr("Applaudir","Clap"))}
 OutlinedTextField(chat,{chat=it.take(2000)},label={Text(tr("Message","Message"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&chat.isNotBlank(),onClick={command("chat",chat)}){Text(tr("Envoyer","Send"))}
 rows(r.optJSONArray("events")).forEach{e->Text(displayName(e.optString("actor"))+" : "+if(e.optString("action")=="chat")e.optString("value") else tr("Réaction","Reaction"))}
 Text(tr("Consentement audio","Audio consent"))
 TextButton(enabled=!busy,onClick={command("consent",true)}){Text(tr("Donner mon accord","Give consent"))}
 TextButton(enabled=!busy,onClick={command("consent",false)}){Text(tr("Retirer mon accord","Withdraw consent"))}
 if(r.optString("recording")=="requested")Text(tr("Demande d’enregistrement non confirmée par le moteur audio.","Recording request not confirmed by the audio engine."))
 if(isHost){
 TextButton(enabled=!busy,onClick={command("record",true)}){Text(tr("Demander l’enregistrement audio","Request audio recording"))}
 TextButton(enabled=!busy,onClick={command("record",false)}){Text(tr("Arrêter la demande","Stop request"))}
 OutlinedTextField(poll,{poll=it.take(2000)},label={Text(tr("Choix du vote séparés par |","Poll choices separated by |"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&poll.contains("|"),onClick={command("poll",JSONArray(poll.split("|").map{it.trim()}.filter{it.isNotEmpty()}),UUID.randomUUID().toString())}){Text(tr("Créer le vote","Create poll"))}
 }
 if(isHost){
 Text(tr("Enquête Premium anonyme","Anonymous Premium survey"))
 OutlinedTextField(surveyQuestion,{surveyQuestion=it.take(200)},label={Text(tr("Question","Question"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(surveyOptions,{surveyOptions=it.take(2000)},label={Text(tr("Options séparées par |","Options separated by |"))},modifier=Modifier.fillMaxWidth())
 Row{Checkbox(surveyMultiple,{surveyMultiple=it});Text(tr("Choix multiples","Multiple choices"))}
 OutlinedTextField(surveyQuorum,{surveyQuorum=it.take(3)},label={Text(tr("Quorum (%)","Quorum (%)"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(surveyThreshold,{surveyThreshold=it.take(3)},label={Text(tr("Seuil (%)","Threshold (%)"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&surveyQuestion.isNotBlank()&&surveyOptions.contains("|")&&(surveyQuorum.toIntOrNull()?:-1) in 0..100&&(surveyThreshold.toIntOrNull()?:0) in 1..100,onClick={command("survey",JSONObject().put("question",surveyQuestion).put("kind",if(surveyMultiple)"multiple" else "single").put("options",JSONArray(surveyOptions.split("|").map{it.trim()}.filter{it.isNotEmpty()})).put("anonymous",true).put("visibility","closed").put("quorum",surveyQuorum.toInt()).put("threshold",surveyThreshold.toInt()),UUID.randomUUID().toString())}){Text(tr("Créer l’enquête","Create survey"))}
 }
 rows(r.optJSONArray("polls")).forEach{p->val opts=p.optJSONArray("options")?:JSONArray();val counts=p.optJSONArray("counts");val pid=p.optString("id");val kind=p.optString("kind","simple");val canVote=!busy&&p.optBoolean("open")&&!p.optBoolean("voted");Text(if(p.isNull("question"))tr("Vote","Poll") else p.optString("question"));if(counts==null)Text(tr("Résultats après clôture","Results after closing"));for(i in 0 until opts.length()){
 val label=opts.optString(i)+(counts?.let{" ("+it.optInt(i)+")"}?:"")
 if(kind=="multiple"){Row{Checkbox(i in (surveySelections[pid]?:emptySet()),{checked->val old=surveySelections[pid]?:emptySet();surveySelections=surveySelections+(pid to if(checked)old+i else old-i)},enabled=canVote);Text(label)}}else TextButton(enabled=canVote,onClick={command(if(kind=="simple")"vote" else "survey_vote",if(kind=="simple")i else JSONArray(listOf(i)),pid)}){Text(label)}
 };if(kind=="multiple")TextButton(enabled=canVote&&!(surveySelections[pid]?:emptySet()).isEmpty(),onClick={command("survey_vote",JSONArray((surveySelections[pid]?:emptySet()).toList()),pid)}){Text(tr("Valider mes choix","Submit choices"))};if(!p.isNull("quorumMet"))Text(tr("Quorum","Quorum")+": "+if(p.optBoolean("quorumMet"))tr("atteint","met") else tr("non atteint","not met"));if(isHost&&p.optBoolean("open"))TextButton(enabled=!busy,onClick={command("close_poll",null,pid)}){Text(tr("Clôturer","Close"))}}
 if(isHost)rows(r.optJSONArray("participants")).filter{it.optString("memberId")!=session.memberId}.forEach{p->val id=p.optString("memberId");Text(displayName(id));TextButton(enabled=!busy,onClick={command(if(p.optBoolean("mic"))"mute" else "allow_mic",null,id)}){Text(if(p.optBoolean("mic"))tr("Couper le micro","Mute") else tr("Autoriser le micro","Allow microphone"))};TextButton(enabled=!busy,onClick={command("screen",!p.optBoolean("screen"),id)}){Text(if(p.optBoolean("screen"))tr("Retirer partage","Revoke share")else tr("Autoriser partage","Allow share"))}}
 }
 }}
 }}
}
