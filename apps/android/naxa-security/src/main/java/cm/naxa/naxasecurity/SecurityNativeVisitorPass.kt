package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.dp
import androidx.activity.compose.rememberLauncherForActivityResult
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import android.graphics.Bitmap
import kotlinx.coroutines.delay
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
import java.security.SecureRandom
internal fun securityPassToken():String=ByteArray(32).also{SecureRandom().nextBytes(it)}.joinToString(""){ "%02x".format(it.toInt() and 255) }
private data class PassPending(val signature:String,val event:String,val detail:JSONObject)
@Composable internal fun SecurityNativeVisitorPass(screen:String){
 if(screen !in setOf("B4.20","B4.22","B4.25","B4.26","B4.28","B4.29"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var register by remember(screen,g){mutableStateOf("")};var code by remember(screen,g){mutableStateOf("")};var issued by remember(screen,g){mutableStateOf("")};var expires by remember(screen,g){mutableLongStateOf(0L)};var minutes by remember(screen,g){mutableStateOf("30")};var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")};var pending by remember(screen,g){mutableStateOf<PassPending?>(null)}
 fun act(op:String,target:String){if(busy)return;busy=true;scope.launch{try{
 val signature=op+":"+target+":"+(if(op=="issue")minutes else if(op=="consume"||op=="consume_entry")code else "")
 val e=pending?.takeIf{it.signature==signature}?:PassPending(signature,UUID.randomUUID().toString(),when(op){"issue"->JSONObject().put("token",securityPassToken()).put("minutes",minutes.toInt());"consume","consume_entry"->JSONObject().put("token",code.substringAfter("."));else->JSONObject()});pending=e
 val v=SecurityNativeApi.visitPass(s,site,e.event,op,target,e.detail)
 if(n.generation==g){if(op=="issue"){expires=java.time.Instant.parse(v.getString("expires_at")).toEpochMilli();check(expires>System.currentTimeMillis());issued=v.getString("pass_id")+"."+e.detail.getString("token")} else code="";pending=null;rows=emptyList();status="Contrôle de passage : "+v.optString("state")+" — aucune ouverture physique."}
 }catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Passage refusé ou non confirmé."}finally{if(n.generation==g)busy=false}}}
 val valid=Regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\\.[a-f0-9]{64}$")
 val scanner=rememberLauncherForActivityResult(ScanContract()){result->if(n.generation==g){val raw=result.contents;if(raw!=null&&valid.matches(raw)){code=raw;status="QR lu. Confirmez au serveur."}else if(raw!=null)status="QR invalide."}}
 LaunchedEffect(issued,expires){if(issued.isNotBlank()&&expires>0){delay((expires-System.currentTimeMillis()).coerceAtLeast(0));issued="";expires=0;status="Code expiré."}}
 Text("Code temporaire de contrôle manuel");Text("Usage unique, aucune ouverture physique. L’agent applique les consignes du site.")
 OutlinedTextField(register,{register=it},enabled=!busy,label={Text("Identifiant du registre examiné")})
 OutlinedTextField(minutes,{minutes=it},enabled=!busy,label={Text("Validité en minutes")})
 Button(enabled=!busy&&register.isNotBlank()&&minutes.toIntOrNull()?.let{it in 1..120}==true,onClick={act("issue",register.trim())}){Text("Créer un code temporaire")}
 if(issued.isNotEmpty()){val image=remember(issued){runCatching{val matrix=QRCodeWriter().encode(issued,BarcodeFormat.QR_CODE,280,280);val pixels=IntArray(280*280){i->if(matrix[i%280,i/280])android.graphics.Color.BLACK else android.graphics.Color.WHITE};Bitmap.createBitmap(pixels,280,280,Bitmap.Config.ARGB_8888).asImageBitmap()}.getOrNull()};image?.let{Image(it,contentDescription="QR du code temporaire",modifier=Modifier.size(240.dp))};OutlinedTextField(issued,{},readOnly=true,label={Text("Code à transmettre")});Button(onClick={issued=""}){Text("Masquer le code")}}
 Button(enabled=!busy,onClick={scanner.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE).setPrompt("Scanner le QR temporaire").setBeepEnabled(false).setBarcodeImageEnabled(false))}){Text("Scanner le QR")}
 OutlinedTextField(code,{code=it},enabled=!busy,label={Text("Code de passage")})
 Button(enabled=!busy&&Regex("^[a-f0-9-]{36}\\.[a-f0-9]{64}$").matches(code),onClick={act("consume",code.substringBefore("."))}){Text("Vérifier et consommer le code")}
 Button(enabled=!busy&&valid.matches(code),onClick={act("consume_entry",code.substringBefore("."))}){Text("Vérifier le QR et consigner l’entrée")}
 Button(enabled=!busy,onClick={busy=true;scope.launch{try{val v=SecurityNativeApi.records(s,site,"sec_visit_passes");if(n.generation==g)rows=v}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){rows=emptyList();status="Lecture refusée."}}finally{if(n.generation==g)busy=false}}}){Text("Actualiser les codes")}
 rows.forEach{r->Text(r.optString("id")+" · "+r.optString("expires_at")+" · "+(if(!r.isNull("revoked_at"))"Révoqué" else if(!r.isNull("used_at"))"Utilisé" else "Non utilisé"));if(r.isNull("used_at")&&r.isNull("revoked_at"))Button(enabled=!busy,onClick={act("revoke",r.optString("id"))}){Text("Révoquer le code")}}
 Text(status)
}
