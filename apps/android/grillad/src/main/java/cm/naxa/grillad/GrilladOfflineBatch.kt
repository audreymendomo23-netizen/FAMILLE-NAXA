package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
@Composable internal fun GrilladOfflineBatch(items:List<JSONObject>,enabled:Boolean,submit:(JSONArray)->Unit){
 var item by remember{mutableStateOf("")};var qty by remember{mutableStateOf("")};val lines=remember{mutableStateListOf<JSONObject>()}
 Text("Lot de préparations hors ligne",style=MaterialTheme.typography.titleMedium)
 Text("Après connexion initiale, jusqu’à 30 lignes. Lot chiffré lors de l’enregistrement ; aucun stock confirmé avant synchronisation.")
 items.forEach{x->TextButton({item=x.optString("id")},enabled=enabled){Text((if(item==x.optString("id"))"✓ " else "")+x.optString("name"))}}
 OutlinedTextField(qty,{qty=it},label={Text("Quantité du lot")},enabled=enabled,modifier=Modifier.fillMaxWidth())
 val q=qty.toLongOrNull()
 Button({if(q!=null){lines.add(obj("event" to UUID.randomUUID().toString(),"operation" to "prepare","payload" to obj("item" to item,"qty" to q)));qty=""}},enabled=enabled&&item.isNotBlank()&&q!=null&&q in 1L..1000000L&&lines.size<30){Text("Ajouter au lot")}
 lines.toList().forEach{x->Row{Text((items.firstOrNull{it.optString("id")==x.optJSONObject("payload")?.optString("item")}?.optString("name")?:"Article")+" × "+x.optJSONObject("payload")?.optString("qty"));TextButton({lines.remove(x)},enabled=enabled){Text("Retirer")}}}
 Button({val a=JSONArray();lines.forEach{a.put(it)};submit(a)},enabled=enabled&&lines.isNotEmpty()){Text("Enregistrer et synchroniser le lot")}
}
