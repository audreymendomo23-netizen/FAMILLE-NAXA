package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject
@Composable internal fun GrilladDirectBasket(items:List<JSONObject>,enabled:Boolean,submit:(JSONArray)->Unit){
 var open by remember{mutableStateOf(false)};val qty=remember{mutableStateMapOf<String,String>()}
 OutlinedButton({open=!open},enabled=enabled){Text(if(open)"Fermer le panier" else "Vente de plusieurs articles")}
 if(!open)return
 Text("Panier de vente",style=MaterialTheme.typography.titleMedium)
 var total=0L;var valid=true;val lines=JSONArray()
 items.forEach{x->val id=x.optString("id");val value=qty[id].orEmpty();val n=value.toLongOrNull();val remaining=x.optLong("remaining");val price=x.optLong("price")
 OutlinedTextField(value,{qty[id]=it},label={Text(x.optString("name")+" · "+price+" F · "+remaining+" restants")},modifier=Modifier.fillMaxWidth(),enabled=enabled)
 if(value.isNotBlank()&&(n==null||n<0||n>remaining||n>1_000_000))valid=false
 if(n!=null&&n>0&&n<=remaining&&n<=1_000_000){lines.put(obj("item" to id,"qty" to n,"price" to price));total+=n*price}}
 Text("Total indicatif : "+total+" F")
 Button({submit(lines);qty.clear();open=false},enabled=enabled&&valid&&lines.length() in 1..20,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text("Valider le panier")}
}
