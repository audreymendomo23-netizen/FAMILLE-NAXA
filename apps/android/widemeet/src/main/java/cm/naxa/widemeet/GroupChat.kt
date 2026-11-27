package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
private fun groupRows(x:JSONObject):List<JSONObject>{val a=x.getJSONArray("items");return (0 until a.length()).map{a.getJSONObject(it)}}
@Composable fun GroupChat(english:Boolean,gateway:AuthGateway,session:Session,onBack:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var groups by remember{mutableStateOf<List<JSONObject>>(emptyList())};var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var members by remember{mutableStateOf<List<JSONObject>>(emptyList())};var messages by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var rename by remember{mutableStateOf("")};var group by remember{mutableStateOf<JSONObject?>(null)};var name by remember{mutableStateOf("")};var selected by remember{mutableStateOf<Set<String>>(emptySet())};var query by remember{mutableStateOf("")};var body by remember{mutableStateOf("")}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var pending by remember{mutableStateOf<JSONObject?>(null)};var creation by remember{mutableStateOf<JSONObject?>(null)}
 suspend fun req(a:String,d:JSONObject=JSONObject())=gateway.identity(session,"group-chat-"+a,d)
 suspend fun load(){groups=groupRows(req("list"));contacts=groupRows(gateway.identity(session,"center-contacts"))}
 suspend fun thread(id:String,q:String=""){try{val next=groupRows(req("thread",JSONObject().put("group_id",id).put("query",q)));val nextMembers=groupRows(req("members",JSONObject().put("group_id",id)));messages=next;members=nextMembers}catch(e:CancellationException){throw e}catch(e:Exception){messages=emptyList();members=emptyList();throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 fun close(){group=null;members=emptyList();messages=emptyList();body="";query="";pending=null}
 LaunchedEffect(session.deviceId){work{load()}}
 LaunchedEffect(group?.optString("id"),query,busy,session.deviceId){val id=group?.optString("id")?:return@LaunchedEffect;if(busy)return@LaunchedEffect;while(true){delay(5000);if(busy)return@LaunchedEffect;try{thread(id,query)}catch(e:CancellationException){throw e}catch(e:Exception){error=true}}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 TextButton(onClick=onBack){Text(tr("Retour aux messages privés","Back to private messages"))}
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error)Text(tr("Accès ou action non confirmé.","Access or action unconfirmed."),color=MaterialTheme.colorScheme.error)
 val g=group
 if(g==null){
 Text(tr("Groupes de discussion","Group chats"),style=MaterialTheme.typography.titleMedium)
 TextButton(enabled=!busy,onClick={work{load()}}){Text(tr("Actualiser","Refresh"))}
 for(x in groups)TextButton(enabled=!busy,onClick={work{thread(x.getString("id"));group=x;query="";rename=x.getString("name")}}){Text(x.getString("name")+" · "+x.optInt("member_count"))}
 OutlinedTextField(name,{name=it.take(80)},enabled=!busy&&creation==null,label={Text(tr("Nom du groupe de discussion","Group chat name"))})
 Text(tr("Participants (2 à 49 contacts)","Participants (2 to 49 contacts)"))
 for(c in contacts){val id=c.getString("member_id");Row{Checkbox(checked=id in selected,enabled=!busy&&creation==null,onCheckedChange={checked->selected=if(checked)selected+id else selected-id});Text(c.getString("display_name"))}}
 Button(enabled=!busy&&name.isNotBlank()&&selected.size in 2..49,onClick={work{val p=creation?:JSONObject().put("group_id",UUID.randomUUID().toString()).put("name",name.trim()).put("member_ids",JSONArray(selected.toList())).also{creation=it};req("create",p);creation=null;name="";selected=emptySet();load()}}){Text(tr("Créer le groupe de discussion","Create group chat"))}
 }else{
 val id=g.getString("id")
 TextButton(enabled=!busy,onClick={work{close();load()}}){Text(tr("Retour aux groupes","Back to groups"))}
 Text(g.getString("name"),style=MaterialTheme.typography.titleMedium)
 if(g.optString("creator_id")==session.memberId){
 OutlinedTextField(rename,{rename=it.take(80)},enabled=!busy,label={Text(tr("Nouveau nom","New name"))})
 TextButton(enabled=!busy&&rename.isNotBlank(),onClick={work{val v=req("rename",JSONObject().put("group_id",id).put("name",rename.trim()));group=JSONObject(g.toString()).put("name",v.getString("name"));load()}}){Text(tr("Renommer","Rename"))}
 Text(tr("Ajouter un participant","Add participant"))
 for(c in contacts.filter{x->members.none{it.optString("member_id")==x.optString("member_id")}})TextButton(enabled=!busy,onClick={work{req("add",JSONObject().put("group_id",id).put("member_id",c.getString("member_id")));thread(id,query)}}){Text(tr("Ajouter ","Add ")+c.getString("display_name"))}
 }
 Text(tr("Participants actifs","Active participants"))
 var removeTarget by remember(id){mutableStateOf<String?>(null)}
 for(m in members){Text(m.getString("display_name"));if(g.optString("creator_id")==session.memberId&&m.getString("member_id")!=session.memberId)TextButton(enabled=!busy,onClick={removeTarget=m.getString("member_id")}){Text(tr("Retirer","Remove"))}}
 TextButton(enabled=!busy,onClick={removeTarget=session.memberId}){Text(tr("Quitter le groupe","Leave group"))}
 removeTarget?.let{target->AlertDialog(onDismissRequest={removeTarget=null},title={Text(tr("Confirmer le retrait ?","Confirm removal?"))},confirmButton={TextButton(onClick={removeTarget=null;work{req("remove",JSONObject().put("group_id",id).put("member_id",target));if(target==session.memberId){close();load()}else thread(id,query)}}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={removeTarget=null}){Text(tr("Annuler","Cancel"))}})}
 OutlinedTextField(query,{query=it.take(100)},label={Text(tr("Rechercher dans le groupe","Search group"))})
 TextButton(enabled=!busy,onClick={work{thread(id,query)}}){Text(tr("Rechercher","Search"))}
 for(m in messages){Text(m.getString("display_name"),style=MaterialTheme.typography.labelLarge);Text(m.getString("body"));Text(m.optString("created_at"));if(m.getString("sender_id")!=session.memberId&&m.isNull("read_at"))TextButton(enabled=!busy,onClick={work{req("seen",JSONObject().put("group_id",id).put("message_id",m.getString("id")));thread(id,query)}}){Text(tr("Marquer comme lu","Mark seen"))}}
 OutlinedTextField(body,{body=it.take(2000)},enabled=!busy&&pending==null,label={Text(tr("Message de groupe","Group message"))})
 Button(enabled=!busy&&body.isNotBlank(),onClick={work{val p=pending?:JSONObject().put("group_id",id).put("message_id",UUID.randomUUID().toString()).put("body",body.trim()).also{pending=it};req("send",p);pending=null;body="";query="";thread(id)}}){Text(tr("Envoyer au groupe","Send to group"))}
 }
 }}
}
