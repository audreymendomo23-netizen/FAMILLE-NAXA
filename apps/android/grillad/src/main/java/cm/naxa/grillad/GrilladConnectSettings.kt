package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import org.json.JSONObject
@Composable internal fun GrilladConnectSettings(connect:JSONObject?,items:List<JSONObject>,enabled:Boolean,onSave:(String,JSONObject)->Unit){
 Text("Partenaires et catalogue partagé");Text("Accords des deux côtés requis. Aucun secret QR affiché.")
 rows(connect?.optJSONArray("links")).forEach{l->key(l.optString("id")){var expanded by remember{mutableStateOf(false)};var reason by remember{mutableStateOf("")};TextButton({expanded=!expanded}){Text(l.optString("partner")+" · "+if(l.optBoolean("available"))"Disponible" else "Indisponible")}
 if(expanded){Text("Échéance : "+l.optString("expires_at"));OutlinedTextField(reason,{reason=it},label={Text("Motif catalogue ou lien")});Button({onSave("connect_link_set",obj("link" to l.optString("id"),"enabled" to !l.optBoolean("enabled"),"reason" to reason))},enabled=enabled&&reason.isNotBlank()){Text(if(l.optBoolean("enabled"))"Suspendre le lien" else "Réactiver le lien")};val arr=l.optJSONArray("items");val published=(0 until (arr?.length()?:0)).map{arr?.optString(it)}
 items.forEach{x->val present=x.optString("id") in published;Text(x.optString("name")+" · "+if(present)"Publié" else "Non publié");TextButton({onSave("connect_item_set",obj("link" to l.optString("id"),"item" to x.optString("id"),"enabled" to !present,"reason" to reason))},enabled=enabled&&reason.isNotBlank()&&(present||l.optBoolean("available"))){Text(if(present)"Retirer" else "Publier")}}}}}
}
