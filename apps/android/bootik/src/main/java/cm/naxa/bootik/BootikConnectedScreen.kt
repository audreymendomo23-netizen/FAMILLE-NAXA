package cm.naxa.bootik
import android.os.Build
import android.os.CancellationSignal
import android.hardware.biometrics.BiometricPrompt
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.launch
import org.json.JSONObject

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable fun BootikConnectedScreen(api:BootikApi,offline:BootikScopedDao,onBack:()->Unit){
 val context=LocalContext.current
 val scope=rememberCoroutineScope()
 val vault=remember{SessionVault(context.applicationContext)}
 val pinManager=remember{LocalAccessPinManager(context.applicationContext)}
 val biometricPrefs=remember{context.getSharedPreferences("bootik_biometric_optin",0)}
 val localePrefs=remember{context.getSharedPreferences("bootik_login_locale",0)}
 var locale by remember{mutableStateOf(localePrefs.getString("locale","fr")?:"fr")}
 fun tr(fr:String,en:String,ff:String)=when(locale){"en"->en;"ff-CM"->ff;else->fr}
 var identifier by remember{mutableStateOf("")};var password by remember{mutableStateOf("")}
 var session by remember{mutableStateOf<BootikSession?>(null)};var site by remember{mutableStateOf("")}
 var message by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)}
 var firstUseDone by remember{mutableStateOf(false)};var showPassword by remember{mutableStateOf(false)}
 var rememberDevice by remember{mutableStateOf(false)}
 var savedToken by remember{mutableStateOf(vault.loadRefreshToken())}
 var unlocked by remember{mutableStateOf<String?>(null)}
 var pin by remember{mutableStateOf("")};var confirmation by remember{mutableStateOf("")}
 var universe by remember{mutableStateOf("retailer")};var plan by remember{mutableStateOf("access")}
 var changing by remember{mutableStateOf(false)};var currentPw by remember{mutableStateOf("")};var newPw by remember{mutableStateOf("")};var confirmPw by remember{mutableStateOf("")}
 var biometricSignal by remember{mutableStateOf<CancellationSignal?>(null)}
 val memberKey=session?.let{it.organization+":"+it.member}
 DisposableEffect(context){
  val lifecycle=(context as? ComponentActivity)?.lifecycle
  val observer=LifecycleEventObserver{_,event->if(event==Lifecycle.Event.ON_STOP){unlocked=null;pin="";confirmation="";biometricSignal?.cancel();biometricSignal=null}}
  lifecycle?.addObserver(observer)
  onDispose{lifecycle?.removeObserver(observer);biometricSignal?.cancel()}
 }
 fun task(block:suspend ()->Unit){if(busy)return;busy=true;scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération refusée ou indisponible"}finally{busy=false}}}
 fun establish(s:BootikSession){firstUseDone=false;session=s;site=s.sites.first().id;unlocked=null;pin="";confirmation="";message="Session confirmée. Déverrouillez avec votre PIN."}
 fun unlock(s:BootikSession,key:String){require(s.expiresAt>System.currentTimeMillis());s.refreshToken?.let{vault.save(it);savedToken=it};unlocked=key;pin="";confirmation="";message="Accès local déverrouillé"}
 fun signOut(s:BootikSession){task{try{api.logout(s);message="Session révoquée"}finally{vault.clear();savedToken=null;session=null;unlocked=null;site="";password="";pin="";confirmation=""}}}
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
 Text("BOOTIK • Connexion et services",style=MaterialTheme.typography.headlineSmall)
 val current=session
 LaunchedEffect(current?.token){
  if(current!=null){
   while(current.permits(current.sites.first().id))kotlinx.coroutines.delay(1000)
   if(session?.token==current.token){unlocked=null;session=null;site="";pin="";confirmation="";biometricSignal?.cancel();message="Session expirée ou horloge modifiée. Reconnectez-vous."}
  }
 }
 if(current==null){
 Row(horizontalArrangement=Arrangement.End,modifier=Modifier.fillMaxWidth()){listOf("fr" to "FR","en" to "EN","ff-CM" to "FF").forEach{(code,label)->TextButton(enabled=locale!=code,onClick={locale=code;localePrefs.edit().putString("locale",code).apply()},modifier=Modifier.testTag("locale-"+if(code=="ff-CM")"ff" else code)){Text(label)}}}
 Text(tr("Bienvenue","Welcome","A jaɓɓaama"),style=MaterialTheme.typography.headlineMedium);Text(tr("Connecte-toi à ton espace professionnel.","Sign in to your professional workspace.","Naatu e nokkuure golle maa."))
 OutlinedTextField(identifier,{identifier=it},label={Text(tr("Identifiant","ID","Innol"))},singleLine=true,modifier=Modifier.fillMaxWidth().testTag("login-identifier"))
 OutlinedTextField(password,{password=it},label={Text(tr("Mot de passe","Password","Finnde"))},singleLine=true,modifier=Modifier.fillMaxWidth().testTag("login-password"),visualTransformation=if(showPassword)VisualTransformation.None else PasswordVisualTransformation(),trailingIcon={TextButton(onClick={showPassword=!showPassword}){Text(if(showPassword)tr("Masquer","Hide","Suuɗu") else tr("Afficher","Show","Hollu"))}})
 Row{Checkbox(rememberDevice,{rememberDevice=it},enabled=!busy);Text(tr("Rester connecté sur cet appareil","Stay signed in on this device","Heddo e naatugol e kaɓirgol ngol"))}
 Button(modifier=Modifier.fillMaxWidth().testTag("login-submit"),enabled=!busy&&identifier.isNotBlank()&&password.isNotBlank(),onClick={task{try{val previous=savedToken;if(previous!=null){api.forget(previous);vault.clear();savedToken=null};establish(api.login(identifier,password,rememberDevice))}finally{password=""}}}){Text(tr("Se connecter","Sign in","Naatu"))}
 if(savedToken!=null){
 Button(enabled=!busy,onClick={task{val old=savedToken?:return@task;val s=api.refresh(old);vault.clear();savedToken=null;establish(s)}}){Text("Reprendre ma session")}
 TextButton(enabled=!busy,onClick={task{try{savedToken?.let{api.forget(it)};message="Session révoquée"}finally{vault.clear();savedToken=null}}}){Text("Oublier cet appareil")}
 }
 TextButton(enabled=!busy&&identifier.isNotBlank(),onClick={task{api.recovery(identifier);message="Demande transmise"}}){Text(tr("Mot de passe oublié","Forgot password?","A yejjitii finnde maa?"))}
 TextButton(enabled=!busy,onClick=onBack){Text("Brouillons locaux")}
 }else if(current.requirePasswordChange||changing){
 Text("Changer le mot de passe")
 Text("12 caractères minimum ; les sessions seront révoquées.")
 OutlinedTextField(currentPw,{currentPw=it},label={Text("Mot de passe actuel")},visualTransformation=PasswordVisualTransformation(),enabled=!busy)
 OutlinedTextField(newPw,{newPw=it},label={Text("Nouveau mot de passe")},visualTransformation=PasswordVisualTransformation(),enabled=!busy)
 OutlinedTextField(confirmPw,{confirmPw=it},label={Text("Confirmer le nouveau mot de passe")},visualTransformation=PasswordVisualTransformation(),enabled=!busy)
 Button(enabled=!busy&&currentPw.isNotBlank()&&newPw.length in 12..128&&newPw==confirmPw&&newPw!=currentPw,onClick={task{try{api.changePassword(current,currentPw,newPw);vault.clear();savedToken=null;session=null;unlocked=null;site="";changing=false;message="Mot de passe changé. Reconnectez-vous."}finally{currentPw="";newPw="";confirmPw=""}}}){Text("Confirmer le changement")}
 TextButton(enabled=!busy,onClick={changing=false;currentPw="";newPw="";confirmPw="";signOut(current)}){Text("Se déconnecter")}
 }else if(memberKey!=null && unlocked!=memberKey){
 val configured=pinManager.isConfigured(memberKey)
 Text(if(configured)"Déverrouillage sécurisé" else "Créer un PIN personnel à quatre chiffres")
 OutlinedTextField(pin,{if(it.length<=4&&it.all{c->c in '0'..'9'})pin=it},label={Text("PIN")},visualTransformation=PasswordVisualTransformation(),singleLine=true)
 if(!configured)OutlinedTextField(confirmation,{if(it.length<=4&&it.all{c->c in '0'..'9'})confirmation=it},label={Text("Confirmer le PIN")},visualTransformation=PasswordVisualTransformation(),singleLine=true)
 Button(enabled=!busy&&LocalAccessPinPolicy.isValid(pin)&&(configured||pin==confirmation),onClick={task{
  val result=if(configured)pinManager.verify(memberKey,pin) else pinManager.enroll(memberKey,pin)
  if(result.code==LocalAccessPinCode.SUCCESS)unlock(current,memberKey)else{pin="";confirmation="";message=if(result.code==LocalAccessPinCode.LOCKED)"PIN temporairement verrouillé" else "PIN refusé"}
 }}){Text(if(configured)"Déverrouiller" else "Enregistrer mon PIN")}
 if(Build.VERSION.SDK_INT>=28&&configured&&biometricPrefs.getBoolean(memberKey,false)&&pinManager.canUseBiometric(memberKey)&&current.expiresAt>System.currentTimeMillis()){
 Button(enabled=!busy,onClick={
  val signal=CancellationSignal();biometricSignal=signal
  BiometricPrompt.Builder(context).setTitle("Déverrouiller BOOTIK").setNegativeButton("Utiliser le PIN",context.mainExecutor){_,_->signal.cancel()}.build().authenticate(signal,context.mainExecutor,object:BiometricPrompt.AuthenticationCallback(){
   override fun onAuthenticationSucceeded(result:BiometricPrompt.AuthenticationResult){if(!signal.isCanceled&&session?.member==current.member&&pinManager.canUseBiometric(memberKey)&&current.expiresAt>System.currentTimeMillis())task{unlock(current,memberKey)}}
   override fun onAuthenticationError(errorCode:Int,errString:CharSequence){message="Biométrie indisponible. Utilisez le PIN."}
  })
 }){Text("Utiliser la biométrie")}
 }
 TextButton(enabled=!busy,onClick={signOut(current)}){Text("Se déconnecter")}
 }else if(!firstUseDone){
 key(current.token){BootikFirstUse(api,current,{firstUseDone=true},{signOut(current)})}
 }else{
 val overview=remember{BringIntoViewRequester()};val cash=remember{BringIntoViewRequester()};val stock=remember{BringIntoViewRequester()};val security=remember{BringIntoViewRequester()};val help=remember{BringIntoViewRequester()}
 Text("Rubriques principales",style=MaterialTheme.typography.titleMedium)
 Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(8.dp)){
 listOf("Mon espace" to overview,"Caisse et ventes" to cash,"Stock et achats" to stock,"Sécurité et abonnement" to security,"Assistance" to help).forEach{(label,requester)->OutlinedButton(onClick={scope.launch{requester.bringIntoView()}}){Text(label)}}}
 Text("Site actif",modifier=Modifier.bringIntoViewRequester(overview))
 var requestId by remember(site){mutableStateOf("")}
 current.sites.forEach{s->Row{RadioButton(selected=site==s.id,onClick={site=s.id;message=""},enabled=!busy&&requestId.isBlank());Text(s.name)}}
 if(Build.VERSION.SDK_INT>=28&&memberKey!=null){
 var bioEnabled by remember(memberKey){mutableStateOf(biometricPrefs.getBoolean(memberKey,false))}
 Row{Checkbox(bioEnabled,{bioEnabled=it;biometricPrefs.edit().putBoolean(memberKey,it).apply()},enabled=!busy);Text("Autoriser le déverrouillage biométrique")}
 }
 TextButton(enabled=!busy,onClick={unlocked=null;pin="";confirmation=""}){Text("Verrouiller")}
 TextButton(enabled=!busy,onClick={changing=true}){Text("Changer le mot de passe")}
 if(current.refreshToken!=null)TextButton(enabled=!busy,onClick={task{val s=api.refresh(current.refreshToken);vault.clear();savedToken=null;establish(s)}}){Text("Renouveler la session")}
 if(current.role!="staff"){
  var team by remember(site){mutableStateOf<List<String>>(emptyList())}
  Text("Équipe du site")
  Button(enabled=!busy,onClick={task{val rows=api.operation(current,site,"team",JSONObject()).getJSONArray("members");team=(0 until rows.length()).map{val row=rows.getJSONObject(it);row.getString("role")+" • "+row.getString("user_id").take(8)+" • "+(if(row.getBoolean("active"))"Actif" else "Inactif")}}}){Text("Actualiser l’équipe")}
  team.forEach{Text(it)}
 }
 Text("Abonnement",modifier=Modifier.bringIntoViewRequester(security))
 Row{RadioButton(universe=="retailer",{universe="retailer"},enabled=!busy);Text("Détaillants");RadioButton(universe=="distributor",{universe="distributor"},enabled=!busy);Text("Distributeurs")}
 Row{RadioButton(plan=="access",{plan="access"},enabled=!busy);Text("ACCÈS");RadioButton(plan=="premium",{plan="premium"},enabled=!busy);Text("PREMIUM")}
 Button(enabled=!busy,onClick={task{val result=api.operation(current,site,"entitlement",JSONObject().put("universe",universe));message=if(result.getBoolean("active"))"Droits actifs" else "Droits inactifs"}}){Text("Vérifier mes droits")}
 Button(enabled=!busy&&current.role!="staff",onClick={task{val result=api.operation(current,site,"trial",JSONObject().put("universe",universe).put("plan",plan));message="Fin d’essai : "+result.getString("expires_at")}}){Text("Activer les 72 heures")}
 key(current.organization,current.member,site){BootikSecurityPanel(api,current,site)}
 BootikPaymentPanel(api,current,site,universe,plan)
 if(current.role!="staff")key(current.organization,current.member,site){BootikMasterPanel(api,current,site)}
 Text("Caisse et ventes",modifier=Modifier.bringIntoViewRequester(cash),style=MaterialTheme.typography.titleMedium)
 key(current.organization,current.member,site){BootikCashPanel(api,current,site)}
 Text("Stock et achats",modifier=Modifier.bringIntoViewRequester(stock),style=MaterialTheme.typography.titleMedium)
 BootikSalesPanel(api,offline,current,site)
 Text("NAXA SECURITY et assistance",modifier=Modifier.bringIntoViewRequester(help))
 var consent by remember(site){mutableStateOf(false)}
 Row{Checkbox(consent,{consent=it},enabled=!busy);Text("Je consens à demander une session multimédia")}
 listOf("ticket" to "Assistance","camera" to "Vidéosurveillance","audio" to "Appel audio","video" to "Visioconférence","screen" to "Partage d’écran").forEach{(kind,label)->
 Button(enabled=!busy&&requestId.isBlank()&&(kind !in setOf("audio","video","screen")||consent)&&(kind!="camera"||current.role!="staff"),onClick={task{val result=api.operation(current,site,"support",JSONObject().put("kind",kind).put("consent",consent));requestId=result.getString("request_id");message="Demande enregistrée par le serveur, flux non démarré";consent=false}}){Text(label)}}
 if(requestId.isNotBlank())Button(enabled=!busy,onClick={task{val result=api.operation(current,site,"support-cancel",JSONObject().put("request_id",requestId));check(result.getBoolean("cancelled"));requestId="";message="Demande annulée"}}){Text("Annuler la demande")}
 Button(enabled=!busy,onClick={signOut(current)}){Text("Se déconnecter")}
 }
 Text(message)
 }
}
