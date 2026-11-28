package cm.naxa.grillad
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.fragment.app.FragmentActivity
import cm.naxa.core.security.BiometricGate
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
@Composable internal fun GrilladPinGate(user:String,manager:LocalAccessPinManager,locale:String="fr",onUnlocked:()->Unit,onSignOut:()->Unit){
 fun tr(k:String)=grilladLabel(k,locale)
 val setup=!manager.isConfigured(user);val activity=LocalContext.current as? FragmentActivity;var alive by remember{mutableStateOf(true)};DisposableEffect(user){onDispose{alive=false}}
 var pin by remember{mutableStateOf("")};var repeat by remember{mutableStateOf("")};var message by remember{mutableStateOf("")}
 BackHandler(true){}
 Box(Modifier.fillMaxSize().safeDrawingPadding().imePadding(),contentAlignment=Alignment.TopCenter){Column(Modifier.widthIn(max=440.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){
 GrilladBrandMark()
 Spacer(Modifier.height(20.dp))
 Text(tr(if(setup)"Créer votre code local" else "Déverrouiller GRILLAD"),style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
 Text(tr("Code personnel à quatre chiffres. Une connexion à votre compte reste nécessaire."),color=MaterialTheme.colorScheme.onSurfaceVariant)
 GrilladPinField(pin,{pin=it},tr("Code local"))
 if(setup)GrilladPinField(repeat,{repeat=it},tr("Confirmer le code"))
 Button({val r=if(setup)manager.enroll(user,pin)else manager.verify(user,pin);pin="";repeat="";if(r.code==LocalAccessPinCode.SUCCESS)onUnlocked() else message=when(r.code){LocalAccessPinCode.LOCKED->"Code verrouillé temporairement. Réessayez après le délai.";LocalAccessPinCode.INVALID->"Code incorrect. Tentatives restantes : "+r.attemptsRemaining;else->"Code indisponible ou invalide. Reconnectez-vous si nécessaire."}},enabled=LocalAccessPinPolicy.isValid(pin)&&(!setup||pin==repeat),modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text(tr(if(setup)"Enregistrer et ouvrir" else "Déverrouiller"))}
 if(!setup&&activity!=null&&manager.biometricEnabled(user)&&BiometricGate.available(activity))TextButton({if(manager.isLocked(user)){message="Code verrouillé temporairement."}else BiometricGate.prompt(activity,{if(alive&&!manager.isLocked(user))onUnlocked()},{if(alive)message="Biométrie indisponible. Utilisez votre code local."})}){Text(tr("Déverrouiller par biométrie"))}
 if(message.isNotBlank())Text(message)
 TextButton(onSignOut,modifier=Modifier.fillMaxWidth()){Text(tr("Se déconnecter"))}
 }}
}
@Composable private fun GrilladPinField(value:String,onValue:(String)->Unit,label:String){
 OutlinedTextField(value,{onValue(it.filter{c->c in '0'..'9'}.take(4))},label={Text(label)},visualTransformation=PasswordVisualTransformation(),keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.NumberPassword),singleLine=true,modifier=Modifier.fillMaxWidth())
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(9.dp)){repeat(4){i->OutlinedCard(Modifier.weight(1f).height(50.dp),shape=RoundedCornerShape(10.dp)){Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){Text(if(i<value.length)"●" else "–",style=MaterialTheme.typography.titleMedium)}}}}
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
