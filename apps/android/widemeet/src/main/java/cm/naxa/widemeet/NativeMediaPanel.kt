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
import io.livekit.android.room.track.LocalVideoTrack
import io.livekit.android.room.track.VideoCaptureParameter
import io.livekit.android.room.track.VideoEncoding
import io.livekit.android.room.participant.VideoTrackPublishOptions
import io.livekit.android.room.participant.ConnectionQuality
import kotlinx.coroutines.delay
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

@Composable fun NativeMediaPanel(english:Boolean,gateway:RoomGateway,session:Session,roomId:String,micAllowed:Boolean,screenAllowed:Boolean,isHost:Boolean=false,presentationCeiling:String="high",authGateway:cm.naxa.widemeet.auth.AuthGateway?=null){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 val preferences=remember(context){context.getSharedPreferences("wm-presentation",android.content.Context.MODE_PRIVATE)};val preferenceKey=session.memberId
 val levels=listOf("low","medium","high");var preferred by remember(preferenceKey){mutableStateOf(preferences.getString(preferenceKey,"medium")?.takeIf{it in levels}?:"medium")};var network by remember{mutableStateOf("high")};val effective=levels[minOf(levels.indexOf(preferred),levels.indexOf(network),levels.indexOf(presentationCeiling).coerceAtLeast(0))];val profile=when(effective){"low"->intArrayOf(640,360,10,450000);"medium"->intArrayOf(1280,720,15,1200000);else->intArrayOf(1920,1080,30,2500000)}
 var applied by remember{mutableStateOf<String?>(null)};var measured by remember{mutableStateOf<String?>(null)};var changingQuality by remember{mutableStateOf(false)}
 fun captureParams():VideoCaptureParameter{val d=context.resources.displayMetrics;val long=maxOf(d.widthPixels,d.heightPixels).coerceAtLeast(2);val short=minOf(d.widthPixels,d.heightPixels).coerceAtLeast(2);val scale=minOf(1.0,profile[0].toDouble()/long,profile[1].toDouble()/short);return VideoCaptureParameter((2*((long*scale/2).toInt())).coerceAtLeast(2),(2*((short*scale/2).toInt())).coerceAtLeast(2),profile[2],false)}
 fun configureDefaults(r:Room){r.localParticipant.screenShareTrackCaptureDefaults=r.localParticipant.screenShareTrackCaptureDefaults.copy(captureParams=captureParams());r.localParticipant.screenShareTrackPublishDefaults=r.localParticipant.screenShareTrackPublishDefaults.copy(videoEncoding=VideoEncoding(profile[3],profile[2]),simulcast=false)}
 var room by remember{mutableStateOf<Room?>(null)}
 var status by remember{mutableStateOf("idle")};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var mic by remember{mutableStateOf(false)};var camera by remember{mutableStateOf(false)};var screen by remember{mutableStateOf(false)};var screenRequestGeneration by remember{mutableIntStateOf(-1)}
 var tracks by remember{mutableStateOf<List<VideoTrack>>(emptyList())}
 var generation by remember{mutableIntStateOf(0)}
 var languagePrefs by remember(roomId,session.deviceId){mutableStateOf<JSONObject?>(null)}
 LaunchedEffect(roomId,session.accessToken){languagePrefs=null;try{languagePrefs=authGateway?.identity(session,"language-preferences")}catch(e:CancellationException){throw e}catch(e:Exception){languagePrefs=null}}
 var captionTouched by remember(roomId,session.deviceId){mutableStateOf(false)}
 var captionLanguage by remember(roomId,session.deviceId){mutableStateOf("off")}
 var caption by remember(roomId,session.deviceId,captionLanguage,status){mutableStateOf<JSONObject?>(null)}
 var captionState by remember(roomId,session.deviceId,captionLanguage,status){mutableStateOf("idle")}
 var captionMenu by remember{mutableStateOf(false)}
 LaunchedEffect(roomId,session.deviceId,captionLanguage,status){
  if(status!="connected"||captionLanguage=="off")return@LaunchedEffect
  while(true){
   try{
    val response=gateway.request("transcription",JSONObject().put("action","live-captions").put("data",JSONObject().put("room_id",roomId).put("language",captionLanguage)),session) as JSONObject
    captionState=response.optString("status");caption=if(captionState=="ready"&&response.optLong("ttl_ms")>0)response else null
    kotlinx.coroutines.delay(minOf(1500L,response.optLong("ttl_ms",1500L).coerceAtLeast(1L)))
    caption=null
   }catch(e:CancellationException){throw e}catch(e:Exception){caption=null;captionState="unavailable";kotlinx.coroutines.delay(1500)}
  }
 }

 fun disposeRoom(r:Room){runCatching{r.disconnect()};runCatching{r.release()}}
 fun leave(){generation++;val r=room;room=null;tracks=emptyList();mic=false;camera=false;screen=false;busy=false;status="idle";if(r!=null)disposeRoom(r)}
 DisposableEffect(session.deviceId,roomId){onDispose{generation++;room?.let{disposeRoom(it)};room=null}}
 LaunchedEffect(room){
 val r=room?:return@LaunchedEffect
 r.events.collect{event->if(room===r)when(event){
 is RoomEvent.TrackSubscribed->{val t=event.track;if(t is VideoTrack&&t !in tracks)tracks=tracks+t}
 is RoomEvent.TrackUnsubscribed->{val t=event.track;if(t is VideoTrack)tracks=tracks-t}
 is RoomEvent.TrackUnpublished->{if(event.publication.source==Track.Source.SCREEN_SHARE&&event.participant===r.localParticipant&&!changingQuality&&r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)==null){screen=false;applied=null;measured=null}}
 is RoomEvent.ConnectionQualityChanged->if(event.participant===r.localParticipant){network=when(event.quality){ConnectionQuality.POOR,ConnectionQuality.LOST->"low";ConnectionQuality.EXCELLENT->"high";else->"medium"}}
 is RoomEvent.Reconnecting->{network="low";status="reconnecting"}
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
 scope.launch{try{if(enable)configureDefaults(r);r.localParticipant.setScreenShareEnabled(enable,data);val active=r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.muted==false;require(active==enable);if(room===r){screen=active;applied=if(active)effective else null;measured=null}}catch(e:CancellationException){throw e}catch(e:Exception){if(room===r){error=true;leave()}}finally{if(room===r)busy=false}}
 }
 val screenPermission=rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()){result->
 val data=result.data
 if(result.resultCode==Activity.RESULT_OK&&data!=null&&screenRequestGeneration==generation&&allowedScreen&&room!=null)share(data)
 else if(result.resultCode==Activity.RESULT_OK)error=true
 screenRequestGeneration=-1
 }
 LaunchedEffect(screenAllowed,screen,room){val r=room;if(!screenAllowed&&screen&&r!=null){try{r.localParticipant.setScreenShareEnabled(false);if(r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.muted==false)leave() else screen=false}catch(e:CancellationException){throw e}catch(e:Exception){leave()}}}

 // Reconfigure only the screen track. Preserve the MediaProjection and call session;
 // republish the same authorized screen track to apply a new encoder ceiling.
 LaunchedEffect(effective,screen,status,room){val r=room?:return@LaunchedEffect;if(!screen||status!="connected"||applied==effective||busy||!allowedScreen)return@LaunchedEffect
  val t=r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.track as? LocalVideoTrack?:return@LaunchedEffect
  changingQuality=true;busy=true
  try{configureDefaults(r);val p=captureParams();val d=context.resources.displayMetrics;val landscape=d.widthPixels>=d.heightPixels;t.options=t.options.copy(captureParams=p);t.capturer.changeCaptureFormat(if(landscape)p.width else p.height,if(landscape)p.height else p.width,p.maxFps);r.localParticipant.unpublishTrack(t,false);require(allowedScreen&&room===r);r.localParticipant.publishVideoTrack(t,VideoTrackPublishOptions(null,r.localParticipant.screenShareTrackPublishDefaults,Track.Source.SCREEN_SHARE));require(r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.track===t);applied=effective}catch(e:CancellationException){runCatching{t.stop()};throw e}catch(e:Exception){runCatching{t.stop()};error=true;leave()}finally{changingQuality=false;if(room===r)busy=false}
 }
 LaunchedEffect(screen,room){val r=room?:return@LaunchedEffect;if(!screen)return@LaunchedEffect;var previousBytes:Double?=null;var previousAt:Double?=null;while(screen&&room===r){try{val t=r.localParticipant.getTrackPublication(Track.Source.SCREEN_SHARE)?.track;val stats=t?.getRTCStats()?.statsMap?.values?.firstOrNull{it.type=="outbound-rtp"&&(it.members["kind"]=="video"||it.members["mediaType"]=="video")};val m=stats?.members;val width=(m?.get("frameWidth") as? Number)?.toInt();val height=(m?.get("frameHeight") as? Number)?.toInt();val fps=(m?.get("framesPerSecond") as? Number)?.toInt();val bytes=(m?.get("bytesSent") as? Number)?.toDouble();val at=stats?.timestampUs?.toDouble();val kbps=if(bytes!=null&&at!=null&&previousBytes!=null&&previousAt!=null&&at>previousAt!!&&bytes>=previousBytes!!) (8000*(bytes-previousBytes!!)/(at-previousAt!!)).toInt() else null;previousBytes=bytes;previousAt=at;measured=if(width!=null&&height!=null) "$width×$height"+(fps?.let{" · $it fps"}?:"")+(kbps?.let{" · $it kbit/s"}?:"")else null}catch(e:CancellationException){throw e}catch(e:Exception){measured=null};delay(2000)}}
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
 if(!captionTouched&&languagePrefs!=null)TextButton(onClick={captionTouched=true;captionLanguage=languagePrefs?.optString("subtitles","original")?:"original"}){Text(tr("Utiliser ma langue de sous-titres","Use my preferred subtitle language"))}
 val languages=listOf("off" to tr("Désactivés","Off"),"original" to tr("Original","Original"),"fr" to "Français","en" to "English","ff" to "Fulfulde","es" to "Español","it" to "Italiano","zh" to "中文")
 Text(tr("Sous-titres (audio consenti)","Captions (consented audio)"))
 Box{OutlinedButton(onClick={captionMenu=true}){Text(languages.firstOrNull{it.first==captionLanguage}?.second?:captionLanguage)};DropdownMenu(expanded=captionMenu,onDismissRequest={captionMenu=false}){for((code,name) in languages)DropdownMenuItem(text={Text(name)},onClick={captionTouched=true;captionLanguage=code;captionMenu=false})}}
 if(captionLanguage!="off"){val c=caption
 Text(if(c!=null)c.optString("text").ifBlank{tr("Silence","Silence")}else if(captionState=="unavailable")tr("Sous-titres indisponibles ou consentement absent.","Captions unavailable or consent missing.")else tr("En attente de parole enregistrée avec consentement.","Waiting for consented recorded speech."))
 if(c?.optBoolean("fallback")==true)Text(tr("Traduction indisponible : langue originale.","Translation unavailable: original language."))
 if(c?.optBoolean("uncertain")==true)Text(tr("Texte à vérifier.","Text needs review."))
 if(c!=null&&c.optString("language")!=c.optString("source_language"))Text(c.optString("original"))
 }
 if(status=="connected")LiveListening(english,gateway,session,roomId,languagePrefs)
 Button(enabled=!busy&&micAllowed,onClick={if(mic||ContextCompat.checkSelfPermission(context,Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)toggle("mic")else micPermission.launch(Manifest.permission.RECORD_AUDIO)}){Text(if(mic)tr("Couper mon micro","Mute my microphone")else tr("Activer mon micro","Enable my microphone"))}
 Button(enabled=!busy,onClick={if(camera||ContextCompat.checkSelfPermission(context,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)toggle("camera")else cameraPermission.launch(Manifest.permission.CAMERA)}){Text(if(camera)tr("Couper ma caméra","Disable my camera")else tr("Activer ma caméra","Enable my camera"))}
 Text(tr("Qualité de présentation","Presentation quality"));for(level in levels)Row{RadioButton(selected=preferred==level,onClick={preferred=level;preferences.edit().putString(preferenceKey,level).apply()},enabled=screenAllowed&&!busy);Text(when(level){"low"->"Low Quality";"medium"->"Medium Quality";else->"High Quality"})};Text(tr("Qualité adaptée : ","Adapted quality: ")+(when(effective){"low"->"Low Quality";"medium"->"Medium Quality";"high"->"High Quality";else->tr("Indisponible","Unavailable")})+(applied?.let{" · "+tr("Qualité appliquée","Applied quality")+": "+when(it){"low"->"Low Quality";"medium"->"Medium Quality";"high"->"High Quality";else->tr("Indisponible","Unavailable")}}?:"")+(if(screen) " · "+(measured?:tr("Qualité effective indisponible","Actual quality unavailable"))else ""))
 Button(enabled=!busy&&(screen||screenAllowed),onClick={if(screen)share(null)else{screenRequestGeneration=generation;val manager=context.getSystemService(MediaProjectionManager::class.java);if(manager==null){error=true;screenRequestGeneration=-1}else screenPermission.launch(manager.createScreenCaptureIntent())}}){Text(if(screen)tr("Arrêter le partage","Stop sharing")else tr("Partager mon écran","Share my screen"))}
 if(BuildConfig.WIDEMEET_CONNECT_ENABLED)ConnectSource(english,gateway,session,roomId,isHost)
 TextButton(onClick={if(BuildConfig.WIDEMEET_CONNECT_ENABLED)scope.launch{runCatching{gateway.request("connect",JSONObject().put("action","source-stop").put("data",JSONObject().put("room_id",roomId)),session)}};leave()}){Text(tr("Quitter l’appel","Leave call"))}
 }else if(status in setOf("connecting","reconnecting"))TextButton(onClick={leave()}){Text(tr("Annuler la connexion","Cancel connection"))}
 else Button(enabled=!busy,onClick={join()}){Text(tr("Rejoindre l’appel","Join call"))}
 if(error)Text(tr("Connexion ou périphérique indisponible. Réessayez.","Connection or device unavailable. Try again."),color=MaterialTheme.colorScheme.error)
 }
}
