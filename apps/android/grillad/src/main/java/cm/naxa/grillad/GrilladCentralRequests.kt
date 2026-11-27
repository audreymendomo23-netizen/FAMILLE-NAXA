package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import org.json.JSONObject
@Composable internal fun GrilladCentralRequests(kind:String,data:JSONObject?,enabled:Boolean,onSave:(String,JSONObject)->Unit){
 var name by remember(kind){mutableStateOf("")};var phone by remember(kind){mutableStateOf("")};var role by remember(kind){mutableStateOf("seller")};var plan by remember(kind){mutableStateOf("grillad_access_month")}
 Text(if(kind=="employee")"Demander une activation" else "Demander un renouvellement",style=MaterialTheme.typography.titleMedium)
 Text("Demande centrale, sans activation automatique.")
 if(kind=="employee"){OutlinedTextField(name,{name=it},label={Text("Nom du collaborateur")});OutlinedTextField(phone,{phone=it},label={Text("Téléphone international")});listOf("seller" to "Vendeur","manager" to "Responsable").forEach{(k,v)->TextButton({role=k}){Text(if(role==k)"✓ "+v else v)}}}
 else listOf("grillad_access_month" to "ACCÈS 2 000 F/mois","grillad_access_year" to "ACCÈS 24 000 F/an","grillad_premium_month" to "PREMIUM 6 000 F/mois","grillad_premium_year" to "PREMIUM 60 000 F/an").forEach{(k,v)->TextButton({plan=k}){Text(if(plan==k)"✓ "+v else v)}}
 Button({if(kind=="employee")onSave("employee_request",obj("name" to name,"phone" to phone.trim(),"role" to role))else onSave("renewal_request",obj("plan" to plan))},enabled=enabled&&(kind!="employee"||name.trim().length>=2&&phone.trim().length>=9)){Text("Enregistrer la demande")}
 rows(data?.optJSONArray("central_requests")).filter{it.optString("kind")==kind}.forEach{x->key(x.optString("id")){var why by remember{mutableStateOf("")};Text(x.optString("label")+" · "+when(x.optString("status")){"pending"->"En attente centrale";"processed"->"Traitée par le centre";"cancelled"->"Annulée";else->"Refusée"});if(x.optString("status")=="pending"){OutlinedTextField(why,{why=it},label={Text("Motif d’annulation")});TextButton({onSave("central_request_cancel",obj("request" to x.optString("id"),"reason" to why))},enabled=enabled&&why.isNotBlank()){Text("Annuler la demande")}}}}
}
