package cm.naxa.grillad
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.os.SystemClock
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import java.io.ByteArrayOutputStream
import org.json.JSONObject
import java.time.Instant
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
@Suppress("MissingPermission")
private suspend fun freshPosition(context:Context):Location=withTimeout(16000){
 val manager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
 require(context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED){"Localisation précise nécessaire"}
 val provider=listOf(LocationManager.GPS_PROVIDER,LocationManager.NETWORK_PROVIDER).firstOrNull{manager.isProviderEnabled(it)}?:error("Localisation désactivée")
 if(Build.VERSION.SDK_INT>=30){suspendCancellableCoroutine{continuation->
  val signal=CancellationSignal();continuation.invokeOnCancellation{signal.cancel()}
  manager.getCurrentLocation(provider,signal,context.mainExecutor){loc->if(continuation.isActive){if(loc!=null&&loc.hasAccuracy()&&!loc.isFromMockProvider&&SystemClock.elapsedRealtimeNanos()-loc.elapsedRealtimeNanos in 0..15_000_000_000L)continuation.resume(loc)else continuation.resumeWithException(IllegalStateException("Position récente indisponible"))}}
 }}else{
  val loc=manager.getLastKnownLocation(provider)?:error("Position récente indisponible")
  require(loc.hasAccuracy()&&!loc.isFromMockProvider&&SystemClock.elapsedRealtimeNanos()-loc.elapsedRealtimeNanos in 0..15_000_000_000L){"Position trop ancienne"};loc
 }
}
@Composable internal fun GrilladAttendance(attendance:JSONObject?,enabled:Boolean,onProof:(JSONObject)->Unit){
 val context=LocalContext.current;val scope=rememberCoroutineScope();var kind by remember{mutableStateOf("arrival")};var working by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 val capture=rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()){bitmap->
  if(bitmap==null){working=false;msg="Photo annulée. Aucun pointage envoyé."}else scope.launch{try{
   val at=Instant.now().toString();val pos=freshPosition(context);val output=ByteArrayOutputStream()
   val scale=minOf(1.0,640.0/maxOf(bitmap.width,bitmap.height));val resized=if(scale<1)Bitmap.createScaledBitmap(bitmap,(bitmap.width*scale).toInt().coerceAtLeast(1),(bitmap.height*scale).toInt().coerceAtLeast(1),true)else bitmap
   resized.compress(Bitmap.CompressFormat.JPEG,72,output);val bytes=output.toByteArray();require(bytes.size in 16..350000){"Photo invalide"}
   onProof(obj("kind" to kind,"at" to at,"lat" to pos.latitude,"lon" to pos.longitude,"accuracy" to pos.accuracy.toDouble(),"photo" to Base64.encodeToString(bytes,Base64.NO_WRAP)))
   bytes.fill(0);if(resized!==bitmap)resized.recycle()
  }catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){msg=e.message?:"Preuve incomplète. Aucun pointage envoyé."}finally{bitmap.recycle();working=false}}
 }
 fun openCamera(){working=true;msg="";try{capture.launch(null)}catch(e:Exception){working=false;msg="Caméra indisponible"}}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){grants->if(grants[Manifest.permission.ACCESS_FINE_LOCATION]==true)openCamera()else{working=false;msg="Autorisation de localisation précise nécessaire."}}
 if(attendance?.optBoolean("enabled")!=true){Text("Pointage indisponible : politique du site non activée ou serveur non raccordé.");return}
 Text("Une position GPS et une photo uniquement au pointage. Pas de suivi continu. La confirmation dépend du serveur.")
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){listOf("arrival" to "Arrivée","departure" to "Départ").forEach{(k,label)->OutlinedButton({kind=k},enabled=enabled&&!working){Text(if(kind==k)"✓ "+label else label)}}}
 Button({working=true;if(context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)openCamera()else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION))},enabled=enabled&&!working,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text(if(working)"Capture en cours…" else "Prendre la photo et pointer")}
 if(msg.isNotBlank())Text(msg)
 Text("Historique confirmé",style=MaterialTheme.typography.titleMedium)
 rows(attendance.optJSONArray("history")).forEach{x->OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){Text((if(x.optString("kind")=="arrival")"Arrivée" else "Départ")+" · "+x.optString("captured_at"));if(!x.isNull("duration_seconds"))Text("Durée : "+(x.optLong("duration_seconds")/60)+" min");Text(if(x.optBoolean("photo_available"))"Preuve privée" else "Preuve expirée ou indisponible")}}}
}
