package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.os.Handler
import android.os.Looper
import java.util.Locale
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

@Composable
private fun RecordingAnnouncement(active: Boolean, english: Boolean) {
    val context = LocalContext.current.applicationContext
    var ready by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var engine by remember { mutableStateOf<TextToSpeech?>(null) }
    DisposableEffect(context) {
        val handler = Handler(Looper.getMainLooper())
        var alive = true
        val speech = TextToSpeech(context) { status ->
            handler.post { if (alive) { ready = status == TextToSpeech.SUCCESS; failed = !ready } }
        }
        speech.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit
            override fun onDone(utteranceId: String?) = Unit
            @Deprecated("Platform callback")
            override fun onError(utteranceId: String?) { handler.post { if (alive) failed = true } }
        })
        engine = speech
        onDispose { alive = false; speech.stop(); speech.shutdown() }
    }
    val message = if (active) {
        if (english) "Audio recording is active." else "L’enregistrement audio est en cours."
    } else {
        if (english) "Audio recording has been requested." else "Un enregistrement audio a été demandé."
    }
    LaunchedEffect(engine, ready, message) {
        val speech = engine
        if (speech != null && ready) {
            failed = speech.setLanguage(if (english) Locale.ENGLISH else Locale.FRENCH) < 0 ||
                speech.speak(message, TextToSpeech.QUEUE_FLUSH, null, "widemeet-recording") == TextToSpeech.ERROR
        }
    }
    if (failed) Text(
        if (english) "Voice announcement unavailable. Read the recording notice on screen."
        else "Annonce vocale indisponible. Lisez l’information d’enregistrement à l’écran.",
        color = MaterialTheme.colorScheme.error
    )
}
@Composable fun RoomPanel(english:Boolean,gateway:RoomGateway,session:Session,workspace:Workspace,initialCreate:Boolean=false,center:String="agenda"){
 fun tr(fr:String,en:String)=if(english)en else fr
 val hostRole=workspace.role in setOf("owner","promoteur","manager")
 val scope=rememberCoroutineScope()
 val window=(LocalContext.current as? Activity)?.window
 DisposableEffect(window){val wasSecure=(window?.attributes?.flags?.and(WindowManager.LayoutParams.FLAG_SECURE)?:0)!=0;window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE);onDispose{if(!wasSecure)window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)}}
 var list by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var search by remember{mutableStateOf("")};var filter by remember{mutableStateOf("all")}
 val visible=list.filter{r->(center!="rooms"||r.optString("status") in setOf("open","paused"))&&(filter=="all"||r.optString("status")==filter)&&r.optString("title").contains(search.trim(),ignoreCase=true)}
 var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var passes by remember{mutableStateOf<List<JSONObject>>(emptyList())};var passId by remember{mutableStateOf("")}
 var room by remember{mutableStateOf<JSONObject?>(null)}
 var mode by remember{mutableStateOf(if(initialCreate&&hostRole)"create" else "list")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var title by remember{mutableStateOf("")};var description by remember{mutableStateOf("")};var date by remember{mutableStateOf("")};var duration by remember{mutableStateOf("30")}
 var invited by remember{mutableStateOf<Set<String>>(emptySet())};var chat by remember{mutableStateOf("")};var poll by remember{mutableStateOf("")}
 var editing by remember{mutableStateOf(false)};var recipient by remember{mutableStateOf("")};var surveyAnonymous by remember{mutableStateOf(true)};var surveyEditable by remember{mutableStateOf(false)};var cancelConfirm by remember{mutableStateOf(false)};var excludeTarget by remember{mutableStateOf<String?>(null)}
 var agendaTitle by remember{mutableStateOf("")};var agendaMinutes by remember{mutableStateOf("5")};var agendaOwner by remember{mutableStateOf("")}
 var recurrence by remember{mutableStateOf("none")};var occurrences by remember{mutableStateOf("2")};var interval by remember{mutableStateOf("1")};var seriesPending by remember{mutableStateOf<JSONObject?>(null)};var creationPending by remember{mutableStateOf<JSONObject?>(null)};var seriesCancelConfirm by remember{mutableStateOf(false)}
 var pollSeconds by remember{mutableStateOf("")};var surveySeconds by remember{mutableStateOf("")}
 var extension by remember{mutableStateOf("15")};var surveyQuestion by remember{mutableStateOf("")};var surveyOptions by remember{mutableStateOf("")};var surveyKind by remember{mutableStateOf("single")};var surveyVisibility by remember{mutableStateOf("closed")};var surveyAudience by remember{mutableStateOf<Set<String>>(emptySet())};var surveyQuorum by remember{mutableStateOf("50")};var surveyThreshold by remember{mutableStateOf("50")};var surveySelections by remember{mutableStateOf<Map<String,Set<Int>>>(emptyMap())}
 suspend fun refresh(){busy=true;error=false;try{if(workspace.kind=="individual"){val all=rows(gateway.request("pass-list",JSONObject(),session) as JSONArray);passes=all.filter{it.isNull("room_id")};if(passes.none{it.optString("id")==passId})passId=passes.firstOrNull()?.optString("id")?:"";if(all.isEmpty()&&!BuildConfig.WIDEMEET_EXTERNAL_ENABLED){list=emptyList();contacts=emptyList();return}};list=rows(gateway.request("list",JSONObject(),session) as JSONArray);if(hostRole)try{contacts=rows(gateway.request("contacts",JSONObject(),session) as JSONArray)}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){contacts=emptyList()}}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;list=emptyList();contacts=emptyList()}finally{busy=false}}
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
 fun execute(action:String,body:JSONObject){if(busy)return;busy=true;error=false;scope.launch{try{val next=gateway.request(action,body,session) as JSONObject;require(next.has("id")&&next.has("revision"));room=next;mode="room";if(action=="create")creationPending=null;chat="";poll="";editing=false}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;if(action=="command"){room=null;mode="list"}}finally{busy=false}}}
 fun seriesAction(action:String,body:JSONObject){if(busy)return;busy=true;error=false;scope.launch{try{gateway.request(action,body,session);seriesPending=null;room=null;mode="list";refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 suspend fun openInvited(id:String):Boolean{if(busy)return false;busy=true;error=false;return try{val next=gateway.request("read",JSONObject().put("room_id",id),session) as JSONObject;require(next.optString("id")==id&&next.has("revision"));room=next;mode="room";chat="";poll="";editing=false;true}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true;false}finally{busy=false}}
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
 if(mode=="create"&&hostRole&&creationPending!=null){
 Text(tr("La création précédente n’a pas été confirmée. Réessayez la même demande.","The previous creation was not confirmed. Retry the same request."));Button(enabled=!busy,onClick={creationPending?.let{execute("create",it)}}){Text(tr("Réessayer la même création","Retry same creation"))};TextButton(enabled=!busy,onClick={creationPending=null;mode="list";scope.launch{refresh()}}){Text(tr("Vérifier mon agenda","Check my calendar"))}
 }else if(mode=="create"&&hostRole){
 OutlinedTextField(title,{title=it.take(120)},label={Text(tr("Titre","Title"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(description,{description=it.take(2000)},label={Text(tr("Description","Description"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(date,{date=it.take(16)},label={Text(tr("Date (AAAA-MM-JJTHH:mm, facultatif)","Date (YYYY-MM-DDTHH:mm, optional)"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(duration,{duration=it.take(3)},label={Text(tr("Durée en minutes","Duration in minutes"))},modifier=Modifier.fillMaxWidth())
 if(workspace.kind=="individual"){Text(tr("Pass payé disponible","Available paid pass"));passes.forEach{p->Row{RadioButton(passId==p.getString("id"),{passId=p.getString("id")},enabled=!busy);Text(p.getInt("capacity").toString()+" "+tr("participants","participants"),Modifier.padding(top=12.dp))}};Text(tr("Le pass sera réservé à cette seule réunion pendant 24 heures maximum.","The pass will be bound to this meeting only, for up to 24 hours."))}
 if(workspace.kind=="enterprise"&&BuildConfig.WIDEMEET_SERIES_ENABLED){Text(tr("Récurrence (heure UTC)","Recurrence (UTC time)"));listOf("none" to tr("Une seule réunion","Single meeting"),"daily" to tr("Quotidienne","Daily"),"weekly" to tr("Hebdomadaire","Weekly"),"monthly" to tr("Mensuelle","Monthly")).forEach{(id,label)->Row{RadioButton(recurrence==id,{recurrence=id},enabled=!busy&&seriesPending==null);Text(label,Modifier.padding(top=12.dp))}};if(recurrence!="none"){OutlinedTextField(occurrences,{occurrences=it.take(2)},enabled=!busy&&seriesPending==null,label={Text(tr("Occurrences (2–12)","Occurrences (2–12)"))});OutlinedTextField(interval,{interval=it.take(2)},enabled=!busy&&seriesPending==null,label={Text(tr("Intervalle (1–12)","Interval (1–12)"))})}}
 Text(tr("Invités","Invitees"))
 contacts.forEach{c->val id=c.optString("member_id");Row{Checkbox(id in invited,{checked->invited=if(checked)invited+id else invited-id});Text(c.optString("display_name"),modifier=Modifier.padding(top=12.dp))}}
 Button(enabled=!busy&&title.isNotBlank()&&(duration.toIntOrNull()?:0) in 5..480&&(workspace.kind!="individual"||passId.isNotEmpty()),onClick={val whenMs=runCatching{if(date.isBlank())System.currentTimeMillis() else LocalDateTime.parse(date).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()}.getOrNull();if(whenMs==null){error=true}else if(recurrence!="none"){val n=occurrences.toIntOrNull()?:0;val every=interval.toIntOrNull()?:0;if(date.isBlank()||n !in 2..12||every !in 1..12){error=true}else{val payload=seriesPending?:JSONObject().put("series_id",UUID.randomUUID().toString()).put("room_ids",JSONArray(List(n){UUID.randomUUID().toString()})).put("title",title).put("description",description).put("scheduled_ms",whenMs).put("duration_minutes",duration.toInt()).put("invitees",JSONArray(invited.toList())).put("recurrence",recurrence).put("interval",every).also{seriesPending=it};seriesAction("series-create",payload)}}else{val data=creationPending?:JSONObject().put("room_id",UUID.randomUUID().toString()).put("title",title).put("description",description).put("scheduled_ms",whenMs).put("duration_minutes",duration.toInt()).put("invitees",JSONArray(invited.toList())).apply{if(workspace.kind=="individual")put("pass_id",passId)}.also{creationPending=it};execute("create",data)}}){Text(tr("Créer","Create"))}
 }else if(mode=="list"){
 if(center!="agenda"){
  val copy=when(center){
   "chat"->tr("Choisissez une réunion pour consulter les messages autorisés et échanger dans la salle ouverte.","Choose a meeting to view authorized messages and chat in the open room.")
   "rooms"->tr("Salles ouvertes ou en pause accessibles. Ouvrir une autre salle quitte l’écran courant.","Accessible open or paused rooms. Opening another room leaves the current screen.")
   "statistics"->tr("Indicateurs des réunions visibles (200 maximum), pas une consolidation de toute l’entreprise.","Visible meeting indicators (maximum 200), not company-wide totals.")
   else->tr("Choisissez une réunion pour consulter les votes ou y participer selon vos droits.","Choose a meeting to view polls or participate according to your permissions.")
  }
  Text(copy)
  OutlinedTextField(search,{search=it},label={Text(tr("Rechercher une réunion","Search meetings"))},modifier=Modifier.fillMaxWidth())
  if(center!="rooms"){Text(tr("État","Status"));for(s in listOf("all","scheduled","open","paused","ended"))Row{RadioButton(selected=filter==s,onClick={filter=s});Text(if(s=="all")tr("Tous","All")else stateLabel(s),Modifier.padding(top=12.dp))}}
  if(center=="statistics"&&!busy&&!error)for(s in listOf("scheduled","open","paused","ended"))Text(stateLabel(s)+": "+list.count{it.optString("status")==s})
 }
 if(center=="agenda"&&BuildConfig.WIDEMEET_EXTERNAL_ENABLED)ExternalInvite(english,gateway,session,parentBusy=busy,onJoined={id->openInvited(id)})
 visible.forEach{r->TextButton(enabled=!busy,onClick={execute("read",JSONObject().put("room_id",r.optString("id")))}){Text(r.optString("title",tr("Réunion","Meeting"))+" — "+stateLabel(r.optString("status")))}}
 if(!busy&&!error&&visible.isEmpty())Text(tr("Aucune réunion dans cet espace.","No meetings in this workspace."))
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
 if(r.optString("confidentiality")=="confidential")Text(tr("Réunion confidentielle : partage d’écran désactivé.","Confidential meeting: screen sharing disabled."))
 val agenda=rows(r.optJSONArray("agenda"));if(agenda.isNotEmpty()||isHost){Text(tr("Ordre du jour","Agenda"),style=MaterialTheme.typography.titleMedium);for(item in agenda){Text(item.optString("title")+" · "+item.optInt("minutes")+" min"+(if(item.isNull("owner"))"" else " · "+displayName(item.optString("owner"))));if(isHost&&status=="open")TextButton(enabled=!busy,onClick={command("agenda_status",if(item.optString("status")=="active")"done" else "active",item.getString("id"))}){Text(if(item.optString("status")=="active")tr("Terminer le sujet","Finish topic")else tr("Démarrer le sujet","Start topic"))};if(isHost&&status in setOf("scheduled","open"))TextButton(enabled=!busy,onClick={command("set_agenda",JSONArray(agenda.filter{it.getString("id")!=item.getString("id")}))}){Text(tr("Retirer","Remove"))}}
 if(isHost&&status in setOf("scheduled","open")){OutlinedTextField(agendaTitle,{agendaTitle=it.take(150)},label={Text(tr("Sujet","Topic"))});OutlinedTextField(agendaMinutes,{agendaMinutes=it.take(3)},label={Text(tr("Minutes","Minutes"))});Text(tr("Responsable","Owner"));Row{RadioButton(agendaOwner.isEmpty(),{agendaOwner=""});Text(tr("Non attribué","Unassigned"))};rows(r.optJSONArray("participants")).forEach{p->val id=p.getString("memberId");Row{RadioButton(agendaOwner==id,{agendaOwner=id});Text(displayName(id))}};Button(enabled=!busy&&agendaTitle.isNotBlank()&&(agendaMinutes.toIntOrNull()?:0) in 1..480,onClick={command("set_agenda",JSONArray(agenda+JSONObject().put("id",UUID.randomUUID().toString()).put("title",agendaTitle).put("minutes",agendaMinutes.toInt()).put("owner",agendaOwner.ifEmpty{null}?:JSONObject.NULL)));agendaTitle=""}){Text(tr("Ajouter un sujet","Add topic"))}}}
 if(isHost)TextButton(enabled=!busy,onClick={title=r.optString("title");description=r.optString("description");duration=r.optInt("durationMinutes",30).toString();invited=rows(r.optJSONArray("participants")).map{it.getString("memberId")}.filter{it!=session.memberId}.toSet();date="";recurrence="none";seriesPending=null;room=null;mode="create"}){Text(tr("Dupliquer la réunion","Duplicate meeting"))}
 if(!isHost&&may("admission")&&status=="open")TextButton(enabled=!busy,onClick={command("lock_admission",!r.optBoolean("admissionLocked"))}){Text(if(r.optBoolean("admissionLocked"))tr("Déverrouiller les admissions","Unlock admissions")else tr("Verrouiller les admissions","Lock admissions"))}
 if(isHost&&status in setOf("scheduled","open")){
 Text(tr("Délégation de modération","Moderator delegation"));rows(r.optJSONArray("participants")).filter{it.optString("memberId")!=session.memberId}.forEach{p->val id=p.optString("memberId");val a=p.optJSONArray("moderatorPermissions");val perms=if(a==null)emptySet()else(0 until a.length()).map{a.getString(it)}.toSet();Text(displayName(id));modLabels.forEach{(k,l)->Row{Checkbox(k in perms,{checked->command("set_moderator",JSONArray((if(checked)perms+k else perms-k).toList()),id)},enabled=!busy);Text(l,Modifier.padding(top=12.dp))}}}

 if(BuildConfig.WIDEMEET_EXTERNAL_ENABLED&&r.optBoolean("lobbyRequired"))key(r.getString("id")){ExternalInvite(english,gateway,session,r.getString("id"))}
 Text(tr("Inviter un membre","Invite a member"))
 contacts.filter{c->rows(r.optJSONArray("participants")).none{it.optString("memberId")==c.optString("member_id")}}.forEach{c->TextButton(enabled=!busy,onClick={command("invite_member",null,c.optString("member_id"))}){Text(c.optString("display_name"))}}
 if(status=="open")TextButton(enabled=!busy,onClick={command("lock_admission",!r.optBoolean("admissionLocked"))}){Text(if(r.optBoolean("admissionLocked"))tr("Déverrouiller les admissions","Unlock admissions")else tr("Verrouiller les admissions","Lock admissions"))}
 }
 if(isHost&&status in setOf("open","paused")&&remaining in 1L..300L){Text(tr("Temps restant","Time remaining")+" "+(remaining/60)+":"+ (remaining%60).toString().padStart(2,'0'));Row{listOf(15,30,60).forEach{m->TextButton(enabled=!busy,onClick={command("extend",m)}){Text("+$m min")}}}}
 Text(r.optString("title"),style=MaterialTheme.typography.titleLarge);Text(r.optString("description"));Text(if(r.optBoolean("cancelled"))tr("Annulée","Cancelled")else stateLabel(status))
 TextButton(enabled=!busy,onClick={execute("read",JSONObject().put("room_id",r.getString("id")))}){Text(tr("Actualiser","Refresh"))}
 if(!isHost&&status in setOf("scheduled","open")){listOf("accepted" to tr("Accepter","Accept"),"maybe" to tr("Peut-être","Maybe"),"declined" to tr("Décliner","Decline")).forEach{(v,l)->TextButton(enabled=!busy,onClick={command("respond",v)}){Text(l)}}}
 if(isHost&&status=="scheduled"){
 Text(tr("Confidentialité","Confidentiality"));listOf("standard" to tr("Standard","Standard"),"confidential" to tr("Confidentiel — partage écran désactivé","Confidential — screen sharing disabled")).forEach{(k,l)->Row{RadioButton(r.optString("confidentiality","standard")==k,{command("confidentiality",k)},enabled=!busy);Text(l,Modifier.padding(top=12.dp))}};Text(tr("Mode hautement confidentiel non qualifié.","Highly confidential mode not qualified."))
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
 Text(tr("Consentement audio","Audio consent"));Text(tr("Autorisez-vous la capture et la conservation de votre voix pour cette réunion ? Vous pouvez retirer votre accord à tout moment.","Do you authorize recording and retention of your voice for this meeting? You may withdraw consent at any time."));Text(if(r.optBoolean("consent"))tr("Votre accord est enregistré.","Your consent is recorded.")else tr("Votre accord n’est pas donné.","Your consent has not been given."))
 TextButton(enabled=!busy,onClick={command("consent",true)}){Text(tr("Donner mon accord","Give consent"))}
 TextButton(enabled=!busy,onClick={command("consent",false)}){Text(tr("Retirer mon accord","Withdraw consent"))}
 val capturePhase=r.optJSONObject("recordingStatus")?.optString("phase")
 if(capturePhase=="active" || (r.optString("recording")=="requested" && capturePhase !in setOf("stopping","complete","discarded"))){
     key(r.getString("id")){RecordingAnnouncement(capturePhase=="active",english)}
 }
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
 }
 if(may("poll")){
 OutlinedTextField(poll,{poll=it.take(2000)},label={Text(tr("Choix du vote séparés par |","Poll choices separated by |"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(pollSeconds,{pollSeconds=it.take(4)},label={Text(tr("Durée du vote (secondes, facultative)","Poll duration (seconds, optional)"))})
 Button(enabled=!busy&&poll.contains("|")&&(pollSeconds.isBlank()||(pollSeconds.toIntOrNull()?:0) in 15..3600),onClick={command("poll",JSONObject().put("options",JSONArray(poll.split("|").map{it.trim()}.filter{it.isNotEmpty()})).put("durationSeconds",pollSeconds.toIntOrNull()?:JSONObject.NULL),UUID.randomUUID().toString())}){Text(tr("Créer le vote","Create poll"))}
 }
 if(may("poll")){
 Text(tr("Enquête Premium","Premium survey"))
 Row{Checkbox(surveyAnonymous,{surveyAnonymous=it});Text(tr("Anonyme","Anonymous"))}
 Row{Checkbox(surveyEditable,{surveyEditable=it});Text(tr("Modifiable avant clôture","Editable until closing"))}
 OutlinedTextField(surveyQuestion,{surveyQuestion=it.take(200)},label={Text(tr("Question","Question"))},modifier=Modifier.fillMaxWidth())
 for((k,label) in listOf("single" to tr("Choix unique","Single choice"),"multiple" to tr("Choix multiples","Multiple choice"),"rating" to tr("Note sur 5","Rating out of 5"),"rating10" to tr("Note sur 10","Rating out of 10")))Row{RadioButton(surveyKind==k,{surveyKind=k});Text(label)}
 if(surveyKind in setOf("single","multiple"))OutlinedTextField(surveyOptions,{surveyOptions=it.take(2000)},label={Text(tr("Options séparées par |","Options separated by |"))},modifier=Modifier.fillMaxWidth())
 for((k,label) in listOf("closed" to tr("Après clôture","After closing"),"live" to tr("En direct","Live")))Row{RadioButton(surveyVisibility==k,{surveyVisibility=k});Text(label)}
 Text(tr("Électeurs ciblés (aucune sélection = tous les admis)","Target voters (no selection = all admitted)"))
 for(p in rows(r.optJSONArray("participants")).filter{it.optString("response")=="accepted"&&(!r.optBoolean("lobbyRequired")||it.optString("memberId")==r.optString("hostId")||it.optString("lobbyStatus")=="admitted")}){val id=p.optString("memberId");Row{Checkbox(id in surveyAudience,{checked->surveyAudience=if(checked)surveyAudience+id else surveyAudience-id});Text(displayName(id))}}
 OutlinedTextField(surveyQuorum,{surveyQuorum=it.take(3)},label={Text(tr("Quorum (%)","Quorum (%)"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(surveySeconds,{surveySeconds=it.take(4)},label={Text(tr("Durée de l’enquête (secondes, facultative)","Survey duration (seconds, optional)"))})
 OutlinedTextField(surveyThreshold,{surveyThreshold=it.take(3)},label={Text(tr("Seuil (%)","Threshold (%)"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&surveyQuestion.isNotBlank()&&(surveyKind.startsWith("rating")||surveyOptions.contains("|"))&&(surveySeconds.isBlank()||(surveySeconds.toIntOrNull()?:0) in 15..3600)&&(surveyQuorum.toIntOrNull()?:-1) in 0..100&&(surveyThreshold.toIntOrNull()?:0) in 1..100,onClick={command("survey",JSONObject().put("question",surveyQuestion).put("kind",if(surveyKind.startsWith("rating"))"rating" else surveyKind).put("options",JSONArray(if(surveyKind.startsWith("rating"))(1..(if(surveyKind=="rating10")10 else 5)).map{it.toString()} else surveyOptions.split("|").map{it.trim()}.filter{it.isNotEmpty()})).apply{if(surveyAudience.isNotEmpty())put("eligibleIds",JSONArray(surveyAudience.toList()))}.put("anonymous",surveyAnonymous).put("editable",surveyEditable).put("visibility",surveyVisibility).put("quorum",surveyQuorum.toInt()).put("threshold",surveyThreshold.toInt()).put("durationSeconds",surveySeconds.toIntOrNull()?:JSONObject.NULL),UUID.randomUUID().toString())}){Text(tr("Créer l’enquête","Create survey"))}
 }
 rows(r.optJSONArray("polls")).forEach{p->val opts=p.optJSONArray("options")?:JSONArray();val counts=p.optJSONArray("counts");val pid=p.optString("id");val kind=p.optString("kind","simple");val canVote=!busy&&p.optBoolean("canVote",true)&&p.optBoolean("open")&&(!p.optBoolean("voted")||p.optBoolean("editable"));val initial=p.optJSONArray("ownSelection")?.let{a->(0 until a.length()).map{a.getInt(it)}.toSet()}?:emptySet<Int>();Text(if(p.isNull("question"))tr("Vote","Poll") else p.optString("question"));if(counts==null)Text(tr("Résultats après clôture","Results after closing"));for(i in 0 until opts.length()){
 val label=opts.optString(i)+(counts?.let{" ("+it.optInt(i)+")"}?:"")
 if(kind=="multiple"){Row{Checkbox(i in (surveySelections[pid]?:initial),{checked->val old=surveySelections[pid]?:initial;surveySelections=surveySelections+(pid to if(checked)old+i else old-i)},enabled=canVote);Text(label)}}else TextButton(enabled=canVote,onClick={command(if(kind=="simple")"vote" else "survey_vote",if(kind=="simple")i else JSONArray(listOf(i)),pid)}){Text(label)}
 };if(kind=="multiple")TextButton(enabled=canVote&&!(surveySelections[pid]?:initial).isEmpty(),onClick={command("survey_vote",JSONArray((surveySelections[pid]?:initial).toList()),pid)}){Text(tr("Valider mes choix","Submit choices"))};rows(p.optJSONArray("nominativeResponses")).forEach{v->val sel=v.optJSONArray("selection")?:JSONArray();Text(displayName(v.optString("memberId"))+" : "+(0 until sel.length()).joinToString(", "){opts.optString(sel.getInt(it))})};if(!p.optBoolean("canVote",true))Text(tr("Non éligible à ce vote","Not eligible for this poll"));if(!p.isNull("responses"))Text(tr("Répondants","Respondents")+" : "+p.optInt("responses")+(if(!p.isNull("eligible"))" / "+p.optInt("eligible") else "")+(if(!p.isNull("nonresponses"))" · "+tr("Non-répondants","Nonrespondents")+": "+p.optInt("nonresponses") else ""));p.optJSONArray("optionShares")?.let{shares->for(i in 0 until shares.length()){val pct=shares.optDouble(i,0.0);Text(opts.optString(i)+" : "+String.format(java.util.Locale.ROOT,"%.1f",pct)+" %");LinearProgressIndicator(progress={ (pct.toFloat()/100f).coerceIn(0f,1f) },modifier=Modifier.fillMaxWidth())}};if(!p.isNull("quorumMet"))Text(tr("Quorum","Quorum")+": "+if(p.optBoolean("quorumMet"))tr("atteint","met") else tr("non atteint","not met"));if(may("poll")&&p.optBoolean("open"))TextButton(enabled=!busy,onClick={command("close_poll",null,pid)}){Text(tr("Clôturer","Close"))}}
 if(may("microphone")||may("screen")||may("exclude")||may("chat"))rows(r.optJSONArray("participants")).filter{it.optString("memberId")!=session.memberId&&it.optString("memberId")!=r.optString("hostId")}.forEach{p->val id=p.optString("memberId");Text(displayName(id));if(may("microphone"))TextButton(enabled=!busy,onClick={command(if(p.optBoolean("mic"))"mute" else "allow_mic",null,id)}){Text(if(p.optBoolean("mic"))tr("Couper le micro","Mute") else tr("Autoriser le micro","Allow microphone"))};if(may("screen"))TextButton(enabled=!busy,onClick={command("screen",!p.optBoolean("screen"),id)}){Text(if(p.optBoolean("screen"))tr("Retirer partage","Revoke share")else tr("Autoriser partage","Allow share"))};if(may("chat"))TextButton(enabled=!busy,onClick={command("chat_permission",!p.optBoolean("chat"),id)}){Text(if(p.optBoolean("chat"))tr("Interdire le chat","Disable chat")else tr("Autoriser le chat","Enable chat"))};if(may("exclude"))TextButton(enabled=!busy,onClick={excludeTarget=id}){Text(tr("Exclure","Exclude"))}}
 }
 }}
 }}
}
