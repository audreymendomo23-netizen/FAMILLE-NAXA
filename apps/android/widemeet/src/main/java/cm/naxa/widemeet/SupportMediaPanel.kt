package cm.naxa.widemeet
import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import cm.naxa.widemeet.auth.*
import io.livekit.android.LiveKit
import io.livekit.android.events.RoomEvent
import io.livekit.android.events.collect
import io.livekit.android.room.Room
import io.livekit.android.room.track.VideoTrack
import io.livekit.android.room.track.Track
import io.livekit.android.renderer.TextureViewRenderer
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.URI
import java.util.UUID

@Composable private fun SupportRemoteScreen(room:Room,track:VideoTrack){
 val context=LocalContext.current
 val renderer=remember(room,track){TextureViewRenderer(context).also{room.initVideoRenderer(it);track.addRenderer(it)}}
 DisposableEffect(room,track,renderer){onDispose{runCatching{track.removeRenderer(renderer)};renderer.release()}}
 AndroidView(factory={renderer},modifier=Modifier.fillMaxWidth().height(200.dp))
}

@Composable fun SupportMediaPanel(english:Boolean,gateway:AuthGateway,session:Session,ticket:JSONObject){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope();val context=LocalContext.current;val ticketId=ticket.getString("id")
 val owner=ticket.optString("viewer")=="requester"
 var call by remember{mutableStateOf<JSONObject?>(null)};var room by remember{mutableStateOf<Room?>(null)}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var connected by remember{mutableStateOf(false)}
 var mic by remember{mutableStateOf(false)};var screen by remember{mutableStateOf(false)};var generation by remember{mutableIntStateOf(0)}
 var screenGeneration by remember{mutableIntStateOf(-1)};var tracks by remember{mutableStateOf<List<VideoTrack>>(emptyList())}
 var consentDialog by remember{mutableStateOf(false)};var requestId by remember{mutableStateOf<String?>(null)}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.identity(session,"support-"+action,data.put("ticket_id",ticketId))
 fun dispose(r:Room){runCatching{r.disconnect()};runCatching{r.release()}}
 fun leave(){generation++;val r=room;room=null;connected=false;mic=false;screen=false;tracks=emptyList();if(r!=null)dispose(r)}
 suspend fun command(action:String,data:JSONObject=JSONObject()):JSONObject{
  if(!data.has("call_id"))data.put("call_id",call?.optString("id"))
  val v=req(action,data);call=v;if(v.optString("state")!="active")leave();return v
 }
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){leave();error=true}finally{busy=false}}}
 DisposableEffect(ticketId,session.deviceId){onDispose{generation++;room?.let{dispose(it)};room=null}}
 LaunchedEffect(ticketId,session.deviceId,session.accessToken){
  while(true){if(!busy){busy=true;try{var v=req("call-read");if(v.optString("state")=="active")v=req("call-heartbeat",JSONObject().put("call_id",v.getString("id")))
   if(room!=null&&(v.optString("state")!="active"||v.optString("id")!=call?.optString("id")||call?.isNull("screen_id")==false&&v.isNull("screen_id")))leave()
   call=v
  }catch(e:CancellationException){throw e}catch(e:Exception){leave();call=null;error=true}finally{busy=false}};delay(3000)}
 }
 LaunchedEffect(room){val r=room?:return@LaunchedEffect;r.events.collect{event->if(room===r)when(event){
  is RoomEvent.TrackSubscribed->{val t=event.track;if(t is VideoTrack&&event.publication.source==Track.Source.SCREEN_SHARE&&t !in tracks)tracks=tracks+t}
  is RoomEvent.TrackUnsubscribed->{val t=event.track;if(t is VideoTrack)tracks=tracks-t}
  is RoomEvent.TrackUnpublished->{if(event.publication.source==Track.Source.SCREEN_SHARE&&event.participant===r.localParticipant){screen=false;val share=call?.takeUnless{it.isNull("screen_id")}?.optString("screen_id");if(share!=null&&!busy)work{command("screen-stop",JSONObject().put("share_id",share));leave()}}}
  is RoomEvent.Reconnecting->connected=false
  is RoomEvent.Reconnected->connected=true
  is RoomEvent.Disconnected->{room=null;connected=false;mic=false;screen=false;tracks=emptyList();r.release()}
  else->Unit
 }}}
 fun join(){work{val serial=++generation;val id=call?.getString("id")?:return@work
  val g=req("call-grant",JSONObject().put("call_id",id));val u=URI(g.getString("url"))
  require(u.scheme=="wss"&&!u.host.isNullOrBlank()&&u.userInfo==null&&u.query==null&&u.fragment==null&&(u.path.isEmpty()||u.path=="/")&&g.getLong("expires_at")>System.currentTimeMillis())
  if(serial!=generation)return@work
  val candidate=LiveKit.create(context.applicationContext);room=candidate;candidate.connect(u.toString(),g.getString("token"))
  if(serial!=generation||room!==candidate){dispose(candidate);return@work};connected=true
 }}
 fun toggleMic(){work{val r=room?:return@work;val next=!mic;r.localParticipant.setMicrophoneEnabled(next);require(!next||r.localParticipant.getTrackPublication(Track.Source.MICROPHONE)?.muted==false);if(room===r)mic=next}}
 val micPermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){if(it)toggleMic()else error=true}
 fun capture(data:Intent){work{val r=room?:return@work;val v=call?:return@work;require(owner&&v.optString("screen_state")=="consented");val share=v.getString("screen_id")
  try{r.localParticipant.setScreenShareEnabled(true,data);require(r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.muted==false);command("screen-start",JSONObject().put("share_id",share));screen=true}
  catch(e:CancellationException){throw e}catch(e:Exception){runCatching{r.localParticipant.setScreenShareEnabled(false,null)};runCatching{command("screen-stop",JSONObject().put("share_id",share))};throw e}
 }}
 val screenPermission=rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()){res->
  val data=res.data;if(res.resultCode==Activity.RESULT_OK&&data!=null&&screenGeneration==generation&&room!=null&&owner)capture(data)else{val share=call?.takeUnless{it.isNull("screen_id")}?.optString("screen_id");if(share!=null)work{command("screen-stop",JSONObject().put("share_id",share));leave()}}
  screenGeneration=-1
 }
 Text(tr("Appel d’assistance privé","Private support call"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Agent attribué uniquement. Pas de caméra ni d’accès aux réunions.","Assigned agent only. No camera or meeting access."))
 val v=call;val state=v?.optString("state")
 if(state=="idle"&&owner)Button(enabled=!busy,onClick={work{val id=requestId?:UUID.randomUUID().toString();requestId=id;command("call-request",JSONObject().put("call_id",id));requestId=null}}){Text(tr("Demander un appel audio","Request audio call"))}
 if(state=="requested"){Text(tr("En attente de l’agent","Waiting for agent"));if(!owner){Button(enabled=!busy,onClick={work{command("call-accept")}}){Text(tr("Accepter","Accept"))};TextButton(enabled=!busy,onClick={work{command("call-decline")}}){Text(tr("Refuser","Decline"))}}}
 if(state=="active"&&v!=null){
  if(!connected)Button(enabled=!busy&&room==null,onClick={join()}){Text(tr("Rejoindre l’assistance","Join support call"))}
  else Button(enabled=!busy,onClick={if(mic||ContextCompat.checkSelfPermission(context,Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)toggleMic()else micPermission.launch(Manifest.permission.RECORD_AUDIO)}){Text(if(mic)tr("Couper le micro","Mute microphone")else tr("Activer le micro","Enable microphone"))}
  if(owner&&v.isNull("screen_id"))Button(enabled=!busy,onClick={consentDialog=true}){Text(tr("Autoriser le partage d’écran","Authorize screen sharing"))}
  if(owner&&connected&&v.optString("screen_state")=="consented")Button(enabled=!busy,onClick={val mgr=context.getSystemService(MediaProjectionManager::class.java);if(mgr==null)error=true else{screenGeneration=generation;screenPermission.launch(mgr.createScreenCaptureIntent())}}){Text(tr("Choisir un écran à partager","Choose screen to share"))}
  if(!v.isNull("screen_id"))TextButton(enabled=!busy,onClick={work{room?.localParticipant?.setScreenShareEnabled(false,null);command("screen-stop",JSONObject().put("share_id",v.getString("screen_id")));leave()}}){Text(tr("Retirer le consentement / arrêter","Withdraw consent / stop"))}
  if(screen)Text(tr("Votre écran est partagé","Your screen is shared"))
 }
 if(state=="requested"||state=="active")TextButton(enabled=!busy,onClick={work{command("call-end");leave()}}){Text(tr("Terminer l’assistance","End support call"))}
 val rr=room;if(rr!=null)tracks.forEach{track->key(track){SupportRemoteScreen(rr,track)}}
 if(consentDialog)AlertDialog(onDismissRequest={consentDialog=false},title={Text(tr("Autoriser le partage avec cet agent uniquement ?","Allow sharing with this agent only?"))},confirmButton={TextButton(onClick={consentDialog=false;work{command("screen-consent",JSONObject().put("share_id",UUID.randomUUID().toString()));leave()}}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={consentDialog=false}){Text(tr("Annuler","Cancel"))}})
 if(error)Text(tr("Action non confirmée. Réessayez.","Action unconfirmed. Retry."),color=MaterialTheme.colorScheme.error)
}
