package cm.naxa.grillad

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import kotlinx.coroutines.flow.first
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.*
import org.json.JSONObject
import org.webrtc.*
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

// Reuses the native WebRTC initialization/SDP lifecycle of GrilladNativeWhepPlayer.
// Explicit one-call screen consent; no recording or remote control. Media stops on app background.
private abstract class CallSdpObserver:SdpObserver{
 override fun onCreateSuccess(s:SessionDescription){}
 override fun onSetSuccess(){}
 override fun onCreateFailure(e:String){}
 override fun onSetFailure(e:String){}
}
private suspend fun callOffer(p:PeerConnection):SessionDescription=suspendCancellableCoroutine{c->
 p.createOffer(object:CallSdpObserver(){
  override fun onCreateSuccess(s:SessionDescription){if(c.isActive)c.resume(s)}
  override fun onCreateFailure(e:String){if(c.isActive)c.resumeWithException(IllegalStateException("Offer failed"))}
 },MediaConstraints())
}
private suspend fun callDescription(p:PeerConnection,s:SessionDescription,local:Boolean)=suspendCancellableCoroutine<Unit>{c->
 val o=object:CallSdpObserver(){
  override fun onSetSuccess(){if(c.isActive)c.resume(Unit)}
  override fun onSetFailure(e:String){if(c.isActive)c.resumeWithException(IllegalStateException("SDP failed"))}
 }
 if(local)p.setLocalDescription(o,s)else p.setRemoteDescription(o,s)
}
@Composable internal fun GrilladNativeSupportCall(ticket:String,enabled:Boolean,request:suspend(JSONObject)->Any){
 val ctx=LocalContext.current;val latest by rememberUpdatedState(request);val host=ctx as? ComponentActivity
 var active by remember(ticket){mutableStateOf(false)}
 var status by remember(ticket){mutableStateOf("Appel désactivé")}
 var mute by remember(ticket){mutableStateOf(false)}
 var screenWanted by remember(ticket){mutableStateOf(false)}
 var screenGrant by remember(ticket){mutableStateOf<Intent?>(null)}
 var awaiting by remember(ticket){mutableStateOf(false)}
 var ending by remember(ticket){mutableStateOf(false)}
 var confirmScreen by remember(ticket){mutableStateOf(false)}
 var audioTrack by remember(ticket){mutableStateOf<AudioTrack?>(null)}
 val screenPermission=rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()){result->
  if(awaiting&&enabled&&result.resultCode==Activity.RESULT_OK&&result.data!=null){screenGrant=result.data;active=true;status="Demande en cours"}
  else{screenGrant=null;status="Partage d’écran non autorisé"}
  awaiting=false
 }
 fun afterMic(){if(screenWanted){val manager=ctx.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager;screenPermission.launch(manager.createScreenCaptureIntent())}else{awaiting=false;active=true;status="Demande en cours"}}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){granted->
  if(granted&&enabled&&awaiting)afterMic() else{awaiting=false;status="Microphone non autorisé"}
 }
 fun start(screen:Boolean){if(active||ending||awaiting||!enabled)return;screenWanted=screen;screenGrant=null;awaiting=true;if(ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)afterMic()else permission.launch(Manifest.permission.RECORD_AUDIO)}
 LaunchedEffect(enabled){if(!enabled){awaiting=false;active=false;screenGrant=null}}
 DisposableEffect(host,ticket){
  val observer=LifecycleEventObserver{_,event->if(event==Lifecycle.Event.ON_STOP&&active){active=false;status="Appel arrêté en arrière-plan"}}
  host?.lifecycle?.addObserver(observer)
  onDispose{host?.lifecycle?.removeObserver(observer)}
 }
 LaunchedEffect(ticket,enabled,active){
  if(!enabled||!active)return@LaunchedEffect
  ending=true
  val grant=screenGrant;screenGrant=null;val sharing=grant!=null
  var factory:PeerConnectionFactory?=null;var source:AudioSource?=null;var track:AudioTrack?=null;var peer:PeerConnection?=null;var requested=false;var running=true
  var egl:EglBase?=null;var texture:SurfaceTextureHelper?=null;var capturer:ScreenCapturerAndroid?=null;var videoSource:VideoSource?=null;var videoTrack:VideoTrack?=null;var serviceStarted=false
  val main=Handler(Looper.getMainLooper())
  suspend fun rpc(op:String,sdp:String?=null):JSONObject{
   val body=obj("action" to "support_call","ticket" to ticket,"operation" to op)
   if(sdp!=null)body.put("sdp",sdp)
   if(op=="request")body.put("screen",sharing)
   return latest(body) as JSONObject
  }
  try{
   check(ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)
   requested=true;val queued=rpc("request")
   check(queued.optString("status") in listOf("queued","accepted"))
   status="Attente de l’agent"
   val accepted=withTimeout(5*60*1000L){var d=queued;while(d.optString("status")=="queued"){delay(1500);d=rpc("read")};d}
   check(accepted.optString("status")=="accepted"&&accepted.optBoolean("screen_consent")==sharing&&!accepted.optBoolean("screen_stopped"))
   PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(ctx.applicationContext).createInitializationOptions())
   if(sharing)egl=EglBase.create()
   val builder=PeerConnectionFactory.builder()
   egl?.let{builder.setVideoEncoderFactory(DefaultVideoEncoderFactory(it.eglBaseContext,true,true)).setVideoDecoderFactory(DefaultVideoDecoderFactory(it.eglBaseContext))}
   factory=builder.createPeerConnectionFactory()
   source=factory.createAudioSource(MediaConstraints());track=factory.createAudioTrack("grillad-support-microphone",source)
   audioTrack=track;track.setEnabled(!mute)
   val config=PeerConnection.RTCConfiguration(emptyList()).apply{sdpSemantics=PeerConnection.SdpSemantics.UNIFIED_PLAN}
   peer=factory.createPeerConnection(config,object:PeerConnection.Observer{
    override fun onSignalingChange(s:PeerConnection.SignalingState){}
    override fun onIceConnectionChange(s:PeerConnection.IceConnectionState){main.post{if(running){if(s==PeerConnection.IceConnectionState.CONNECTED||s==PeerConnection.IceConnectionState.COMPLETED)status="Appel audio connecté";if(s==PeerConnection.IceConnectionState.FAILED){status="Connexion audio interrompue";active=false}}}}
    override fun onIceConnectionReceivingChange(receiving:Boolean){}
    override fun onIceGatheringChange(s:PeerConnection.IceGatheringState){}
    override fun onIceCandidate(c:IceCandidate){}
    override fun onIceCandidatesRemoved(c:Array<out IceCandidate>){}
    override fun onAddStream(s:MediaStream){}
    override fun onRemoveStream(s:MediaStream){}
    override fun onDataChannel(c:DataChannel){}
    override fun onRenegotiationNeeded(){}
    override fun onTrack(transceiver:RtpTransceiver){val remote=transceiver.receiver.track() as? AudioTrack;remote?.setEnabled(true)}
   })?:error("Peer unavailable")
   val connection=peer
   connection.addTrack(track,listOf("grillad-support"))
   if(grant!=null){
    check(host?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED)==true)
    GrilladProjectionService.ready.value=false
    serviceStarted=true
    ctx.startForegroundService(Intent(ctx,GrilladProjectionService::class.java))
    withTimeout(5000){GrilladProjectionService.ready.first{it}}
    val displaySource=factory.createVideoSource(true);videoSource=displaySource
    val helper=SurfaceTextureHelper.create("grillad-screen",checkNotNull(egl).eglBaseContext);texture=helper
    val display=ScreenCapturerAndroid(grant,object:MediaProjection.Callback(){override fun onStop(){main.post{if(running){active=false;status="Partage arrêté"}}}});capturer=display
    display.initialize(helper,ctx.applicationContext,displaySource.capturerObserver)
    val metrics=ctx.resources.displayMetrics
    val scale=minOf(1f,1280f/maxOf(metrics.widthPixels,metrics.heightPixels).coerceAtLeast(1))
    display.startCapture((metrics.widthPixels*scale).toInt().coerceAtLeast(2)/2*2,(metrics.heightPixels*scale).toInt().coerceAtLeast(2)/2*2,12)
    val screenTrack=factory.createVideoTrack("grillad-support-screen",displaySource);videoTrack=screenTrack
    connection.addTrack(screenTrack,listOf("grillad-support"))
   }
   status=if(sharing)"Connexion audio et écran en cours" else "Connexion audio en cours"
   withTimeout(15000){callDescription(connection,callOffer(connection),true)}
   withTimeout(10000){while(connection.iceGatheringState()!=PeerConnection.IceGatheringState.COMPLETE)delay(100)}
   rpc("offer",connection.localDescription.description)
   val answer=withTimeout(30000){var d=rpc("read");while(d.optString("status")=="accepted"&&(d.isNull("answer")||d.optString("answer").isBlank())){delay(1000);d=rpc("read")};d}
   check(answer.optString("status")=="accepted"&&!answer.isNull("answer"))
   withTimeout(15000){callDescription(connection,SessionDescription(SessionDescription.Type.ANSWER,answer.getString("answer")),false)}
   while(isActive){delay(1500);if(sharing&&!GrilladProjectionService.ready.value){status="Partage arrêté";break};val current=rpc("read");if(current.optString("status")!="accepted"||(sharing&&current.optBoolean("screen_stopped"))){status="Appel terminé";break}}
  }catch(e:CancellationException){throw e}catch(e:Exception){status="Appel non confirmé ou réseau indisponible"}finally{
   running=false;audioTrack=null;track?.setEnabled(false);videoTrack?.setEnabled(false)
   runCatching{capturer?.stopCapture()};runCatching{capturer?.dispose()}
   runCatching{peer?.close()};runCatching{peer?.dispose()}
   runCatching{videoTrack?.dispose()};runCatching{videoSource?.dispose()};runCatching{texture?.dispose()}
   runCatching{track?.dispose()};runCatching{source?.dispose()};runCatching{factory?.dispose()};runCatching{egl?.release()}
   if(serviceStarted)runCatching{ctx.stopService(Intent(ctx,GrilladProjectionService::class.java))}
   if(requested)withContext(NonCancellable){withTimeoutOrNull(5000){runCatching{rpc("end")}}}
   active=false;mute=false;ending=false;screenWanted=false
  }
 }
 Text("Appel audio assistance",style=MaterialTheme.typography.titleMedium)
 Text(status)
 if(active){OutlinedButton({mute=!mute;audioTrack?.setEnabled(!mute)},enabled=enabled){Text(if(mute)"Réactiver micro" else "Couper micro")};OutlinedButton({active=false;status="Appel terminé"}){Text("Terminer l’appel")}}
 else {
  Button({start(false)},enabled=enabled&&!ending&&!awaiting){Text("Demander un appel audio")}
  OutlinedButton({confirmScreen=true},enabled=enabled&&!ending&&!awaiting){Text("Appel avec partage d’écran")}
 }
 if(confirmScreen)AlertDialog(onDismissRequest={confirmScreen=false},title={Text("Partager votre écran ?")},text={Text("Seul l’agent habilité reçoit l’image pendant l’appel. Fermez les données sensibles. Vous pouvez terminer à tout moment.")},confirmButton={TextButton({confirmScreen=false;start(true)}){Text("Choisir l’écran")}},dismissButton={TextButton({confirmScreen=false}){Text("Annuler")}})
 Text("Microphone et écran uniquement pendant l’appel autorisé. Terminer l’appel arrête également le partage.")
}
