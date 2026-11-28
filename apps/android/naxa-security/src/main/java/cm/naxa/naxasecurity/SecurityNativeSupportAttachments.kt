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
import java.security.MessageDigest
import java.util.UUID
@Composable internal fun SecurityNativeSupportAttachments(screen:String){
 if(screen !in setOf("B6.12","B6.13","B6.14"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope();val context=LocalContext.current
 var cases by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var files by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,g){mutableStateOf("")};var file by remember(screen,g){mutableStateOf("")};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")};var bytes by remember(screen,g){mutableStateOf<ByteArray?>(null)}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")){uri->val b=bytes;bytes=null;if(uri!=null&&b!=null&&n.generation==g){scope.launch{try{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(b)}?:error("output")};if(n.generation==g)status="Pièce enregistrée."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Enregistrement non confirmé."}finally{b.fill(0)}}}else b?.fill(0)}
 DisposableEffect(screen,g){onDispose{bytes?.fill(0)}}
 fun run(op:String,id:String?=null){if(busy)return;busy=true;scope.launch{try{
 if(op=="load"){val c=SecurityNativeApi.records(s,site,"sec_support_cases");val e=SecurityNativeApi.records(s,site,"sec_evidence_files");if(n.generation==g){cases=c.filter{it.optString("requester_id")==s.user||it.optString("agent_id")==s.user};files=e.filter{it.optString("owner_id")==s.user};selected="";rows=emptyList();file=""}}
 else{val p=JSONObject().put("p_case",selected).put("p_op",op);if(op=="add"){val sig=selected+":"+file;val k=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to k;p.put("p_id",k).put("p_evidence",file)}else if(id!=null)p.put("p_id",id);val v=SecurityNativeApi.supportAttachment(s,site,p);if(n.generation==g){when(op){"list"->{val a=v.getJSONArray("result");rows=(0 until a.length()).map{a.getJSONObject(it)}};"download"->{val r=v.getJSONObject("result");check(r.getString("id")==id);val raw=r.getString("base64");check(raw.length<=350000);val b=Base64.decode(raw,Base64.DEFAULT);check(b.size in 1..262144);check(MessageDigest.getInstance("SHA-256").digest(b).joinToString(""){"%02x".format(it.toInt() and 255)}==r.getString("digest"));bytes=b;save.launch("security-support-attachment.bin")};else->{val r=v.getJSONObject("result");check(r.getString("id")==p.getString("p_id")&&r.getString("owner_id")==s.user);pending=null;rows=emptyList()}}}}
 if(n.generation==g)status=if(op=="download")"Intégrité vérifiée." else "Opération pièces jointes confirmée : "+op
 }catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){rows=emptyList();status="Opération refusée ou indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Pièces jointes Livecare");Text("Preuve personnelle partagée explicitement. Aucun lien public. Les agents précédents perdent l’accès ; les copies enregistrées restent possibles.")
 Button(enabled=!busy,onClick={run("load")}){Text("Charger dossiers et preuves personnelles")}
 cases.forEach{r->FilterChip(selected=selected==r.optString("id"),enabled=!busy,onClick={selected=r.getString("id");rows=emptyList();file=""},label={Text(r.optString("category")+" · "+r.optString("id").take(8))})}
 if(selected.isNotBlank()){Button(enabled=!busy,onClick={run("list")}){Text("Actualiser les pièces jointes")};if(cases.firstOrNull{it.optString("id")==selected}?.optString("state") in setOf("open","assigned","waiting_customer")){files.forEach{r->FilterChip(selected=file==r.optString("id"),enabled=!busy,onClick={file=r.getString("id")},label={Text(r.optString("reference"))})};Button(enabled=!busy&&file.isNotBlank(),onClick={run("add")}){Text("Joindre explicitement la preuve")}}
 rows.forEach{r->Text(r.optString("reference")+" · "+r.optString("size_bytes")+" octets");if(r.isNull("revoked_at")){Button(enabled=!busy&&bytes==null,onClick={run("download",r.getString("id"))}){Text("Télécharger la pièce")};if(r.optString("owner_id")==s.user)Button(enabled=!busy,onClick={run("revoke",r.getString("id"))}){Text("Révoquer la pièce")}}}}
 Text(status)
}
