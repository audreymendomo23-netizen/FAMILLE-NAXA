package cm.naxa.grillad
import android.os.Handler
import android.os.Looper
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import kotlinx.coroutines.*
import org.json.JSONObject
import org.webrtc.*
import java.net.URI
import javax.net.ssl.HttpsURLConnection
import java.time.Instant
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal data class GrilladVideoTicket(val session:String,val endpoint:URI,val authorization:String,val expiry:Long){
 companion object{
  fun parse(v:JSONObject,now:Long=System.currentTimeMillis()):GrilladVideoTicket{
   val id=v.getString("session");val uri=URI(v.getString("whepUrl"));val auth=v.getString("authorization");val expiry=Instant.parse(v.getString("expiresAt")).toEpochMilli()
   require(id.matches(Regex("[0-9a-fA-F-]{36}"))&&uri.scheme=="https"&&uri.host!=null&&uri.userInfo==null&&uri.query==null&&uri.fragment==null&&uri.path.endsWith("/whep")&&auth.matches(Regex("Bearer [A-Za-z0-9_-]{43,160}"))&&expiry>now&&expiry-now<=900_000)
   return GrilladVideoTicket(id,uri,auth,expiry)
  }
 }
 fun resource(location:String):URI{val r=endpoint.resolve(location);require(r.scheme=="https"&&r.host.equals(endpoint.host,true)&&port(r)==port(endpoint)&&r.userInfo==null&&r.fragment==null);return r}
 private fun port(u:URI)=if(u.port==-1)443 else u.port
}
private abstract class Observer:SdpObserver{override fun onCreateSuccess(s:SessionDescription){};override fun onSetSuccess(){};override fun onCreateFailure(e:String){};override fun onSetFailure(e:String){}}
private suspend fun offer(p:PeerConnection):SessionDescription=suspendCancellableCoroutine{c->p.createOffer(object:Observer(){override fun onCreateSuccess(s:SessionDescription){if(c.isActive)c.resume(s)};override fun onCreateFailure(e:String){if(c.isActive)c.resumeWithException(IllegalStateException("Offre refusée"))}},MediaConstraints())}
private suspend fun description(p:PeerConnection,s:SessionDescription,local:Boolean)=suspendCancellableCoroutine<Unit>{c->val o=object:Observer(){override fun onSetSuccess(){if(c.isActive)c.resume(Unit)};override fun onSetFailure(e:String){if(c.isActive)c.resumeWithException(IllegalStateException("Description refusée"))}};if(local)p.setLocalDescription(o,s)else p.setRemoteDescription(o,s)}
private suspend fun whep(t:GrilladVideoTicket,sdp:String):Pair<String,URI?> = withContext(Dispatchers.IO){
 val c=t.endpoint.toURL().openConnection() as HttpsURLConnection
 try{c.instanceFollowRedirects=false;c.requestMethod="POST";c.connectTimeout=10000;c.readTimeout=15000;c.doOutput=true;c.setRequestProperty("Authorization",t.authorization);c.setRequestProperty("Content-Type","application/sdp");c.outputStream.use{it.write(sdp.toByteArray())};check(c.responseCode in 200..299);val result=c.inputStream.bufferedReader().use{it.readText()};check(result.isNotBlank()&&result.length<262144);result to c.getHeaderField("Location")?.let{t.resource(it)}}finally{c.disconnect()}
}
private suspend fun deleteWhep(t:GrilladVideoTicket,u:URI)=withContext(Dispatchers.IO){val c=u.toURL().openConnection() as HttpsURLConnection;try{c.instanceFollowRedirects=false;c.requestMethod="DELETE";c.connectTimeout=4000;c.readTimeout=4000;c.setRequestProperty("Authorization",t.authorization);c.responseCode}finally{c.disconnect()}}
@Composable internal fun GrilladNativeWhepPlayer(camera:String,request:suspend(JSONObject)->JSONObject){
 val ctx=LocalContext.current;val latest by rememberUpdatedState(request);var active by remember{mutableStateOf(false)};var status by remember{mutableStateOf("Direct désactivé")};var renderer by remember{mutableStateOf<SurfaceViewRenderer?>(null)}
 if(active){
  val egl=remember{EglBase.create()};DisposableEffect(egl){onDispose{renderer?.release();renderer=null;egl.release()}}
  AndroidView(factory={c->SurfaceViewRenderer(c).also{it.init(egl.eglBaseContext,null);it.setEnableHardwareScaler(true);renderer=it}},modifier=Modifier.fillMaxWidth().height(220.dp))
  val target=renderer
  LaunchedEffect(camera,target){if(target==null)return@LaunchedEffect;val main=Handler(Looper.getMainLooper());var ticket:GrilladVideoTicket?=null;var resource:URI?=null;var factory:PeerConnectionFactory?=null;var peer:PeerConnection?=null;var running=true
   try{status="Autorisation en cours…";ticket=GrilladVideoTicket.parse(latest(obj("action" to "security_live_session","camera" to camera)));val t=ticket
    PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(ctx.applicationContext).createInitializationOptions());factory=PeerConnectionFactory.builder().setVideoDecoderFactory(DefaultVideoDecoderFactory(egl.eglBaseContext)).createPeerConnectionFactory()
    val config=PeerConnection.RTCConfiguration(emptyList()).apply{sdpSemantics=PeerConnection.SdpSemantics.UNIFIED_PLAN}
    peer=factory.createPeerConnection(config,object:PeerConnection.Observer{
      override fun onSignalingChange(s:PeerConnection.SignalingState){}
      override fun onIceConnectionChange(s:PeerConnection.IceConnectionState){if(s==PeerConnection.IceConnectionState.FAILED||s==PeerConnection.IceConnectionState.DISCONNECTED)main.post{if(running)status="Direct indisponible"}}
      override fun onIceConnectionReceivingChange(receiving:Boolean){}
      override fun onIceGatheringChange(s:PeerConnection.IceGatheringState){}
      override fun onIceCandidate(c:IceCandidate){}
      override fun onIceCandidatesRemoved(c:Array<out IceCandidate>){}
      override fun onAddStream(s:MediaStream){}
      override fun onRemoveStream(s:MediaStream){}
      override fun onDataChannel(c:DataChannel){}
      override fun onRenegotiationNeeded(){}
      override fun onTrack(transceiver:RtpTransceiver){val track=transceiver.receiver.track() as? VideoTrack?:return;main.post{if(running){track.addSink(target);status="Direct actif"}}}
    })?:error("Connexion indisponible")
    val p=peer;p.addTransceiver(MediaStreamTrack.MediaType.MEDIA_TYPE_VIDEO,RtpTransceiver.RtpTransceiverInit(RtpTransceiver.RtpTransceiverDirection.RECV_ONLY))
    status="Connexion au relais…";withTimeout(15000){description(p,offer(p),true)};withTimeoutOrNull(8000){while(p.iceGatheringState()!=PeerConnection.IceGatheringState.COMPLETE)delay(100)}
    val answer=whep(t,p.localDescription.description);resource=answer.second;withTimeout(15000){description(p,SessionDescription(SessionDescription.Type.ANSWER,answer.first),false)}
    delay((t.expiry-System.currentTimeMillis()-2000).coerceAtLeast(1));status="Session vidéo expirée — rouvrir le direct"
   }catch(e:CancellationException){throw e}catch(e:Exception){status="Direct indisponible"}finally{running=false;peer?.close();peer?.dispose();factory?.dispose();withContext(NonCancellable){val t=ticket;if(t!=null){resource?.let{runCatching{deleteWhep(t,it)}};runCatching{latest(obj("action" to "security_live_revoke","session" to t.session))}}}}
  }
 }
 Text(status);OutlinedButton({active=!active;if(!active)status="Direct désactivé"}){Text(if(active)"Fermer le direct" else "Voir en direct")}
}
