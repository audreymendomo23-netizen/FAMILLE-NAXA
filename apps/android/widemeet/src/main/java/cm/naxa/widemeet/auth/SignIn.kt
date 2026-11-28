package cm.naxa.widemeet.auth
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.Image
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import cm.naxa.widemeet.R
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import cm.naxa.widemeet.BuildConfig
import java.util.UUID

@Composable fun SignIn(english:Boolean,configured:Boolean,gateway:AuthGateway,onSession:(Session)->Unit,onBack:()->Unit){
 var identifier by remember{mutableStateOf("")};var password by remember{mutableStateOf("")};var show by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var recoveryError by remember{mutableStateOf(false)};var recoveryNotice by remember{mutableStateOf(false)}
 var keep by remember{mutableStateOf(false)};var pin by remember{mutableStateOf("")};var pinConfirm by remember{mutableStateOf("")}
 var signup by remember{mutableStateOf(false)};var enterprise by remember{mutableStateOf(false)};var display by remember{mutableStateOf("")};var workspace by remember{mutableStateOf("")};var confirm by remember{mutableStateOf("")};var accepted by remember{mutableStateOf(false)};var registered by remember{mutableStateOf("")};var requestId by remember{mutableStateOf(UUID.randomUUID().toString())}
 var keyRecovery by remember{mutableStateOf(false)};var recovered by remember{mutableStateOf(false)}
 var signupEnabled by remember{mutableStateOf(false)};var policyLoading by remember{mutableStateOf(false)};var registrationPending by remember{mutableStateOf(false)};var legal by remember{mutableStateOf("")};var privacyAccepted by remember{mutableStateOf(false)};var forgot by remember{mutableStateOf(false)};var copied by remember{mutableStateOf(false)}
 val clipboard=LocalClipboardManager.current
 LaunchedEffect(signup,configured){signupEnabled=false;policyLoading=signup&&configured;if(signup&&configured)try{signupEnabled=gateway.registrationPolicy()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){signupEnabled=false}finally{policyLoading=false}}
 val scope=rememberCoroutineScope()
 fun tr(fr:String,en:String)=if(english)en else fr
 if(legal.isNotEmpty()){CommercialLegal(english,legal,signupEnabled){legal=""};return}
 if(forgot){Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text(tr("Mot de passe oublié ?","Forgot password?"),style=MaterialTheme.typography.headlineMedium);Text(tr("Indiquez votre identifiant WideMeet pour demander une assistance à la récupération de votre compte.","Enter your WideMeet ID to request account recovery assistance."));OutlinedTextField(identifier,{identifier=it.take(27)},label={Text(tr("Identifiant WideMeet","WideMeet ID"))},enabled=!busy,modifier=Modifier.fillMaxWidth());Button(enabled=configured&&!busy&&Regex("^WM-[A-Z0-9]{8,24}$").matches(identifier.trim().uppercase()),onClick={busy=true;recoveryError=false;recoveryNotice=false;scope.launch{try{gateway.requestRecovery(identifier);recoveryNotice=true}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){recoveryError=true}finally{busy=false}}}){Text(tr("Demander une assistance","Request assistance"))};if(recoveryNotice)Text(tr("Demande reçue. Un contrôle d’identité est nécessaire avant toute récupération.","Request received. Identity verification is required before recovery."));if(recoveryError)Text(tr("Demande non confirmée. Réessayez plus tard.","Request not confirmed. Try again later."));if(BuildConfig.WIDEMEET_RECOVERY_ENABLED)TextButton(enabled=configured&&!busy,onClick={forgot=false;keyRecovery=true}){Text(tr("Récupérer avec ma clé","Recover with my key"))};TextButton(enabled=!busy,onClick={forgot=false;recoveryNotice=false;recoveryError=false}){Text(tr("Retour","Back"))}}};return}
 if(keyRecovery){RecoveryForm(english,gateway,identifier,{keyRecovery=false},{identifier=it;password="";keyRecovery=false;recovered=true});return}
 if(signup){
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
 Surface(color=Color.White,shape=MaterialTheme.shapes.medium,modifier=Modifier.align(Alignment.CenterHorizontally)){Image(painterResource(R.drawable.widemeet_logo),contentDescription="WideMeet",modifier=Modifier.widthIn(max=220.dp).height(64.dp).padding(6.dp))}
 Text(tr("Créer un compte","Create an account"),style=MaterialTheme.typography.headlineMedium,modifier=Modifier.testTag("wm-signup-title"))
 if(registered.isEmpty()&&policyLoading)Text(tr("Chargement…","Loading…"))
 if(registered.isEmpty()&&!policyLoading&&!signupEnabled)Text(tr("Les inscriptions sont momentanément indisponibles. Réessayez ultérieurement.","Registration is temporarily unavailable. Please try again later."),modifier=Modifier.testTag("wm-signup-unavailable"))
 Text(tr("Créez votre espace personnel ou professionnel pour organiser vos réunions.","Create your personal or business workspace to organize meetings."))
 if(registered.isNotEmpty()){Text(tr("Votre identifiant","Your ID"));Text(registered);Text(tr("Conservez cet identifiant : il vous permettra de vous connecter à votre compte.","Keep this ID: you will need it to sign in."));TextButton(onClick={clipboard.setText(AnnotatedString(registered));copied=true}){Text(tr("Copier mon identifiant","Copy my ID"))};if(copied)Text(tr("Identifiant copié.","ID copied."));Button(onClick={identifier=registered;registered="";signup=false;display="";workspace="";enterprise=false;accepted=false;privacyAccepted=false;copied=false}){Text(tr("Se connecter","Sign in"))}}
 else{
 Row(verticalAlignment=Alignment.CenterVertically){RadioButton(selected=!enterprise,onClick={enterprise=false},enabled=!busy&&!registrationPending);Text(tr("Particulier","Individual"));RadioButton(selected=enterprise,onClick={enterprise=true},enabled=!busy&&!registrationPending);Text(tr("Entreprise","Company"))}
 OutlinedTextField(display,{display=it.take(120)},label={Text(tr("Nom affiché","Display name"))},enabled=!busy&&!registrationPending,modifier=Modifier.fillMaxWidth())
 if(enterprise)OutlinedTextField(workspace,{workspace=it.take(120)},label={Text(tr("Nom de l’entreprise","Company name"))},enabled=!busy&&!registrationPending,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(password,{password=it.take(256)},label={Text(tr("Mot de passe","Password"))},visualTransformation=PasswordVisualTransformation(),enabled=!busy,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(confirm,{confirm=it.take(256)},label={Text(tr("Confirmer le mot de passe","Confirm password"))},visualTransformation=PasswordVisualTransformation(),enabled=!busy,modifier=Modifier.fillMaxWidth())
 Text(tr("Mot de passe : au moins 12 caractères.","Password: at least 12 characters."));TextButton(enabled=!busy,onClick={legal="terms"},modifier=Modifier.testTag("wm-legal-terms")){Text(tr("Conditions générales d’utilisation (CGU)","Terms of use"))};Row{Checkbox(accepted,{accepted=it},enabled=!busy,modifier=Modifier.testTag("wm-accept-terms"));Text(tr("J’accepte les CGU.","I accept the terms of use."),Modifier.padding(top=12.dp))};TextButton(enabled=!busy,onClick={legal="privacy"},modifier=Modifier.testTag("wm-legal-privacy")){Text(tr("Politique de confidentialité","Privacy policy"))};Row{Checkbox(privacyAccepted,{privacyAccepted=it},enabled=!busy,modifier=Modifier.testTag("wm-accept-privacy"));Text(tr("J’ai pris connaissance de la politique de confidentialité.","I have read the privacy policy."),Modifier.padding(top=12.dp))}
 Button(modifier=Modifier.testTag("wm-signup-submit"),enabled=signupEnabled&&!busy&&accepted&&privacyAccepted&&display.isNotBlank()&&(!enterprise||workspace.isNotBlank())&&password.length>=12&&password==confirm,onClick={busy=true;error=false;registrationPending=true;scope.launch{try{registered=gateway.register(if(enterprise)"enterprise"else "individual",display,if(enterprise)workspace else display,password,requestId);requestId=UUID.randomUUID().toString();registrationPending=false}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true}finally{password="";confirm="";busy=false}}}){Text(tr("Créer mon compte","Create account"))}
 }
 if(error)Text(tr("Inscription non confirmée. Réessayez avec les mêmes informations.","Registration not confirmed. Retry with the same details."),color=MaterialTheme.colorScheme.error)
 if(registered.isEmpty())TextButton(modifier=Modifier.testTag("wm-signup-back"),enabled=!busy,onClick={signup=false;password="";confirm="";error=false;accepted=false;privacyAccepted=false}){Text(tr("Retour","Back"))}
 }}
 return
 }
 Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)){
 Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
 Surface(color=Color.White,shape=MaterialTheme.shapes.medium,modifier=Modifier.align(Alignment.CenterHorizontally)){Image(painterResource(R.drawable.widemeet_logo),contentDescription="WideMeet",modifier=Modifier.widthIn(max=220.dp).height(72.dp).padding(6.dp).testTag("wm-signin-logo"))}
 Text(tr("Vos réunions, sans frontières.","Your meetings, without borders."),style=MaterialTheme.typography.bodyMedium,modifier=Modifier.align(Alignment.CenterHorizontally))
 HorizontalDivider()
 Text(tr("Connexion","Sign in"),style=MaterialTheme.typography.headlineMedium,modifier=Modifier.align(Alignment.CenterHorizontally).testTag("wm-signin-title"))
 OutlinedTextField(identifier,{identifier=it.take(27)},enabled=!busy,label={Text(tr("Identifiant WideMeet","WideMeet ID"))},singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(password,{password=it.take(256)},enabled=!busy,label={Text(tr("Mot de passe","Password"))},singleLine=true,visualTransformation=if(show)VisualTransformation.None else PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 TextButton(onClick={show=!show}){Text(if(show)tr("Masquer le mot de passe","Hide password")else tr("Afficher le mot de passe","Show password"))}
 Row{Checkbox(keep,{keep=it;if(!it){pin="";pinConfirm=""}},enabled=!busy);Text(tr("Rester connecté","Keep me signed in"),Modifier.padding(top=12.dp))}
 if(keep){
 OutlinedTextField(pin,{pin=it.filter{c->c in '0'..'9'}.take(4)},enabled=!busy,label={Text(tr("Code local à 4 chiffres","4-digit local PIN"))},visualTransformation=PasswordVisualTransformation(),singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(pinConfirm,{pinConfirm=it.filter{c->c in '0'..'9'}.take(4)},enabled=!busy,label={Text(tr("Confirmer le code","Confirm PIN"))},visualTransformation=PasswordVisualTransformation(),singleLine=true,modifier=Modifier.fillMaxWidth())
 }
 Button(modifier=Modifier.fillMaxWidth().testTag("wm-signin-submit"),enabled=configured&&!busy&&identifier.isNotBlank()&&password.isNotBlank()&&(!keep||pin.length==4&&pin==pinConfirm),onClick={busy=true;error=false;recoveryError=false;recoveryNotice=false;scope.launch{try{onSession(gateway.login(identifier,password,keep,pin))}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true}finally{password="";pin="";pinConfirm="";busy=false}}}){Text(if(busy)tr("Connexion…","Signing in…")else tr("Se connecter","Sign in"))}
 if(!configured)Text(tr("Connexion momentanément indisponible.","Sign-in temporarily unavailable."))
 if(error)Text(tr("Connexion impossible. Vérifiez vos identifiants ou réessayez plus tard.","Unable to sign in. Check your credentials or try again later."),color=MaterialTheme.colorScheme.error)
 TextButton(enabled=!busy,onClick={forgot=true;password="";error=false;recoveryError=false;recoveryNotice=false}){Text(tr("Mot de passe oublié ?","Forgot password?"))}
 if(BuildConfig.WIDEMEET_RECOVERY_ENABLED)TextButton(enabled=configured&&!busy,onClick={keyRecovery=true;password=""}){Text(tr("Récupérer avec ma clé","Recover with my key"))}
 if(recovered)Text(tr("Compte récupéré. Connectez-vous.","Account recovered. Sign in."))
 if(recoveryNotice)Text(tr("Demande reçue. Un contrôle d’identité est nécessaire avant toute récupération.","Request received. Identity verification is required before recovery."))
 if(recoveryError)Text(tr("Demande non confirmée. Vérifiez votre identifiant ou réessayez plus tard.","Request not confirmed. Check your ID or try again later."),color=MaterialTheme.colorScheme.error)
 OutlinedButton(modifier=Modifier.fillMaxWidth().testTag("wm-signup-open"),enabled=!busy,onClick={signup=true;error=false;password="";confirm="";accepted=false;privacyAccepted=false;copied=false}){Text(tr("Créer un compte","Create an account"))}
 TextButton(enabled=!busy,onClick=onBack,modifier=Modifier.testTag("wm-signin-back")){Text(tr("Retour","Back"))}
 }
 }
}
