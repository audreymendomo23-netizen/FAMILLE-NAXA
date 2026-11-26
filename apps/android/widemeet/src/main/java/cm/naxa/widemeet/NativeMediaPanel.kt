package cm.naxa.widemeet
import android.Manifest
import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.content.pm.PackageManager
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
import cm.naxa.widemeet.auth.RoomGateway
import cm.naxa.widemeet.auth.Session
import io.livekit.android.LiveKit
import io.livekit.android.events.RoomEvent
import io.livekit.android.events.collect
import io.livekit.android.room.Room
import io.livekit.android.room.track.VideoTrack
import io.livekit.android.room.track.Track
import io.livekit.android.renderer.TextureViewRenderer
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import java.net.URI

@Composable private fun RemoteVideo(room:Room,track:VideoTrack){
 val context=LocalContext.current
 val renderer=remember(room,track){TextureViewRenderer(context).also{room.initVideoRenderer(it);track.addRenderer(it)}}
 DisposableEffect(room,track,renderer){onDispose{runCatching{track.removeRenderer(renderer)};renderer.release()}}
 AndroidView(factory={renderer},modifier=Modifier.fillMaxWidth().height(200.dp))
}

@Composable fun NativeMediaPanel(english:Boolean,gateway:RoomGateway,session:Session,roomId:String,micAllowed:Boolean,screenAllowed:Boolean){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var room by remember{mutableStateOf<Room?>(null)}
 var status by remember{mutableStateOf("idle")};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var mic by remember{mutableStateOf(false)};var camera by remember{mutableStateOf(false)};var screen by remember{mutableStateOf(false)};var screenRequestGeneration by remember{mutableIntStateOf(-1)}
 var tracks by remember{mutableStateOf<List<VideoTrack>>(emptyList())}
 var generation by remember{mutableIntStateOf(0)}
 fun disposeRoom(r:Room){runCatching{r.disconnect()};runCatching{r.release()}}
 fun leave(){generation++;val r=room;room=null;tracks=emptyList();mic=false;camera=false;screen=false;busy=false;status="idle";if(r!=null)disposeRoom(r)}
 DisposableEffect(session.deviceId,roomId){onDispose{generation++;room?.let{disposeRoom(it)};room=null}}
 LaunchedEffect(room){
 val r=room?:return@LaunchedEffect
 r.events.collect{event->if(room===r)when(event){
 is RoomEvent.TrackSubscribed->{val t=event.track;if(t is VideoTrack&&t !in tracks)tracks=tracks+t}
 is RoomEvent.TrackUnsubscribed->{val t=event.track;if(t is VideoTrack)tracks=tracks-t}
 is RoomEvent.TrackUnpublished->{if(event.publication.source==Track.Source.SCREEN_SHARE&&event.participant===r.localParticipant)screen=false}
 is RoomEvent.Reconnecting->status="reconnecting"
 is RoomEvent.Reconnected->status="connected"
 is RoomEvent.Disconnected->{room=null;tracks=emptyList();mic=false;camera=false;busy=false;status="disconnected";r.release()}
 else->Unit
 }}
 }
 LaunchedEffect(micAllowed,mic,room){val r=room;if(!micAllowed&&mic&&r!=null){try{r.localParticipant.setMicrophoneEnabled(false);if(r.localParticipant.getTrackPublication(Track.Source.MICROPHONE)?.muted==false)leave() else mic=false}catch(e:CancellationException){throw e}catch(e:Exception){leave()}}}
 fun toggle(which:String){
 val r=room?:return
 if(status!="connected"||busy||which=="mic"&&!micAllowed)return
 busy=true;error=false
 scope.launch{
 try{
 if(which=="mic"){val next=!mic;r.localParticipant.setMicrophoneEnabled(next);require(!next||r.localParticipant.getTrackPublication(Track.Source.MICROPHONE)?.muted==false);if(room===r)mic=next}
 else{val next=!camera;r.localParticipant.setCameraEnabled(next);require(!next||r.localParticipant.getTrackPublication(Track.Source.CAMERA)?.muted==false);if(room===r)camera=next}
 }catch(e:CancellationException){throw e}catch(e:Exception){if(room===r)error=true}finally{if(room===r)busy=false}
 }
 }
 val micPermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){if(it)toggle("mic") else error=true}
 val cameraPermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){if(it)toggle("camera") else error=true}
 val allowedScreen by rememberUpdatedState(screenAllowed)
 fun share(data:Intent?){
 val r=room?:return
 if(status!="connected"||busy||data!=null&&!allowedScreen)return
 val enable=data!=null;busy=true;error=false
 scope.launch{try{r.localParticipant.setScreenShareEnabled(enable,data);val active=r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.muted==false;require(active==enable);if(room===r)screen=active}catch(e:CancellationException){throw e}catch(e:Exception){if(room===r){error=true;leave()}}finally{if(room===r)busy=false}}
 }
 val screenPermission=rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()){result->
 val data=result.data
 if(result.resultCode==Activity.RESULT_OK&&data!=null&&screenRequestGeneration==generation&&allowedScreen&&room!=null)share(data)
 else if(result.resultCode==Activity.RESULT_OK)error=true
 screenRequestGeneration=-1
 }
 LaunchedEffect(screenAllowed,screen,room){val r=room;if(!screenAllowed&&screen&&r!=null){try{r.localParticipant.setScreenShareEnabled(false);if(r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.muted==false)leave() else screen=false}catch(e:CancellationException){throw e}catch(e:Exception){leave()}}}

 fun join(){
 if(busy||room!=null)return
 val serial=++generation;busy=true;error=false;status="connecting"
 scope.launch{
 var r:Room?=null
 try{
 val grant=gateway.request("media-grant",JSONObject().put("room_id",roomId),session) as JSONObject
 val uri=URI(grant.getString("url"));val token=grant.getString("token")
 require(uri.scheme=="wss"&&!uri.host.isNullOrBlank()&&uri.userInfo==null&&uri.query==null&&uri.fragment==null&&(uri.path.isEmpty()||uri.path=="/")&&token.isNotBlank()&&grant.getLong("expires_at")>System.currentTimeMillis())
 if(generation!=serial)return@launch
 val candidate=LiveKit.create(context.applicationContext);r=candidate;room=candidate
 // Connect without activating microphone/camera. Permissions require a separate user gesture.
 candidate.connect(uri.toString(),token)
 if(generation!=serial||room!==candidate){if(room===candidate)room=null;disposeRoom(candidate);return@launch}
 status="connected"
 }catch(e:CancellationException){if(generation==serial){room=null;r?.let{disposeRoom(it)}};throw e}catch(e:Exception){if(generation==serial){room=null;r?.let{disposeRoom(it)};tracks=emptyList();status="idle";error=true}}
 finally{if(generation==serial)busy=false}
 }
 }
 Column(verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(when(status){"connecting"->tr("Connexion…","Connecting…");"connected"->tr("Connecté à la réunion","Connected to meeting");"reconnecting"->tr("Reconnexion…","Reconnecting…");"disconnected"->tr("Connexion terminée","Connection ended");else->tr("Prêt à rejoindre","Ready to join")})
 val r=room;if(r!=null)tracks.forEach{track->key(track){RemoteVideo(r,track)}}
 if(status=="connected"){
 Button(enabled=!busy&&micAllowed,onClick={if(mic||ContextCompat.checkSelfPermission(context,Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)toggle("mic")else micPermission.launch(Manifest.permission.RECORD_AUDIO)}){Text(if(mic)tr("Couper mon micro","Mute my microphone")else tr("Activer mon micro","Enable my microphone"))}
 Button(enabled=!busy,onClick={if(camera||ContextCompat.checkSelfPermission(context,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)toggle("camera")else cameraPermission.launch(Manifest.permission.CAMERA)}){Text(if(camera)tr("Couper ma caméra","Disable my camera")else tr("Activer ma caméra","Enable my camera"))}
 Button(enabled=!busy&&(screen||screenAllowed),onClick={if(screen)share(null)else{screenRequestGeneration=generation;val manager=context.getSystemService(MediaProjectionManager::class.java);if(manager==null){error=true;screenRequestGeneration=-1}else screenPermission.launch(manager.createScreenCaptureIntent())}}){Text(if(screen)tr("Arrêter le partage","Stop sharing")else tr("Partager mon écran","Share my screen"))}
 TextButton(onClick={leave()}){Text(tr("Quitter l’appel","Leave call"))}
 }else if(status in setOf("connecting","reconnecting"))TextButton(onClick={leave()}){Text(tr("Annuler la connexion","Cancel connection"))}
 else Button(enabled=!busy,onClick={join()}){Text(tr("Rejoindre l’appel","Join call"))}
 if(error)Text(tr("Connexion ou périphérique indisponible. Réessayez.","Connection or device unavailable. Try again."),color=MaterialTheme.colorScheme.error)
 }
}
