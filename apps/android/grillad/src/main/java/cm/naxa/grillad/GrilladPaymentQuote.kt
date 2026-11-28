package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun GrilladPaymentQuote(data:JSONObject?,enabled:Boolean,request:suspend(JSONObject)->JSONObject){
 val pending=rows(data?.optJSONArray("central_requests")).firstOrNull{it.optString("kind")=="renewal"&&it.optString("status")=="pending"}?:return
 var channel by remember(pending.optString("id")){mutableStateOf("mtn_momo")};var result by remember(pending.optString("id")){mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")};val scope=rememberCoroutineScope()
 Text("Référence de paiement",style=MaterialTheme.typography.titleMedium);Text("Aucun débit automatique. Attendre les instructions du centre.")
 listOf("mtn_momo" to "MTN MoMo","orange_money" to "Orange Money","bank" to "Banque").forEach{(k,v)->TextButton({channel=k;result=null},enabled=enabled&&!busy){Text((if(channel==k)"✓ " else "")+v)}}
 Button({busy=true;msg="";scope.launch{try{result=request(obj("action" to "payment_quote","request" to pending.optString("id"),"channel" to channel))}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){msg="Référence indisponible. Contactez le centre."}finally{busy=false}}},enabled=enabled&&!busy){Text("Créer la référence de paiement")}
 result?.let{Text("Aucun débit effectué");Text("Référence : "+it.optString("intent")+" · "+it.optString("amount")+" F")}
 if(msg.isNotBlank())Text(msg)
}
