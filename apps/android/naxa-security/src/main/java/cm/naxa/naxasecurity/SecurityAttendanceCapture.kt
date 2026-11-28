package cm.naxa.naxasecurity
import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import java.time.Instant
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@SuppressLint("MissingPermission")
internal suspend fun securityFreshLocation(context:Context):Location=withTimeout(25000){
 suspendCancellableCoroutine{c->
  val manager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
  val listener=object:LocationListener{
   override fun onLocationChanged(location:Location){
    if(location.hasAccuracy()&&location.accuracy>0&&location.accuracy<=100&&!location.isFromMockProvider&&System.currentTimeMillis()-location.time in 0L..120000L){
     manager.removeUpdates(this);if(c.isActive)c.resume(location)
    }
   }
   override fun onProviderEnabled(provider:String){}
   override fun onProviderDisabled(provider:String){manager.removeUpdates(this);if(c.isActive)c.resumeWithException(IllegalStateException("GPS unavailable"))}
   @Deprecated("Deprecated in Java") override fun onStatusChanged(provider:String?,status:Int,extras:android.os.Bundle?){}
  }
  c.invokeOnCancellation{manager.removeUpdates(listener)}
  try{manager.requestLocationUpdates(LocationManager.GPS_PROVIDER,0L,0f,listener,Looper.getMainLooper())}catch(e:Exception){if(c.isActive)c.resumeWithException(e)}
 }
}

@Composable
internal fun SecurityAttendanceCapture(id:String){
 val context=LocalContext.current
 val scope=rememberCoroutineScope()
 var busy by remember(id){mutableStateOf(false)}
 var message by remember(id){mutableStateOf("")}
 var proof by remember(id){mutableStateOf<Location?>(null)}
 val native=LocalSecurityNative.current;val generation=native.generation
 var action by remember(id,generation){mutableStateOf("arrival")}
 var pending by remember(id,generation){mutableStateOf("")}
 LaunchedEffect(generation){proof=null;message="";pending=""}
 fun capture(){if(busy)return;busy=true;proof=null;message="";scope.launch{
  try{val p=securityFreshLocation(context);if(native.generation==generation){proof=p;pending=UUID.randomUUID().toString();message="Preuve GPS capturée — non transmise."}}
  catch(c:CancellationException){throw c}catch(_:Exception){message="Capture indisponible ou précision insuffisante."}finally{busy=false}
 }}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){granted->if(granted[Manifest.permission.ACCESS_FINE_LOCATION]==true)capture()else message="Autorisation GPS précise nécessaire."}
 Text("Capture ponctuelle — aucun suivi permanent")
 listOf("arrival","departure").forEach{v->FilterChip(selected=action==v,enabled=!busy,onClick={action=v;proof=null;pending="";message=""},label={Text(if(v=="arrival")"Arrivée" else "Départ")})}
 Button(enabled=!busy,onClick={if(ContextCompat.checkSelfPermission(context,Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)capture()else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION))}){Text("Capturer ma position")}
 proof?.let{p->Text("Précision : "+p.accuracy+" m");Text("État : preuve locale non confirmée");val s=native.session;val site=native.site;if(s!=null&&site!=null)Button(enabled=!busy&&pending.isNotBlank(),onClick={busy=true;val rid=pending;val a=action;scope.launch{try{check(!p.isFromMockProvider);val ok=SecurityNativeApi.submitAttendance(s,site,a,p.latitude,p.longitude,p.accuracy,p.time,rid);if(native.generation==generation){message=if(ok)"Preuve reçue — statut à consulter." else "Réception non confirmée.";if(ok){proof=null;pending=""}}}catch(e:CancellationException){throw e}catch(_:Exception){if(native.generation==generation)message="Réception non confirmée ou preuve expirée."}finally{busy=false}}}){Text("Transmettre la preuve GPS")}}
 Text(message)
}
