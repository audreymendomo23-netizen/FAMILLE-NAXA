package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

private fun minuteRows(a:JSONArray?):List<JSONObject> = if(a==null)emptyList() else (0 until a.length()).mapNotNull{a.optJSONObject(it)}
@Composable fun MinutesPanel(english:Boolean,gateway:RoomGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember{mutableStateOf<JSONObject?>(null)};var prep by remember{mutableStateOf<JSONObject?>(null)};var version by remember{mutableStateOf<JSONObject?>(null)}
 var body by remember{mutableStateOf("")};var recipients by remember{mutableStateOf<Set<String>>(emptySet())};var pending by remember{mutableStateOf<JSONObject?>(null)}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var revokeConfirm by remember{mutableStateOf(false)}
 suspend fun req(action:String,data:JSONObject=JSONObject())=gateway.request("minutes",JSONObject().put("action",action).put("data",data),session) as JSONObject
 suspend fun refresh(){items=minuteRows(req("list").optJSONArray("items"))}
 suspend fun read(id:String,vid:String){val v=req("read",JSONObject().put("room_id",id).put("version_id",vid));version=v;body=v.getString("body")}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId){busy=true;try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 suspend fun loadVersion(id:String,vid:String){read(id,vid);prep=req("prepare",JSONObject().put("room_id",id));refresh()}
 fun mutate(action:String){val id=selected?.optString("room_id")?:return;val vid=version?.optString("version_id")?:return;work{req(action,JSONObject().put("room_id",id).put("version_id",vid).apply{if(action=="publish")put("recipients",JSONArray(recipients.toList()))});if(action=="revoke"){selected=null;prep=null;version=null;body="";refresh()}else loadVersion(id,vid)}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Archives et comptes rendus","Archives and minutes"),style=MaterialTheme.typography.titleLarge)
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Action non confirmée. Actualisez ou réessayez.","Action not confirmed. Refresh or retry."),color=MaterialTheme.colorScheme.error)
 val current=selected
 if(current==null){
 TextButton(enabled=!busy,onClick={work{refresh()}}){Text(tr("Actualiser","Refresh"))}
 for(item in items)TextButton(enabled=!busy,onClick={work{selected=item;version=null;prep=null;body="";recipients=emptySet();pending=null;val id=item.getString("room_id");if(item.optBoolean("can_manage"))prep=req("prepare",JSONObject().put("room_id",id));if(!item.isNull("version_id"))read(id,item.getString("version_id"))}}){Text(item.optString("title")+" · "+item.optString("closed_at").take(10)+(if(item.optBoolean("unread"))" · "+tr("Nouveau","New") else ""))}
 if(!busy&&items.isEmpty())Text(tr("Aucune archive autorisée.","No authorized archive."))
 }else{
 TextButton(enabled=!busy,onClick={selected=null;version=null;prep=null;body="";pending=null;work{refresh()}}){Text(tr("Retour aux archives","Back to archives"))}
 Text(current.optString("title"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Présence réelle inconnue sans preuve média qualifiée.","Actual attendance unknown without qualified media evidence."))
 val v=version;val p=prep
 if(v!=null)Text(tr("Version","Version")+" "+v.optInt("version")+" · "+when{!v.isNull("published_at")->tr("Publiée","Published");!v.isNull("approved_at")->tr("Validée","Approved");else->tr("Brouillon","Draft")})
 if(current.optBoolean("can_manage")&&p?.optBoolean("premium")==true){
 OutlinedTextField(body,{body=it.take(8000)},enabled=!busy&&pending==null,label={Text(tr("Compte rendu manuel (pas une transcription IA)","Manual minutes (not an AI transcript)"))},modifier=Modifier.fillMaxWidth(),minLines=5)
 Button(enabled=!busy&&body.isNotBlank(),onClick={work{val id=current.getString("room_id");val data=pending?:JSONObject().put("room_id",id).put("version_id",UUID.randomUUID().toString()).put("expected_version",p.getInt("latest_version")).put("body",body.trim()).also{pending=it};val saved=req("draft",data);pending=null;loadVersion(id,saved.getString("version_id"))}}){Text(tr("Enregistrer une nouvelle version","Save new version"))}
 if(v!=null&&v.isNull("approved_at"))Button(enabled=!busy&&body==v.optString("body")&&pending==null,onClick={mutate("approve")}){Text(tr("Valider cette version exacte","Approve this exact version"))}
 if(v!=null&&!v.isNull("approved_at")&&v.isNull("published_at")){
 Text(tr("Destinataires autorisés","Authorized recipients"))
 for(m in minuteRows(p.optJSONArray("recipients"))){val id=m.getString("member_id");Row{Checkbox(id in recipients,{checked->recipients=if(checked)recipients+id else recipients-id},enabled=!busy);Text(m.optString("display_name"),Modifier.padding(top=12.dp))}}
 Button(enabled=!busy&&recipients.isNotEmpty()&&body==v.optString("body")&&pending==null,onClick={mutate("publish")}){Text(tr("Publier aux destinataires choisis","Publish to selected recipients"))}
 }
 if(v!=null)TextButton(enabled=!busy,onClick={revokeConfirm=true}){Text(tr("Révoquer","Revoke"))}
 }else if(v!=null)Text(v.getString("body"))else Text(tr("Aucun compte rendu publié.","No published minutes."))
 }
 if(revokeConfirm)AlertDialog(onDismissRequest={revokeConfirm=false},title={Text(tr("Révoquer cette version ?","Revoke this version?"))},confirmButton={TextButton(onClick={revokeConfirm=false;mutate("revoke")}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={revokeConfirm=false}){Text(tr("Retour","Back"))}})
 }}
}
