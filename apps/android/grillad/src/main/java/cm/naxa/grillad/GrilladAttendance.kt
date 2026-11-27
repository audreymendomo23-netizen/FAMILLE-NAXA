package cm.naxa.grillad
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
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
@Composable internal fun GrilladAttendance(attendance:JSONObject?,enabled:Boolean,onPhoto:suspend(String)->String,userId:String,manager:Boolean,onCorrection:(String,JSONObject)->Unit,onProof:(JSONObject)->Unit){
 val context=LocalContext.current;val scope=rememberCoroutineScope();var kind by remember{mutableStateOf("arrival")};var working by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")};var photo by remember{mutableStateOf<Pair<String,Bitmap>?>(null)};var correctionSeconds by remember{mutableStateOf("")};var correctionReason by remember{mutableStateOf("")};var decisionReason by remember{mutableStateOf("")}
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
 OutlinedButton({kind="departure_without_arrival"},enabled=enabled&&!working){Text(if(kind=="departure_without_arrival")"✓ Départ sans arrivée" else "Départ sans arrivée")}
 Button({working=true;if(context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)openCamera()else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION))},enabled=enabled&&!working,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text(if(working)"Capture en cours…" else "Prendre la photo et pointer")}
 if(msg.isNotBlank())Text(msg)
 Text("Historique confirmé",style=MaterialTheme.typography.titleMedium)
 rows(attendance.optJSONArray("history")).forEach{x->OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){Text((when(x.optString("kind")){"arrival"->"Arrivée";"departure_without_arrival"->"Départ sans arrivée";else->"Départ"})+" · "+x.optString("captured_at"));if(!x.isNull("duration_seconds")){Text("Durée constatée : "+x.optLong("duration_seconds")+" s · retenue : "+x.optLong("effective_duration_seconds",x.optLong("duration_seconds"))+" s");if(x.optString("actor")==userId&&x.optLong("duration_seconds")>0&&rows(attendance.optJSONArray("corrections")).none{c->c.optString("departure")==x.optString("id")&&c.optString("status") in listOf("pending","approved")}){OutlinedTextField(correctionSeconds,{correctionSeconds=it},label={Text("Durée corrigée (secondes)")});OutlinedTextField(correctionReason,{correctionReason=it},label={Text("Motif de régularisation")});TextButton({onCorrection("attendance_request",obj("departure" to x.optString("id"),"seconds" to correctionSeconds.toLongOrNull(),"reason" to correctionReason))},enabled=enabled){Text("Demander une correction")}}};if(x.optBoolean("open_arrival")&&x.optString("actor")==userId&&rows(attendance.optJSONArray("missing_departures")).none{m->m.optString("arrival")==x.optString("id")&&m.optString("status") in listOf("pending","approved")}){var duration by remember(x.optString("id")){mutableStateOf("")};var why by remember(x.optString("id")){mutableStateOf("")};Text("Départ oublié : déclaration sans preuve GPS/photo.");OutlinedTextField(duration,{duration=it},label={Text("Durée déclarée (secondes)")});OutlinedTextField(why,{why=it},label={Text("Motif du départ manquant")});Button({onCorrection("missing_departure_request",obj("arrival" to x.optString("id"),"seconds" to duration.toLongOrNull(),"reason" to why))},enabled=enabled&&duration.toLongOrNull()?.let{it>0}==true&&why.isNotBlank()){Text("Déclarer le départ manquant")}};Text(if(x.optBoolean("photo_available"))"Preuve privée" else "Preuve expirée ou indisponible");if(x.optBoolean("photo_available"))TextButton({working=true;photo=null;scope.launch{try{val bytes=Base64.decode(onPhoto(x.optString("id")),Base64.DEFAULT);try{val bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.size)?:error("Photo invalide");photo=x.optString("id") to bitmap}finally{bytes.fill(0)}}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){msg="Preuve non disponible ou accès refusé"}finally{working=false}}},enabled=enabled&&!working){Text("Consulter la preuve")};photo?.takeIf{it.first==x.optString("id")}?.let{p->Image(p.second.asImageBitmap(),contentDescription="Preuve de pointage autorisée",modifier=Modifier.fillMaxWidth().heightIn(max=350.dp));TextButton({photo=null}){Text("Fermer la preuve")}}}}}
 Text("Régularisations",style=MaterialTheme.typography.titleMedium)
 rows(attendance.optJSONArray("corrections")).forEach{c->OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){Text(c.optString("proposed_seconds")+" s · "+c.optString("reason"));Text(when(c.optString("status")){"approved"->"Approuvée";"rejected"->"Refusée";else->"En attente"});if(!c.isNull("decision_reason"))Text(c.optString("decision_reason"));if(manager&&c.optString("requester")!=userId&&c.optString("status")=="pending"){OutlinedTextField(decisionReason,{decisionReason=it},label={Text("Motif de décision")});Row{TextButton({onCorrection("attendance_decide",obj("request" to c.optString("id"),"decision" to "approved","reason" to decisionReason))},enabled=enabled){Text("Approuver")};TextButton({onCorrection("attendance_decide",obj("request" to c.optString("id"),"decision" to "rejected","reason" to decisionReason))},enabled=enabled){Text("Refuser")}}}}}}

 GrilladMissingArrivals(attendance,userId,manager,enabled,onCorrection)
 Text("Départs manquants déclarés",style=MaterialTheme.typography.titleMedium)
 rows(attendance.optJSONArray("missing_departures")).forEach{m->key(m.optString("id")){var why by remember{mutableStateOf("")};OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){Text("Déclaration manuelle sans preuve de départ · "+m.optString("seconds")+" s · "+m.optString("reason"));Text(when(m.optString("status")){"approved"->"Approuvée";"rejected"->"Refusée";else->"En attente"});if(!m.isNull("decision_reason"))Text(m.optString("decision_reason"));if(manager&&m.optString("requester")!=userId&&m.optString("status")=="pending"){OutlinedTextField(why,{why=it},label={Text("Motif de décision départ manquant")});Row{TextButton({onCorrection("missing_departure_decide",obj("request" to m.optString("id"),"decision" to "approved","reason" to why))},enabled=enabled&&why.isNotBlank()){Text("Approuver")};TextButton({onCorrection("missing_departure_decide",obj("request" to m.optString("id"),"decision" to "rejected","reason" to why))},enabled=enabled&&why.isNotBlank()){Text("Refuser")}}}}}}}

}
