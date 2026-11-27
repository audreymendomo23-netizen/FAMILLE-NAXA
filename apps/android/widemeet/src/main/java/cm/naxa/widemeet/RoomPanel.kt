package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import android.app.Activity
import android.view.WindowManager
import androidx.compose.ui.platform.LocalContext
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
 val window=(LocalContext.current as? Activity)?.window
 DisposableEffect(window){val wasSecure=(window?.attributes?.flags?.and(WindowManager.LayoutParams.FLAG_SECURE)?:0)!=0;window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE);onDispose{if(!wasSecure)window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)}}
 var list by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var passes by remember{mutableStateOf<List<JSONObject>>(emptyList())};var passId by remember{mutableStateOf("")}
 var room by remember{mutableStateOf<JSONObject?>(null)}
 var mode by remember{mutableStateOf(if(initialCreate&&hostRole)"create" else "list")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var title by remember{mutableStateOf("")};var description by remember{mutableStateOf("")};var date by remember{mutableStateOf("")};var duration by remember{mutableStateOf("30")}
 var invited by remember{mutableStateOf<Set<String>>(emptySet())};var chat by remember{mutableStateOf("")};var poll by remember{mutableStateOf("")}
 var editing by remember{mutableStateOf(false)};var recipient by remember{mutableStateOf("")};var surveyAnonymous by remember{mutableStateOf(true)};var surveyEditable by remember{mutableStateOf(false)};var cancelConfirm by remember{mutableStateOf(false)};var excludeTarget by remember{mutableStateOf<String?>(null)}
 var recurrence by remember{mutableStateOf("none")};var occurrences by remember{mutableStateOf("2")};var interval by remember{mutableStateOf("1")};var seriesPending by remember{mutableStateOf<JSONObject?>(null)};var seriesCancelConfirm by remember{mutableStateOf(false)}
 var extension by remember{mutableStateOf("15")};var surveyQuestion by remember{mutableStateOf("")};var surveyOptions by remember{mutableStateOf("")};var surveyMultiple by remember{mutableStateOf(false)};var surveyQuorum by remember{mutableStateOf("50")};var surveyThreshold by remember{mutableStateOf("50")};var surveySelections by remember{mutableStateOf<Map<String,Set<Int>>>(emptyMap())}
 suspend fun refresh(){busy=true;error=false;try{if(workspace.kind=="individual"){val all=rows(gateway.request("pass-list",JSONObject(),session) as JSONArray);passes=all.filter{it.isNull("room_id")};if(passes.none{it.optString("id")==passId})passId=passes.firstOrNull()?.optString("id")?:"";if(all.isEmpty()){list=emptyList();contacts=emptyList();return}};list=rows(gateway.request("list",JSONObject(),session) as JSONArray);if(hostRole)contacts=rows(gateway.request("contacts",JSONObject(),session) as JSONArray)}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;list=emptyList();contacts=emptyList()}finally{busy=false}}
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
 fun execute(action:String,body:JSONObject){if(busy)return;busy=true;error=false;scope.launch{try{val next=gateway.request(action,body,session) as JSONObject;require(next.has("id")&&next.has("revision"));room=next;mode="room";chat="";poll="";editing=false}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;if(action=="command")room=null}finally{busy=false}}}
 fun seriesAction(action:String,body:JSONObject){if(busy)return;busy=true;error=false;scope.launch{try{gateway.request(action,body,session);seriesPending=null;room=null;mode="list";refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
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
 if(workspace.kind=="individual"){Text(tr("Pass payé disponible","Available paid pass"));passes.forEach{p->Row{RadioButton(passId==p.getString("id"),{passId=p.getString("id")},enabled=!busy);Text(p.getInt("capacity").toString()+" "+tr("participants","participants"),Modifier.padding(top=12.dp))}};Text(tr("Le pass sera réservé à cette seule réunion pendant 24 heures maximum.","The pass will be bound to this meeting only, for up to 24 hours."))}
 if(workspace.kind=="enterprise"&&BuildConfig.WIDEMEET_SERIES_ENABLED){Text(tr("Récurrence (heure UTC)","Recurrence (UTC time)"));listOf("none" to tr("Une seule réunion","Single meeting"),"daily" to tr("Quotidienne","Daily"),"weekly" to tr("Hebdomadaire","Weekly"),"monthly" to tr("Mensuelle","Monthly")).forEach{(id,label)->Row{RadioButton(recurrence==id,{recurrence=id},enabled=!busy&&seriesPending==null);Text(label,Modifier.padding(top=12.dp))}};if(recurrence!="none"){OutlinedTextField(occurrences,{occurrences=it.take(2)},enabled=!busy&&seriesPending==null,label={Text(tr("Occurrences (2–12)","Occurrences (2–12)"))});OutlinedTextField(interval,{interval=it.take(2)},enabled=!busy&&seriesPending==null,label={Text(tr("Intervalle (1–12)","Interval (1–12)"))})}}
 Text(tr("Invités","Invitees"))
 contacts.forEach{c->val id=c.optString("member_id");Row{Checkbox(id in invited,{checked->invited=if(checked)invited+id else invited-id});Text(c.optString("display_name"),modifier=Modifier.padding(top=12.dp))}}
 Button(enabled=!busy&&title.isNotBlank()&&(duration.toIntOrNull()?:0) in 5..480&&(workspace.kind!="individual"||passId.isNotEmpty()),onClick={val whenMs=runCatching{if(date.isBlank())System.currentTimeMillis() else LocalDateTime.parse(date).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()}.getOrNull();if(whenMs==null){error=true}else if(recurrence!="none"){val n=occurrences.toIntOrNull()?:0;val every=interval.toIntOrNull()?:0;if(date.isBlank()||n !in 2..12||every !in 1..12){error=true}else{val payload=seriesPending?:JSONObject().put("series_id",UUID.randomUUID().toString()).put("room_ids",JSONArray(List(n){UUID.randomUUID().toString()})).put("title",title).put("description",description).put("scheduled_ms",whenMs).put("duration_minutes",duration.toInt()).put("invitees",JSONArray(invited.toList())).put("recurrence",recurrence).put("interval",every).also{seriesPending=it};seriesAction("series-create",payload)}}else execute("create",JSONObject().put("room_id",UUID.randomUUID().toString()).put("title",title).put("description",description).put("scheduled_ms",whenMs).put("duration_minutes",duration.toInt()).put("invitees",JSONArray(invited.toList())).apply{if(workspace.kind=="individual")put("pass_id",passId)})}){Text(tr("Créer","Create"))}
 }else if(mode=="list"){
 list.forEach{r->TextButton(enabled=!busy,onClick={execute("read",JSONObject().put("room_id",r.optString("id")))}){Text(r.optString("title",tr("Réunion","Meeting"))+" — "+stateLabel(r.optString("status")))}}
 if(!busy&&!error&&list.isEmpty())Text(tr("Aucune réunion dans cet espace.","No meetings in this workspace."))
 }else{val r=room
 if(r!=null){val status=r.optString("status");val isHost=r.optString("hostId")==session.memberId&&hostRole
 fun may(p:String)=isHost||(r.optJSONArray("moderatorPermissions")?.let{a->(0 until a.length()).any{a.optString(it)==p}}==true)
 val modLabels=listOf("admission" to tr("Admissions","Admissions"),"microphone" to tr("Micros","Microphones"),"screen" to tr("Partage","Screen share"),"chat" to tr("Messagerie","Chat"),"exclude" to tr("Exclusion","Exclusion"),"poll" to tr("Votes et enquêtes","Polls and surveys"),"pause" to tr("Pause/reprise","Pause/resume"),"end" to tr("Clôture","End meeting"))
 var remaining by remember(r.optLong("endMs"),r.optLong("serverNowMs")){mutableStateOf(0L)}
 LaunchedEffect(r.optLong("endMs"),r.optLong("serverNowMs"),status){val end=r.optLong("endMs");val base=r.optLong("serverNowMs",System.currentTimeMillis());val start=android.os.SystemClock.elapsedRealtime();while(status in setOf("open","paused")){remaining=((end-base-(android.os.SystemClock.elapsedRealtime()-start)+999)/1000).coerceAtLeast(0);delay(1000)}}
 if(!isHost&&status=="open"&&r.optString("response")=="accepted"&&r.optBoolean("lobbyRequired")&&r.optString("lobbyStatus")!="admitted"){
 Text(when(r.optString("lobbyStatus")){"waiting"->tr("En attente de l’organisateur","Waiting for the host");"rejected"->tr("Admission refusée","Admission declined");else->tr("Salle d’attente","Waiting room")})
 Button(enabled=!busy&&!r.optBoolean("admissionLocked")&&r.optString("lobbyStatus")!="waiting",onClick={command("lobby_request")}){Text(tr("Demander à rejoindre","Request to join"))}
 }
 if(may("admission")&&status=="open"&&r.optBoolean("lobbyRequired")){
 Text(tr("Salle d’attente","Waiting room"))
 rows(r.optJSONArray("participants")).filter{it.optString("lobbyStatus")=="waiting"}.forEach{p->val id=p.optString("memberId");Text(displayName(id));TextButton(enabled=!busy&&!r.optBoolean("admissionLocked"),onClick={command("lobby_admit",null,id)}){Text(tr("Admettre","Admit"))};TextButton(enabled=!busy,onClick={command("lobby_reject",null,id)}){Text(tr("Refuser","Decline"))}}
 }
 if(isHost&&status in setOf("scheduled","open")){
 Text(tr("Délégation de modération","Moderator delegation"));rows(r.optJSONArray("participants")).filter{it.optString("memberId")!=session.memberId}.forEach{p->val id=p.optString("memberId");val a=p.optJSONArray("moderatorPermissions");val perms=if(a==null)emptySet()else(0 until a.length()).map{a.getString(it)}.toSet();Text(displayName(id));modLabels.forEach{(k,l)->Row{Checkbox(k in perms,{checked->command("set_moderator",JSONArray((if(checked)perms+k else perms-k).toList()),id)},enabled=!busy);Text(l,Modifier.padding(top=12.dp))}}}

 Text(tr("Inviter un membre","Invite a member"))
 contacts.filter{c->rows(r.optJSONArray("participants")).none{it.optString("memberId")==c.optString("member_id")}}.forEach{c->TextButton(enabled=!busy,onClick={command("invite_member",null,c.optString("member_id"))}){Text(c.optString("display_name"))}}
 if(status=="open")TextButton(enabled=!busy,onClick={command("lock_admission",!r.optBoolean("admissionLocked"))}){Text(if(r.optBoolean("admissionLocked"))tr("Déverrouiller les admissions","Unlock admissions")else tr("Verrouiller les admissions","Lock admissions"))}
 }
 if(isHost&&status in setOf("open","paused")&&remaining in 1L..300L){Text(tr("Temps restant","Time remaining")+" "+(remaining/60)+":"+ (remaining%60).toString().padStart(2,'0'));Row{listOf(15,30,60).forEach{m->TextButton(enabled=!busy,onClick={command("extend",m)}){Text("+$m min")}}}}
 Text(r.optString("title"),style=MaterialTheme.typography.titleLarge);Text(r.optString("description"));Text(if(r.optBoolean("cancelled"))tr("Annulée","Cancelled")else stateLabel(status))
 TextButton(enabled=!busy,onClick={execute("read",JSONObject().put("room_id",r.getString("id")))}){Text(tr("Actualiser","Refresh"))}
 if(!isHost&&status in setOf("scheduled","open")){listOf("accepted" to tr("Accepter","Accept"),"maybe" to tr("Peut-être","Maybe"),"declined" to tr("Décliner","Decline")).forEach{(v,l)->TextButton(enabled=!busy,onClick={command("respond",v)}){Text(l)}}}
 if(isHost&&status=="scheduled"){
 if(!r.isNull("seriesId")&&BuildConfig.WIDEMEET_SERIES_ENABLED)TextButton(enabled=!busy,onClick={seriesCancelConfirm=true}){Text(tr("Annuler la série","Cancel series"))}
 if(seriesCancelConfirm)AlertDialog(onDismissRequest={seriesCancelConfirm=false},title={Text(tr("Annuler toutes les réunions non démarrées de cette série ?","Cancel all unstarted meetings in this series?"))},confirmButton={TextButton(onClick={seriesCancelConfirm=false;seriesAction("series-cancel",JSONObject().put("series_id",r.getString("seriesId")))}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={seriesCancelConfirm=false}){Text(tr("Retour","Back"))}})
 TextButton(enabled=!busy,onClick={command("lobby_config",!r.optBoolean("lobbyRequired"))}){Text(if(r.optBoolean("lobbyRequired"))tr("Désactiver la salle d’attente","Disable waiting room")else tr("Activer la salle d’attente","Enable waiting room"))}
 TextButton(enabled=!busy,onClick={title=r.optString("title");description=r.optString("description");duration=r.optInt("durationMinutes").toString();date=java.time.Instant.ofEpochMilli(r.optLong("scheduledMs")).atZone(ZoneId.systemDefault()).toLocalDateTime().format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm"));editing=true}){Text(tr("Modifier la réunion","Edit meeting"))}
 TextButton(enabled=!busy,onClick={cancelConfirm=true}){Text(tr("Annuler la réunion","Cancel meeting"))}
 if(cancelConfirm)AlertDialog(onDismissRequest={cancelConfirm=false},title={Text(tr("Annuler cette réunion ?","Cancel this meeting?"))},confirmButton={TextButton(onClick={cancelConfirm=false;command("cancel")}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={cancelConfirm=false}){Text(tr("Retour","Back"))}})
 if(editing){
 OutlinedTextField(title,{title=it.take(120)},label={Text(tr("Titre modifié","Updated title"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(description,{description=it.take(2000)},label={Text(tr("Description modifiée","Updated description"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(date,{date=it.take(16)},label={Text(tr("Nouvelle date (AAAA-MM-JJTHH:mm)","New date (YYYY-MM-DDTHH:mm)"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(duration,{duration=it.take(3)},label={Text(tr("Durée modifiée","Updated duration"))},modifier=Modifier.fillMaxWidth())
 Text(tr("Les invités devront confirmer à nouveau.","Invitees must confirm again."))
 Button(enabled=!busy&&title.isNotBlank()&&(duration.toIntOrNull()?:0) in 5..480,onClick={val ms=runCatching{LocalDateTime.parse(date).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()}.getOrNull();if(ms==null)error=true else command("reschedule",JSONObject().put("title",title).put("description",description).put("scheduledMs",ms).put("durationMinutes",duration.toInt()))}){Text(tr("Enregistrer la modification","Save changes"))}
 TextButton(onClick={editing=false}){Text(tr("Fermer","Close"))}
 }}
 if(isHost&&status in setOf("open","paused")){OutlinedTextField(extension,{extension=it.take(3)},label={Text(tr("Prolongation (minutes)","Extension (minutes)"))},modifier=Modifier.fillMaxWidth());Button(enabled=!busy&&(extension.toIntOrNull()?:0) in 1..480,onClick={command("extend",extension.toInt())}){Text(tr("Prolonger","Extend"))}}
 if(isHost||may("pause")||may("end")){if(isHost&&status=="scheduled")Button(enabled=!busy,onClick={command("start")}){Text(tr("Ouvrir la salle","Open room"))};if(may("pause")&&status=="open")Button(enabled=!busy,onClick={command("pause")}){Text(tr("Mettre en pause","Pause"))};if(may("pause")&&status=="paused")Button(enabled=!busy,onClick={command("resume")}){Text(tr("Reprendre","Resume"))};if(may("end")&&status!="ended"&&(isHost||status!="scheduled"))TextButton(enabled=!busy,onClick={command("end")}){Text(tr("Terminer","End"))}}
 excludeTarget?.let{id->AlertDialog(onDismissRequest={excludeTarget=null},title={Text(tr("Exclure ce participant ?","Exclude this participant?"))},confirmButton={TextButton(onClick={excludeTarget=null;command("exclude",null,id)}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={excludeTarget=null}){Text(tr("Retour","Back"))}})}
 if(status=="open"&&r.optString("response")=="accepted"&&(!r.optBoolean("lobbyRequired")||isHost||r.optString("lobbyStatus")=="admitted")){
 if(BuildConfig.WIDEMEET_MEDIA_ENABLED){key(session.deviceId,r.getString("id")){NativeMediaPanel(english,gateway,session,r.getString("id"),rows(r.optJSONArray("participants")).any{it.optString("memberId")==session.memberId&&it.optBoolean("mic")},rows(r.optJSONArray("participants")).any{it.optString("memberId")==session.memberId&&it.optBoolean("screen")})}}else Text(tr("Audio et vidéo indisponibles pour le moment.","Audio and video are currently unavailable."))
 TextButton(enabled=!busy,onClick={command("hand",true)}){Text(tr("Lever la main","Raise hand"))}
 TextButton(enabled=!busy,onClick={command("hand",false)}){Text(tr("Baisser la main","Lower hand"))}
 TextButton(enabled=!busy,onClick={command("reaction","clap")}){Text(tr("Applaudir","Clap"))}
 Text(tr("Destinataire","Recipient"))
 Row{RadioButton(recipient=="",{recipient=""},enabled=!busy);Text(tr("Tous les participants","Everyone"),Modifier.padding(top=12.dp))}
 rows(r.optJSONArray("participants")).filter{it.optString("memberId")!=session.memberId&&it.optString("response")=="accepted"}.forEach{p->val id=p.optString("memberId");Row{RadioButton(recipient==id,{recipient=id},enabled=!busy);Text(displayName(id),Modifier.padding(top=12.dp))}}
 OutlinedTextField(chat,{chat=it.take(2000)},label={Text(tr("Message","Message"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&chat.isNotBlank(),onClick={command(if(recipient.isEmpty())"chat" else "private_chat",chat,recipient.ifEmpty{null})}){Text(tr("Envoyer","Send"))}
 rows(r.optJSONArray("events")).forEach{e->Text(displayName(e.optString("actor"))+" : "+when(e.optString("action")){"chat"->e.optString("value");"private_chat"->tr("Privé","Private")+" · "+e.optString("value");else->tr("Réaction","Reaction")})}
 Text(tr("Consentement audio","Audio consent"))
 TextButton(enabled=!busy,onClick={command("consent",true)}){Text(tr("Donner mon accord","Give consent"))}
 TextButton(enabled=!busy,onClick={command("consent",false)}){Text(tr("Retirer mon accord","Withdraw consent"))}
 when(r.optJSONObject("recordingStatus")?.optString("phase")){
 "active"->Text(tr("● Enregistrement audio en cours","● Audio recording active"),color=MaterialTheme.colorScheme.error)
 "stopping"->Text(tr("Arrêt de la capture en cours","Stopping recording"))
 "complete"->Text(tr("Enregistrement audio terminé et vérifié","Audio recording completed and verified"))
 "discarded"->Text(tr("Segment audio supprimé par sécurité","Audio segment discarded for safety"))
 else->if(r.optString("recording")=="requested")Text(tr("Demande d’enregistrement non confirmée par le moteur audio.","Recording request not confirmed by the audio engine."))
 }
 if(isHost){
 TextButton(enabled=!busy&&r.optString("recording")!="requested"&&r.optJSONObject("recordingStatus")?.optString("phase") !in setOf("active","starting","stopping"),onClick={command("record",true)}){Text(if(r.optBoolean("recordingPaused"))tr("Reprendre la capture","Resume recording")else tr("Demander l’enregistrement audio","Request audio recording"))}
 if(r.optString("recording")=="requested")TextButton(enabled=!busy,onClick={command("record_pause")}){Text(tr("Pause audio uniquement","Pause recording only"))}
 TextButton(enabled=!busy,onClick={command("record",false)}){Text(tr("Arrêter la demande","Stop request"))}
 OutlinedTextField(poll,{poll=it.take(2000)},label={Text(tr("Choix du vote séparés par |","Poll choices separated by |"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&poll.contains("|"),onClick={command("poll",JSONArray(poll.split("|").map{it.trim()}.filter{it.isNotEmpty()}),UUID.randomUUID().toString())}){Text(tr("Créer le vote","Create poll"))}
 }
 if(isHost){
 Text(tr("Enquête Premium","Premium survey"))
 Row{Checkbox(surveyAnonymous,{surveyAnonymous=it});Text(tr("Anonyme","Anonymous"))}
 Row{Checkbox(surveyEditable,{surveyEditable=it});Text(tr("Modifiable avant clôture","Editable until closing"))}
 OutlinedTextField(surveyQuestion,{surveyQuestion=it.take(200)},label={Text(tr("Question","Question"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(surveyOptions,{surveyOptions=it.take(2000)},label={Text(tr("Options séparées par |","Options separated by |"))},modifier=Modifier.fillMaxWidth())
 Row{Checkbox(surveyMultiple,{surveyMultiple=it});Text(tr("Choix multiples","Multiple choices"))}
 OutlinedTextField(surveyQuorum,{surveyQuorum=it.take(3)},label={Text(tr("Quorum (%)","Quorum (%)"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(surveyThreshold,{surveyThreshold=it.take(3)},label={Text(tr("Seuil (%)","Threshold (%)"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&surveyQuestion.isNotBlank()&&surveyOptions.contains("|")&&(surveyQuorum.toIntOrNull()?:-1) in 0..100&&(surveyThreshold.toIntOrNull()?:0) in 1..100,onClick={command("survey",JSONObject().put("question",surveyQuestion).put("kind",if(surveyMultiple)"multiple" else "single").put("options",JSONArray(surveyOptions.split("|").map{it.trim()}.filter{it.isNotEmpty()})).put("anonymous",surveyAnonymous).put("editable",surveyEditable).put("visibility","closed").put("quorum",surveyQuorum.toInt()).put("threshold",surveyThreshold.toInt()),UUID.randomUUID().toString())}){Text(tr("Créer l’enquête","Create survey"))}
 }
 rows(r.optJSONArray("polls")).forEach{p->val opts=p.optJSONArray("options")?:JSONArray();val counts=p.optJSONArray("counts");val pid=p.optString("id");val kind=p.optString("kind","simple");val canVote=!busy&&p.optBoolean("open")&&(!p.optBoolean("voted")||p.optBoolean("editable"));val initial=p.optJSONArray("ownSelection")?.let{a->(0 until a.length()).map{a.getInt(it)}.toSet()}?:emptySet<Int>();Text(if(p.isNull("question"))tr("Vote","Poll") else p.optString("question"));if(counts==null)Text(tr("Résultats après clôture","Results after closing"));for(i in 0 until opts.length()){
 val label=opts.optString(i)+(counts?.let{" ("+it.optInt(i)+")"}?:"")
 if(kind=="multiple"){Row{Checkbox(i in (surveySelections[pid]?:initial),{checked->val old=surveySelections[pid]?:initial;surveySelections=surveySelections+(pid to if(checked)old+i else old-i)},enabled=canVote);Text(label)}}else TextButton(enabled=canVote,onClick={command(if(kind=="simple")"vote" else "survey_vote",if(kind=="simple")i else JSONArray(listOf(i)),pid)}){Text(label)}
 };if(kind=="multiple")TextButton(enabled=canVote&&!(surveySelections[pid]?:initial).isEmpty(),onClick={command("survey_vote",JSONArray((surveySelections[pid]?:initial).toList()),pid)}){Text(tr("Valider mes choix","Submit choices"))};rows(p.optJSONArray("nominativeResponses")).forEach{v->val sel=v.optJSONArray("selection")?:JSONArray();Text(displayName(v.optString("memberId"))+" : "+(0 until sel.length()).joinToString(", "){opts.optString(sel.getInt(it))})};if(!p.isNull("quorumMet"))Text(tr("Quorum","Quorum")+": "+if(p.optBoolean("quorumMet"))tr("atteint","met") else tr("non atteint","not met"));if(may("poll")&&p.optBoolean("open"))TextButton(enabled=!busy,onClick={command("close_poll",null,pid)}){Text(tr("Clôturer","Close"))}}
 if(may("microphone")||may("screen")||may("exclude")||may("chat"))rows(r.optJSONArray("participants")).filter{it.optString("memberId")!=session.memberId&&it.optString("memberId")!=r.optString("hostId")}.forEach{p->val id=p.optString("memberId");Text(displayName(id));if(may("microphone"))TextButton(enabled=!busy,onClick={command(if(p.optBoolean("mic"))"mute" else "allow_mic",null,id)}){Text(if(p.optBoolean("mic"))tr("Couper le micro","Mute") else tr("Autoriser le micro","Allow microphone"))};if(may("screen"))TextButton(enabled=!busy,onClick={command("screen",!p.optBoolean("screen"),id)}){Text(if(p.optBoolean("screen"))tr("Retirer partage","Revoke share")else tr("Autoriser partage","Allow share"))};if(may("chat"))TextButton(enabled=!busy,onClick={command("chat_permission",!p.optBoolean("chat"),id)}){Text(if(p.optBoolean("chat"))tr("Interdire le chat","Disable chat")else tr("Autoriser le chat","Enable chat"))};if(may("exclude"))TextButton(enabled=!busy,onClick={excludeTarget=id}){Text(tr("Exclure","Exclude"))}}
 }
 }}
 }}
}
