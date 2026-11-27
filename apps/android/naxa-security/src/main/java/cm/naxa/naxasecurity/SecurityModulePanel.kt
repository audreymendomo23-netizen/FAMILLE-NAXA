package cm.naxa.naxasecurity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable internal fun SecurityModulePanel(screen:String){
 val m=securityModules.firstOrNull{it.screen==screen}?:return
 val values=remember(m.id){mutableStateMapOf<String,String>()}
 var result by remember(m.id){mutableStateOf("")}
 val labels=mapOf("device" to "Référence équipement","reference" to "Référence non sensible","purpose" to "Motif","duration" to "Durée (minutes)","detail" to "Description sans donnée sensible","value" to "Valeur saisie","threshold" to "Seuil saisi","observed" to "Âge du heartbeat (secondes)","amount" to "Montant FCFA","digest" to "Empreinte SHA-256","consent" to "Consentement","locale" to "Langue")
 fun choices(k:String):List<String>?=when(k){
 "consent"->listOf("yes","no")
 "kind"->if(m.kind=="alarm")listOf("intrusion","sabotage","fault")else listOf("temperature","humidity","water","co","gas")
 "channel"->if(m.kind=="payment")listOf("mobile_money","bank")else listOf("push","sms","email","whatsapp")
 "protocol"->listOf("onvif","rtsp","vendor_api","other")
 "category"->listOf("account","technical","billing","privacy","other")
 "preference"->listOf("enabled","disabled")
 "locale"->listOf("fr","en","ff-CM")
 else->null
 }
 Column(verticalArrangement=Arrangement.spacedBy(8.dp)){
  Text(m.title,style=MaterialTheme.typography.titleLarge);Text(m.note)
  if(m.fields.isEmpty())SecurityNativeModuleAction(m,emptyMap())
  else{
   m.fields.forEach{k->
    val options=choices(k)
    if(options==null)OutlinedTextField(values[k]?:"",{values[k]=it.take(500);result=""},label={Text(labels[k]?:k)},modifier=Modifier.fillMaxWidth())
    else {Text(labels[k]?:k);options.forEach{v->FilterChip(selected=values[k]==v,onClick={values[k]=v;result=""},label={Text(v)})}}
   }
   Button(onClick={result=try{SecurityModuleRules.evaluate(m,values.toMap())}catch(e:IllegalArgumentException){"Saisie invalide ou incomplète."}}){Text("Vérifier le brouillon")}
   Text(result)
   SecurityNativeModuleAction(m,values.toMap())
  }
 }
}
