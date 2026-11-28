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
@Composable internal fun GrilladSelfSignup(api:ConnectedApi,installation:String,locale:String,mode:String,done:(JSONObject)->Unit,back:()->Unit){
 val scope=rememberCoroutineScope()
 fun tr(v:String)=grilladLabel(v,locale)
 var step by remember{mutableStateOf(0)};var name by remember{mutableStateOf("")};var email by remember{mutableStateOf("")};var phone by remember{mutableStateOf("")};var org by remember{mutableStateOf("")};var site by remember{mutableStateOf("")};var password by remember{mutableStateOf("")};var confirm by remember{mutableStateOf("")};var verification by remember{mutableStateOf("")};var consent by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")};var show by remember{mutableStateOf(false)}
 fun profile(action:String)=obj("action" to action,"name" to name,"email" to email,"phone" to phone,"organization" to org,"site_name" to site,"terms" to (if(consent)"grillad-2026-11-28-v1" else ""),"installation" to installation,"platform" to "android")
 androidx.activity.compose.BackHandler(!busy){back()}
 Column(Modifier.fillMaxSize().imePadding().safeDrawingPadding().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
  GrilladBrandMark()
  Text(tr(if(mode=="signup")if(step==0)"Créer mon compte" else "Vérifier mon adresse e-mail" else if(step==0)"Mot de passe oublié" else "Créer un nouveau mot de passe"),style=MaterialTheme.typography.headlineMedium)
  if(mode=="signup")Text(tr("72 heures gratuites, sans paiement."))
  if(step==0){
   if(mode=="signup")OutlinedTextField(name,{name=it},label={Text(tr("Nom et prénom"))},modifier=Modifier.fillMaxWidth())
   OutlinedTextField(email,{email=it},label={Text(tr("Adresse e-mail"))},modifier=Modifier.fillMaxWidth(),keyboardOptions=androidx.compose.foundation.text.KeyboardOptions(keyboardType=androidx.compose.ui.text.input.KeyboardType.Email))
   if(mode=="signup"){
    OutlinedTextField(phone,{phone=it},label={Text(tr("Téléphone (+237…)"))},modifier=Modifier.fillMaxWidth(),keyboardOptions=androidx.compose.foundation.text.KeyboardOptions(keyboardType=androidx.compose.ui.text.input.KeyboardType.Phone))
    OutlinedTextField(org,{org=it},label={Text(tr("Nom de l’entreprise"))},modifier=Modifier.fillMaxWidth())
    OutlinedTextField(site,{site=it},label={Text(tr("Premier point de vente"))},modifier=Modifier.fillMaxWidth())
    Text(tr("Essai gratuit de 72 heures, sans prélèvement automatique. Les données servent à fournir et sécuriser le service. Après expiration, les opérations sont bloquées jusqu’au renouvellement."))
    Row{Checkbox(consent,{consent=it},enabled=!busy);Text(tr("J’accepte les conditions d’utilisation et la politique de confidentialité"),modifier=Modifier.weight(1f))}
   }
  }
  if(step==1){Text(tr("Copiez le code ou le lien de vérification reçu par e-mail, sans ouvrir le lien."));OutlinedTextField(verification,{verification=it},label={Text(tr("Code ou lien de vérification"))},modifier=Modifier.fillMaxWidth())}
  if((mode=="signup"&&step==0)||(mode=="reset"&&step==1)){OutlinedTextField(password,{password=it},label={Text(tr("Mot de passe"))},visualTransformation=if(show)VisualTransformation.None else PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth());OutlinedTextField(confirm,{confirm=it},label={Text(tr("Confirmer le mot de passe"))},visualTransformation=if(show)VisualTransformation.None else PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth());TextButton({show=!show}){Text(tr(if(show)"Masquer le mot de passe" else "Afficher le mot de passe"))}}
  if(step!=2)Button({if(!busy){busy=true;message="";scope.launch{try{
   if(mode=="signup"&&step==0){check(password==confirm){"Les mots de passe ne correspondent pas."};api.call(profile("signup_start").put("password",password));password="";confirm="";step=1}
   else if(mode=="signup"){val s=api.call(profile("signup_complete").put("verification",verification)) as JSONObject;verification="";done(s)}
   else if(step==0){api.call(obj("action" to "recovery_email","email" to email));step=1}
   else{check(password==confirm){"Les mots de passe ne correspondent pas."};val s=api.call(obj("action" to "recovery_complete","email" to email,"verification" to verification,"password" to password)) as JSONObject;password="";confirm="";verification="";step=2;message=if(s.optBoolean("sessions_revoked"))"Mot de passe modifié." else "Mot de passe modifié. Déconnexion des autres appareils non confirmée."}
  }catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message=grilladCommercialError(e)}finally{busy=false}}}},enabled=!busy&&(mode!="signup"||step!=0||consent),modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text(tr(if(step==0)"Continuer" else if(mode=="signup")"Démarrer mon essai gratuit" else "Enregistrer le nouveau mot de passe"))}
  if(message.isNotBlank())Text(tr(message))
  TextButton(back,enabled=!busy){Text(tr("Retour à la connexion"))}
 }
}
