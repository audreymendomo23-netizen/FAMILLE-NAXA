package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityNativeEvidenceInventory(screen:String){
 if(screen !in setOf("B6.22","B6.25"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var data by remember(screen,g){mutableStateOf<JSONObject?>(null)};var checks by remember(screen,g){mutableStateOf<Map<String,JSONObject>>(emptyMap())};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 fun run(verify:String?=null,next:Boolean=false){if(busy)return;busy=true;scope.launch{try{val p=JSONObject();if(verify!=null)p.put("p_verify",verify) else if(next)data?.optJSONObject("next")?.let{p.put("p_before",it.getString("before")).put("p_before_id",it.getString("before_id"))};val v=SecurityNativeApi.evidenceInventory(s,site,p);if(n.generation==g){if(verify!=null){check(!v.optBoolean("denied"));val x=v.getJSONObject("verification");check(x.optString("id")==verify);checks=checks+(verify to x);status="Contrôle d’intégrité effectué."}else{v.getJSONArray("files");data=v;checks=emptyMap();status="Inventaire serveur confirmé."}}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){checks=emptyMap();status="Opération refusée ou indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Stockage personnel et intégrité");Text("Quota commercial non configuré. L'intégrité ne certifie pas l'authenticité de la scène.")
 Button(enabled=!busy,onClick={run()}){Text("Charger le stockage")}
 data?.let{v->Text(v.optString("total_files")+" fichiers · "+v.optString("total_bytes")+" octets");val a=v.getJSONArray("files");(0 until a.length()).forEach{i->val r=a.getJSONObject(i);val id=r.getString("id");Text(r.optString("reference")+" · "+r.optString("size_bytes")+" octets");Button(enabled=!busy,onClick={run(id)}){Text("Vérifier côté serveur")};checks[id]?.let{x->Text(if(x.optBoolean("digest_matches")&&x.optBoolean("size_matches"))"Intégrité vérifiée" else "Anomalie d’intégrité");Text(x.optString("checked_at"))}};if(v.optJSONObject("next")!=null)Button(enabled=!busy,onClick={run(next=true)}){Text("Page suivante")}}
 Text(status)
}
