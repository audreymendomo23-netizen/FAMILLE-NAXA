package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import android.util.Base64
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.security.MessageDigest
import java.util.UUID
@Composable internal fun SecurityNativeEvidenceInventory(screen:String){
 if(screen !in setOf("B6.22","B6.25"))return
 val context=LocalContext.current
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var data by remember(screen,g){mutableStateOf<JSONObject?>(null)};var checks by remember(screen,g){mutableStateOf<Map<String,JSONObject>>(emptyMap())};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 var reference by remember(screen,g){mutableStateOf("")};var picked by remember(screen,g){mutableStateOf<ByteArray?>(null)};var output by remember(screen,g){mutableStateOf<ByteArray?>(null)};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)}
 DisposableEffect(screen,g){onDispose{picked?.fill(0);output?.fill(0)}}
 fun digest(bytes:ByteArray)=MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){"%02x".format(it.toInt() and 255)}
 val choose=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null&&n.generation==g&&!busy){busy=true;picked?.fill(0);picked=null;pending=null;scope.launch{try{val bytes=withContext(Dispatchers.IO){context.contentResolver.openInputStream(uri)?.use{input->val buffer=ByteArray(262145);var count=0;while(count<buffer.size){val k=input.read(buffer,count,buffer.size-count);if(k<0)break;if(k==0)error("empty read");count+=k};try{check(count in 1..262144);buffer.copyOf(count)}finally{buffer.fill(0)}}?:error("input unavailable")};if(n.generation==g){picked=bytes;status="Fichier sélectionné : "+bytes.size+" octets"}else bytes.fill(0)}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Fichier illisible ou supérieur à 256 Kio."}finally{if(n.generation==g)busy=false}}}}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")){uri->val bytes=output;output=null;if(uri!=null&&bytes!=null&&n.generation==g){scope.launch{try{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(bytes)}?:error("output unavailable")};if(n.generation==g)status="Preuve enregistrée et intégrité vérifiée."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Enregistrement non confirmé."}finally{bytes.fill(0)}}}else bytes?.fill(0)}
 fun upload(){val bytes=picked?:return;if(busy)return;busy=true;scope.launch{try{val hash=digest(bytes);val ref=reference.trim();check(ref.matches(Regex("^[A-Za-z0-9._-]{1,80}$")));val sig=ref+":"+hash;val id=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to id;SecurityNativeApi.storeEvidence(s,site,id,ref,hash,Base64.encodeToString(bytes,Base64.NO_WRAP));if(n.generation==g){bytes.fill(0);picked=null;pending=null;reference="";data=null;checks=emptyMap();status="Preuve enregistrée sur le serveur."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Enregistrement refusé ou non confirmé."}finally{if(n.generation==g)busy=false}}}
 fun download(id:String){if(busy||output!=null)return;busy=true;scope.launch{try{val v=SecurityNativeApi.personalEvidence(s,site,id);val raw=v.getString("base64");check(raw.length<=350000);val bytes=Base64.decode(raw,Base64.DEFAULT);if(bytes.size !in 1..262144||digest(bytes)!=v.getString("digest")){bytes.fill(0);error("integrity")};if(n.generation==g){output=bytes;save.launch("security-evidence.bin")}else bytes.fill(0)}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){output?.fill(0);output=null;status="Téléchargement refusé ou intégrité non vérifiée."}}finally{if(n.generation==g)busy=false}}}
 fun run(verify:String?=null,next:Boolean=false){if(busy)return;busy=true;scope.launch{try{val p=JSONObject();if(verify!=null)p.put("p_verify",verify) else if(next)data?.optJSONObject("next")?.let{p.put("p_before",it.getString("before")).put("p_before_id",it.getString("before_id"))};val v=SecurityNativeApi.evidenceInventory(s,site,p);if(n.generation==g){if(verify!=null){check(!v.optBoolean("denied"));val x=v.getJSONObject("verification");check(x.optString("id")==verify);checks=checks+(verify to x);status="Contrôle d’intégrité effectué."}else{v.getJSONArray("files");data=v;checks=emptyMap();status="Inventaire serveur confirmé."}}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){checks=emptyMap();status="Opération refusée ou indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Stockage personnel et intégrité");Text("Quota commercial non configuré. L'intégrité ne certifie pas l'authenticité de la scène.")
 if(screen=="B6.22"){OutlinedTextField(reference,{reference=it.take(80)},enabled=!busy,label={Text("Référence de preuve")});Button(enabled=!busy,onClick={choose.launch(arrayOf("*/*"))}){Text("Choisir un fichier")};picked?.let{Text(it.size.toString()+" octets sélectionnés")};Button(enabled=!busy&&picked!=null&&reference.trim().matches(Regex("^[A-Za-z0-9._-]{1,80}$")),onClick={upload()}){Text("Enregistrer la preuve")}}
 Button(enabled=!busy,onClick={run()}){Text("Charger le stockage")}
 data?.let{v->Text(v.optString("total_files")+" fichiers · "+v.optString("total_bytes")+" octets");val a=v.getJSONArray("files");(0 until a.length()).forEach{i->val r=a.getJSONObject(i);val id=r.getString("id");Text(r.optString("reference")+" · "+r.optString("size_bytes")+" octets");Button(enabled=!busy,onClick={run(id)}){Text("Vérifier côté serveur")};Button(enabled=!busy&&output==null,onClick={download(id)}){Text("Télécharger et vérifier")};checks[id]?.let{x->Text(if(x.optBoolean("digest_matches")&&x.optBoolean("size_matches"))"Intégrité vérifiée" else "Anomalie d’intégrité");Text(x.optString("checked_at"))}};if(v.optJSONObject("next")!=null)Button(enabled=!busy,onClick={run(next=true)}){Text("Page suivante")}}
 Text(status)
}
