package cm.naxa.grillad
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
@Composable internal fun GrilladPinGate(user:String,manager:LocalAccessPinManager,onUnlocked:()->Unit,onSignOut:()->Unit){
 val setup=!manager.isConfigured(user)
 var pin by remember{mutableStateOf("")};var repeat by remember{mutableStateOf("")};var message by remember{mutableStateOf("")}
 BackHandler(true){}
 Column(Modifier.fillMaxSize().padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
 Text(if(setup)"Créer votre code local" else "Déverrouiller GRILLAD",style=MaterialTheme.typography.headlineSmall)
 Text("Code individuel à quatre chiffres. La connexion serveur reste obligatoire.")
 OutlinedTextField(pin,{pin=it.filter{c->c in '0'..'9'}.take(4)},label={Text("Code local")},visualTransformation=PasswordVisualTransformation())
 if(setup)OutlinedTextField(repeat,{repeat=it.filter{c->c in '0'..'9'}.take(4)},label={Text("Confirmer le code")},visualTransformation=PasswordVisualTransformation())
 Button({val r=if(setup)manager.enroll(user,pin)else manager.verify(user,pin);pin="";repeat="";if(r.code==LocalAccessPinCode.SUCCESS)onUnlocked() else message=when(r.code){LocalAccessPinCode.LOCKED->"Code verrouillé temporairement. Réessayez après le délai.";LocalAccessPinCode.INVALID->"Code incorrect. Tentatives restantes : "+r.attemptsRemaining;else->"Code indisponible ou invalide. Reconnectez-vous si nécessaire."}},enabled=LocalAccessPinPolicy.isValid(pin)&&(!setup||pin==repeat)){Text(if(setup)"Enregistrer et ouvrir" else "Déverrouiller")}
 if(message.isNotBlank())Text(message)
 TextButton(onSignOut){Text("Se déconnecter")}
 }
}
