package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import org.json.JSONObject
@Composable internal fun GrilladDimensionTargets(data:JSONObject,enabled:Boolean,onSave:(JSONObject)->Unit){
 var kind by remember{mutableStateOf("family")};var subject by remember{mutableStateOf("")};var amount by remember{mutableStateOf("")};var reason by remember{mutableStateOf("")}
 Text("Objectifs détaillés du jour",style=MaterialTheme.typography.titleMedium);Text("Axes indépendants : ne pas les additionner.")
 rows(data.optJSONArray("dimension_targets")).forEach{x->Text((if(x.optString("kind")=="seller")x.optString("subject").take(8) else x.optString("label"))+" : "+x.optString("actual")+" / "+x.optString("amount")+" F")}
 Row{listOf("family" to "Famille","item" to "Article","seller" to "Vendeur").forEach{(k,v)->TextButton({kind=k;subject=""},enabled=enabled){Text(if(kind==k)"✓ "+v else v)}}}
 val choices=when(kind){"family"->families.map{it to it};"item"->rows(data.optJSONArray("items")).map{it.optString("id") to it.optString("name")};else->rows(data.optJSONObject("pilotage")?.optJSONArray("team")).filter{it.optString("role")=="seller"}.map{it.optString("id") to it.optString("id").take(8)}}
 choices.forEach{(id,label)->OutlinedButton({subject=id},enabled=enabled){Text((if(subject==id)"✓ " else "")+label)}}
 OutlinedTextField(amount,{amount=it},label={Text("Montant objectif détaillé")});OutlinedTextField(reason,{reason=it},label={Text("Motif de l’objectif")})
 Button({onSave(obj("day" to dayKey(),"kind" to kind,"subject" to subject,"amount" to amount.toLongOrNull(),"reason" to reason))},enabled=enabled&&choices.any{it.first==subject}&&amount.toLongOrNull()?.let{it in 0..1000000000}==true&&reason.isNotBlank()){Text("Enregistrer l’objectif détaillé")}
}
