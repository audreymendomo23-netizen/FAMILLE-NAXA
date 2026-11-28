package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
@Composable internal fun SecurityNativePresence(screen:String){
 if(screen !in setOf("B4.07","B4.12","B4.13"))return
 val context=LocalContext.current
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var shifts by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember(screen,g){mutableStateOf("")};var report by remember(screen,g){mutableStateOf<JSONObject?>(null)};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 var exportData by remember(screen,g){mutableStateOf<String?>(null)}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")){uri->val data=exportData;exportData=null;if(uri!=null&&data!=null&&n.generation==g){scope.launch{try{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(data.toByteArray(Charsets.UTF_8))}?:error("output unavailable")};if(n.generation==g)status="CSV enregistré."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Export non confirmé."}}}}
 fun export(r:JSONObject){if(r.optString("shift_id")!=selected||exportData!=null)return;val keys=listOf("organization_id","site_id","shift_id","state","attendance_status","complete","scheduled_start","scheduled_end","arrived_at","departed_at","worked_seconds","pause_seconds","late_seconds","early_departure_seconds","pending","rejected","anomalies","manual_approved_events","absence_approved","physical_presence_certified");fun quote(raw:String):String{val clean=if(raw.trimStart().firstOrNull() in listOf('=','+','-','@'))"'"+raw else raw;return "\""+clean.replace("\"","\"\"")+"\""};exportData=keys.joinToString(",")+"\r\n"+keys.joinToString(","){k->quote(if(r.isNull(k))"" else r.optString(k))};save.launch("security-presence.csv")}
 fun load(detail:Boolean){if(busy)return;busy=true;scope.launch{try{if(detail){val v=SecurityNativeApi.presenceReport(s,site,selected);if(n.generation==g)report=v}else{val v=SecurityNativeApi.records(s,site,"sec_shifts");if(n.generation==g){shifts=v;selected="";report=null}};if(n.generation==g)status="Données serveur confirmées."}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){report=null;status="Rapport indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Bilan de présence par vacation");Text("Pointages examinés dans la fenêtre planifiée ; aucune paie ni certification physique.")
 Button(enabled=!busy,onClick={load(false)}){Text("Charger les vacations")}
 shifts.forEach{r->FilterChip(selected=selected==r.optString("id"),enabled=!busy,onClick={selected=r.optString("id");report=null},label={Text(r.optString("label")+" · "+r.optString("starts_at"))})}
 Button(enabled=!busy&&selected.isNotBlank(),onClick={load(true)}){Text("Calculer le bilan")}
 report?.let{r->
  fun mins(k:String):String { return if(r.isNull(k)) "Non calculé" else (r.optLong(k)/60).toString()+" min" }
  Text(if(r.optBoolean("complete"))"Séquence examinée complète" else "Séquence incomplète ou à revoir");Text(when(r.optString("attendance_status")){"not_accepted"->"Vacation non acceptée";"reviewed_complete"->"Pointages examinés complets";"review_required"->"Examen nécessaire";"scheduled"->"Vacation à venir";"in_progress_unconfirmed"->"Vacation en cours, présence non certifiée";"missing_evidence"->"Aucune preuve reçue — absence non confirmée";"incomplete_evidence"->"Preuves incomplètes";"cancelled"->"Vacation annulée";"absence_reviewed"->"Absence examinée";else->"Situation indéterminée"});Text("Événements manuels approuvés : "+r.optString("manual_approved_events","—"));Text("Travail : "+mins("worked_seconds")+" · Pause : "+mins("pause_seconds"));Text("Retard : "+mins("late_seconds")+" · Départ anticipé : "+mins("early_departure_seconds"));Text("En attente : "+r.optString("pending")+" · Rejetés : "+r.optString("rejected")+" · Anomalies : "+r.optString("anomalies"));Button(enabled=!busy&&exportData==null,onClick={export(r)}){Text("Exporter le bilan CSV")}}
 Text(status)
}
