package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityNativePresence(screen:String){
 if(screen !in setOf("B4.07","B4.12","B4.13"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var shifts by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,g){mutableStateOf("")};var report by remember(screen,g){mutableStateOf<JSONObject?>(null)};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 fun load(detail:Boolean){if(busy)return;busy=true;scope.launch{try{if(detail){val v=SecurityNativeApi.presenceReport(s,site,selected);if(n.generation==g)report=v}else{val v=SecurityNativeApi.records(s,site,"sec_shifts");if(n.generation==g){shifts=v;selected="";report=null}};if(n.generation==g)status="Données serveur confirmées."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){report=null;status="Rapport indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Bilan de présence par vacation");Text("Pointages examinés dans la fenêtre planifiée ; aucune paie ni certification physique.")
 Button(enabled=!busy,onClick={load(false)}){Text("Charger les vacations")}
 shifts.forEach{r->FilterChip(selected=selected==r.optString("id"),enabled=!busy,onClick={selected=r.optString("id");report=null},label={Text(r.optString("label")+" · "+r.optString("starts_at"))})}
 Button(enabled=!busy&&selected.isNotBlank(),onClick={load(true)}){Text("Calculer le bilan")}
 report?.let{r->fun mins(k:String)=if(r.isNull(k))"Non calculé" else (r.optLong(k)/60).toString()+" min";Text(if(r.optBoolean("complete"))"Séquence examinée complète" else "Séquence incomplète ou à revoir");Text("Travail : "+mins("worked_seconds")+" · Pause : "+mins("pause_seconds"));Text("Retard : "+mins("late_seconds")+" · Départ anticipé : "+mins("early_departure_seconds"));Text("En attente : "+r.optString("pending")+" · Rejetés : "+r.optString("rejected")+" · Anomalies : "+r.optString("anomalies"))}
 Text(status)
}
