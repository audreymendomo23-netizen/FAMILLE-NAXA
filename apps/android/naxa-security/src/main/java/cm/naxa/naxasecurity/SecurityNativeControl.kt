package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityNativeControl(screen:String){
 val env=screen=="B3.22";if(!env&&screen !in setOf("B3.01","B3.02","B3.03","B2.25"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var result by remember(screen,g){mutableStateOf<JSONObject?>(null)};var device by remember(screen,g){mutableStateOf("")};var metric by remember(screen,g){mutableStateOf("temperature")};var limit by remember(screen,g){mutableStateOf("")};var status by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)}
 val labels=mapOf("devices_total" to "Équipements recensés","devices_recent" to "Contact récent","devices_stale_or_unknown" to "Contact ancien ou inconnu","devices_fault_or_offline" to "Défaut ou hors ligne récent","incidents_open" to "Incidents ouverts","critical_open" to "Incidents critiques ouverts","warnings_recent" to "Avertissements récents","fire_sources_active" to "Derniers états incendie actifs ou défaut","patrols_overdue" to "Rondes en retard","safety_open" to "Signalements internes ouverts")
 fun run(op:String){if(busy)return;busy=true;scope.launch{try{val p=JSONObject();if(env&&op!="list"){p.put("p_device",SecurityNativeContract.uuid(device.trim())).put("p_metric",metric).put("p_limit",if(op=="remove")JSONObject.NULL else limit.toDouble()).put("p_remove",op=="remove")};val v=SecurityNativeApi.control(s,site,env,p);if(n.generation==g){result=v;status="Données serveur confirmées."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){result=null;status="Données indisponibles ou action refusée."}}finally{if(n.generation==g)busy=false}}}
 Text(if(env)"Seuils environnementaux" else "Control 360 — instantané du site")
 Text("Contact récent : 120 secondes. Aucune commande physique. Absence de données ≠ sécurité confirmée.")
 Button(enabled=!busy,onClick={run("list")}){Text("Actualiser la supervision")}
 if(env){OutlinedTextField(device,{device=it},label={Text("Identifiant capteur")});listOf("temperature","humidity","water","co","gas").forEach{k->FilterChip(selected=metric==k,onClick={metric=k},label={Text(k)},enabled=!busy)};OutlinedTextField(limit,{limit=it},label={Text("Seuil haut")});Button(enabled=!busy&&device.isNotBlank()&&limit.toDoubleOrNull()?.isFinite()==true,onClick={run("set")}){Text("Enregistrer le seuil")};Button(enabled=!busy&&device.isNotBlank(),onClick={run("remove")}){Text("Retirer le seuil")};result?.optJSONArray("thresholds")?.let{a->(0 until a.length()).forEach{i->val r=a.getJSONObject(i);Text(r.optString("device_id")+" · "+r.optString("metric")+" : "+r.optString("upper_limit"))}}}else result?.let{v->Text("Calculé : "+v.optString("generated_at"));labels.forEach{(k,label)->Text(label+" : "+v.optString(k))}}
 Text(status)
}
