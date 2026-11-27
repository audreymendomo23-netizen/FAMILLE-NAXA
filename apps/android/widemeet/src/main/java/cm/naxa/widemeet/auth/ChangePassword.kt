package cm.naxa.widemeet.auth
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import java.util.UUID

@Composable fun ChangePassword(english:Boolean,gateway:AuthGateway,session:Session,onChanged:()->Unit,onCancel:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 var old by remember{mutableStateOf("")};var next by remember{mutableStateOf("")};var confirm by remember{mutableStateOf("")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 val request=remember{UUID.randomUUID().toString()};val scope=rememberCoroutineScope()
 Column(verticalArrangement=Arrangement.spacedBy(12.dp)){
 Text(tr("Modifier le mot de passe","Change password"),style=MaterialTheme.typography.titleLarge)
 OutlinedTextField(old,{old=it.take(256)},label={Text(tr("Mot de passe actuel","Current password"))},visualTransformation=PasswordVisualTransformation(),enabled=!busy,singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(next,{next=it.take(256)},label={Text(tr("Nouveau mot de passe (12 caractères minimum)","New password (at least 12 characters)"))},visualTransformation=PasswordVisualTransformation(),enabled=!busy,singleLine=true,modifier=Modifier.fillMaxWidth())
 OutlinedTextField(confirm,{confirm=it.take(256)},label={Text(tr("Confirmer le nouveau mot de passe","Confirm new password"))},visualTransformation=PasswordVisualTransformation(),enabled=!busy,singleLine=true,modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&old.isNotBlank()&&old!=next&&next.length>=12&&next==confirm,onClick={busy=true;error=false;scope.launch{try{gateway.changePassword(session,old,next,request);onChanged()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){error=true}finally{old="";next="";confirm="";busy=false}}}){Text(tr("Modifier et se reconnecter","Change and sign in again"))}
 if(error)Text(tr("Modification non confirmée. Réessayez avec les mêmes informations ou contactez le support.","Change not confirmed. Retry with the same details or contact support."),color=MaterialTheme.colorScheme.error)
 TextButton(enabled=!busy,onClick=onCancel){Text(tr("Se déconnecter","Sign out"))}
 }
}
