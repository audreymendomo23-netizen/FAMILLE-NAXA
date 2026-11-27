package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import org.json.JSONObject
@Composable internal fun GrilladMissingArrivals(data:JSONObject,user:String,manager:Boolean,enabled:Boolean,onSave:(String,JSONObject)->Unit){
 val requests=rows(data.optJSONArray("missing_arrivals"))
 Text("Arrivées manquantes déclarées")
 rows(data.optJSONArray("history")).filter{x->x.optString("kind")=="departure_without_arrival"&&x.optString("actor")==user&&requests.none{it.optString("departure")==x.optString("id")&&it.optString("status") in listOf("pending","approved")}}.forEach{x->key(x.optString("id")){var seconds by remember{mutableStateOf("")};var why by remember{mutableStateOf("")};Text("Départ prouvé : "+x.optString("captured_at"));OutlinedTextField(seconds,{seconds=it},label={Text("Durée avant départ (secondes)")});OutlinedTextField(why,{why=it},label={Text("Motif arrivée manquante")});Button({onSave("missing_arrival_request",obj("departure" to x.optString("id"),"seconds" to seconds.toLongOrNull(),"reason" to why))},enabled=enabled&&seconds.toLongOrNull()?.let{it in 1..86400}==true&&why.isNotBlank()){Text("Déclarer l’arrivée manquante")}}}
 requests.forEach{x->key(x.optString("id")){var why by remember{mutableStateOf("")};Text("Arrivée déclarée · "+x.optString("seconds")+" s · "+x.optString("reason")+" · "+when(x.optString("status")){"approved"->"Approuvée";"rejected"->"Refusée";else->"En attente"});if(manager&&x.optString("requester")!=user&&x.optString("status")=="pending"){OutlinedTextField(why,{why=it},label={Text("Motif décision arrivée")});listOf("approved" to "Approuver","rejected" to "Refuser").forEach{(k,v)->TextButton({onSave("missing_arrival_decide",obj("request" to x.optString("id"),"decision" to k,"reason" to why))},enabled=enabled&&why.isNotBlank()){Text(v)}}}}}
}
