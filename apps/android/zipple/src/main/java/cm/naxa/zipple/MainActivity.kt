package cm.naxa.zipple
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import cm.naxa.core.security.BiometricGate
import kotlinx.coroutines.launch
class MainActivity:FragmentActivity(){
 override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{ZippleRoot()}}
}
@Composable fun ZippleRoot(){
 var dark by remember { mutableStateOf(false) };var en by remember { mutableStateOf(false) }
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 val lock=remember { LocalAccessPinManager(context) }
 var identifier by remember { mutableStateOf("") };var password by remember { mutableStateOf("") }
 var session by remember { mutableStateOf<Session?>(null) };var site by remember { mutableStateOf("") }
 var unlocked by remember { mutableStateOf(false) };var pin by remember { mutableStateOf("") };var message by remember { mutableStateOf("") };var busy by remember { mutableStateOf(false) }
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val navy=Color(0xFF0E224D);val orange=Color(0xFFF56202)
 MaterialTheme(colorScheme=if(dark)darkColorScheme(primary=Color(0xFFFFB37C),secondary=orange,background=Color(0xFF0A1632),surface=Color(0xFF15244D))else lightColorScheme(primary=navy,secondary=orange,background=Color(0xFFFFF0E3),surface=Color.White,onPrimary=Color.White)){
 Surface(Modifier.fillMaxSize(),color=MaterialTheme.colorScheme.background){
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){TextButton(onClick={en=!en}){Text(if(en)"FR" else "EN")};TextButton(onClick={dark=!dark}){Text(tr("Thème","Theme"))}}
 Image(painterResource(R.drawable.zipple_logo),contentDescription="ZIPPLE",modifier=Modifier.height(92.dp).fillMaxWidth())
 Text(tr("Votre restaurant, bien piloté","Manage your restaurant"),style=MaterialTheme.typography.headlineSmall)
 val current=session
 if(current!=null){LaunchedEffect(current.expiresAt){kotlinx.coroutines.delay((current.expiresAt-System.currentTimeMillis()).coerceAtLeast(0));if(session==current){session=null;unlocked=false;site="";message=tr("Session expirée","Session expired")}}}
 if(current==null){
 OutlinedTextField(identifier,{identifier=it},label={Text(tr("Identifiant","Identifier"))},singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(password,{password=it},label={Text(tr("Mot de passe","Password"))},singleLine=true,visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 Button(enabled=identifier.isNotBlank()&&password.isNotBlank()&&!busy,modifier=Modifier.fillMaxWidth(),onClick={busy=true;message="";scope.launch{try{session=ZippleAuth(BuildConfig.ZIPPLE_API_URL).login(identifier,password);site=session!!.sites.first().id;unlocked=false}catch(_:Exception){message=tr("Connexion indisponible ou refusée","Connection unavailable or denied")}finally{password="";busy=false}}}){Text(tr("Se connecter","Sign in"))}
 Text(tr("Accès professionnel sécurisé","Secure professional access"))
 }else if(!unlocked){
 Text(if(lock.isConfigured(current.member))tr("Déverrouiller","Unlock") else tr("Configurer votre code local","Set your local PIN"))
 OutlinedTextField(pin,{pin=it.filter{c->c in '0'..'9'}.take(4)},label={Text("PIN")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.NumberPassword),visualTransformation=PasswordVisualTransformation())
 if(lock.isConfigured(current.member)&&context is FragmentActivity&&BiometricGate.available(context)){TextButton(onClick={BiometricGate.prompt(context,{if(session?.member==current.member&&current.expiresAt>System.currentTimeMillis())unlocked=true},{message=tr("Biométrie non validée","Biometric verification failed")})}){Text(tr("Empreinte digitale","Fingerprint"))}}
 Button(enabled=pin.length==4,onClick={val result=if(!lock.isConfigured(current.member))lock.enroll(current.member,pin)else lock.verify(current.member,pin);unlocked=result.code==LocalAccessPinCode.SUCCESS;if(!unlocked)message=tr("Code refusé ou verrouillé","PIN denied or locked");pin=""}){Text(tr("Continuer","Continue"))}
 }else{
 Text(current.name,style=MaterialTheme.typography.titleLarge);Text(tr("Établissement autorisé","Authorized site"))
 current.sites.forEach { s->OutlinedButton(onClick={if(current.permits(s.id))site=s.id},enabled=current.permits(s.id)){Text((if(site==s.id)"✓ " else "")+s.name)} }
 if(current.permits(site))Text(tr("Espace professionnel — socle N1","Professional workspace — N1 foundation"))else Text(tr("Session expirée","Session expired"))
 TextButton(onClick={unlocked=false}){Text(tr("Verrouiller","Lock"))}
 }
 if(current!=null)TextButton(onClick={session=null;site="";pin="";unlocked=false;message=""}){Text(tr("Déconnexion","Sign out"))}
 if(message.isNotEmpty())Text(message,color=MaterialTheme.colorScheme.error)
 }
 }
 }
}
