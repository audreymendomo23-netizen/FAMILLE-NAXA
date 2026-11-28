package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable internal fun GrilladSupportCenter(enabled:Boolean,locale:String,onLocale:(String)->Unit,request:suspend(JSONObject)->Any){
 fun tr(k:String)=grilladLabel(k,locale)
 val labels=when(locale){"en"->listOf("Language","Help","Create ticket","Submit request");"ff-CM"->listOf("Ɗemngal","Ballal","Sos kayit","Neldu ɗaɓɓitannde");else->listOf("Langue","Aide","Créer un ticket","Envoyer la demande")}
 val scope=rememberCoroutineScope();var subject by remember{mutableStateOf("")};var description by remember{mutableStateOf("")};var id by remember{mutableStateOf(UUID.randomUUID().toString())};var uncertain by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")};var tickets by remember{mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember{mutableStateOf("")}
 Text(labels[0]);Row{listOf("fr" to "FR","en" to "EN","ff-CM" to "Fufulɓe").forEach{(l,n)->TextButton({onLocale(l)}){Text(if(locale==l)"✓ "+n else n)}}}
 if(locale=="ff-CM")Text("Commandes d’aide traduites ; guides métier en français, validation linguistique en attente.")
 Text("FAQ · "+labels[1],style=MaterialTheme.typography.titleMedium)
 Text(if(locale=="en")"Payment: manually record cash, MTN or Orange. GRILLAD does not debit customer funds." else "Règlement : déclaration manuelle espèces, MTN ou Orange. Aucun débit client par GRILLAD.")
 Text(if(locale=="en")"Offline: keep the encrypted batch and retry the same request after reconnecting." else "Hors ligne : conservez le lot chiffré, réessayez la même demande après reconnexion.")
 Text(if(locale=="en")"Subscription: the owner follows the instructions and waits for central confirmation." else "Abonnement : le promoteur suit les instructions et attend la validation centrale.")
 Text(if(locale=="en")"Never share your PIN, OTP or password." else "Ne communiquez jamais PIN, OTP ou mot de passe.")
 Text(labels[2],style=MaterialTheme.typography.titleMedium);Text("Registre Famille NAXA. Conversation disponible ; accès agent soumis à habilitation. Appels audio natifs en qualification ; accès agent et réseau requis.")
 OutlinedTextField(subject,{if(it.length<=120)subject=it},label={Text(tr("Sujet assistance"))},enabled=enabled&&!busy&&!uncertain,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(description,{if(it.length<=2000)description=it},label={Text(tr("Description assistance"))},enabled=enabled&&!busy&&!uncertain,modifier=Modifier.fillMaxWidth())
 Button({busy=true;uncertain=true;scope.launch{try{val x=request(obj("action" to "support_open","event" to id,"subject" to subject.trim(),"description" to description.trim())) as JSONObject;message="Dossier enregistré : "+x.optString("id");subject="";description="";id=UUID.randomUUID().toString();uncertain=false}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Confirmation non obtenue. Réessayez la même demande."}finally{busy=false}}},enabled=enabled&&!busy&&subject.trim().length>=3&&description.trim().length>=10){Text(if(uncertain)"Réessayer la même demande" else labels[3])}
 OutlinedButton({busy=true;scope.launch{try{tickets=rows(request(obj("action" to "support_list")) as org.json.JSONArray)}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Assistance indisponible."}finally{busy=false}}},enabled=enabled&&!busy){Text(tr("Mes dossiers / Actualiser"))}
 tickets.forEach{t->Text(t.optString("subject")+" — "+t.optString("status"));TextButton({selected=t.optString("id")},enabled=enabled&&!busy){Text(tr("Conversation"))}};if(selected.isNotBlank())key(selected){GrilladSupportThread(selected,enabled,request,locale)};if(message.isNotBlank())Text(message)
}
