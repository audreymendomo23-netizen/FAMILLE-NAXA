package cm.naxa.naxaservices

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

private fun JSONArray.collabRows()=(0 until length()).mapNotNull{optJSONObject(it)}
@Composable
internal fun MeetingCollaborationCard(session:AuthSession,meetingId:String,host:Boolean){
 key(session.account.organizationId,session.account.memberId,session.deviceId,meetingId){
  val latest by rememberUpdatedState(session)
  val scope=rememberCoroutineScope()
  fun tr(fr:String,en:String,ff:String)=when(session.account.defaultLocale){"en"->en;"ff-CM"->ff;else->fr}
  var people by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var chat by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var reactions by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var draft by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var ready by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var reload by remember{mutableIntStateOf(0)}
  var exclude by remember{mutableStateOf<JSONObject?>(null)}
  val emojis=linkedMapOf("like" to "👍","clap" to "👏","heart" to "❤️","laugh" to "😄","agree" to "✅","celebrate" to "🎉")
  suspend fun refresh(){
   try{
    val id=UUID.fromString(meetingId).toString();val current=latest
    val p=JSONArray(StaffRosterApi.call(current,"rpc/ns_meeting_participants",JSONObject().put("p_id",id))).collabRows()
    if(p.none{it.getString("member_id")==current.account.memberId}){ready=false;people=emptyList();chat=emptyList();reactions=emptyList();return}
    val c=JSONArray(StaffRosterApi.call(current,"ns_meeting_chat?select=id,member_id,message,created_at&meeting_id=eq."+id+"&order=created_at.desc,id.desc&limit=100")).collabRows()
    val r=JSONArray(StaffRosterApi.call(current,"ns_meeting_reactions?select=id,member_id,reaction&meeting_id=eq."+id+"&order=created_at.desc&limit=20")).collabRows()
    people=p;chat=c.reversed();reactions=r;ready=true;error=false
   }catch(c:CancellationException){throw c}catch(_:Exception){ready=false;error=true;people=emptyList();chat=emptyList();reactions=emptyList()}
  }
  LaunchedEffect(reload,session.accessToken){while(true){if(!busy)refresh();delay(3000)}}
  fun act(action:String,value:String?=null,target:String?=null){
   if(busy||!ready)return;busy=true
   scope.launch{
    try{
     val body=JSONObject().put("p_id",meetingId).put("p_event",UUID.randomUUID().toString()).put("p_action",action)
     if(target!=null)body.put("p_target",target)else body.put("p_value",value?:JSONObject.NULL)
     StaffRosterApi.call(latest,if(target!=null)"rpc/ns_moderate_meeting" else "rpc/ns_meeting_action",body)
     if(action=="chat"&&target==null)draft=""
     reload++
    }catch(c:CancellationException){throw c}catch(_:Exception){error=true}finally{busy=false}
   }
  }
  val own=people.firstOrNull{it.optString("member_id")==session.account.memberId}
  Text(tr("Échanges de réunion","Meeting discussion","Jeewte dental"),style=MaterialTheme.typography.titleMedium)
  Text(tr("Autorisations micro/écran sans appel actif.","Mic/screen permissions without active call.","Yamirooje daande e ekran tan."))
  if(error)Text(tr("Échanges indisponibles.","Discussion unavailable.","Jeewte heɓotaake."),color=MaterialTheme.colorScheme.error)
  if(ready&&own!=null){
   OutlinedButton(onClick={act(if(own.isNull("hand_raised_at"))"raise_hand" else "lower_hand")},enabled=!busy){Text(if(own.isNull("hand_raised_at"))tr("Lever la main","Raise hand","Ɓamtu junngo")else tr("Baisser la main","Lower hand","Lesɗin junngo"))}
   emojis.entries.chunked(3).forEach{group->Row{group.forEach{(k,v)->TextButton(onClick={act("reaction",k)},enabled=!busy){Text(v)}}}}
   Text(reactions.mapNotNull{emojis[it.optString("reaction")]}.joinToString(" "))
   Text(tr("Invités habilités","Authorized invitees","Noddaaɓe yamiraaɓe"))
   people.forEach{p->
    val id=p.getString("member_id");Text(p.getString("display_name")+if(!p.isNull("hand_raised_at"))" ✋"else "")
    if(host&&id!=session.account.memberId){
     val actions=listOf((if(p.optBoolean("mic_muted_by_host"))"allow_mic"else "mute") to (if(p.optBoolean("mic_muted_by_host"))tr("Autoriser micro","Allow mic","Yamir daande")else tr("Restreindre micro","Restrict mic","Haɗ daande")),
     (if(p.optBoolean("screen_allowed"))"deny_screen"else "allow_screen") to (if(p.optBoolean("screen_allowed"))tr("Retirer partage","Remove sharing","Haɗ ekran")else tr("Autoriser partage","Allow sharing","Yamir ekran")),
     (if(p.optBoolean("chat_allowed"))"deny_chat"else "allow_chat") to (if(p.optBoolean("chat_allowed"))tr("Restreindre chat","Restrict chat","Haɗ jeewte")else tr("Autoriser chat","Allow chat","Yamir jeewte")),
     "lower_hand" to tr("Baisser main","Lower hand","Lesɗin junngo"))
     actions.forEach{(a,label)->TextButton(onClick={act(a,target=id)},enabled=!busy){Text(label)}}
     TextButton(onClick={exclude=p},enabled=!busy){Text(tr("Exclure","Exclude","Ittu"))}
    }
   }
   exclude?.let{p->AlertDialog(onDismissRequest={exclude=null},title={Text(tr("Exclure ?","Exclude?","Ittu?"))},text={Text(p.optString("display_name"))},confirmButton={TextButton(onClick={exclude=null;act("exclude",target=p.getString("member_id"))}){Text(tr("Confirmer","Confirm","Tabbitin"))}},dismissButton={TextButton(onClick={exclude=null}){Text(tr("Annuler","Cancel","Haaytu"))}})}
   Text(tr("Discussion","Chat","Jeewte"))
   chat.forEach{c->val name=people.firstOrNull{it.optString("member_id")==c.optString("member_id")}?.optString("display_name")?:tr("Participant","Participant","Jeyaaɗo");Text(name+" : "+c.optString("message"))}
   if(own.optBoolean("chat_allowed")){OutlinedTextField(draft,{if(it.length<=2000)draft=it},label={Text(tr("Message","Message","Ɓatakuru"))},modifier=Modifier.fillMaxWidth());Button(onClick={act("chat",draft)},enabled=!busy&&draft.isNotBlank()){Text(tr("Envoyer","Send","Neldu"))}}
  }
 }
}
