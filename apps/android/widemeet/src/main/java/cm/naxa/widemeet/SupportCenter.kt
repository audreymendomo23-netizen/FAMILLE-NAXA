package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import org.json.JSONObject
import java.util.UUID
private fun supportRows(x:JSONObject,key:String):List<JSONObject>{val a=x.getJSONArray(key);return (0 until a.length()).map{a.getJSONObject(it)}}
@Composable fun SupportCenter(english:Boolean,gateway:AuthGateway,session:Session,onFaq:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var agent by remember{mutableStateOf(false)};var queue by remember{mutableStateOf(false)};var ready by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var ticket by remember{mutableStateOf<JSONObject?>(null)}
 var subject by remember{mutableStateOf("")};var category by remember{mutableStateOf("account")};var body by remember{mutableStateOf("")};var reply by remember{mutableStateOf("")};var pending by remember{mutableStateOf<JSONObject?>(null)};var closeConfirm by remember{mutableStateOf(false)};var releaseConfirm by remember{mutableStateOf(false)};var rating by remember{mutableIntStateOf(0)};var reviewer by remember{mutableStateOf(false)};var reviewMode by remember{mutableStateOf(false)};var mediaReady by remember{mutableStateOf(false)}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.identity(session,"support-"+action,data)
 suspend fun refresh(q:Boolean=queue){try{items=supportRows(req(if(q)"queue" else "list"),"items")}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();ticket=null;reply="";agent=false;queue=false;ready=false;throw e}}
 suspend fun load(){val c=req("capabilities");agent=c.optBoolean("agent");reviewer=c.optBoolean("recovery_reviewer");mediaReady=c.optBoolean("transport_ready");refresh(false);ready=true}
 suspend fun open(id:String){try{ticket=req("read",JSONObject().put("ticket_id",id));reply="";rating=0;pending=null}catch(e:CancellationException){throw e}catch(e:Exception){ticket=null;items=emptyList();reply="";agent=false;queue=false;ready=false;throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 fun privacyLabel(s:String)=when(s){"privacy_access"->tr("Accès aux données","Data access");"privacy_rectify"->tr("Rectification des données","Data correction");"privacy_erase"->tr("Effacement des données","Data erasure");else->""}
 fun status(s:String)=when(s){"open"->tr("Ouverte","Open");"assigned"->tr("Prise en charge","Assigned");"waiting"->tr("En attente de réponse","Waiting for response");"closed"->tr("Clôturée","Closed");else->s}
 LaunchedEffect(session.deviceId){work{load()}}
 LaunchedEffect(ticket?.optString("id"),ticket?.optString("status"),busy,session.deviceId){val id=ticket?.optString("id")?:return@LaunchedEffect;if(busy||pending!=null)return@LaunchedEffect;while(true){delay(5000);if(busy||pending!=null||ticket?.optString("id")!=id)return@LaunchedEffect;try{val fresh=req("read",JSONObject().put("ticket_id",id));if(!busy&&pending==null&&ticket?.optString("id")==id)ticket=fresh}catch(e:CancellationException){throw e}catch(e:Exception){ticket=null;items=emptyList();reply="";agent=false;queue=false;ready=false;error=true;return@LaunchedEffect}}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Mes demandes d’assistance","My support requests"),style=MaterialTheme.typography.titleLarge)
 Text(tr("Ne communiquez jamais vos mots de passe, codes de récupération ou contenus privés de réunion.","Never share passwords, recovery codes or private meeting content."))
 TextButton(onClick=onFaq){Text(tr("Consulter la FAQ","Read FAQ"))}
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error)Text(tr("Action non confirmée. Réessayez.","Action unconfirmed. Retry."),color=MaterialTheme.colorScheme.error)
 if(!ready&&!busy)Button(onClick={work{load()}}){Text(tr("Réessayer","Retry"))}
 if(ready&&reviewer)TextButton(enabled=!busy&&pending==null,onClick={reviewMode=!reviewMode;ticket=null;reply=""}){Text(if(reviewMode)tr("Retour au support","Back to support")else tr("Demandes de récupération supervisée","Supervised recovery requests"))}
 if(ready&&reviewMode&&reviewer)SupportRecoveryReview(english,gateway,session)
 if(ready&&!reviewMode){
 if(agent){TextButton(enabled=!busy&&pending==null,onClick={work{ticket=null;refresh(false);queue=false}}){Text(tr("Mes demandes","My requests"))};TextButton(enabled=!busy&&pending==null,onClick={work{ticket=null;refresh(true);queue=true}}){Text(tr("File agent","Agent queue"))}}
 val t=ticket
 if(t!=null){val id=t.getString("id")
 TextButton(enabled=!busy&&pending==null,onClick={work{ticket=null;refresh()}}){Text(tr("Retour aux demandes","Back to requests"))}
 Text(t.getString("subject"),style=MaterialTheme.typography.titleMedium);if(privacyLabel(t.optString("category")).isNotEmpty())Text(privacyLabel(t.optString("category"))+" · "+tr("Demande à examiner, pas une décision juridique.","Request for review, not a legal decision."));Text(status(t.getString("status")))
 TextButton(enabled=!busy&&pending==null,onClick={work{open(id)}}){Text(tr("Actualiser","Refresh"))}
 for(m in supportRows(t,"messages")){Text(if(m.optString("author_kind")=="agent")tr("Assistance","Support") else tr("Demandeur","Requester"),style=MaterialTheme.typography.labelLarge);Text(m.getString("body"))}
 if(mediaReady&&t.optString("status")!="closed")key(id,session.deviceId){SupportMediaPanel(english,gateway,session,t)}
 if(t.optString("viewer")=="agent"&&t.optString("status")!="closed"){TextButton(enabled=!busy&&pending==null,onClick={releaseConfirm=true}){Text(tr("Remettre dans la file","Release to queue"))}}
 if(releaseConfirm)AlertDialog(onDismissRequest={releaseConfirm=false},title={Text(tr("Remettre cette demande dans la file ?","Release this request to the queue?"))},confirmButton={TextButton(onClick={releaseConfirm=false;work{req("release",JSONObject().put("ticket_id",id).put("assignment_version",t.optString("assignment_version")));ticket=null;reply="";refresh(true);queue=true}}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={releaseConfirm=false}){Text(tr("Annuler","Cancel"))}})
 if(t.optString("viewer")=="requester"&&t.optString("status")=="closed"){
 Text(tr("Votre satisfaction","Your satisfaction"))
 if(!t.isNull("feedback")){Text(tr("Note enregistrée","Rating saved")+" : "+t.optInt("feedback")+"/5")}else{
 for(n in 1..5)Row{RadioButton(selected=rating==n,onClick={rating=n},enabled=!busy);Text("$n/5")}
 Button(enabled=!busy&&rating in 1..5,onClick={work{req("feedback",JSONObject().put("ticket_id",id).put("rating",rating));open(id)}}){Text(tr("Envoyer mon avis","Submit feedback"))}
 }}
 if(t.optString("status")!="closed"){OutlinedTextField(reply,{reply=it.take(4000)},enabled=!busy&&pending==null,label={Text(tr("Votre message","Your message"))},modifier=Modifier.fillMaxWidth());Button(enabled=!busy&&reply.isNotBlank(),onClick={work{val p=pending?:JSONObject().put("ticket_id",id).put("message_id",UUID.randomUUID().toString()).put("body",reply.trim()).also{pending=it};req("reply",p);pending=null;open(id);refresh()}}){Text(tr("Envoyer","Send"))};TextButton(enabled=!busy&&pending==null,onClick={closeConfirm=true}){Text(tr("Clôturer","Close"))}}
 if(closeConfirm)AlertDialog(onDismissRequest={closeConfirm=false},title={Text(tr("Clôturer cette demande ?","Close this request?"))},confirmButton={TextButton(onClick={closeConfirm=false;work{req("close",JSONObject().put("ticket_id",id));open(id);refresh()}}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={closeConfirm=false}){Text(tr("Annuler","Cancel"))}})
 }else{
 TextButton(enabled=!busy&&pending==null,onClick={work{refresh()}}){Text(tr("Actualiser","Refresh"))}
 for(x in items){val id=x.getString("id");Text((if(x.isNull("subject"))tr("Demande en attente","Pending request") else x.getString("subject"))+" · "+status(x.getString("status"))+(if(privacyLabel(x.optString("category")).isNotEmpty())" · "+privacyLabel(x.optString("category")) else ""));TextButton(enabled=!busy&&pending==null,onClick={work{if(queue&&!x.optBoolean("assigned")){req("claim",JSONObject().put("ticket_id",id));refresh(true)};open(id)}}){Text(if(queue&&!x.optBoolean("assigned"))tr("Prendre en charge","Claim") else tr("Ouvrir","Open"))}}
 if(items.isEmpty())Text(tr("Aucune demande.","No requests."))
 if(!queue){Text(tr("Nouvelle demande","New request"),style=MaterialTheme.typography.titleMedium);OutlinedTextField(subject,{subject=it.take(120)},enabled=!busy&&pending==null,label={Text(tr("Sujet","Subject"))},modifier=Modifier.fillMaxWidth());for((value,label) in listOf("account" to tr("Compte","Account"),"meeting" to tr("Réunion","Meeting"),"billing" to tr("Abonnement","Billing"),"other" to tr("Autre","Other"),"privacy_access" to privacyLabel("privacy_access"),"privacy_rectify" to privacyLabel("privacy_rectify"),"privacy_erase" to privacyLabel("privacy_erase")))Row{RadioButton(selected=category==value,onClick={category=value},enabled=!busy&&pending==null);Text(label,Modifier.padding(top=12.dp))}
 if(privacyLabel(category).isNotEmpty())Text(tr("Ne transmettez ni mot de passe, ni clé, ni pièce d’identité ni contenu privé. Dossier de suivi uniquement, aucune exportation, correction ou suppression automatique.","Do not share passwords, keys, identity documents or private content. Tracking case only, no automatic export, correction or deletion."))
 OutlinedTextField(body,{body=it.take(4000)},enabled=!busy&&pending==null,label={Text(tr("Description du problème","Issue description"))},modifier=Modifier.fillMaxWidth())
 Button(enabled=!busy&&subject.isNotBlank()&&body.isNotBlank(),onClick={work{val p=pending?:JSONObject().put("ticket_id",UUID.randomUUID().toString()).put("message_id",UUID.randomUUID().toString()).put("subject",subject.trim()).put("category",category).put("body",body.trim()).also{pending=it};req("create",p);pending=null;subject="";body="";refresh(false);open(p.getString("ticket_id"))}}){Text(tr("Envoyer la demande","Submit request"))}}
 }}
 if(!mediaReady)Text(tr("Les appels audio et le partage d’écran avec un agent ne sont pas encore disponibles.","Audio calls and screen sharing with an agent are not yet available."))
 }}
}
