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
 val lock=remember { LocalAccessPinManager(context) };val biometricPrefs=remember { ZippleBiometricPreferences(context) };val vault=remember { SessionVault(context) };val api=remember { ZippleAuth(BuildConfig.ZIPPLE_API_URL) }
 var rememberDevice by remember { mutableStateOf(false) };var identifier by remember { mutableStateOf("") };var password by remember { mutableStateOf("") }
 var session by remember { mutableStateOf<Session?>(null) };var site by remember { mutableStateOf("") }
 var unlocked by remember { mutableStateOf(false) };var unlockedByPin by remember { mutableStateOf(false) };var biometricEnabled by remember { mutableStateOf(false) };var pin by remember { mutableStateOf("") };var message by remember { mutableStateOf("") };var busy by remember { mutableStateOf(false) }
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 LaunchedEffect(Unit){val saved=vault.loadRefreshToken();if(saved!=null){busy=true;try{val restored=api.refresh(saved);val replacement=restored.refreshToken?:error("refresh missing");vault.save(replacement);session=restored;site=restored.sites.first().id;unlocked=false;rememberDevice=true}catch(_:Exception){vault.clear()}finally{busy=false}}}
 val navy=Color(0xFF0E224D);val orange=Color(0xFFF56202)
 MaterialTheme(colorScheme=if(dark)darkColorScheme(primary=Color(0xFFFFB37C),secondary=orange,background=Color(0xFF0A1632),surface=Color(0xFF15244D))else lightColorScheme(primary=navy,secondary=orange,background=Color(0xFFFFF0E3),surface=Color.White,onPrimary=Color.White)){
 Surface(Modifier.fillMaxSize(),color=MaterialTheme.colorScheme.background){
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){TextButton(onClick={en=!en}){Text(if(en)"FR" else "EN")};TextButton(onClick={dark=!dark}){Text(tr("Thème","Theme"))}}
 Image(painterResource(R.drawable.zipple_logo),contentDescription="ZIPPLE",modifier=Modifier.height(92.dp).fillMaxWidth())
 Text(tr("Votre restaurant, bien piloté","Manage your restaurant"),style=MaterialTheme.typography.headlineSmall)
 val current=session
 LaunchedEffect(current?.member){biometricEnabled=current?.member?.let{biometricPrefs.enabled(it)}?:false;unlockedByPin=false}
 LaunchedEffect(current,unlocked){ZippleSyncSession.current=if(unlocked)current else null;if(unlocked&&current!=null)ZippleSyncSession.schedule(context)}
 DisposableEffect(Unit){onDispose{ZippleSyncSession.current=null}}
 if(current!=null){LaunchedEffect(current.expiresAt){kotlinx.coroutines.delay((current.expiresAt-System.currentTimeMillis()).coerceAtLeast(0));if(session==current){session=null;unlocked=false;site="";message=tr("Session expirée","Session expired")}}}
 if(current==null){
 OutlinedTextField(identifier,{identifier=it},label={Text(tr("Identifiant","Identifier"))},singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(password,{password=it},label={Text(tr("Mot de passe","Password"))},singleLine=true,visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 Row(verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Checkbox(checked=rememberDevice,onCheckedChange={rememberDevice=it});Text(tr("Rester connecté","Remember me"))}
 Button(enabled=identifier.isNotBlank()&&password.isNotBlank()&&!busy,modifier=Modifier.fillMaxWidth(),onClick={busy=true;message="";scope.launch{try{val authenticated=api.login(identifier,password,rememberDevice);if(rememberDevice&&authenticated.refreshToken!=null)vault.save(authenticated.refreshToken)else vault.clear();session=authenticated;site=authenticated.sites.first().id;unlocked=false}catch(_:Exception){message=tr("Connexion indisponible ou refusée","Connection unavailable or denied")}finally{password="";busy=false}}}){Text(tr("Se connecter","Sign in"))}
 TextButton(enabled=identifier.isNotBlank()&&!busy,onClick={scope.launch{try{api.recovery(identifier);message=tr("Si le compte est reconnu, la demande sera traitée.","If recognized, your request will be processed.")}catch(_:Exception){message=tr("Assistance indisponible","Recovery unavailable")}}}){Text(tr("Mot de passe oublié","Forgot password"))}
 Text(tr("Accès professionnel sécurisé","Secure professional access"))
 }else if(!unlocked){
 Text(if(lock.isConfigured(current.member))tr("Déverrouiller","Unlock") else tr("Configurer votre code local","Set your local PIN"))
 OutlinedTextField(pin,{pin=it.filter{c->c in '0'..'9'}.take(4)},label={Text("PIN")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.NumberPassword),visualTransformation=PasswordVisualTransformation())
 if(context is FragmentActivity&&ZippleBiometricPolicy.allowed(lock.canUseBiometric(current.member),biometricEnabled,BiometricGate.available(context),session===current,current.expiresAt,System.currentTimeMillis())){TextButton(onClick={BiometricGate.prompt(context,{if(ZippleBiometricPolicy.allowed(lock.canUseBiometric(current.member),biometricPrefs.enabled(current.member),BiometricGate.available(context),session===current,current.expiresAt,System.currentTimeMillis())){unlockedByPin=false;unlocked=true}},{message=tr("Biométrie non validée","Biometric verification failed")})}){Text(tr("Empreinte digitale","Fingerprint"))}}
 Button(enabled=pin.length==4,onClick={val result=if(!lock.isConfigured(current.member))lock.enroll(current.member,pin)else lock.verify(current.member,pin);unlocked=result.code==LocalAccessPinCode.SUCCESS;unlockedByPin=unlocked;if(!unlocked)message=tr("Code refusé ou verrouillé","PIN denied or locked");pin=""}){Text(tr("Continuer","Continue"))}
 }else{
 Text(current.name,style=MaterialTheme.typography.titleLarge);Text(tr("Établissement autorisé","Authorized site"))
 current.sites.forEach { s->OutlinedButton(onClick={if(current.permits(s.id))site=s.id},enabled=current.permits(s.id)){Text((if(site==s.id)"✓ " else "")+s.name)} }
 if(current.permits(site))Text(tr("Espace professionnel — socle N1","Professional workspace — N1 foundation"))else Text(tr("Session expirée","Session expired"))
 if(unlockedByPin&&context is FragmentActivity&&BiometricGate.available(context)){Row(verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Checkbox(checked=biometricEnabled,onCheckedChange={biometricPrefs.set(current.member,it);biometricEnabled=it});Text(tr("Autoriser la biométrie de cet appareil","Allow this device biometrics"))}}
 TextButton(onClick={ZippleSyncSession.schedule(context)}){Text(tr("Synchroniser","Synchronize"))}
 TextButton(onClick={unlocked=false;unlockedByPin=false;ZippleSyncSession.current=null}){Text(tr("Verrouiller","Lock"))}
 }
 if(current!=null)TextButton(onClick={ZippleSyncSession.current=null;vault.clear();session=null;site="";pin="";unlocked=false;unlockedByPin=false;message="";scope.launch{try{api.logout(current.token)}catch(_:Exception){message=tr("Session locale fermée ; révocation distante non confirmée","Local session closed; remote revocation unconfirmed")}}}){Text(tr("Déconnexion","Sign out"))}
 if(message.isNotEmpty())Text(message,color=MaterialTheme.colorScheme.error)
 }
 }
 }
}
