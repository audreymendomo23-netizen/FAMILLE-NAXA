package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun GrilladPersonalProfile(enabled:Boolean,request:suspend(JSONObject)->JSONObject){
 val scope=rememberCoroutineScope()
 var profile by remember{mutableStateOf<JSONObject?>(null)}
 var name by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 fun invoke(body:JSONObject){if(busy)return;busy=true;message="";scope.launch{try{val v=request(body);profile=v;name=v.optString("display_name");if(body.optString("action")=="profile_set")message="Profil enregistré"}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Profil indisponible ou modifié ailleurs. Actualisez avant de réessayer."}finally{busy=false}}}
 Text("Mon profil",style=MaterialTheme.typography.titleMedium)
 Text("Nom d’affichage GRILLAD, visible uniquement sur votre compte. Ne modifie pas votre identité de connexion.")
 OutlinedButton({invoke(obj("action" to "profile_get"))},enabled=enabled&&!busy){Text(if(profile==null)"Afficher mon profil" else "Actualiser mon profil")}
 profile?.let{p->OutlinedTextField(name,{if(it.length<=80)name=it},label={Text("Mon nom d’affichage")},modifier=Modifier.fillMaxWidth(),enabled=enabled&&!busy);Button({invoke(obj("action" to "profile_set","name" to name.trim(),"revision" to p.optInt("revision")))},enabled=enabled&&!busy&&name.trim().length>=2){Text("Enregistrer mon profil")}}
 if(message.isNotBlank())Text(message)
}
