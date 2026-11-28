package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable internal fun GrilladSupportThread(ticket:String,enabled:Boolean,request:suspend(JSONObject)->Any){
 val scope=rememberCoroutineScope();var data by remember{mutableStateOf<JSONObject?>(null)};var message by remember{mutableStateOf("")};var pending by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var status by remember{mutableStateOf("")}
 fun read(send:Boolean){if(busy||!enabled)return;busy=true;scope.launch{try{val req=if(send)pending?:obj("action" to "support_thread","ticket" to ticket,"event" to UUID.randomUUID().toString(),"message" to message.trim()).also{pending=it}else obj("action" to "support_thread","ticket" to ticket);data=request(req) as JSONObject;if(send){message="";pending=null};status=""}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status=if(send)"Envoi non confirmé : réessayez le même message." else "Conversation indisponible."}finally{busy=false}}}
 Text("Conversation assistance",style=MaterialTheme.typography.titleMedium);Text(data?.optString("description").orEmpty());rows(data?.optJSONArray("messages")).forEach{m->Text((if(m.optString("author_kind")=="agent")"Agent NAXA" else "Vous")+" · "+m.optString("body"))}
 OutlinedButton({read(false)},enabled=enabled&&!busy){Text("Actualiser la conversation")};OutlinedTextField(message,{if(it.length<=2000)message=it},label={Text("Message assistance")},enabled=enabled&&!busy&&pending==null,modifier=Modifier.fillMaxWidth());Button({read(true)},enabled=enabled&&!busy&&message.isNotBlank()){Text(if(pending!=null)"Réessayer" else "Envoyer le message")};if(status.isNotBlank())Text(status)
}
