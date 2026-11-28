package cm.naxa.naxasecurity
import android.util.Base64
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.UUID
import java.security.MessageDigest
@Composable internal fun SecurityNativeEvidenceShare(screen:String){
 if(screen!="B6.23")return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope();val context=LocalContext.current
 var rows by remember(g){mutableStateOf<List<JSONObject>>(emptyList())};var evidence by remember(g){mutableStateOf("")};var recipient by remember(g){mutableStateOf("")};var minutes by remember(g){mutableStateOf("60")};var status by remember(g){mutableStateOf("")};var busy by remember(g){mutableStateOf(false)};var pending by remember(g){mutableStateOf<Pair<String,String>?>(null)};var bytes by remember(g){mutableStateOf<ByteArray?>(null)}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")){uri->val data=bytes;bytes=null;if(uri!=null&&data!=null&&n.generation==g){scope.launch{try{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(data)}?:error("output")};if(n.generation==g)status="Preuve enregistrée."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Enregistrement non confirmé."}finally{data.fill(0)}}}else data?.fill(0)}
 DisposableEffect(g){onDispose{bytes?.fill(0)}}
 fun run(op:String,id:String?=null){if(busy)return;busy=true;scope.launch{try{val p=JSONObject().put("p_op",op);if(op=="create"){val sig=evidence+":"+recipient+":"+minutes;val k=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to k;p.put("p_id",k).put("p_evidence",SecurityNativeContract.uuid(evidence.trim())).put("p_recipient",SecurityNativeContract.uuid(recipient.trim())).put("p_minutes",minutes.toInt())}else if(id!=null)p.put("p_id",id);val v=SecurityNativeApi.evidenceShare(s,site,p);if(n.generation==g){if(op=="list"){val a=v.getJSONArray("shares");rows=(0 until a.length()).map{a.getJSONObject(it)}.filter{it.optString("owner_id")==s.user||it.optString("recipient_id")==s.user}}else{check(v.optString("owner_id")==s.user&&v.optString("id")==p.optString("p_id"));pending=null;rows=emptyList()};status="Partage confirmé : "+op}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Partage refusé ou indisponible."}finally{if(n.generation==g)busy=false}}}
 fun download(id:String){if(busy||bytes!=null)return;busy=true;scope.launch{try{val v=SecurityNativeApi.evidenceShareDownload(s,site,id);val raw=v.getString("base64");check(raw.length<=350000);val data=Base64.decode(raw,Base64.DEFAULT);check(data.size in 1..262144);val digest=MessageDigest.getInstance("SHA-256").digest(data).joinToString(""){"%02x".format(it.toInt() and 255)};check(digest==v.getString("digest"));if(n.generation==g){bytes=data;save.launch("security-shared-evidence.bin");status="Intégrité vérifiée."}else data.fill(0)}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){bytes?.fill(0);bytes=null;status="Téléchargement refusé ou intégrité non vérifiée."}}finally{if(n.generation==g)busy=false}}}
 Text("Partage nominatif temporaire — aucun lien public");Text("Révocation des accès futurs uniquement, pas des copies déjà enregistrées.")
 OutlinedTextField(evidence,{evidence=it},label={Text("Identifiant de ma preuve")});OutlinedTextField(recipient,{recipient=it},label={Text("Identifiant destinataire")});OutlinedTextField(minutes,{minutes=it},label={Text("Validité en minutes")})
 Button(enabled=!busy&&evidence.isNotBlank()&&recipient.isNotBlank()&&minutes.toIntOrNull()?.let{it in 1..1440}==true,onClick={run("create")}){Text("Partager la preuve")}
 Button(enabled=!busy,onClick={run("list")}){Text("Actualiser les partages")}
 rows.forEach{r->Text(r.optString("reference")+" · "+r.optString("expires_at"));if(r.isNull("revoked_at")&&r.optString("owner_id")==s.user)Button(enabled=!busy,onClick={run("revoke",r.getString("id"))}){Text("Révoquer")};if(r.isNull("revoked_at")&&r.optString("recipient_id")==s.user)Button(enabled=!busy&&bytes==null,onClick={download(r.getString("id"))}){Text("Télécharger et vérifier")}}
 Text(status)
}
