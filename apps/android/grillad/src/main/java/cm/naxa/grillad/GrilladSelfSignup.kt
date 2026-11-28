package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun GrilladSelfSignup(api:ConnectedApi,installation:String,locale:String,done:(JSONObject)->Unit,back:()->Unit){
 val scope=rememberCoroutineScope()
 fun tr(v:String)=grilladLabel(v,locale)
 var name by remember{mutableStateOf("")};var username by remember{mutableStateOf("")};var phone by remember{mutableStateOf("")};var org by remember{mutableStateOf("")};var site by remember{mutableStateOf("")};var password by remember{mutableStateOf("")};var confirm by remember{mutableStateOf("")};var consent by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")};var show by remember{mutableStateOf(false)}
 androidx.activity.compose.BackHandler(!busy){back()}
 Column(Modifier.fillMaxSize().imePadding().safeDrawingPadding().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
  GrilladBrandMark();Text(tr("Créer mon compte"),style=MaterialTheme.typography.headlineMedium);Text(tr("72 heures gratuites, sans paiement."))
  OutlinedTextField(name,{name=it},label={Text(tr("Nom et prénom"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
  OutlinedTextField(username,{username=it},label={Text(tr("Nom d’utilisateur"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
  OutlinedTextField(phone,{phone=it},label={Text(tr("Téléphone (+237…)"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
  OutlinedTextField(org,{org=it},label={Text(tr("Nom de l’entreprise"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
  OutlinedTextField(site,{site=it},label={Text(tr("Premier point de vente"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
  Text(tr("Essai gratuit de 72 heures, sans prélèvement automatique. Les données servent à fournir et sécuriser le service. Après expiration, les opérations sont bloquées jusqu’au renouvellement."))
  Row{Checkbox(consent,{consent=it},enabled=!busy);Text(tr("J’accepte les conditions d’utilisation et la politique de confidentialité"),modifier=Modifier.weight(1f))}
  OutlinedTextField(password,{password=it},label={Text(tr("Mot de passe"))},visualTransformation=if(show)VisualTransformation.None else PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth(),enabled=!busy)
  OutlinedTextField(confirm,{confirm=it},label={Text(tr("Confirmer le mot de passe"))},visualTransformation=if(show)VisualTransformation.None else PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth(),enabled=!busy)
  TextButton({show=!show}){Text(tr(if(show)"Masquer le mot de passe" else "Afficher le mot de passe"))}
  Button({if(!busy){busy=true;message="";scope.launch{try{check(password==confirm){"Les mots de passe ne correspondent pas."};val s=api.call(obj("action" to "signup_internal","name" to name,"username" to username,"phone" to phone,"organization" to org,"site_name" to site,"terms" to (if(consent)"grillad-2026-11-28-v1" else ""),"installation" to installation,"platform" to "android","password" to password)) as JSONObject;password="";confirm="";done(s)}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message=grilladCommercialError(e)}finally{busy=false}}}},enabled=!busy&&consent,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text(tr("Démarrer mon essai gratuit"))}
  if(message.isNotBlank())Text(tr(message));TextButton(back,enabled=!busy){Text(tr("Retour à la connexion"))}
 }
}
