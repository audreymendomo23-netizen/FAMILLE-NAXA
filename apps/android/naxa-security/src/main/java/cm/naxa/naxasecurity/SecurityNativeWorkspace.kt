package cm.naxa.naxasecurity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

internal class SecurityNativeState {
 var session by mutableStateOf<SecurityNativeSession?>(null)
 var site by mutableStateOf<SecurityNativeSite?>(null)
 var generation by mutableIntStateOf(0)
 fun reset(){generation++;session=null;site=null}
 fun select(v:SecurityNativeSite){if(v!=site){generation++;site=v}}
}
internal val LocalSecurityNative=staticCompositionLocalOf<SecurityNativeState>{error("SECURITY scope unavailable")}
@Composable internal fun SecurityNativeWorkspace(content:@Composable ()->Unit){
 val state=remember{SecurityNativeState()}
 val session=state.session
 LaunchedEffect(session){if(session!=null){delay((session.expiresAt-System.currentTimeMillis()).coerceAtLeast(0));if(state.session===session)state.reset()}}
 CompositionLocalProvider(LocalSecurityNative provides state,content=content)
}
@Composable internal fun SecurityNativeSessionPanel(){
 val state=LocalSecurityNative.current;val scope=rememberCoroutineScope()
 var expanded by remember{mutableStateOf(false)}
 var email by remember{mutableStateOf("")};var password by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 val session=state.session
 TextButton(onClick={expanded=!expanded}){Text(if(session==null)"Connexion SECURITY (recette)" else "Session SECURITY · "+(state.site?.name?:""))}
 if(!expanded)return
 if(!SecurityNativeApi.configured){Text("Clé publique de recette non configurée ; accès local uniquement.");return}
 if(session==null){
  OutlinedTextField(email,{email=it},label={Text("Identifiant e-mail provisionné")},singleLine=true,enabled=!busy,modifier=Modifier.fillMaxWidth())
  OutlinedTextField(password,{password=it},label={Text("Mot de passe")},visualTransformation=PasswordVisualTransformation(),singleLine=true,enabled=!busy,modifier=Modifier.fillMaxWidth())
  Button(enabled=!busy&&email.isNotBlank()&&password.isNotBlank(),onClick={busy=true;message="";scope.launch{try{val s=SecurityNativeApi.login(email,password);state.generation++;state.session=s;state.site=s.sites.first();expanded=false}catch(e:CancellationException){throw e}catch(_:Exception){message="Connexion refusée ou indisponible."}finally{password="";busy=false}}}){Text("Connexion")}
 }else{
  var menu by remember{mutableStateOf(false)}
  Box{TextButton(onClick={menu=true}){Text(state.site?.name?:"Choisir un site")};DropdownMenu(expanded=menu,onDismissRequest={menu=false}){session.sites.forEach{site->DropdownMenuItem(text={Text(site.name)},onClick={state.select(site);menu=false;expanded=false})}}}
  Button(onClick={state.reset();expanded=false;scope.launch{try{SecurityNativeApi.logout(session)}catch(e:CancellationException){throw e}catch(_:Exception){message="Déconnexion locale ; révocation non confirmée."}}}){Text("Déconnexion")}
 }
 if(message.isNotEmpty())Text(message)
}
@Composable internal fun SecurityNativeModuleAction(module:SecurityModule,input:Map<String,String>){
 val state=LocalSecurityNative.current;val s=state.session;val site=state.site;val generation=state.generation
 val scope=rememberCoroutineScope()
 var busy by remember(module.id,generation){mutableStateOf(false)}
 var message by remember(module.id,generation){mutableStateOf("")}
 var pendingId by remember(module.id,generation){mutableStateOf("")}
 var pendingInput by remember(module.id,generation){mutableStateOf<Map<String,String>>(emptyMap())}
 if(s==null||site==null){if(module.fields.isEmpty())Text("Connectez une session de recette pour lire les données.");return}
 val read=module.kind in setOf("overview","report","audit")
 if(!read&&module.kind !in SecurityNativeContract.persistent)return
 Button(enabled=!busy,onClick={if(busy)return@Button;busy=true;message="";scope.launch{
  try{
   if(read){val rows=SecurityNativeApi.read(s,site,module.kind);if(state.generation==generation)message=rows.joinToString("\n")}
   else{
    SecurityNativeContract.payload(module,input)
    if(pendingId.isBlank()||pendingInput!=input){pendingId=UUID.randomUUID().toString();pendingInput=input.toMap()}
    val confirmed=SecurityNativeApi.submit(s,site,module,input,pendingId)
    if(state.generation==generation)message=if(confirmed)"Demande enregistrée ; aucune exécution physique confirmée." else "Enregistrement non confirmé."
   }
  }catch(e:CancellationException){throw e}catch(_:Exception){if(state.generation==generation)message="Saisie invalide ou opération non confirmée."}finally{if(state.generation==generation)busy=false}
 }}){Text(if(read)"Lire les données autorisées" else "Transmettre la demande")}
 if(message.isNotEmpty())Text(message)
}
