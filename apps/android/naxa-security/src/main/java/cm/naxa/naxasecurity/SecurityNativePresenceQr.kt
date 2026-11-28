package cm.naxa.naxasecurity
import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.Instant
import java.util.UUID
private data class QrPending(val key:String,val event:String,val detail:JSONObject)
@Composable internal fun SecurityNativePresenceQr(screen:String){
 if(screen!="B4.09")return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val context=LocalContext.current;val scope=rememberCoroutineScope()
 var shifts by remember(g){mutableStateOf<List<JSONObject>>(emptyList())};var shift by remember(g){mutableStateOf("")};var action by remember(g){mutableStateOf("arrival")};var issued by remember(g){mutableStateOf("")};var expires by remember(g){mutableLongStateOf(0)};var code by remember(g){mutableStateOf("")};var status by remember(g){mutableStateOf("")};var busy by remember(g){mutableStateOf(false)};var pending by remember(g){mutableStateOf<QrPending?>(null)}
 val valid=securityTemporaryQrPattern
 fun run(op:String){if(busy)return;busy=true;scope.launch{try{if(op=="load"){val v=SecurityNativeApi.records(s,site,"sec_shifts");if(n.generation==g){shifts=v.filter{it.optString("agent_id")!=s.user&&it.optString("state")=="accepted"};status="Vacations chargées."};return@launch}
 val target=if(op=="issue")shift else code.substringBefore(".");val key=op+":"+target+":"+(if(op=="issue")action else code)
 val e=pending?.takeIf{it.key==key}?:kotlin.run{val detail=if(op=="issue")JSONObject().put("token",securityPassToken()).put("action",action)else{check(valid.matches(code));val p=securityFreshLocation(context);check(!p.isFromMockProvider);JSONObject().put("token",code.substringAfter(".")).put("lat",p.latitude).put("lon",p.longitude).put("accuracy_m",p.accuracy.toDouble()).put("observed_at",Instant.ofEpochMilli(p.time).toString()).put("source","android").put("mock_reported",false)};QrPending(key,UUID.randomUUID().toString(),detail)}
 if(n.generation!=g)return@launch
 pending=e;val v=SecurityNativeApi.presenceQr(s,site,e.event,op,target,e.detail)
 if(n.generation==g){if(op=="issue"){check(v.optString("challenge_id")==e.event&&v.optString("shift_id")==target&&v.optString("state")=="issued");expires=Instant.parse(v.getString("expires_at")).toEpochMilli();check(expires>System.currentTimeMillis());issued=e.event+"."+e.detail.getString("token");status="QR de pointage émis."}else{check(v.optString("challenge_id")==target&&v.optString("state")=="pending_review"&&!v.isNull("draft_id"));code="";status="Pointage QR reçu — en attente de revue."};pending=null}
 }catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Opération refusée ou non confirmée."}finally{if(n.generation==g)busy=false}}}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){p->if(p[Manifest.permission.ACCESS_FINE_LOCATION]==true&&n.generation==g)run("consume")else status="Autorisation GPS nécessaire."}
 val scan=rememberLauncherForActivityResult(ScanContract()){r->if(n.generation==g&&r.contents!=null){val raw=r.contents.orEmpty();if(valid.matches(raw))code=raw else status="QR invalide."}}
 LaunchedEffect(issued,expires){if(issued.isNotBlank()&&expires>0){delay((expires-System.currentTimeMillis()).coerceAtLeast(0));issued="";expires=0}}
 Text("Pointage QR à usage unique");Text("QR nominatif, deux minutes maximum. Position ponctuelle, non certifiée.")
 Button(enabled=!busy,onClick={run("load")}){Text("Charger les vacations d’équipe")}
 shifts.forEach{r->FilterChip(selected=shift==r.optString("id"),enabled=!busy,onClick={shift=r.getString("id");issued=""},label={Text(r.optString("label")+" · "+r.optString("agent_id"))})}
 listOf("arrival","departure","pause_start","pause_end").forEach{k->FilterChip(selected=action==k,enabled=!busy,onClick={action=k;issued=""},label={Text(k)})}
 Button(enabled=!busy&&shift.isNotBlank(),onClick={run("issue")}){Text("Émettre le QR nominatif")}
 if(issued.isNotBlank()){val image=remember(issued){runCatching{securityTemporaryQrBitmap(issued).asImageBitmap()}.getOrNull()};image?.let{Image(it,contentDescription="QR de pointage",modifier=Modifier.size(240.dp))};OutlinedTextField(issued,{},readOnly=true,label={Text("Code QR de pointage")})}
 Button(enabled=!busy,onClick={scan.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE).setBeepEnabled(false).setBarcodeImageEnabled(false))}){Text("Scanner le QR")}
 OutlinedTextField(code,{code=it},enabled=!busy,label={Text("Code de pointage")})
 Button(enabled=!busy&&valid.matches(code),onClick={if(ContextCompat.checkSelfPermission(context,Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)run("consume")else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION))}){Text("Confirmer le QR et la position")}
 Text(status)
}
