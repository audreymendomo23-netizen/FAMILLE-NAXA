package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONObject

@Composable fun BootikConnectedScreen(api:BootikApi,onBack:()->Unit){
 val scope=rememberCoroutineScope()
 var identifier by remember{mutableStateOf("")};var password by remember{mutableStateOf("")}
 var session by remember{mutableStateOf<BootikSession?>(null)};var site by remember{mutableStateOf("")}
 var message by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)}
 var universe by remember{mutableStateOf("retailer")};var plan by remember{mutableStateOf("access")}
 fun task(block:suspend ()->Unit){if(busy)return;busy=true;scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération refusée ou indisponible"}finally{busy=false}}}
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
 Text("BOOTIK • Connexion et services",style=MaterialTheme.typography.headlineSmall)
 val current=session
 if(current==null){
 OutlinedTextField(identifier,{identifier=it},label={Text("Identifiant")},singleLine=true)
 OutlinedTextField(password,{password=it},label={Text("Mot de passe")},singleLine=true,visualTransformation=PasswordVisualTransformation())
 Button(enabled=!busy&&identifier.isNotBlank()&&password.isNotBlank(),onClick={task{try{val s=api.login(identifier,password);session=s;site=s.sites.first().id;message="Session confirmée"}finally{password=""}}}){Text("Se connecter")}
 TextButton(enabled=!busy&&identifier.isNotBlank(),onClick={task{api.recovery(identifier);message="Demande transmise"}}){Text("Mot de passe oublié")}
 TextButton(enabled=!busy,onClick=onBack){Text("Brouillons locaux")}
 }else{
 Text("Site actif")
 current.sites.forEach{s->Row{RadioButton(selected=site==s.id,onClick={site=s.id;message=""},enabled=!busy);Text(s.name)}}
 Text("Abonnement")
 Row{RadioButton(universe=="retailer",{universe="retailer"},enabled=!busy);Text("Détaillants");RadioButton(universe=="distributor",{universe="distributor"},enabled=!busy);Text("Distributeurs")}
 Row{RadioButton(plan=="access",{plan="access"},enabled=!busy);Text("ACCÈS");RadioButton(plan=="premium",{plan="premium"},enabled=!busy);Text("PREMIUM")}
 Button(enabled=!busy,onClick={task{val result=api.operation(current,site,"entitlement",JSONObject().put("universe",universe));message=if(result.getBoolean("active"))"Droits actifs" else "Droits inactifs"}}){Text("Vérifier mes droits")}
 Button(enabled=!busy&&current.role!="staff",onClick={task{val result=api.operation(current,site,"trial",JSONObject().put("universe",universe).put("plan",plan));message="Fin d’essai : "+result.getString("expires_at")}}){Text("Activer les 72 heures")}
 Text("NAXA SECURITY et assistance")
 var consent by remember(site){mutableStateOf(false)}
 Row{Checkbox(consent,{consent=it},enabled=!busy);Text("Je consens à demander une session multimédia")}
 listOf("ticket" to "Assistance","camera" to "Vidéosurveillance","audio" to "Appel audio","video" to "Visioconférence","screen" to "Partage d’écran").forEach{(kind,label)->
 Button(enabled=!busy&&(kind !in setOf("audio","video","screen")||consent)&&(kind!="camera"||current.role!="staff"),onClick={task{api.operation(current,site,"support",JSONObject().put("kind",kind).put("consent",consent));message="Demande enregistrée par le serveur, flux non démarré";consent=false}}){Text(label)}}
 Button(enabled=!busy,onClick={task{try{api.logout(current);message="Session révoquée"}finally{session=null;site="";password=""}}}){Text("Se déconnecter")}
 }
 Text(message)
 }
}
