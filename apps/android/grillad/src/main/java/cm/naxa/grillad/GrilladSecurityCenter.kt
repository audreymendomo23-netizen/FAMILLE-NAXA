package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.json.JSONObject
@Composable internal fun GrilladSecurityCenter(security:JSONObject?,request:suspend(JSONObject)->JSONObject){
 val cameras=if(security?.optBoolean("available")==true)rows(security.optJSONArray("cameras")) else emptyList()
 var page by remember{mutableStateOf(0)};var selected by remember{mutableStateOf("")};val pages=((cameras.size+3)/4).coerceAtLeast(1);val index=page.coerceIn(0,pages-1)
 Text("Centre de surveillance",style=MaterialTheme.typography.titleMedium);Text(if(security?.optBoolean("available")==true)"Site lié à NAXA SECURITY." else "Aucune liaison autorisée.");Text("Aucun flux direct sans session autorisée du relais.")
 repeat(2){row->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp)){repeat(2){col->val c=cameras.getOrNull(index*4+row*2+col);OutlinedCard(Modifier.weight(1f).heightIn(min=112.dp)){Column(Modifier.padding(8.dp)){if(c==null)Text("Emplacement libre")else TextButton({selected=c.optString("id")}){Column{Text(c.optString("name"));Text(when(c.optString("status")){"online"->"En ligne";"offline"->"Hors ligne";else->"État inconnu"});Text("Inventaire")}}}}}}}
 Row{TextButton({page=index-1},enabled=index>0){Text("Précédent")};Text("${index+1} / $pages");TextButton({page=index+1},enabled=index+1<pages){Text("Suivant")}}
 cameras.firstOrNull{it.optString("id")==selected}?.let{c->Text(c.optString("name"));Text(c.optString("observed_at"));if(security?.optBoolean("live_request_available")==true&&c.optString("status")=="online")key(c.optString("id")){GrilladNativeWhepPlayer(c.optString("id"),request)}else Text("Direct indisponible sans autorisation du relais.");TextButton({selected=""}){Text("Fermer le détail")}}
 Text("Incidents");if(security?.optBoolean("available")==true)rows(security.optJSONArray("incidents")).forEach{Text(it.optString("category")+" · "+it.optString("observed_at"))}
}
