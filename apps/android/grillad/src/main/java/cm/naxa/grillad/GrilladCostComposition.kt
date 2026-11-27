package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import org.json.JSONArray
import org.json.JSONObject
@Composable internal fun GrilladCostComposition(item:JSONObject,enabled:Boolean,onSave:(JSONObject)->Unit){
 var expanded by remember{mutableStateOf(false)}
 var lines by remember{mutableStateOf(rows(item.optJSONArray("cost_components")).joinToString("\n"){it.optString("label")+";"+if(it.isNull("amount"))"" else it.optString("amount")})}
 var reason by remember{mutableStateOf("")};var error by remember{mutableStateOf("")}
 TextButton({expanded=!expanded}){Text("Estimer le coût par composition")}
 if(expanded){Text("Montant direct estimé par unité vendue. Une ligne : composant ; FCFA. Montant vide si inconnu.")
 Text("Qualité : "+if(item.isNull("cost"))"Incomplet" else "Estimé")
 OutlinedTextField(lines,{lines=it},label={Text("Composants du coût")},minLines=3,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(reason,{reason=it},label={Text("Motif de composition")})
 if(error.isNotBlank())Text(error)
 Button({try{val parts=lines.lines().filter{it.isNotBlank()};require(parts.size in 1..30);var total=0L;val array=JSONArray();parts.forEach{val p=it.split(";");require(p.size==2&&p[0].trim().length in 1..160);val a=p[1].trim();val value=if(a.isEmpty())null else a.toLongOrNull()?:error("Montant invalide");if(value!=null){require(value in 0..1000000000);total+=value};array.put(obj("label" to p[0].trim(),"amount" to value))};require(total<=1000000000&&reason.trim().length in 1..300);error="";onSave(obj("item" to item.optString("id"),"components" to array,"reason" to reason))}catch(e:Exception){error="Composition invalide : libellé ; montant FCFA ou vide."}},enabled=enabled){Text("Enregistrer l’estimation")}
 }
}
