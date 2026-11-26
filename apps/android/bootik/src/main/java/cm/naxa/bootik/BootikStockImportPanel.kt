package cm.naxa.bootik
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.UUID
@Composable fun BootikStockImportPanel(api:BootikApi,session:BootikSession,site:String,activity:String){
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var csv by remember{mutableStateOf("")};var preview by remember{mutableStateOf<List<JSONObject>>(emptyList())};var batch by remember{mutableStateOf("")};var model by remember{mutableStateOf("")};var message by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)}
 fun edit(value:String){csv=value;preview=emptyList();batch=""}
 fun task(block:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Import non confirmé. Vérifiez le fichier et les droits."}finally{busy=false}}}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")){uri->if(uri!=null)task{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(model.toByteArray(Charsets.UTF_8))}?:error("Fichier indisponible")};message="Modèle CSV enregistré"}}
 val open=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null)task{val data=withContext(Dispatchers.IO){context.contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use{reader->val buf=CharArray(10001);var size=0;while(size<buf.size){val n=reader.read(buf,size,buf.size-size);if(n<0)break;size+=n};require(size<=10000);String(buf,0,size)}?:error("Fichier indisponible")};edit(data)}}
 Text("Import CSV par activité",style=MaterialTheme.typography.titleMedium)
 Text("UTF-8, point-virgule, 1 à 30 lignes. Création uniquement, sans écrasement des références existantes.")
 Button(enabled=!busy,onClick={task{val r=api.operation(session,site,"stock-template",JSONObject().put("activity_id",activity));model=r.getString("csv");save.launch("bootik-"+r.getString("profile")+".csv")}}){Text("Télécharger le modèle CSV")}
 Button(enabled=!busy,onClick={open.launch(arrayOf("text/csv","text/plain","application/vnd.ms-excel"))}){Text("Choisir un fichier CSV")}
 OutlinedTextField(csv,{if(it.length<=10000)edit(it)},label={Text("Contenu CSV")},enabled=!busy,maxLines=5)
 Button(enabled=!busy&&csv.isNotBlank(),onClick={task{val a=api.operation(session,site,"stock-import-preview",JSONObject().put("activity_id",activity).put("csv",csv)).getJSONArray("rows");preview=(0 until a.length()).map{a.getJSONObject(it)};batch=UUID.randomUUID().toString()}}){Text("Analyser le fichier")}
 preview.forEach{x->Text("Ligne "+x.getInt("row")+" • "+if(x.getString("status")=="create")x.getJSONObject("data").getString("sku")+" : création, stock "+x.getString("quantity") else "Rejet : "+x.optString("reason"))}
 Button(enabled=!busy&&batch.isNotBlank()&&preview.isNotEmpty()&&preview.all{it.getString("status")=="create"},onClick={task{val r=api.operation(session,site,"stock-import-apply",JSONObject().put("activity_id",activity).put("csv",csv).put("batch_id",batch));check(r.getString("batch_id")==batch);val n=r.getJSONArray("report").length();edit("");message="$n article(s) créé(s) avec reçu serveur. Actualisez le catalogue."}}){Text("Confirmer l’import")}
 Text(message)
}
