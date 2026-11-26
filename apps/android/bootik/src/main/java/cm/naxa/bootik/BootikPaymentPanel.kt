package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.security.MessageDigest
import java.util.UUID

@Composable fun BootikPaymentPanel(api:BootikApi,session:BootikSession,site:String,universe:String,plan:String){
 if(session.role=="staff")return
 val scope=rememberCoroutineScope()
 var channel by remember(site){mutableStateOf("mtn_momo")};var months by remember(site){mutableStateOf(1)}
 var intent by remember(site,universe){mutableStateOf<JSONObject?>(null)};var raw by remember(site,universe){mutableStateOf("")}
 var reference by remember(site,universe){mutableStateOf("")};var amount by remember(site,universe){mutableStateOf("")};var destination by remember(site,universe){mutableStateOf("")};var date by remember(site,universe){mutableStateOf("")}
 var message by remember(site){mutableStateOf("")};var busy by remember(site){mutableStateOf(false)}
 val keys=remember(site){mutableMapOf<String,String>()}
 fun task(block:suspend ()->Unit){if(busy)return;busy=true;message="";scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération non confirmée. Vérifiez les informations."}finally{busy=false}}}
 val current=intent;val state=current?.optString("state").orEmpty();val pending=state in setOf("awaiting_payment","awaiting_verification")
 Text("Règlement de l’abonnement",style=MaterialTheme.typography.titleMedium)
 Text("Effectuez le paiement dans l’interface de l’opérateur. BOOTIK ne demande jamais PIN MoMo/OM ni OTP.")
 Row{RadioButton(channel=="mtn_momo",{channel="mtn_momo"},enabled=!busy&&!pending);Text("MTN MoMo");RadioButton(channel=="orange_money",{channel="orange_money"},enabled=!busy&&!pending);Text("Orange Money")}
 Row{RadioButton(months==1,{months=1},enabled=!busy&&!pending);Text("Mensuel");RadioButton(months==12,{months=12},enabled=!busy&&!pending);Text("Annuel")}
 Text("Montant : "+cm.naxa.bootik.domain.BootikPolicy.quote(universe,plan,months)+" FCFA")
 Button(enabled=!busy&&!pending,onClick={task{val slot="$universe:$plan:$months:$channel";if(state in setOf("confirmed","expired","refunded"))keys.remove(slot);val key=keys.getOrPut(slot){UUID.randomUUID().toString()};intent=api.operation(session,site,"payment-intent",JSONObject().put("universe",universe).put("plan",plan).put("months",months).put("channel",channel).put("request_key",key));message="Intention préparée, aucun paiement confirmé."}}){Text("Préparer le paiement")}
 Button(enabled=!busy,onClick={task{val result=api.operation(session,site,"payment-current",JSONObject().put("universe",universe));intent=result.optJSONObject("intent");message=if(intent==null)"Aucun règlement retrouvé" else "État récupéré"}}){Text("Retrouver mon règlement")}
 if(current!=null){
 Text(current.getString("amount_fcfa")+" FCFA • "+current.getString("beneficiary"))
 Text("Destination : "+current.getString("destination"));Text(current.optString("instructions"))
 Text("État : "+when(state){"confirmed"->"Confirmé";"awaiting_verification"->"En vérification";"expired"->"Expiré";"refunded"->"Remboursé — période révoquée";else->"En attente de paiement"})
 Button(enabled=!busy,onClick={task{intent=api.operation(session,site,"payment-status",JSONObject().put("intent_id",current.getString("id")))}}){Text("Vérifier le statut")}
 if(state=="awaiting_payment"){
 OutlinedTextField(raw,{if(it.length<=8000)raw=it},label={Text("SMS de débit volontairement partagé")})
 TextButton(enabled=!busy&&raw.length>=12,onClick={val parsed=SmsPaymentParser.parsePayer(raw,current.getString("channel"));if(parsed==null)message="Format non reconnu : complétez les champs du SMS." else{reference=parsed.reference.orEmpty();amount=parsed.amount?.toString().orEmpty();date=parsed.occurredAt.orEmpty();destination=parsed.merchantNumber.orEmpty()}}){Text("Lire les champs du SMS")}
 OutlinedTextField(reference,{reference=it},label={Text("Référence transaction")},singleLine=true)
 OutlinedTextField(amount,{amount=it},label={Text("Montant SMS")},singleLine=true)
 OutlinedTextField(destination,{destination=it},label={Text("Destination SMS")},singleLine=true)
 OutlinedTextField(date,{date=it},label={Text("Date et heure (Douala ou ISO)")},singleLine=true)
 Button(enabled=!busy&&raw.trim().length>=12&&reference.isNotBlank()&&(amount.toLongOrNull()?:0)>0&&destination.isNotBlank()&&date.isNotBlank(),onClick={task{
 val sha=MessageDigest.getInstance("SHA-256").digest(raw.trim().toByteArray(Charsets.UTF_8)).joinToString(""){"%02x".format(it.toInt() and 255)}
 val result=api.operation(session,site,"payment-debit",JSONObject().put("intent_id",current.getString("id")).put("direction","payer_debit").put("success",true).put("reference",reference.trim()).put("amount_fcfa",amount.toLong()).put("destination",destination.trim()).put("provider_at",SmsPaymentParser.toIsoDateTime(date)).put("evidence_sha",sha))
 check(result.getBoolean("accepted"));raw="";reference="";amount="";destination="";date="";intent=api.operation(session,site,"payment-status",JSONObject().put("intent_id",current.getString("id")));message="Déclaration reçue. Confirmation indépendante du marchand nécessaire."
 }}){Text("Déclarer la preuve de débit")}
 }
 }
 Text(message)
}
