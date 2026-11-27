package cm.naxa.widemeet
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

private fun evidenceRows(a:JSONArray?):List<JSONObject> = if(a==null)emptyList() else (0 until a.length()).mapNotNull{a.optJSONObject(it)}
@Composable fun ArchiveEvidence(english:Boolean,gateway:RoomGateway,session:Session,roomId:String,canManage:Boolean){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var presence by remember(roomId){mutableStateOf<JSONObject?>(null)};var audio by remember(roomId){mutableStateOf<List<JSONObject>>(emptyList())};var presenceError by remember{mutableStateOf(false)};var audioError by remember{mutableStateOf(false)}
 var busy by remember{mutableStateOf(false)};var downloadError by remember{mutableStateOf(false)};var pending by remember{mutableStateOf<File?>(null)}
 val picker=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("audio/ogg")){uri->
  val file=pending;pending=null
  if(file!=null){if(uri==null){file.delete();busy=false}else scope.launch{try{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri,"w")?.use{out->file.inputStream().use{it.copyTo(out)}}?:error("output unavailable")}}catch(e:CancellationException){throw e}catch(e:Exception){downloadError=true}finally{file.delete();busy=false}}}
 }
 DisposableEffect(roomId){onDispose{pending?.delete()}}
 LaunchedEffect(roomId,session.deviceId){
  if(BuildConfig.WIDEMEET_PRESENCE_ENABLED)try{presence=gateway.request("presence",JSONObject().put("room_id",roomId),session) as JSONObject}catch(e:CancellationException){throw e}catch(e:Exception){presenceError=true}
  if(canManage&&BuildConfig.WIDEMEET_RECORDING_STORAGE_ENABLED)try{audio=evidenceRows((gateway.request("recordings",JSONObject().put("room_id",roomId),session) as JSONObject).optJSONArray("items"))}catch(e:CancellationException){throw e}catch(e:Exception){audioError=true}
 }
 if(BuildConfig.WIDEMEET_PRESENCE_ENABLED){
  Text(tr("Présences observées","Observed attendance"),style=MaterialTheme.typography.titleMedium)
  presence?.let{p->Text(tr("Durées estimées entre observations SFU, pas une preuve de présence humaine continue.","Estimated duration between SFU observations, not proof of continuous human attendance."));Text(tr("Observations","Samples")+": "+p.optInt("samples"));for(r in evidenceRows(p.optJSONArray("rows")))Text(r.optString("display_name")+" — "+if(r.optString("attendance")=="observed")(r.optLong("estimated_ms")/1000).toString()+" s · "+tr("Connexion observée","Connection observed")else tr("Inconnue","Unknown"))}
  if(presenceError)Text(tr("Registre de présence indisponible.","Attendance report unavailable."))
 }else Text(tr("Présences non qualifiées.","Attendance not qualified."))
 if(canManage&&BuildConfig.WIDEMEET_RECORDING_STORAGE_ENABLED){
  Text(tr("Segments audio privés","Private audio segments"),style=MaterialTheme.typography.titleMedium)
  for(item in audio){Text(item.optString("finished_at")+" · "+(item.optLong("bytes")/1024)+" Ko");TextButton(enabled=!busy,onClick={busy=true;downloadError=false;scope.launch{try{val file=gateway.downloadRecording(roomId,item,session,context.cacheDir);pending=file;picker.launch("widemeet-"+item.getString("recording_id")+".ogg")}catch(e:CancellationException){pending?.delete();pending=null;throw e}catch(e:Exception){pending?.delete();pending=null;downloadError=true;busy=false}}}){Text(tr("Télécharger","Download"))}}
  if(audioError)Text(tr("Archives audio indisponibles.","Audio archives unavailable."))else if(audio.isEmpty())Text(tr("Aucun segment disponible.","No segment available."))
  if(downloadError)Text(tr("Téléchargement non confirmé ou intégrité non vérifiée.","Download unconfirmed or integrity not verified."),color=MaterialTheme.colorScheme.error)
 }
}
