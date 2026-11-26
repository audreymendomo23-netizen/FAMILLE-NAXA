package cm.naxa.zipple
import android.os.Bundle
import android.net.Uri
import android.widget.VideoView
import androidx.compose.ui.viewinterop.AndroidView
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.scale
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import android.provider.Settings
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.input.VisualTransformation
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
 var splash by remember { mutableStateOf(runCatching{Settings.Global.getFloat(context.contentResolver,Settings.Global.ANIMATOR_DURATION_SCALE,1f)>0f}.getOrDefault(true)) }
 val lock=remember { LocalAccessPinManager(context) };val biometricPrefs=remember { ZippleBiometricPreferences(context) };val vault=remember { SessionVault(context) };val api=remember { ZippleAuth(BuildConfig.ZIPPLE_API_URL) }
 var showPassword by remember { mutableStateOf(false) };var rememberDevice by remember { mutableStateOf(false) };var identifier by remember { mutableStateOf("") };var password by remember { mutableStateOf("") }
 var session by remember { mutableStateOf<Session?>(null) };var site by remember { mutableStateOf("") }
 var unlocked by remember { mutableStateOf(false) };var unlockedByPin by remember { mutableStateOf(false) };var biometricEnabled by remember { mutableStateOf(false) };var pin by remember { mutableStateOf("") };var message by remember { mutableStateOf("") };var busy by remember { mutableStateOf(false) }
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 LaunchedEffect(Unit){val saved=vault.loadRefreshToken();if(saved!=null){busy=true;try{val restored=api.refresh(saved);val replacement=restored.refreshToken?:error("refresh missing");vault.save(replacement);session=restored;site=restored.sites.first().id;unlocked=false;rememberDevice=true}catch(_:Exception){vault.clear()}finally{busy=false}}}
 val navy=Color(0xFF482817);val orange=Color(0xFFA66A25)
 MaterialTheme(colorScheme=if(dark)darkColorScheme(primary=Color(0xFFE5BE85),secondary=orange,background=Color(0xFF2B1A11),surface=Color(0xFF3D281B))else lightColorScheme(primary=orange,secondary=navy,background=Color(0xFFF1E4D8),surface=Color(0xFFFCF9F5),onPrimary=Color.White)){
 Surface(Modifier.fillMaxSize(),color=MaterialTheme.colorScheme.background){
 Box(Modifier.fillMaxSize().clipToBounds()){
 Image(painterResource(R.drawable.zipple_restaurant_bar),contentDescription=null,contentScale=ContentScale.Crop,modifier=Modifier.fillMaxSize(),alpha=if(dark)0.62f else 1f)
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(18.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center){
 Surface(modifier=Modifier.widthIn(max=570.dp).fillMaxWidth(),shape=RoundedCornerShape(28.dp),color=MaterialTheme.colorScheme.surface.copy(alpha=if(dark)0.94f else 0.88f),tonalElevation=0.dp){
 Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){TextButton(onClick={en=!en}){Text(if(en)"FR" else "EN")};TextButton(onClick={dark=!dark}){Text(tr("Thème","Theme"))}}
 Column(Modifier.fillMaxWidth(),horizontalAlignment=Alignment.CenterHorizontally){
 Image(painterResource(R.drawable.zipple_cloche),contentDescription=null,modifier=Modifier.width(96.dp).height(78.dp))
 Text("ZIPPLE",color=if(dark)Color(0xFFF1E4D8) else navy,fontSize=40.sp,fontWeight=FontWeight.ExtraBold,letterSpacing=6.sp)
 Spacer(Modifier.height(8.dp));Box(Modifier.width(46.dp).height(3.dp).background(orange,RoundedCornerShape(2.dp)))
 }
 Text(tr("Servez mieux, gérez en toute sécurité.","Serve better, manage securely."),style=MaterialTheme.typography.headlineSmall,textAlign=TextAlign.Center,modifier=Modifier.fillMaxWidth())
 val current=session
 LaunchedEffect(current?.member){biometricEnabled=current?.member?.let{biometricPrefs.enabled(it)}?:false;unlockedByPin=false}
 LaunchedEffect(current,unlocked){ZippleSyncSession.current=if(unlocked)current else null;if(unlocked&&current!=null)ZippleSyncSession.schedule(context)}
 DisposableEffect(Unit){onDispose{ZippleSyncSession.current=null}}
 if(current!=null){LaunchedEffect(current.expiresAt){kotlinx.coroutines.delay((current.expiresAt-System.currentTimeMillis()).coerceAtLeast(0));if(session==current){session=null;unlocked=false;site="";message=tr("Session expirée","Session expired")}}}
 if(current==null){
 OutlinedTextField(identifier,{identifier=it},label={Text(tr("Identifiant","Identifier"))},singleLine=true,shape=RoundedCornerShape(12.dp),modifier=Modifier.fillMaxWidth())
 OutlinedTextField(password,{password=it},label={Text(tr("Mot de passe","Password"))},singleLine=true,visualTransformation=if(showPassword)VisualTransformation.None else PasswordVisualTransformation(),trailingIcon={TextButton(onClick={showPassword=!showPassword}){Text(if(showPassword)tr("Masquer","Hide") else tr("Afficher","Show"))}},shape=RoundedCornerShape(12.dp),modifier=Modifier.fillMaxWidth())
 Row(verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Checkbox(checked=rememberDevice,onCheckedChange={rememberDevice=it});Text(tr("Rester connecté","Remember me"))}
 Button(enabled=identifier.isNotBlank()&&password.isNotBlank()&&!busy,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp),shape=RoundedCornerShape(12.dp),onClick={busy=true;message="";scope.launch{try{val authenticated=api.login(identifier,password,rememberDevice);if(rememberDevice&&authenticated.refreshToken!=null)vault.save(authenticated.refreshToken)else vault.clear();session=authenticated;site=authenticated.sites.first().id;unlocked=false}catch(_:Exception){message=tr("Connexion indisponible ou refusée","Connection unavailable or denied")}finally{password="";showPassword=false;busy=false}}}){Text(tr("Se connecter","Sign in"))}
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
 if(splash)ZippleSplash{ splash=false }
 }
 }
 }
}
@Composable private fun ZippleSplash(onFinished:()->Unit){
 val context=LocalContext.current
 val resource=remember{context.resources.getIdentifier("zipple_startup","raw",context.packageName)}
 var failed by remember{mutableStateOf(false)}
 if(resource!=0&&!failed){
  val view=remember{VideoView(context)}
  val finished by rememberUpdatedState(onFinished)
  DisposableEffect(resource,view){view.setOnPreparedListener{player->player.setVolume(0f,0f);view.start()};view.setOnCompletionListener{finished()};view.setOnErrorListener{_,_,_->failed=true;true};view.setVideoURI(Uri.parse("android.resource://"+context.packageName+"/"+resource));onDispose{view.stopPlayback()}}
  LaunchedEffect(Unit){kotlinx.coroutines.delay(3600);finished()}
  Box(Modifier.fillMaxSize().background(Color(0xFF2B170E)).clearAndSetSemantics{},contentAlignment=Alignment.Center){AndroidView(factory={view},modifier=Modifier.fillMaxWidth().aspectRatio(16f/9f))}
  return
 }
 var stage by remember { mutableIntStateOf(0) }
 LaunchedEffect(Unit){kotlinx.coroutines.delay(650);stage=1;kotlinx.coroutines.delay(750);stage=2;kotlinx.coroutines.delay(1000);onFinished()}
 val photo by animateFloatAsState(if(stage>=1)1f else 0f,tween(550),label="food")
 val lift by animateDpAsState(if(stage>=1)(-66).dp else 0.dp,tween(600),label="cloche")
 val cloche by animateFloatAsState(if(stage>=1)0f else 1f,tween(600),label="clocheOpacity")
 val brand by animateFloatAsState(if(stage>=2)1f else 0f,tween(650),label="brand")
 Box(Modifier.fillMaxSize().clipToBounds().background(Color(0xFF2B170E)).clearAndSetSemantics{}){
  Image(painterResource(R.drawable.zipple_restaurant_bar),contentDescription=null,contentScale=ContentScale.Crop,alignment=Alignment.BottomStart,modifier=Modifier.fillMaxSize().scale(1.4f).alpha(photo))
  Box(Modifier.fillMaxSize().background(Color(0xFF2B170E).copy(alpha=.34f)))
  Image(painterResource(R.drawable.zipple_cloche),contentDescription=null,modifier=Modifier.align(Alignment.Center).offset(y=lift).size(124.dp).alpha(cloche))
  Column(Modifier.align(Alignment.Center).alpha(brand).padding(24.dp),horizontalAlignment=Alignment.CenterHorizontally){
   Image(painterResource(R.drawable.zipple_cloche),contentDescription=null,modifier=Modifier.size(92.dp))
   Text("ZIPPLE",color=Color(0xFFFFF3E1),fontSize=43.sp,fontWeight=FontWeight.ExtraBold,letterSpacing=8.sp)
   Spacer(Modifier.height(14.dp));Text("Servez mieux, gérez en toute sécurité.",color=Color(0xFFFFF3E1),textAlign=TextAlign.Center,fontSize=17.sp,fontWeight=FontWeight.SemiBold)
  }
 }
}

