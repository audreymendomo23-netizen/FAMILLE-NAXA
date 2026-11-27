package cm.naxa.grillad
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.fragment.app.FragmentActivity
import cm.naxa.core.security.BiometricGate
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
@Composable internal fun GrilladPinGate(user:String,manager:LocalAccessPinManager,onUnlocked:()->Unit,onSignOut:()->Unit){
 val setup=!manager.isConfigured(user);val activity=LocalContext.current as? FragmentActivity;var alive by remember{mutableStateOf(true)};DisposableEffect(user){onDispose{alive=false}}
 var pin by remember{mutableStateOf("")};var repeat by remember{mutableStateOf("")};var message by remember{mutableStateOf("")}
 BackHandler(true){}
 Column(Modifier.fillMaxSize().padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
 Text(if(setup)"Créer votre code local" else "Déverrouiller GRILLAD",style=MaterialTheme.typography.headlineSmall)
 Text("Code individuel à quatre chiffres. La connexion serveur reste obligatoire.")
 OutlinedTextField(pin,{pin=it.filter{c->c in '0'..'9'}.take(4)},label={Text("Code local")},visualTransformation=PasswordVisualTransformation())
 if(setup)OutlinedTextField(repeat,{repeat=it.filter{c->c in '0'..'9'}.take(4)},label={Text("Confirmer le code")},visualTransformation=PasswordVisualTransformation())
 Button({val r=if(setup)manager.enroll(user,pin)else manager.verify(user,pin);pin="";repeat="";if(r.code==LocalAccessPinCode.SUCCESS)onUnlocked() else message=when(r.code){LocalAccessPinCode.LOCKED->"Code verrouillé temporairement. Réessayez après le délai.";LocalAccessPinCode.INVALID->"Code incorrect. Tentatives restantes : "+r.attemptsRemaining;else->"Code indisponible ou invalide. Reconnectez-vous si nécessaire."}},enabled=LocalAccessPinPolicy.isValid(pin)&&(!setup||pin==repeat)){Text(if(setup)"Enregistrer et ouvrir" else "Déverrouiller")}
 if(!setup&&activity!=null&&manager.biometricEnabled(user)&&BiometricGate.available(activity))TextButton({if(manager.isLocked(user)){message="Code verrouillé temporairement."}else BiometricGate.prompt(activity,{if(alive&&!manager.isLocked(user))onUnlocked()},{if(alive)message="Biométrie indisponible. Utilisez votre code local."})}){Text("Déverrouiller par biométrie")}
 if(message.isNotBlank())Text(message)
 TextButton(onSignOut){Text("Se déconnecter")}
 }
}

@Composable internal fun GrilladBiometricSettings(user:String,manager:LocalAccessPinManager,enabled:Boolean){
 val activity=LocalContext.current as? FragmentActivity
 var opted by remember(user){mutableStateOf(manager.biometricEnabled(user))};var code by remember(user){mutableStateOf("")};var message by remember(user){mutableStateOf("")}
 Text("Sécurité de l’appareil",style=MaterialTheme.typography.titleMedium)
 if(activity!=null&&BiometricGate.available(activity)){
 Text("Option biométrique personnelle. N’activez pas cette option si une autre personne a enregistré sa biométrie sur cet appareil.")
 if(opted){TextButton({if(manager.setBiometric(user,false)){opted=false;message="Biométrie désactivée"}},enabled=enabled){Text("Désactiver la biométrie")}}
 else{OutlinedTextField(code,{code=it.filter{c->c in '0'..'9'}.take(4)},label={Text("Code local pour activer la biométrie")},visualTransformation=PasswordVisualTransformation());Button({val r=manager.verify(user,code);code="";if(r.code==LocalAccessPinCode.SUCCESS&&manager.setBiometric(user,true)){opted=true;message="Biométrie activée pour ce compte"}else message="Code non validé. Biométrie non activée."},enabled=enabled&&LocalAccessPinPolicy.isValid(code)){Text("Activer la biométrie")}}
 }else Text("Biométrie forte indisponible. Le code local reste utilisable.")
 if(message.isNotBlank())Text(message)
}
