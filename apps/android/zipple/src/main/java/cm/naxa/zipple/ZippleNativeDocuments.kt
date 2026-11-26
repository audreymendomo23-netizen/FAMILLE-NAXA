package cm.naxa.zipple
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.*
import org.json.JSONObject
import android.util.Base64
import java.security.MessageDigest

private const val MAX_EVIDENCE=2097152
internal fun evidenceHash(bytes:ByteArray):String=MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){ "%02x".format(it.toInt() and 255) }
@Composable internal fun ZippleNativeDocuments(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val ctx=LocalContext.current;val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
 var data by remember{mutableStateOf<JSONObject?>(null)};var source by remember{mutableStateOf("")};var label by remember{mutableStateOf("")};var mime by remember{mutableStateOf("")};var bytes by remember{mutableStateOf<ByteArray?>(null)};var download by remember{mutableStateOf<ByteArray?>(null)}
 var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")};var open by remember{mutableStateOf(false)}
 val allowed=session.role in setOf("promoteur","manager")&&session.permits(site)
 suspend fun load(){data=api.call(session,site,"finance_documents_snapshot") as? JSONObject?:error("UNAVAILABLE")}
 fun run(block:suspend()->Unit){if(busy||!allowed)return;busy=true;msg="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){msg=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null)run{
  val file=withContext(Dispatchers.IO){
   val type=ctx.contentResolver.getType(uri);require(type in setOf("application/pdf","image/jpeg","image/png"))
   val input=ctx.contentResolver.openInputStream(uri)?:error("FILE")
   val b=input.use{stream->val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192);var total=0;while(true){val n=stream.read(buffer);if(n<0)break;total+=n;require(total<=MAX_EVIDENCE);out.write(buffer,0,n)};out.toByteArray()}
   require(b.size>=8);type!! to b
  };mime=file.first;bytes=file.second;msg=tr("Fichier sélectionné","File selected")
 }}
 val saver=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")){uri->
  val b=download;download=null
  if(uri!=null&&b!=null)run{withContext(Dispatchers.IO){val out=ctx.contentResolver.openOutputStream(uri)?:error("FILE");out.use{it.write(b)}};msg=tr("Justificatif enregistré","Document saved")}
 }
 LaunchedEffect(session.member,site){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){msg=tr("Données indisponibles","Data unavailable")}}
 val sources=data?.rows("sources").orEmpty();val chosen=sources.find{it.optString("kind")+":"+it.optString("source_id")==source}
 Text(tr("Pièces justificatives","Supporting documents"),style=MaterialTheme.typography.titleLarge)
 Text(tr("PDF, JPG ou PNG — 2 Mio maximum.","PDF, JPG or PNG — maximum 2 MiB."))
 OutlinedButton(enabled=!busy&&allowed,onClick={run{load()}}){Text(tr("Actualiser les justificatifs","Refresh documents"))}
 Box{OutlinedButton(enabled=!busy&&sources.isNotEmpty(),onClick={open=true}){Text(tr("Opération à justifier","Source operation")+" : "+(chosen?.optString("label")?:"—"))}
 DropdownMenu(expanded=open,onDismissRequest={open=false}){sources.forEach{x->DropdownMenuItem(text={Text(x.optString("label")+" · "+x.optString("amount_xaf")+" FCFA · "+x.optString("entry_date"))},onClick={source=x.optString("kind")+":"+x.optString("source_id");open=false})}}}
 OutlinedTextField(label,{label=it.take(160)},label={Text(tr("Intitulé","Document label"))},modifier=Modifier.fillMaxWidth(),singleLine=true,enabled=!busy)
 OutlinedButton(enabled=!busy&&allowed,onClick={picker.launch(arrayOf("application/pdf","image/jpeg","image/png"))}){Text(tr("Choisir un fichier","Choose file"))}
 if(bytes!=null)Text(tr("Fichier prêt à joindre","File ready to attach"))
 Button(enabled=allowed&&!busy&&chosen!=null&&bytes!=null&&label.trim().isNotEmpty(),onClick={run{
  val x=requireNotNull(chosen);val b=requireNotNull(bytes)
  val payload=JSONObject().put("kind",x.getString("kind")).put("source_id",x.getString("source_id")).put("label",label.trim()).put("mime",mime).put("base64",Base64.encodeToString(b,Base64.NO_WRAP))
  api.call(session,site,"finance_document_add",keys.apply("finance_document_add",payload));keys.confirmed("finance_document_add")
  bytes=null;label="";msg=tr("Justificatif joint","Document attached");load()
 }}){Text(tr("Joindre le justificatif","Attach document"))}
 data?.rows("documents")?.forEach{x->
  Text(x.optString("label")+" · "+x.optString("created_at"))
  OutlinedButton(enabled=allowed&&!busy&&download==null,onClick={run{
   val result=api.call(session,site,"finance_document_read",JSONObject().put("document_id",x.getString("id"))) as? JSONObject?:error("DOCUMENT")
   require(result.getString("id")==x.getString("id")&&result.getString("mime")==x.getString("mime")&&result.getString("sha256_hex")==x.getString("sha256_hex"))
   val ext=when(result.getString("mime")){"application/pdf"->"pdf";"image/jpeg"->"jpg";"image/png"->"png";else->error("DOCUMENT")}
   val b=Base64.decode(result.getString("base64"),Base64.DEFAULT);require(b.size in 8..MAX_EVIDENCE&&evidenceHash(b)==x.getString("sha256_hex"))
   download=b;saver.launch("zipple-"+x.getString("id")+"."+ext)
  }}){Text(tr("Enregistrer le justificatif","Save document"))}
 }
 if(msg.isNotBlank())Text(msg)
}
