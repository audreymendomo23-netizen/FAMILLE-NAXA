package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
@Composable internal fun GrilladOfflineBatch(items:List<JSONObject>,enabled:Boolean,sale:Boolean,submit:(JSONArray)->Unit){
 var item by remember{mutableStateOf("")};var qty by remember{mutableStateOf("")};var received by remember{mutableStateOf("")};var method by remember{mutableStateOf("cash")};val lines=remember{mutableStateListOf<JSONObject>()}
 Text(if(sale)"Lot de ventes hors ligne" else "Lot de préparations hors ligne",style=MaterialTheme.typography.titleMedium)
 Text("Lot chiffré à l’enregistrement, jusqu’à 30 lignes. Aucun stock ni vente confirmé avant synchronisation. Même jour, caisse et prix pour les ventes.")
 items.forEach{x->TextButton({item=x.optString("id")},enabled=enabled){Text((if(item==x.optString("id"))"✓ " else "")+x.optString("name"))}}
 OutlinedTextField(qty,{qty=it},label={Text("Quantité du lot")},enabled=enabled,modifier=Modifier.fillMaxWidth())
 val q=qty.toLongOrNull();val price=items.firstOrNull{it.optString("id")==item}?.optLong("price");val total=if(q!=null&&q in 1L..1000000L&&price!=null&&price in 1L..1000000000L)q*price else null
 if(sale){GrilladTenderChoice(method){method=it};Text("Total indicatif : "+(total?: "—")+" F");OutlinedTextField(received,{received=it},label={Text("Montant net déclaré du lot")},enabled=enabled)}
 Button({if(q!=null){val p=obj("item" to item,"qty" to q);if(sale)p.put("price",price).put("received",received.toLongOrNull()).apply{if(method!="cash")put("method",method)};lines.add(obj("event" to UUID.randomUUID().toString(),"operation" to if(sale)"sell" else "prepare","payload" to p));qty="";received=""}},enabled=enabled&&item.isNotBlank()&&q!=null&&q in 1L..1000000L&&(!sale||total!=null&&received.toLongOrNull()==total)&&lines.size<30){Text("Ajouter au lot")}
 lines.toList().forEach{x->Row{Text((items.firstOrNull{it.optString("id")==x.optJSONObject("payload")?.optString("item")}?.optString("name")?:"Article")+" × "+x.optJSONObject("payload")?.optString("qty"));TextButton({lines.remove(x)},enabled=enabled){Text("Retirer")}}}
 Button({val a=JSONArray();lines.forEach{a.put(it)};submit(a)},enabled=enabled&&lines.isNotEmpty()){Text("Enregistrer et synchroniser le lot")}
}
