package cm.naxa.naxasecurity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@Composable internal fun SecurityOperationalPanel(id:String){
 val incident=id in listOf("B3.27","B3.28")
 val work=id in listOf("B5.11","B5.12","B5.16","B5.17")
 if(id in listOf("B1.17","B1.18")){
 var plan by remember(id){mutableStateOf("Essentiel")}
 var annual by remember(id){mutableStateOf(false)}
 var siteCount by remember(id){mutableStateOf("1")}
 listOf("Essentiel","Business","Professional").forEach{p->FilterChip(selected=p==plan,onClick={plan=p},label={Text(p)})}
 Row{Checkbox(annual,{annual=it});Text("Annuel")}
 OutlinedTextField(siteCount,{siteCount=it.filter{c->c.isDigit()}.take(9)},label={Text("Nombre de sites envisagés")},modifier=Modifier.fillMaxWidth())
 Text("${SecurityDomain.quote(plan,annual)} FCFA")
 Text(if(SecurityDomain.siteEligibility(plan,siteCount.toIntOrNull()?:0))"Éligible sous réserve des quotas et de la validation serveur" else "Nombre de sites incompatible")
 }else if(incident||work){
 var subject by remember(id){mutableStateOf("")}
 var option by remember(id){mutableStateOf(if(incident)"P2" else "preventive")}
 var result by remember(id){mutableStateOf("")}
 OutlinedTextField(subject,{if(it.length<=500){subject=it;result=""}},label={Text("Objet du brouillon")},modifier=Modifier.fillMaxWidth())
 (if(incident)listOf("P2","P3","P4") else listOf("preventive","corrective","inspection")).forEach{v->FilterChip(selected=v==option,onClick={option=v;result=""},label={Text(v)})}
 Button(onClick={result=if(SecurityDomain.validDraft(subject,option,incident))"Brouillon validé en mémoire — non transmis" else "Saisie invalide"}){Text("Vérifier le brouillon")}
 Text(result)
 }
}
