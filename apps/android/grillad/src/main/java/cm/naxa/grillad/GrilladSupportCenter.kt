package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable internal fun GrilladSupportCenter(enabled:Boolean,request:suspend(JSONObject)->Any){
 val ctx=LocalContext.current;val pref=remember{ctx.getSharedPreferences("grillad-help-v1",0)};var locale by remember{mutableStateOf(pref.getString("locale","fr")?:"fr")}
 val labels=when(locale){"en"->listOf("Language","Help","Create ticket","Submit request");"ff-CM"->listOf("Ɗemngal","Ballal","Sos kayit","Neldu ɗaɓɓitannde");else->listOf("Langue","Aide","Créer un ticket","Envoyer la demande")}
 val scope=rememberCoroutineScope();var subject by remember{mutableStateOf("")};var description by remember{mutableStateOf("")};var id by remember{mutableStateOf(UUID.randomUUID().toString())};var uncertain by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")};var tickets by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 Text(labels[0]);Row{listOf("fr" to "FR","en" to "EN","ff-CM" to "Fufulɓe").forEach{(l,n)->TextButton({locale=l;pref.edit().putString("locale",l).apply()}){Text(if(locale==l)"✓ "+n else n)}}}
 if(locale!="fr")Text("Commandes d’aide traduites ; guides métier encore en français.")
 Text("FAQ · "+labels[1],style=MaterialTheme.typography.titleMedium)
 Text("Règlement : déclaration manuelle espèces, MTN ou Orange. Aucun débit client par GRILLAD.")
 Text("Hors ligne : conservez le lot chiffré, réessayez la même demande après reconnexion.")
 Text("Abonnement : le promoteur suit les instructions et attend la validation centrale.")
 Text("Ne communiquez jamais PIN, OTP ou mot de passe.")
 Text(labels[2],style=MaterialTheme.typography.titleMedium);Text("Registre Famille NAXA. Livechat/appels : raccordement en attente.")
 OutlinedTextField(subject,{if(it.length<=120)subject=it},label={Text("Sujet assistance")},enabled=enabled&&!busy&&!uncertain,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(description,{if(it.length<=2000)description=it},label={Text("Description assistance")},enabled=enabled&&!busy&&!uncertain,modifier=Modifier.fillMaxWidth())
 Button({busy=true;uncertain=true;scope.launch{try{val x=request(obj("action" to "support_open","event" to id,"subject" to subject.trim(),"description" to description.trim())) as JSONObject;message="Dossier enregistré : "+x.optString("id");subject="";description="";id=UUID.randomUUID().toString();uncertain=false}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Confirmation non obtenue. Réessayez la même demande."}finally{busy=false}}},enabled=enabled&&!busy&&subject.trim().length>=3&&description.trim().length>=10){Text(if(uncertain)"Réessayer la même demande" else labels[3])}
 OutlinedButton({busy=true;scope.launch{try{tickets=rows(request(obj("action" to "support_list")) as org.json.JSONArray)}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Assistance indisponible."}finally{busy=false}}},enabled=enabled&&!busy){Text("Mes dossiers / Actualiser")}
 tickets.forEach{Text(it.optString("subject")+" — "+it.optString("status"))};if(message.isNotBlank())Text(message)
}
