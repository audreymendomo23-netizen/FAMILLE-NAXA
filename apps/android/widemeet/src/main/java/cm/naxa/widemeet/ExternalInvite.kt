package cm.naxa.widemeet
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.ui.graphics.asImageBitmap
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeEncoder
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.security.SecureRandom
import java.util.UUID
@Composable fun ExternalInvite(english:Boolean,gateway:RoomGateway,session:Session,roomId:String?=null,parentBusy:Boolean=false,onJoined:suspend (String)->Boolean={false}){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope();val clipboard=LocalClipboardManager.current
 var login by remember{mutableStateOf("")};var token by remember{mutableStateOf("")};var issued by remember{mutableStateOf("")};var pending by remember{mutableStateOf<JSONObject?>(null)};var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var busy by remember{mutableStateOf(false)};var failure by remember{mutableStateOf(false)}
 val scanner=rememberLauncherForActivityResult(ScanContract()){ result ->
  result.contents?.let { value ->
   val candidate=value.substringAfter("#invite=").trim()
   if(Regex("^[a-f0-9]{64}$").matches(candidate)){token=candidate;failure=false}else{token="";failure=true}
  }
 }
 suspend fun req(action:String,data:JSONObject)=gateway.request("external-invite",JSONObject().put("action",action).put("data",data),session) as JSONObject
 suspend fun refresh(){val a=req("list",JSONObject().put("room_id",roomId)).getJSONArray("items");items=(0 until a.length()).map{a.getJSONObject(it)}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;failure=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){failure=true}finally{busy=false}}}
 LaunchedEffect(roomId){if(roomId!=null)try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){failure=true}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){
 Text(if(roomId==null)tr("Rejoindre par invitation","Join by invitation")else tr("Inviter un compte extérieur","Invite an external account"),style=MaterialTheme.typography.titleMedium)
 if(failure)Text(tr("Invitation non confirmée.","Invitation not confirmed."),color=MaterialTheme.colorScheme.error)
 if(roomId==null){
  val scanPrompt=tr("Scannez le QR code de votre invitation","Scan your invitation QR code")
  TextButton(enabled=!busy,onClick={scanner.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE).setPrompt(scanPrompt).setBeepEnabled(false).setBarcodeImageEnabled(false))}){Text(tr("Scanner une invitation","Scan invitation"))}
  OutlinedTextField(token,{token=it.trim().substringAfter("#invite=")},enabled=!busy,label={Text(tr("Code d’invitation","Invitation code"))},modifier=Modifier.fillMaxWidth());Button(enabled=!busy&&!parentBusy&&Regex("^[a-f0-9]{64}$").matches(token),onClick={work{val x=req("redeem",JSONObject().put("token",token));require(onJoined(x.getString("room_id")));token=""}}){Text(tr("Rejoindre","Join"))}}
 else{OutlinedTextField(login,{login=it.take(70)},enabled=!busy&&pending==null,label={Text(tr("Identifiant WideMeet du destinataire","Recipient WideMeet ID"))},modifier=Modifier.fillMaxWidth());Button(enabled=!busy&&login.isNotBlank(),onClick={work{val d=pending?:JSONObject().put("room_id",roomId).put("invite_id",UUID.randomUUID().toString()).put("login_id",login.trim().uppercase()).put("token",ByteArray(32).also{SecureRandom().nextBytes(it)}.joinToString(""){"%02x".format(it.toInt() and 255)}).also{pending=it};req("issue",d);issued=d.getString("token");pending=null;login="";refresh()}}){Text(tr("Créer une invitation nominative","Create named invitation"))}
 if(issued.isNotEmpty()){
  val qr=remember(issued){BarcodeEncoder().encodeBitmap(issued,BarcodeFormat.QR_CODE,480,480).asImageBitmap()}
  Image(bitmap=qr,contentDescription=tr("QR code de l’invitation","Invitation QR code"),modifier=Modifier.size(220.dp))
  Text(tr("Transmettez ce code uniquement au destinataire.","Share this code only with the recipient."));Text(issued);TextButton(onClick={clipboard.setText(AnnotatedString(issued))}){Text(tr("Copier","Copy"))};TextButton(onClick={issued=""}){Text(tr("Masquer","Hide"))}}
 for(x in items){Text(x.getString("name")+" · "+when{!x.isNull("revoked_at")->tr("Révoquée","Revoked");!x.isNull("redeemed_at")->tr("Utilisée","Redeemed");else->tr("En attente","Pending")});if(x.isNull("revoked_at"))TextButton(enabled=!busy,onClick={work{req("revoke",JSONObject().put("room_id",roomId).put("invite_id",x.getString("id")));refresh()}}){Text(tr("Révoquer","Revoke"))}}
 }
 }}
}
