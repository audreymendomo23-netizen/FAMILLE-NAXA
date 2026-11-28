package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable internal fun SecurityNativeBilling(screen:String){
 if(screen !in setOf("B1.17","B1.18","B1.20","B1.21","B1.22","B6.17"))return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var data by remember(screen,g){mutableStateOf<JSONObject?>(null)};var target by remember(screen,g){mutableStateOf("")};var plan by remember(screen,g){mutableStateOf("Essentiel")};var period by remember(screen,g){mutableStateOf("monthly")};var status by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)}
 fun load(){if(busy)return;busy=true;scope.launch{try{val v=SecurityNativeApi.billingStatus(s,site);if(n.generation==g){data=v;status="Situation commerciale confirmée."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){data=null;status="Situation indisponible."}}finally{if(n.generation==g)busy=false}}}
 fun allocate(){if(busy)return;busy=true;scope.launch{try{val t=SecurityNativeContract.uuid(target.trim());val sig=t+plan+period;val id=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to id;val v=SecurityNativeApi.allocateSubscription(s,site,id,t,plan,period);if(n.generation==g){pending=null;target="";data=null;status="Reçu alloué : "+v.optString("starts_at")+" — "+v.optString("ends_at")+" ; actualisez."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Allocation refusée ou non confirmée."}finally{if(n.generation==g)busy=false}}}
 Text("Abonnement de l’organisation");Text("Essentiel : un site. Business/Professional : multisite. Aucun impact sur les alarmes locales.")
 Button(enabled=!busy,onClick={load()}){Text("Actualiser l’abonnement")}
 data?.let{v->Text(v.optString("status")+" · "+v.optString("current_plan"));Text("Échéance : "+v.optString("current_ends_at"));Text("Prochaine période : "+v.optString("next_plan")+" · "+v.optString("next_starts_at"));Text("ERP : "+if(v.optBoolean("erp_entitled"))"Inclus" else "Non inclus");Text("Multisite : "+if(v.optBoolean("multisite_entitled"))"Inclus" else "Non inclus");val a=v.getJSONArray("history");(0 until a.length()).forEach{i->val h=a.getJSONObject(i);Text(h.optString("plan")+" · "+h.optString("amount_fcfa")+" FCFA · "+h.optString("starts_at")+" — "+h.optString("ends_at"))}
 if(v.optBoolean("can_allocate")&&screen in setOf("B1.17","B1.20","B1.22")){OutlinedTextField(target,{target=it},enabled=!busy,label={Text("Identifiant demande paiement")});listOf("Essentiel","Business","Professional").forEach{k->FilterChip(selected=plan==k,onClick={plan=k},enabled=!busy,label={Text(k)})};listOf("monthly","annual").forEach{k->FilterChip(selected=period==k,onClick={period=k},enabled=!busy,label={Text(k)})};Button(enabled=!busy&&target.isNotBlank(),onClick={allocate()}){Text("Allouer le reçu confirmé")}}}
 Text(status)
}
