package cm.naxa.widemeet
import androidx.activity.compose.rememberLauncherForActivityResult
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.RoomGateway
import cm.naxa.widemeet.auth.Session
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable fun ConnectSource(english:Boolean,gateway:RoomGateway,session:Session,roomId:String,isHost:Boolean){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var state by remember{mutableStateOf<JSONObject?>(null)};var code by remember{mutableStateOf("")};var preview by remember{mutableStateOf<String?>(null)}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 val scanner=rememberLauncherForActivityResult(ScanContract()){result->result.contents?.let{value->val candidate=value.trim();if(candidate.startsWith("wm-connect:")&&Regex("^[a-f0-9]{64}$").matches(candidate.removePrefix("wm-connect:"))){code=candidate.removePrefix("wm-connect:");preview=null;error=false}else{code="";preview=null;error=true}}}
 suspend fun req(action:String,data:JSONObject=JSONObject()):JSONObject=gateway.request("connect",JSONObject().put("action",action).put("data",data.put("room_id",roomId)),session) as JSONObject
 suspend fun refresh(){state=req("source-status")}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){state=null;preview=null;error=true}finally{busy=false}}}
 LaunchedEffect(roomId,session.deviceId,busy){if(busy)return@LaunchedEffect;while(true){try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){state=null;preview=null;error=true};delay(4000)}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text("WideMeet Connect",style=MaterialTheme.typography.titleMedium)
 if(error)Text(tr("Affichage non confirmé ou indisponible.","Display unconfirmed or unavailable."),color=MaterialTheme.colorScheme.error)
 if(isHost)Button(enabled=!busy&&state!=null,onClick={work{req("policy",JSONObject().put("enabled",state?.optBoolean("enabled")!=true));refresh()}}){Text(if(state?.optBoolean("enabled")==true)tr("Interdire l’affichage distant","Disallow remote display")else tr("Autoriser l’affichage distant","Allow remote display"))}
 val receiver=state?.optString("receiver_name","").orEmpty()
 if(receiver.isNotEmpty()){Text(tr("Récepteur autorisé : ","Authorized display: ")+receiver);Button(enabled=!busy,onClick={work{req("source-stop");refresh()}}){Text(tr("Arrêter l’affichage","Stop display"))}}
 else if(state?.optBoolean("enabled")==true){
 TextButton(enabled=!busy,onClick={scanner.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE).setPrompt(tr("Scannez le QR Connect","Scan Connect QR")).setBeepEnabled(false).setBarcodeImageEnabled(false))}){Text(tr("Scanner l’écran","Scan display"))}
 OutlinedTextField(code,{code=it.trim().lowercase().removePrefix("wm-connect:");preview=null},enabled=!busy,label={Text(tr("Code de l’écran","Display code"))})
 Button(enabled=!busy&&Regex("^[a-f0-9]{64}$").matches(code),onClick={work{preview=req("preview",JSONObject().put("code",code)).getString("receiver_name")}}){Text(tr("Vérifier l’écran","Check display"))}
 preview?.let{name->Text(tr("Confirmer cet écran : ","Confirm this display: ")+name);Button(enabled=!busy,onClick={work{req("confirm",JSONObject().put("code",code).put("receiver_name",name));preview=null;code="";refresh()}}){Text(tr("Confirmer l’appairage","Confirm pairing"))}}
 }else Text(tr("L’organisateur doit autoriser l’affichage distant.","The organizer must allow remote display."))
 }}
}
