package cm.naxa.widemeet.auth
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@Composable fun SignIn(english:Boolean,configured:Boolean,gateway:AuthGateway,onSession:(Session)->Unit,onBack:()->Unit){
 var identifier by remember{mutableStateOf("")};var password by remember{mutableStateOf("")};var show by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 val scope=rememberCoroutineScope()
 fun tr(fr:String,en:String)=if(english)en else fr
 Card(Modifier.fillMaxWidth()){
 Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
 Text(tr("Connexion","Sign in"),style=MaterialTheme.typography.headlineMedium)
 OutlinedTextField(identifier,{identifier=it.take(27)},enabled=!busy,label={Text(tr("Identifiant WideMeet","WideMeet ID"))},singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(password,{password=it.take(256)},enabled=!busy,label={Text(tr("Mot de passe","Password"))},singleLine=true,visualTransformation=if(show)VisualTransformation.None else PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
 TextButton(onClick={show=!show}){Text(if(show)tr("Masquer le mot de passe","Hide password")else tr("Afficher le mot de passe","Show password"))}
 Button(enabled=configured&&!busy&&identifier.isNotBlank()&&password.isNotBlank(),onClick={busy=true;error=false;scope.launch{try{onSession(gateway.login(identifier,password))}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true}finally{password="";busy=false}}}){Text(if(busy)tr("Connexion…","Signing in…")else tr("Se connecter","Sign in"))}
 if(!configured)Text(tr("Connexion momentanément indisponible.","Sign-in temporarily unavailable."))
 if(error)Text(tr("Connexion impossible. Vérifiez vos identifiants ou réessayez plus tard.","Unable to sign in. Check your credentials or try again later."),color=MaterialTheme.colorScheme.error)
 TextButton(onClick=onBack){Text(tr("Retour","Back"))}
 }
 }
}
