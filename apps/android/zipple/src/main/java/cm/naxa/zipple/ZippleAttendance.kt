package cm.naxa.zipple
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
private suspend fun zippleFreshLocation(context:Context):Location=withTimeout(25000){
 suspendCancellableCoroutine{c->
  val manager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
  val listener=object:LocationListener{
   override fun onLocationChanged(location:Location){
    if(location.hasAccuracy()&&location.accuracy>0&&location.accuracy<=500&&!location.isFromMockProvider&&kotlin.math.abs(System.currentTimeMillis()-location.time)<=120000){
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
internal fun ZippleAttendance(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var data by remember{mutableStateOf<JSONObject?>(null)}
 var busy by remember{mutableStateOf(false)}
 var message by remember{mutableStateOf("")}
 var action by remember{mutableStateOf("clock_in")}
 var pending by remember{mutableStateOf<JSONObject?>(null)}
 suspend fun load(){data=api.call(session,site,"attendance_snapshot") as? JSONObject}
 fun label(v:String)=if(v=="clock_in")tr("Prise de service","Start shift")else tr("Fin de service","End shift")
 fun submit(){if(busy)return;busy=true;message="";scope.launch{
  try{
   val old=pending
   val body=if(old!=null&&old.optString("event_type")==action&&kotlin.math.abs(System.currentTimeMillis()-Instant.parse(old.getString("gps_at")).toEpochMilli())<=120000)old else {
    val p=zippleFreshLocation(context)
    JSONObject().put("request_id",UUID.randomUUID().toString()).put("event_type",action).put("latitude",p.latitude).put("longitude",p.longitude).put("accuracy_m",p.accuracy.toDouble()).put("gps_at",Instant.ofEpochMilli(p.time).toString()).also{pending=it}
   }
   val response=api.call(session,site,"attendance_record",body) as? JSONObject
   require(!response?.optString("id").isNullOrBlank());pending=null;load();message=tr("Pointage enregistré","Attendance recorded")
  }catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Pointage non confirmé. Vérifiez la position et la connexion.","Attendance unconfirmed. Check location and connection.");try{load()}catch(c:CancellationException){throw c}catch(_:Exception){}}finally{busy=false}
 }}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){granted->if(granted[Manifest.permission.ACCESS_FINE_LOCATION]==true)submit()else message=tr("Autorisation GPS nécessaire","Location permission required")}
 fun request(v:String){action=v;if(ContextCompat.checkSelfPermission(context,Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)submit()else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION))}
 LaunchedEffect(session.token,site){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Pointage indisponible","Attendance unavailable")}}
 Text(tr("Pointage géolocalisé","Location attendance"))
 Text(tr("Position uniquement au pointage, sans suivi permanent.","Location only when clocking, no continuous tracking."))
 OutlinedButton(enabled=!busy,onClick={scope.launch{try{load()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Pointage indisponible","Attendance unavailable")}}}){Text(tr("Actualiser le pointage","Refresh attendance"))}
 if(message.isNotBlank())Text(message)
 data?.let{r->
  Text(if(r.optBoolean("on_shift"))if(r.optBoolean("on_this_site"))tr("Service en cours","Shift active")else tr("Service ouvert dans un autre établissement","Shift active at another site")else tr("Hors service","Off duty"))
  Button(enabled=!busy&&!r.optBoolean("on_shift"),onClick={request("clock_in")}){Text(label("clock_in"))}
  Button(enabled=!busy&&r.optBoolean("on_this_site"),onClick={request("clock_out")}){Text(label("clock_out"))}
  Text(tr("Mes pointages récents","My recent attendance"))
  r.rows("mine").forEach{x->Text(label(x.optString("event_type"))+" · "+x.optString("recorded_at")+" · "+x.optString("latitude")+", "+x.optString("longitude")+" (±"+x.optString("accuracy_m")+" m)")}
  if(r.optBoolean("can_manage")){Text(tr("Pointages récents de l’équipe","Recent team attendance"));r.rows("team").forEach{x->Text(x.optString("login_id")+" · "+label(x.optString("event_type"))+" · "+x.optString("recorded_at")+" · "+x.optString("latitude")+", "+x.optString("longitude")+" (±"+x.optString("accuracy_m")+" m)")}}
 }
}
