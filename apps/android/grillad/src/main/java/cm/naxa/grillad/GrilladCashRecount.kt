package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import org.json.JSONObject
@Composable internal fun GrilladCashRecount(closure:JSONObject,user:String,owner:Boolean,enabled:Boolean,onSave:(String,JSONObject)->Unit){
 var count by remember{mutableStateOf("")};var reason by remember{mutableStateOf("")};val requests=rows(closure.optJSONArray("recounts"))
 Text("Recomptage documentaire, sans réouverture ni remboursement.")
 if(!closure.isNull("reviewed_counted"))Text("Compté après revue : "+closure.optString("reviewed_counted")+" F · écart revu : "+closure.optString("reviewed_difference")+" F")
 if(requests.none{it.optString("status") in listOf("pending","approved")}){OutlinedTextField(count,{count=it},label={Text("Montant recompté")});OutlinedTextField(reason,{reason=it},label={Text("Motif du recomptage")});Button({onSave("cash_recount_request",obj("cash" to closure.optString("id"),"counted" to count.toLongOrNull(),"reason" to reason))},enabled=enabled&&count.toLongOrNull()?.let{it in 0..1000000000000}==true&&reason.isNotBlank()){Text("Demander le recomptage")}}
 requests.forEach{x->key(x.optString("id")){var why by remember{mutableStateOf("")};Text(x.optString("proposed_count")+" F · "+x.optString("reason")+" · "+when(x.optString("status")){"approved"->"Approuvé";"rejected"->"Refusé";else->"En attente"});if(owner&&x.optString("requester")!=user&&x.optString("status")=="pending"){OutlinedTextField(why,{why=it},label={Text("Motif décision recomptage")});listOf("approved" to "Approuver","rejected" to "Refuser").forEach{(k,v)->TextButton({onSave("cash_recount_decide",obj("request" to x.optString("id"),"decision" to k,"reason" to why))},enabled=enabled&&why.isNotBlank()){Text(v)}}}}}
}
