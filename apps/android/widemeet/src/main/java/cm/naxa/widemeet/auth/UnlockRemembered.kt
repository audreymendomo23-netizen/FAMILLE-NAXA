package cm.naxa.widemeet.auth

import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException

@Composable fun UnlockRemembered(english:Boolean,gateway:AuthGateway,onSession:(Session)->Unit,onForget:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var pin by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var signal by remember{mutableStateOf<CancellationSignal?>(null)}
 DisposableEffect(Unit){onDispose{signal?.cancel();signal=null}}
 fun finishFailure(){busy=false;error=true;if(!gateway.hasRememberedSession())onForget()}
 fun restore(attempt:BiometricUnlock.Attempt?=null,authenticated:javax.crypto.Cipher?=null){
  busy=true;error=false
  scope.launch{try{val s=if(attempt!=null)gateway.restoreAfterBiometric(attempt,authenticated) else gateway.restoreWithPin(pin);onSession(s)}
  catch(e:CancellationException){throw e}catch(e:Exception){finishFailure()}finally{pin="";busy=false}}
 }
 val biometricAvailable=gateway.biometricAvailable()
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
 Text(tr("Déverrouiller WideMeet","Unlock WideMeet"),style=MaterialTheme.typography.headlineMedium)
 Text(tr("Saisissez votre code local pour restaurer votre session.","Enter your local PIN to restore your session."))
 OutlinedTextField(pin,{pin=it.filter{c->c in '0'..'9'}.take(4)},enabled=!busy,label={Text(tr("Code à 4 chiffres","4-digit PIN"))},singleLine=true,visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&pin.length==4,onClick={restore()}){Text(tr("Déverrouiller","Unlock"))}
 if(biometricAvailable&&Build.VERSION.SDK_INT>=30)TextButton(enabled=!busy,onClick={
  busy=true;error=false
  val cancel=CancellationSignal();signal=cancel
  try{
   val attempt=gateway.prepareBiometric()?:error("biometric_unavailable")
   val prompt=BiometricPrompt.Builder(context).setTitle(tr("Déverrouiller WideMeet","Unlock WideMeet"))
    .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
    .setNegativeButton(tr("Utiliser le code","Use PIN"),context.mainExecutor){_,_->busy=false}.build()
   prompt.authenticate(BiometricPrompt.CryptoObject(attempt.cipher),cancel,context.mainExecutor,object:BiometricPrompt.AuthenticationCallback(){
    override fun onAuthenticationSucceeded(result:BiometricPrompt.AuthenticationResult){if(!cancel.isCanceled)restore(attempt,result.cryptoObject?.cipher)}
    override fun onAuthenticationError(errorCode:Int,errString:CharSequence){if(!cancel.isCanceled)busy=false}
   })
  }catch(e:Exception){busy=false;error=true}
 }){Text(tr("Utiliser la biométrie","Use biometrics"))}
 if(error)Text(tr("Déverrouillage non confirmé. Réessayez ou reconnectez-vous.","Unlock not confirmed. Retry or sign in again."),color=MaterialTheme.colorScheme.error)
 TextButton(enabled=!busy,onClick={gateway.clearLocalSession();onForget()}){Text(tr("Oublier cet appareil et se reconnecter","Forget this device and sign in"))}
 }}
}
