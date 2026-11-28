package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityNativeTracker(screen:String){
 if(screen !in setOf("B4.01","B4.02","B4.03","B4.04","B4.05","B4.06"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var trackers by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var history by remember(screen,g){mutableStateOf<JSONObject?>(null)};var device by remember(screen,g){mutableStateOf("")};var label by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 fun run(op:String,active:Boolean=false){if(busy)return;busy=true;scope.launch{try{val read=op in setOf("history","next");val p=JSONObject();if(op=="set")p.put("p_device",SecurityNativeContract.uuid(device.trim())).put("p_label",label.trim()).put("p_enabled",active);if(read){p.put("p_device",SecurityNativeContract.uuid(device.trim()));if(op=="next")history?.optJSONObject("next")?.let{p.put("p_before",it.getString("before")).put("p_before_id",it.getString("before_id"))}};val v=SecurityNativeApi.tracker(s,site,read,p);if(n.generation==g){if(read)history=v else{val a=v.getJSONArray("trackers");trackers=(0 until a.length()).map{a.getJSONObject(it)};history=null};status="Données GPS confirmées par le serveur."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){history=null;status="Lecture ou opération refusée."}}finally{if(n.generation==g)busy=false}}}
 Text("Traceurs des actifs et véhicules");Text("Aucun suivi permanent des personnes. Position reçue non certifiée ; schéma local sans fond routier.")
 Button(enabled=!busy,onClick={run("list")}){Text("Actualiser les traceurs")}
 trackers.forEach{r->TextButton(enabled=!busy,onClick={device=r.optString("device_id");label=r.optString("asset_label");history=null}){Text(r.optString("asset_label")+" · "+if(r.optBoolean("enabled"))"Actif" else "Suspendu")}}
 OutlinedTextField(device,{device=it;history=null},enabled=!busy,label={Text("Identifiant traceur")});OutlinedTextField(label,{label=it},enabled=!busy,label={Text("Libellé actif")})
 if(screen=="B4.06"){Button(enabled=!busy&&device.isNotBlank()&&label.isNotBlank(),onClick={run("set",true)}){Text("Activer le suivi de cet actif")};Button(enabled=!busy&&device.isNotBlank()&&label.isNotBlank(),onClick={run("set",false)}){Text("Suspendre le suivi")}}
 Button(enabled=!busy&&device.isNotBlank(),onClick={run("history")}){Text("Charger les positions")}
 history?.let{v->Text("Calculé : "+v.optString("generated_at"));val a=v.getJSONArray("rows");val rows=(0 until a.length()).map{a.getJSONObject(it)};val points=rows.mapNotNull{r->val lat=r.optDouble("latitude");val lon=r.optDouble("longitude");if(lat.isFinite()&&lon.isFinite())lat to lon else null}.reversed();if(points.isNotEmpty()){val minLat=points.minOf{it.first};val maxLat=points.maxOf{it.first};val minLon=points.minOf{it.second};val maxLon=points.maxOf{it.second};Canvas(Modifier.fillMaxWidth().height(180.dp)){val offsets=points.map{(lat,lon)->Offset(12f+(size.width-24f)*((lon-minLon)/(maxLon-minLon).coerceAtLeast(0.000001)).toFloat(),size.height-12f-(size.height-24f)*((lat-minLat)/(maxLat-minLat).coerceAtLeast(0.000001)).toFloat())};offsets.zipWithNext().forEach{(a,b)->drawLine(Color.Cyan,a,b,strokeWidth=2f)};offsets.forEach{drawCircle(Color.Cyan,4f,it)}}};val z=v.getJSONArray("zones");(0 until z.length()).forEach{i->val r=z.getJSONObject(i);Text(r.optString("label")+" · "+r.optString("assessment")+" · "+r.optString("distance_m")+" m")};rows.forEach{r->Text(r.optString("observed_at")+" · "+r.optString("latitude")+", "+r.optString("longitude")+" · ±"+r.optString("accuracy_m")+" m")};if(v.optJSONObject("next")!=null)Button(enabled=!busy,onClick={run("next")}){Text("Positions précédentes")}}
 Text(status)
}
