package cm.naxa.widemeet.auth
import android.app.Activity
import cm.naxa.widemeet.BuildConfig
import android.view.WindowManager
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.util.UUID

@Composable private fun ProtectSecretScreen(){
 val context=LocalContext.current
 DisposableEffect(context){
  val window=(context as? Activity)?.window
  val wasSecure=window?.attributes?.flags?.and(WindowManager.LayoutParams.FLAG_SECURE)!=0
  window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
  onDispose{if(!wasSecure)window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)}
 }
}
@Composable fun RecoveryEnrollment(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 var password by remember{mutableStateOf("")};var recoveryKey by remember{mutableStateOf("")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var supervised by remember{mutableStateOf(false)}
 val scope=rememberCoroutineScope()
 Text(tr("Clé de récupération","Recovery key"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Conservez la clé hors ligne et ne la partagez pas. Une nouvelle clé invalide la précédente.","Keep the key offline and do not share it. A new key invalidates the previous one."))
 if(recoveryKey.isNotEmpty()){
  ProtectSecretScreen();Text(recoveryKey);Button(onClick={recoveryKey=""}){Text(tr("J’ai conservé ma clé","I saved my key"))}
 }else{
  if(BuildConfig.WIDEMEET_SUPPORT_RECOVERY_ENABLED)Row{Checkbox(checked=supervised,onCheckedChange={supervised=it},enabled=!busy);Text(tr("Code de secours supervisé (sur environnement qualifié)","Supervised backup code (qualified environment)"))}
  OutlinedTextField(password,{password=it.take(256)},enabled=!busy,label={Text(tr("Mot de passe actuel","Current password"))},visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
  Button(enabled=!busy&&password.isNotEmpty(),onClick={busy=true;error=false;scope.launch{try{recoveryKey=gateway.enrollRecoveryKey(session,password,supervised)}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{password="";busy=false}}}){Text(tr("Générer une clé","Generate key"))}
 }
 if(error)Text(tr("Action non confirmée.","Action not confirmed."),color=MaterialTheme.colorScheme.error)
}
@Composable fun RecoveryForm(english:Boolean,gateway:AuthGateway,initialIdentifier:String,onBack:()->Unit,onRecovered:(String)->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 var identifier by remember{mutableStateOf(initialIdentifier)}
 var recoveryKey by remember{mutableStateOf("")};var password by remember{mutableStateOf("")};var confirm by remember{mutableStateOf("")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var requestId by remember{mutableStateOf<String?>(null)};var supervised by remember{mutableStateOf(false)};var caseId by remember{mutableStateOf("")}
 val scope=rememberCoroutineScope()
 val locked=busy||requestId!=null
 val valid=Regex("^WM-[A-Z0-9]{8,24}$").matches(identifier.trim().uppercase())&&Regex("^[a-fA-F0-9]{64}$").matches(recoveryKey.trim())&&password.length in 12..256&&password==confirm
 ProtectSecretScreen()
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Récupérer mon compte","Recover account"),style=MaterialTheme.typography.titleLarge)
 if(BuildConfig.WIDEMEET_SUPPORT_RECOVERY_ENABLED)Row{Checkbox(checked=supervised,onCheckedChange={supervised=it;caseId=""},enabled=!locked);Text(tr("Utiliser mon code de secours supervisé","Use my supervised backup code"))}
 if(supervised)Text(tr("Une demande préalable, deux examens et votre code préenregistré sont requis. Ne partagez jamais ce code.","A prior request, two reviews and your pre-enrolled code are required. Never share the code."))
 OutlinedTextField(identifier,{identifier=it.take(27);caseId=""},enabled=!locked,label={Text(tr("Identifiant WideMeet","WideMeet ID"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(recoveryKey,{recoveryKey=it.take(64);caseId=""},enabled=!locked,label={Text(tr("Clé de récupération","Recovery key"))},visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 if(supervised){Button(enabled=!locked&&Regex("^WM-[A-Z0-9]{8,24}$").matches(identifier.trim().uppercase())&&Regex("^[a-fA-F0-9]{64}$").matches(recoveryKey.trim()),onClick={busy=true;error=false;scope.launch{try{caseId=gateway.requestSupervisedRecovery(identifier,recoveryKey)}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}){Text(tr("Ouvrir ou retrouver mon dossier","Open or retrieve my case"))};if(caseId.isNotEmpty())Text(tr("Référence à communiquer au support (jamais le code)","Reference to give support (never the code)")+": "+caseId)}
 OutlinedTextField(password,{password=it.take(256)},enabled=!locked,label={Text(tr("Nouveau mot de passe","New password"))},visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 OutlinedTextField(confirm,{confirm=it.take(256)},enabled=!locked,label={Text(tr("Confirmer","Confirm"))},visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 Button(enabled=valid&&!busy&&(!supervised||caseId.isNotEmpty()),onClick={busy=true;error=false;val id=requestId?:UUID.randomUUID().toString();requestId=id;scope.launch{try{gateway.recoverWithKey(identifier,recoveryKey,password,id,supervised);recoveryKey="";password="";confirm="";onRecovered(identifier.trim().uppercase())}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}){Text(if(error)tr("Réessayer la même demande","Retry same request")else tr("Récupérer","Recover"))}
 if(error)Text(tr("Récupération non confirmée. Réessayez la même demande ou contactez le support.","Recovery not confirmed. Retry the same request or contact support."),color=MaterialTheme.colorScheme.error)
 TextButton(enabled=!busy,onClick=onBack){Text(tr("Retour","Back"))}
 }}
}
