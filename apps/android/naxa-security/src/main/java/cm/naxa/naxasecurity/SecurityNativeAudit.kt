package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import org.json.JSONObject

@Composable internal fun SecurityNativeAudit(screen:String){
 if(screen !in setOf("B6.19","B6.20","B6.30"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope();val context=LocalContext.current
 var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var next by remember(screen,g){mutableStateOf<JSONObject?>(null)};var source by remember(screen,g){mutableStateOf("all")};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 fun load(before:JSONObject?){if(busy)return;busy=true;val selected=source;scope.launch{try{val v=SecurityNativeApi.auditPage(s,site,selected,before);val a=v.getJSONArray("rows");if(n.generation==g){rows=(0 until a.length()).map{a.getJSONObject(it)};next=v.optJSONObject("next");status="Journal autorisé chargé."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){rows=emptyList();next=null;status="Journal indisponible."}}finally{if(n.generation==g)busy=false}}}
 fun quote(raw:String):String{val clean=if(raw.trimStart().firstOrNull() in listOf('=','+','-','@'))"'"+raw else raw;return "\""+clean.replace("\"","\"\"")+"\""}
 val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")){uri->if(uri!=null&&n.generation==g){val data=rows;scope.launch{try{val csv=(listOf("source,event,actor,operation,state,date,object,origin,correlation")+data.map{r->listOf("source","id","actor_id","operation","state","created_at","object_id","origin","correlation_id").joinToString(","){k->quote(if(r.isNull(k))"" else r.optString(k))}}).joinToString("\r\n");withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(csv.toByteArray(Charsets.UTF_8))}?:error("output unavailable")};if(n.generation==g)status="Page CSV enregistrée."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Export non confirmé."}}}}
 Text("Journal transversal — pages de 100 événements autorisés")
 listOf("all","field","service","erp","support","fire_ack","admin","access").forEach{k->FilterChip(selected=source==k,onClick={source=k;rows=emptyList();next=null;status=""},enabled=!busy,label={Text(k)})}
 Button(enabled=!busy,onClick={load(null)}){Text("Actualiser le journal transversal")}
 rows.forEach{r->Text(r.optString("source")+" · "+r.optString("operation")+" · "+r.optString("state")+" · "+r.optString("created_at")+" · "+r.optString("origin")+" · "+r.optString("object_id",""))}
 Button(enabled=!busy&&next!=null,onClick={load(next)}){Text("Page suivante")}
 Button(enabled=!busy&&rows.isNotEmpty(),onClick={export.launch("security-audit-page.csv")}){Text("Exporter cette page CSV")}
 Text(status)
}
