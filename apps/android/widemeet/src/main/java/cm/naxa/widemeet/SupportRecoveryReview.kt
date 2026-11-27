package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject

@Composable fun SupportRecoveryReview(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var items by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var selected by remember{mutableStateOf("")};var reference by remember{mutableStateOf("")};var decision by remember{mutableStateOf("")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var confirming by remember{mutableStateOf(false)}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.identity(session,"support-recovery-"+action,data)
 suspend fun refresh(){val rows=req("queue").getJSONArray("items");items=(0 until rows.length()).map{rows.getJSONObject(it)}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();selected="";reference="";decision="";error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId,session.activeWorkspaceId){work{refresh()}}
 val valid=Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").matches(reference)&&decision in listOf("escalate","reject")
 Text(tr("Examen supervisé","Supervised review"),style=MaterialTheme.typography.titleLarge)
 Text(tr("Examen administratif uniquement, sans autorisation de réinitialisation. Ne saisissez ni mot de passe ni document personnel.","Administrative review only, without reset authority. Never enter passwords or personal documents."))
 Button(enabled=!busy,onClick={work{refresh()}}){Text(tr("Actualiser les dossiers","Refresh cases"))}
 if(error)Text(tr("Accès ou action non confirmé.","Access or action unconfirmed."),color=MaterialTheme.colorScheme.error)
 for(item in items){val id=item.getString("id");Text(id);Text(item.optString("requested_at")+" · "+tr("Escalades","Escalations")+": "+item.optInt("escalations")+" · "+tr("Objections","Objections")+": "+item.optInt("objections"))
 if(item.optBoolean("reviewed"))Text(tr("Examen enregistré","Review recorded"))else TextButton(enabled=!busy,onClick={selected=id;reference="";decision=""}){Text(tr("Examiner","Review"))}}
 if(selected.isNotEmpty()&&items.any{it.optString("id")==selected&&!it.optBoolean("reviewed")}){
 OutlinedTextField(reference,{reference=it.take(36)},enabled=!busy,label={Text(tr("Référence de dossier (UUID)","Case reference (UUID)"))},modifier=Modifier.fillMaxWidth())
 for((v,label) in listOf("escalate" to tr("Transmettre au niveau supérieur","Escalate"),"reject" to tr("Émettre une objection","Record objection")))Row{RadioButton(selected=decision==v,onClick={decision=v},enabled=!busy);Text(label)}
 Button(enabled=valid&&!busy,onClick={confirming=true}){Text(tr("Enregistrer l’examen","Record review"))}
 if(confirming)AlertDialog(onDismissRequest={confirming=false},title={Text(tr("Confirmer sans réinitialiser le compte ?","Confirm without resetting the account?"))},confirmButton={TextButton(onClick={confirming=false;work{req("review",JSONObject().put("request_id",selected).put("evidence_ref",reference).put("decision",decision));selected="";reference="";decision="";refresh()}}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={confirming=false}){Text(tr("Annuler","Cancel"))}})
 }
}
