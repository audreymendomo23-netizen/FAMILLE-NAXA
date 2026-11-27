package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun GrilladReportFilters(site:JSONObject?,data:JSONObject,period:String,enabled:Boolean,request:suspend(JSONObject)->JSONObject){
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var network by remember(site,period){mutableStateOf(false)};var family by remember(site,period){mutableStateOf("")}
 var actor by remember(site,period){mutableStateOf("")};var item by remember(site,period){mutableStateOf("")}
 var result by remember(site,period){mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 var pdfLines by remember(site,period){mutableStateOf<List<String>?>(null)}
 var xlsxRows by remember(site,period){mutableStateOf<List<List<Any?>>?>(null)}
 val xlsxLauncher=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")){uri->val table=xlsxRows;xlsxRows=null;if(uri!=null&&table!=null)try{writeGrilladXlsx(context,uri,table);message="Excel enregistré"}catch(e:Exception){message="Export Excel impossible"}}
 val pdfLauncher=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")){uri->val lines=pdfLines;pdfLines=null;if(uri!=null&&lines!=null)try{writeGrilladPdf(context,uri,"GRILLAD - Rapport",lines);message="PDF enregistré"}catch(e:Exception){message="Export PDF impossible"}}
 Text("Rapport détaillé",style=MaterialTheme.typography.titleMedium)
 if(data.optJSONObject("pilotage")?.optBoolean("network_allowed")==true)Row{Text("Réseau");Switch(network,{network=it;result=null},enabled=enabled&&!busy)}
 Row(Modifier.horizontalScroll(rememberScrollState())){(listOf("")+families).forEach{x->TextButton({family=x;result=null},enabled=enabled&&!busy){Text((if(family==x)"✓ " else "")+x.ifEmpty{"Toutes familles"})}}}
 Row(Modifier.horizontalScroll(rememberScrollState())){TextButton({item="";result=null},enabled=enabled&&!busy){Text("Tous articles")};rows(data.optJSONArray("items")).forEach{x->TextButton({item=x.optString("id");result=null},enabled=enabled&&!busy){Text((if(item==x.optString("id"))"✓ " else "")+x.optString("name"))}}}
 Row(Modifier.horizontalScroll(rememberScrollState())){TextButton({actor="";result=null},enabled=enabled&&!busy){Text("Tous vendeurs")};rows(data.optJSONObject("pilotage")?.optJSONArray("team")).forEach{x->TextButton({actor=x.optString("id");result=null},enabled=enabled&&!busy){Text((if(actor==x.optString("id"))"✓ " else "")+x.optString("role")+" "+x.optString("id").take(8))}}}
 Button({busy=true;result=null;message="";scope.launch{try{val (from,to)=bounds(period);result=request(obj("from" to from,"to" to to,"network" to network,"family" to family.ifEmpty{null},"actor" to actor.ifEmpty{null},"item" to item.ifEmpty{null}))}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Rapport indisponible ou accès refusé"}finally{busy=false}}},enabled=enabled&&!busy){Text("Calculer")}
 if(message.isNotBlank())Text(message)
 result?.let{r->fun amount(k:String)=if(r.isNull(k))"Non attribué / inconnu" else r.optString(k)+" F"
 Text("CA "+amount("ca")+" · Direct "+amount("direct_ca")+" · Connect "+amount("connect_ca"));Text("Encaissements espèces "+amount("encaissements"))
 Text("Coût "+amount("cost")+" · Dépenses "+amount("expenses"))
 rows(r.optJSONArray("sites")).forEach{x->Text(x.optString("name")+" : "+x.optString("ca")+" F")}
 Text(r.optString("from")+" → "+r.optString("to")+" · Confirmé serveur uniquement")
 OutlinedButton({val content=buildString{append("GRILLAD — rapport ");append(r.optString("from"));append(" / ");append(r.optString("to"));append("\nCA ");append(amount("ca"));append("\n");rows(r.optJSONArray("sites")).forEach{x->append(x.optString("name")+" : "+x.optString("ca")+" F\n")}};context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{type="text/plain";putExtra(Intent.EXTRA_TEXT,content)},"Partager le rapport"))},enabled=enabled){Text("Partager le rapport")}
 OutlinedButton({pdfLines=reportPdfLines(r);pdfLauncher.launch("grillad-rapport-"+r.optString("from")+"-"+r.optString("to")+".pdf")},enabled=enabled){Text("Exporter PDF")}
 OutlinedButton({xlsxRows=grilladReportRows(r);xlsxLauncher.launch("grillad-rapport-"+r.optString("from")+"-"+r.optString("to")+".xlsx")},enabled=enabled){Text("Exporter Excel")}}
}
