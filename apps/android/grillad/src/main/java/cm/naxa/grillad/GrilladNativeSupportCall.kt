package cm.naxa.grillad

import android.Manifest
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
// Customer audio only, no background recording, no screen capture or remote control.
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
 var audioTrack by remember(ticket){mutableStateOf<AudioTrack?>(null)}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){granted->
  if(granted&&enabled){active=true;status="Demande en cours"}else status="Microphone non autorisé"
 }
 DisposableEffect(host,ticket){
  val observer=LifecycleEventObserver{_,event->if(event==Lifecycle.Event.ON_STOP){active=false;status="Appel arrêté en arrière-plan"}}
  host?.lifecycle?.addObserver(observer)
  onDispose{host?.lifecycle?.removeObserver(observer)}
 }
 LaunchedEffect(ticket,enabled,active){
  if(!enabled||!active)return@LaunchedEffect
  var factory:PeerConnectionFactory?=null;var source:AudioSource?=null;var track:AudioTrack?=null;var peer:PeerConnection?=null;var requested=false;var running=true
  val main=Handler(Looper.getMainLooper())
  suspend fun rpc(op:String,sdp:String?=null):JSONObject{
   val body=obj("action" to "support_call","ticket" to ticket,"operation" to op)
   if(sdp!=null)body.put("sdp",sdp)
   return latest(body) as JSONObject
  }
  try{
   check(ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)
   requested=true;val queued=rpc("request")
   check(queued.optString("status") in listOf("queued","accepted"))
   status="Attente de l’agent"
   val accepted=withTimeout(5*60*1000L){var d=queued;while(d.optString("status")=="queued"){delay(1500);d=rpc("read")};d}
   check(accepted.optString("status")=="accepted")
   PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(ctx.applicationContext).createInitializationOptions())
   factory=PeerConnectionFactory.builder().createPeerConnectionFactory()
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
   status="Connexion audio en cours"
   withTimeout(15000){callDescription(connection,callOffer(connection),true)}
   withTimeout(10000){while(connection.iceGatheringState()!=PeerConnection.IceGatheringState.COMPLETE)delay(100)}
   rpc("offer",connection.localDescription.description)
   val answer=withTimeout(30000){var d=rpc("read");while(d.optString("status")=="accepted"&&(d.isNull("answer")||d.optString("answer").isBlank())){delay(1000);d=rpc("read")};d}
   check(answer.optString("status")=="accepted"&&!answer.isNull("answer"))
   withTimeout(15000){callDescription(connection,SessionDescription(SessionDescription.Type.ANSWER,answer.getString("answer")),false)}
   while(isActive){delay(1500);if(rpc("read").optString("status")!="accepted"){status="Appel terminé";break}}
  }catch(e:CancellationException){throw e}catch(e:Exception){status="Appel non confirmé ou réseau indisponible"}finally{
   running=false;audioTrack=null;track?.setEnabled(false);peer?.close();peer?.dispose();track?.dispose();source?.dispose();factory?.dispose()
   if(requested)withContext(NonCancellable){withTimeoutOrNull(5000){runCatching{rpc("end")}}}
   active=false;mute=false
  }
 }
 Text("Appel audio assistance",style=MaterialTheme.typography.titleMedium)
 Text(status)
 if(active){OutlinedButton({mute=!mute;audioTrack?.setEnabled(!mute)},enabled=enabled){Text(if(mute)"Réactiver micro" else "Couper micro")};OutlinedButton({active=false;status="Appel terminé"}){Text("Terminer l’appel")}}
 else Button({if(ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED){active=true;status="Demande en cours"}else permission.launch(Manifest.permission.RECORD_AUDIO)},enabled=enabled){Text("Demander un appel audio")}
 Text("Microphone uniquement pendant l’appel. Partage d’écran disponible sur Web en qualification, pas sur Android natif.")
}
