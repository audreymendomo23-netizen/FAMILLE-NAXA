package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityNativeEvidencePolicy(screen:String){
 if(screen!="B6.25")return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var data by remember(g){mutableStateOf<JSONObject?>(null)};var cap by remember(g){mutableStateOf("")};var days by remember(g){mutableStateOf("")};var hold by remember(g){mutableStateOf(true)};var status by remember(g){mutableStateOf("")};var busy by remember(g){mutableStateOf(false)}
 fun run(save:Boolean){if(busy)return;busy=true;scope.launch{try{val p=JSONObject();if(save){val c=cap.toLong();val d=days.toInt();require(c in 1L..9007199254740991L&&d in 1..3650);p.put("p_max_bytes",c).put("p_retention_days",d).put("p_hold",hold)};val v=SecurityNativeApi.evidencePolicy(s,site,p);if(n.generation==g){data=v;cap=if(v.isNull("technical_max_bytes"))"" else v.getString("technical_max_bytes");days=if(v.isNull("retention_days"))"" else v.getString("retention_days");hold=v.getBoolean("legal_hold");status=if(save)"Politique technique enregistrée." else "Politique technique chargée."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Opération refusée ou indisponible."}finally{if(n.generation==g)busy=false}}}
 Text("Capacité technique et conservation");Text("Propriétaire uniquement ; aucun quota commercial ni suppression automatique.")
 Button(enabled=!busy,onClick={run(false)}){Text("Charger la politique")}
 data?.let{v->Text(v.optString("total_files")+" fichiers · "+v.optString("total_bytes")+" octets utilisés");Text("Prévisualisation : "+v.optString("unreferenced_old_files")+" fichiers anciens non liés");OutlinedTextField(cap,{cap=it},enabled=!busy,label={Text("Capacité maximale en octets")});OutlinedTextField(days,{days=it},enabled=!busy,label={Text("Conservation en jours")});FilterChip(selected=hold,enabled=!busy,onClick={hold=!hold},label={Text("Gel de conservation")});Button(enabled=!busy&&cap.isNotBlank()&&days.isNotBlank(),onClick={run(true)}){Text("Enregistrer la politique technique")}}
 Text(status)
}
