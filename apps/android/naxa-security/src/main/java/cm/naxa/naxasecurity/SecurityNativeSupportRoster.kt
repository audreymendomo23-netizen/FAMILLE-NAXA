package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityNativeSupportRoster(screen:String){
 if(screen !in setOf("B6.15","B6.16"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 fun run(user:String?=null,active:Boolean=false){if(busy)return;busy=true;scope.launch{try{val v=SecurityNativeApi.supportRoster(s,site,user,active);if(n.generation==g){val a=v.getJSONArray("members");rows=(0 until a.length()).map{a.getJSONObject(it)};status=if(user==null)"Agents du site chargés." else "Habilitation confirmée. Dossiers remis en file : "+v.optInt("released")}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){rows=emptyList();status="Accès refusé ou indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Agents Livecare du site");Text("Propriétaire uniquement. Révocation et remise en file des dossiers ouverts.")
 Button(enabled=!busy,onClick={run()}){Text("Charger les habilitations")}
 rows.forEach{r->val active=r.optBoolean("active");Text(r.getString("user_id")+" · "+r.optString("role"));Button(enabled=!busy,onClick={run(r.getString("user_id"),!active)}){Text(if(active)"Révoquer" else "Habiliter")}}
 Text(status)
}
