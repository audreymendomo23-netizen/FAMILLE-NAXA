package cm.naxa.naxaservices

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

private fun JSONArray.meetingRows() = (0 until length()).mapNotNull { optJSONObject(it) }
private fun JSONObject.optional(key:String):String?=if(isNull(key))null else optString(key).takeIf{it.isNotBlank()}
private val meetingDateFormat=DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
private fun meetingDate(s:String)=runCatching{OffsetDateTime.parse(s).atZoneSameInstant(ZoneOffset.ofHours(1)).format(meetingDateFormat)}.getOrDefault("—")
private fun meetingInstant(s:String)=LocalDateTime.parse(s,meetingDateFormat).toInstant(ZoneOffset.ofHours(1)).toString()
@Composable
internal fun InternalMeetingsCard(session:AuthSession,siteId:String){
 if(!BuildConfig.MEETINGS_ENABLED||!rosterAvailable(session.account.businessMode)||siteId.isBlank()||session.requirePasswordChange)return
 key(session.account.organizationId,session.account.memberId,session.deviceId,siteId){
  val latest by rememberUpdatedState(session)
  val scope=rememberCoroutineScope()
  fun tr(fr:String,en:String,ff:String)=when(session.account.defaultLocale){"en"->en;"ff-CM"->ff;else->fr}
  var meetings by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var invites by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var targets by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var selected by remember{mutableStateOf(setOf<String>())}
  var post by remember{mutableStateOf("")}
  var title by remember{mutableStateOf("")};var whenAt by remember{mutableStateOf("")};var agenda by remember{mutableStateOf("")};var duration by remember{mutableStateOf("30")}
  var edited by remember{mutableStateOf<JSONObject?>(null)}
  var frequency by remember{mutableStateOf("once")};var count by remember{mutableStateOf("3")}
  var pendingCreation by remember{mutableStateOf<Pair<String,JSONObject>?>(null)}
  var seriesToCancel by remember{mutableStateOf<String?>(null)}
  var busy by remember{mutableStateOf(false)};var loaded by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var reload by remember{mutableIntStateOf(0)}
  val languages=linkedMapOf("original" to "Original","fr" to "Français","en" to "English","ff-CM" to "Fulfulde","es" to "Español","it" to "Italiano","zh-CN" to "中文")
  fun status(s:String)=when(s){
   "scheduled"->tr("Programmée","Scheduled","Feewnaama");"open"->tr("Ouverte","Open","Udditaama");"closed"->tr("Terminée","Ended","Timmi");"cancelled"->tr("Annulée","Cancelled","Haaytaama");"accepted"->tr("Acceptée","Accepted","Jaɓaama");"declined"->tr("Refusée","Declined","Salaama");"tentative"->tr("Provisoire","Tentative","Haa jooni");else->tr("En attente","Pending","E fadade")
  }
  suspend fun refresh(){
   try{
    val current=latest;val org=UUID.fromString(current.account.organizationId);val site=UUID.fromString(siteId)
    val filter="org_id=eq."+org
    val m=JSONArray(StaffRosterApi.call(current,"ns_internal_meetings?select=*&"+filter+"&site_id=eq."+site+"&order=scheduled_at.desc&limit=100")).meetingRows()
    val i=JSONArray(StaffRosterApi.call(current,"ns_internal_meeting_invitees?select=*&"+filter+"&limit=2000")).meetingRows()
    val t=JSONArray(StaffRosterApi.call(current,"rpc/ns_roster_targets",JSONObject().put("p_org",org.toString()).put("p_site",site.toString()))).meetingRows()
    meetings=m;invites=i;targets=t;loaded=true;error=false
   }catch(c:CancellationException){throw c}catch(_:Exception){loaded=false;error=true;meetings=emptyList();invites=emptyList();targets=emptyList()}
  }
  LaunchedEffect(reload,session.accessToken){while(true){if(!busy)refresh();delay(20000)}}
  fun perform(action:suspend()->Unit){
   if(busy||!loaded)return;busy=true;error=false
   scope.launch{try{action();reload++}catch(c:CancellationException){throw c}catch(_:Exception){error=true}finally{busy=false}}
  }
  fun clear(){edited=null;title="";whenAt="";agenda="";duration="30";selected=emptySet();frequency="once";count="3";pendingCreation=null}
  fun transition(m:JSONObject,next:String)=perform{StaffRosterApi.call(latest,"rpc/ns_transition_internal_meeting",JSONObject().put("p_id",m.getString("id")).put("p_revision",m.getInt("revision")).put("p_next",next))}
  seriesToCancel?.let{sid->
   AlertDialog(onDismissRequest={seriesToCancel=null},title={Text(tr("Annuler la série","Cancel series","Haaytu dentuuji"))},text={Text(tr("Annuler toutes les réunions encore programmées de cette série ?","Cancel all still-scheduled meetings in this series?","Haaytu dentuuji feewnaaɗi ɗii fof?"))},confirmButton={TextButton(onClick={seriesToCancel=null;perform{
    val expected=JSONArray();meetings.filter{it.optional("series_id")==sid&&it.optString("status")=="scheduled"}.forEach{expected.put(JSONObject().put("id",it.getString("id")).put("revision",it.getInt("revision")))}
    StaffRosterApi.call(latest,"rpc/ns_cancel_meeting_series",JSONObject().put("p_id",sid).put("p_expected",expected))
   }}){Text(tr("Confirmer","Confirm","Tabbitin"))}},dismissButton={TextButton(onClick={seriesToCancel=null}){Text(tr("Abandonner","Discard","Accu"))}})
  }
  Card(Modifier.fillMaxWidth()){
   Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
    Text(tr("Mes réunions","My meetings","Dentuuji am"),style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
    Text(tr("Heure de Douala. Appel audio/vidéo non disponible.","Douala time. Audio/video calling unavailable.","Sahaa Duwaala. Noddaango daande e natal heɓotaako."))
    OutlinedButton(onClick={reload++},enabled=!busy){Text(tr("Actualiser","Refresh","Hesɗitin"))}
    if(error)Text(tr("Réunion ou modification indisponible.","Meeting or change unavailable.","Dental walla baylugol heɓotaako."),color=MaterialTheme.colorScheme.error)
    if(loaded&&(targets.isNotEmpty()||edited!=null)){
     Text(if(edited==null)tr("Programmer","Schedule","Feewnu") else tr("Modifier","Edit","Waylu"))
     if(edited==null){
      targets.distinctBy{it.optional("workstation_id")}.forEach{t->val p=t.optional("workstation_id")?:"";OutlinedButton(onClick={post=p;selected=emptySet()},enabled=!busy){Text((if(post==p)"✓ " else "")+(t.optional("workstation_name")?:tr("Site entier","Whole site","Nokkuure fof")))}}
      targets.filter{(it.optional("workstation_id")?:"")==post}.forEach{t->val id=t.getString("member_id");Row{Checkbox(checked=id in selected,onCheckedChange={v->selected=if(v)selected+id else selected-id},enabled=!busy);Text(t.getString("display_name"))}}
     }
     OutlinedTextField(title,{title=it},label={Text(tr("Intitulé","Title","Innde"))},singleLine=true,modifier=Modifier.fillMaxWidth())
     OutlinedTextField(whenAt,{whenAt=it},label={Text(tr("AAAA-MM-JJ HH:mm (vide : maintenant)","YYYY-MM-DD HH:mm (blank: now)","Ñalnde e sahaa"))},singleLine=true,modifier=Modifier.fillMaxWidth())
     OutlinedTextField(agenda,{agenda=it},label={Text(tr("Ordre du jour","Agenda","Feere dental"))},modifier=Modifier.fillMaxWidth());OutlinedTextField(duration,{duration=it},label={Text(tr("Durée (min)","Duration (min)","Sahaa (min)"))},modifier=Modifier.fillMaxWidth())
     if(edited==null){
      Text(tr("Répétition","Repeat","Yaltinde"))
      listOf("once" to tr("Une seule fois","Once","Gooto"),"daily" to tr("Chaque jour","Daily","Kala ñalnde"),"weekly" to tr("Chaque semaine","Weekly","Kala yontere")).forEach{(code,label)->OutlinedButton(onClick={frequency=code},enabled=!busy){Text((if(frequency==code)"✓ " else "")+label)}}
      if(frequency!="once")OutlinedTextField(count,{count=it},label={Text(tr("Nombre de réunions","Number of meetings","Limoore dentuuji"))},singleLine=true,modifier=Modifier.fillMaxWidth())
     }
     Button(onClick={perform{
      val m=edited
      if(m==null){
       val fields=JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId).put("p_post",post.takeIf{it.isNotBlank()}?:JSONObject.NULL).put("p_title",title).put("p_at",whenAt).put("p_members",JSONArray(selected.sorted())).put("p_agenda",agenda).put("p_duration",duration.toInt())
       if(frequency!="once")fields.put("p_frequency",frequency).put("p_count",count.toInt())
       val signature=fields.toString()
       val payload=pendingCreation?.takeIf{it.first==signature}?.second?:fields.put("p_id",UUID.randomUUID().toString()).put("p_at",if(whenAt.isBlank())Instant.now().toString() else meetingInstant(whenAt)).also{pendingCreation=signature to it}
       StaffRosterApi.call(latest,if(frequency=="once")"rpc/ns_schedule_internal_meeting_details" else "rpc/ns_schedule_meeting_series",payload)
      }
      else StaffRosterApi.call(latest,"rpc/ns_revise_internal_meeting",JSONObject().put("p_id",m.getString("id")).put("p_revision",m.getInt("revision")).put("p_title",title).put("p_at",meetingInstant(whenAt)).put("p_agenda",agenda).put("p_duration",duration.toInt()))
      clear()
     }},enabled=!busy&&title.isNotBlank()&&agenda.length<=2000&&duration.toIntOrNull()?.let{it in 5..480}==true&&(edited!=null||selected.isNotEmpty()&&(frequency=="once"||count.toIntOrNull()?.let{it in 2..12}==true))){Text(tr("Enregistrer et inviter","Save and invite","Danndu e noddu"))}
     if(edited!=null)TextButton(onClick={clear()}){Text(tr("Abandonner","Discard","Accu"))}
    }
    if(loaded&&meetings.isEmpty())Text(tr("Aucune réunion.","No meetings.","Alaa dental."))
    meetings.forEach{m->
     HorizontalDivider()
     val id=m.getString("id");val state=m.getString("status");val host=m.getString("host_member_id")==session.account.memberId;val own=invites.firstOrNull{it.getString("meeting_id")==id&&it.getString("member_id")==session.account.memberId}
     Text(m.getString("title"),fontWeight=FontWeight.Bold);Text(meetingDate(m.getString("scheduled_at"))+" · "+m.optInt("duration_minutes",30)+" min · "+status(state));m.optional("agenda")?.let{Text(it)};if(m.optInt("series_occurrence",0)>0)Text(tr("Réunion récurrente","Recurring meeting","Dental yaltindetee")+" · "+m.optInt("series_occurrence"))
     if(host&&state=="scheduled"){
      OutlinedButton(onClick={edited=m;title=m.getString("title");whenAt=meetingDate(m.getString("scheduled_at"));agenda=m.optString("agenda");duration=m.optInt("duration_minutes",30).toString()},enabled=!busy){Text(tr("Modifier","Edit","Waylu"))}
      Button(onClick={transition(m,"open")},enabled=!busy){Text(tr("Ouvrir (sans appel)","Open (no call)","Uddit dental"))}
      TextButton(onClick={transition(m,"cancelled")},enabled=!busy){Text(tr("Annuler","Cancel","Haaytu"))}
      m.optional("series_id")?.let{sid->TextButton(onClick={seriesToCancel=sid},enabled=!busy){Text(tr("Annuler la série","Cancel series","Haaytu dentuuji"))}}
     }
     if(host&&state=="open")Button(onClick={transition(m,"closed")},enabled=!busy){Text(tr("Terminer","End","Timmin"))}
     if(host)invites.filter{it.getString("meeting_id")==id&&it.getString("member_id")!=session.account.memberId}.forEach{i->Text((targets.firstOrNull{it.getString("member_id")==i.getString("member_id")}?.getString("display_name")?:tr("Participant","Participant","Jeyaaɗo"))+" : "+status(i.optString("response")))}
     if(!host&&own!=null&&state=="scheduled"){
      Text(status(own.optString("response")))
      listOf("accepted","declined","tentative").forEach{r->OutlinedButton(onClick={perform{StaffRosterApi.call(latest,"rpc/ns_respond_meeting_invitation",JSONObject().put("p_id",id).put("p_revision",m.getInt("revision")).put("p_response",r))}},enabled=!busy){Text(status(r))}}
     }
     if(own!=null&&state=="open"&&own.optString("response")!="declined")MeetingCollaborationCard(session,id,host)
     if(own!=null&&state in listOf("scheduled","open")){
      Text(tr("Langue d’écoute souhaitée","Preferred listening language","Ɗemngal heɗagol"))
      languages.forEach{(k,v)->OutlinedButton(onClick={perform{StaffRosterApi.call(latest,"rpc/ns_set_meeting_listener",JSONObject().put("p_id",id).put("p_locale",k).put("p_consent",JSONObject.NULL))}},enabled=!busy){Text((if(own.optString("listening_locale")==k)"✓ " else "")+v)}}
      Text(tr("Consentement à un futur enregistrement audio","Consent to future audio recording","Jaɓgol nanndugol daande"))
      listOf(true,false).forEach{v->TextButton(onClick={perform{StaffRosterApi.call(latest,"rpc/ns_set_meeting_listener",JSONObject().put("p_id",id).put("p_locale",own.getString("listening_locale")).put("p_consent",v))}},enabled=!busy){Text((if(!own.isNull("recording_consent")&&own.optBoolean("recording_consent")==v)"✓ " else "")+if(v)tr("J’accepte","I consent","Mi jaɓii") else tr("Je refuse","I decline","Mi salii"))}}
     }
    }
   }
  }
 }
}
