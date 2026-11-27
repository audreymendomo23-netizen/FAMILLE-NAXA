package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import org.json.JSONObject
@Composable internal fun GrilladPurchases(data:JSONObject,enabled:Boolean,onSave:(String,JSONObject)->Unit){
 var supplier by remember{mutableStateOf("")};var input by remember{mutableStateOf("")};var unit by remember{mutableStateOf("")};var quantity by remember{mutableStateOf("")};var amount by remember{mutableStateOf("")};var ref by remember{mutableStateOf("")}
 Text("Achats et intrants reçus");Text("Registre documentaire : aucun mouvement de caisse ni coût de vente automatique.")
 OutlinedTextField(supplier,{supplier=it},label={Text("Fournisseur")});OutlinedTextField(input,{input=it},label={Text("Intrant reçu")});OutlinedTextField(unit,{unit=it},label={Text("Unité d’achat")});OutlinedTextField(quantity,{quantity=it},label={Text("Quantité reçue")});OutlinedTextField(amount,{amount=it},label={Text("Montant achat FCFA")});OutlinedTextField(ref,{ref=it},label={Text("Référence achat")})
 val q=quantity.replace(',','.').toDoubleOrNull();val a=amount.toLongOrNull()
 Button({if(q!=null&&a!=null)onSave("record_purchase",obj("supplier" to supplier,"input_name" to input,"unit" to unit,"quantity" to q,"amount" to a,"receipt_reference" to ref))},enabled=enabled&&supplier.isNotBlank()&&input.isNotBlank()&&unit.isNotBlank()&&q!=null&&q.isFinite()&&q>0&&a!=null&&a in 1..1000000000){Text("Enregistrer la réception")}
 rows(data.optJSONArray("purchases")).forEach{x->key(x.optString("id")){var why by remember{mutableStateOf("")};Text(x.optString("input_name")+" · "+x.optString("supplier"));Text(x.optString("quantity")+" "+x.optString("unit")+" · "+x.optString("amount")+" F · coût indicatif "+x.optString("unit_cost_estimate"));if(!x.isNull("cancelled_at"))Text("Annulé · "+x.optString("cancel_reason"))else{OutlinedTextField(why,{why=it},label={Text("Motif d’annulation achat")});TextButton({onSave("cancel_purchase",obj("purchase" to x.optString("id"),"reason" to why))},enabled=enabled&&why.isNotBlank()){Text("Annuler l’achat")}}}}
}
