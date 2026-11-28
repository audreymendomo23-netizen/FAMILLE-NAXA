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
 var days by remember(screen,g){mutableIntStateOf(30)};var exportRows by remember(screen,g){mutableStateOf<List<JSONObject>?>(null)}
 fun quote(raw:String):String{val clean=if(raw.trimStart().firstOrNull() in listOf('=','+','-','@'))"'"+raw else raw;return "\""+clean.replace("\"","\"\"")+"\""}
 val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")){uri->if(uri!=null&&n.generation==g){val data=exportRows?:rows;exportRows=null;scope.launch{try{val csv=(listOf("source,event,actor,operation,state,date,object,origin,correlation")+data.map{r->listOf("source","id","actor_id","operation","state","created_at","object_id","origin","correlation_id").joinToString(","){k->quote(if(r.isNull(k))"" else r.optString(k))}}).joinToString("\r\n");withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(csv.toByteArray(Charsets.UTF_8))}?:error("output unavailable")};if(n.generation==g)status="CSV enregistré."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Export non confirmé."}}}}
 Text("Journal transversal — pages de 100 événements autorisés")
 listOf("all","field","service","erp","support","fire_ack","admin","access","catalog").forEach{k->FilterChip(selected=source==k,onClick={source=k;rows=emptyList();next=null;status=""},enabled=!busy,label={Text(k)})}
 Button(enabled=!busy,onClick={load(null)}){Text("Actualiser le journal transversal")}
 rows.forEach{r->Text(r.optString("source")+" · "+r.optString("operation")+" · "+r.optString("state")+" · "+r.optString("created_at")+" · "+r.optString("origin")+" · "+r.optString("object_id",""))}
 Button(enabled=!busy&&next!=null,onClick={load(next)}){Text("Page suivante")}
 Button(enabled=!busy&&rows.isNotEmpty(),onClick={exportRows=null;export.launch("security-audit-page.csv")}){Text("Exporter cette page CSV")}
 listOf(1,7,30,90,365).forEach{d->FilterChip(selected=days==d,enabled=!busy,onClick={days=d},label={Text("$d jours")})}
 Button(enabled=!busy,onClick={busy=true;scope.launch{try{val v=SecurityNativeApi.auditExport(s,site,source,days);val a=v.getJSONArray("rows");if(n.generation==g){exportRows=(0 until a.length()).map{a.getJSONObject(it)};export.launch("security-audit-interval.csv")}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Export refusé ou indisponible. Réduisez la période."}finally{if(n.generation==g)busy=false}}}){Text("Exporter toute la période CSV")}
 Text("Maximum 10 000 événements et 7,5 Mo de données par export, sans troncature.")
 var retentionDays by remember(screen,g){mutableStateOf("")};var hold by remember(screen,g){mutableStateOf(true)};var candidate by remember(screen,g){mutableStateOf<Long?>(null)}
 fun retention(save:Boolean){if(busy)return;busy=true;scope.launch{try{val v=SecurityNativeApi.auditRetention(s,site,if(save)retentionDays.toInt() else null,if(save)hold else null);if(n.generation==g){retentionDays=if(v.isNull("days"))"" else v.optString("days");hold=v.optBoolean("legal_hold",true);candidate=v.getLong("access_trace_candidates");status="Politique consultée — simulation uniquement."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){candidate=null;status="Politique refusée ou indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Conservation des traces — propriétaire")
 Button(enabled=!busy,onClick={retention(false)}){Text("Consulter la politique")}
 OutlinedTextField(retentionDays,{retentionDays=it},enabled=!busy,label={Text("Durée en jours")})
 FilterChip(selected=hold,enabled=!busy,onClick={hold=!hold},label={Text("Gel de conservation")})
 Button(enabled=!busy&&retentionDays.toIntOrNull()?.let{it in 1..3650}==true,onClick={retention(true)}){Text("Enregistrer la politique de simulation")}
 candidate?.let{Text("Traces candidates : "+it+" — aucune suppression.")}
 Text(status)
}
