package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId
internal data class PortalPage(val id:String,val fr:String,val en:String,val manager:Boolean)
internal val portalPages=listOf(PortalPage("profile","Profil","Profile",false),PortalPage("tickets","Support professionnel","Professional support",false),PortalPage("notifications","Notifications","Notifications",false),PortalPage("team","Équipe","Team",true),PortalPage("planning","Plannings","Schedules",false),PortalPage("objectives","Objectifs","Objectives",false),PortalPage("training","Formation","Training",false),PortalPage("incidents","Feedback interne","Internal feedback",false),PortalPage("intelligence","ZIPPLE Intelligence","ZIPPLE Intelligence",true))
@Composable private fun PortalSelect(label:String,options:List<Pair<String,String>>,value:String,enabled:Boolean,change:(String)->Unit){
 var open by remember{mutableStateOf(false)}
 Box{OutlinedButton(enabled=enabled&&options.isNotEmpty(),onClick={open=true}){Text(label+" : "+(options.find{it.first==value}?.second?:"—"))}
 DropdownMenu(expanded=open,onDismissRequest={open=false}){options.forEach{(id,name)->DropdownMenuItem(text={Text(name)},onClick={change(id);open=false})}}}
}
@Composable internal fun ZipplePortalWorkspace(api:ZippleBusiness,session:Session,site:String,en:Boolean,page:String){
 val t:(String,String)->String={fr,eng->if(en)eng else fr}
 val spec=portalPages.first{it.id==page};val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
 var data by remember{mutableStateOf<JSONObject?>(null)};var values by remember{mutableStateOf<Map<String,String>>(emptyMap())}
 var selected by remember{mutableStateOf("")};var reply by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 val manage=data?.optBoolean("can_manage")==true;val allowed=session.permits(site)&&!busy
 fun v(k:String)=values[k].orEmpty()
 fun set(k:String,x:String){values=values+(k to x)}
 suspend fun load(){val d=api.call(session,site,"workspace_snapshot",JSONObject().put("page",page)) as? JSONObject?:error("DATA");data=d;if(page=="profile"){val p=d.getJSONObject("profile");values=mapOf("display_name" to p.optString("display_name"),"phone" to p.optString("phone"),"language" to p.optString("language"))}}
 fun run(block:suspend()->Unit){if(!allowed)return;busy=true;msg="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 fun write(operation:String,payload:JSONObject){run{val body=JSONObject().put("operation",operation).put("payload",payload);val out=api.call(session,site,"workspace_write",keys.apply(operation,body)) as? JSONObject?:error("UNCONFIRMED");require(out.optBoolean("confirmed"));keys.confirmed(operation);if(operation=="work_create")values=emptyMap();if(operation=="work_reply")reply="";load();msg=t("Opération enregistrée","Operation saved")}}
 LaunchedEffect(session.member,site,page){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Données indisponibles","Data unavailable")}}
 val rows=data?.rows("rows").orEmpty();val members=data?.rows("members").orEmpty();val options=members.map{it.optString("id") to it.optString("label")}
 val kind=mapOf("tickets" to "ticket","planning" to "shift","objectives" to "objective","training" to "training","incidents" to "incident")[page]
 val row=rows.find{it.optString("id")==selected}
 fun date(k:String):String?=v(k).takeIf{it.isNotBlank()}?.let{LocalDateTime.parse(it).atZone(ZoneId.of("Africa/Douala")).toInstant().toString()}
 fun state(s:String)=when(s){"open"->t("Ouvert","Open");"in_progress"->t("En cours","In progress");"done"->t("Terminé","Done");"cancelled"->t("Annulé","Cancelled");else->s}
 Text(if(en)spec.en else spec.fr,style=MaterialTheme.typography.titleLarge)
 OutlinedButton(enabled=allowed,onClick={run{load()}}){Text(t("Actualiser cet espace","Refresh workspace"))}
 if(msg.isNotBlank())Text(msg)
 if(data==null)return
 when(page){
 "profile"->{val p=data!!.getJSONObject("profile");Text(p.optString("organization")+" · "+p.optString("site")+" · "+p.optString("role"))
 OutlinedTextField(v("display_name"),{set("display_name",it.take(120))},label={Text(t("Nom affiché","Display name"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 OutlinedTextField(v("phone"),{set("phone",it.take(15))},label={Text(t("Téléphone professionnel","Work phone"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 PortalSelect(t("Langue préférée","Preferred language"),listOf("fr" to "Français","en" to "English"),v("language"),allowed){set("language",it)}
 Button(enabled=allowed&&v("display_name").isNotBlank(),onClick={write("profile_save",JSONObject().put("display_name",v("display_name")).put("phone",v("phone")).put("language",v("language")))}){Text(t("Enregistrer le profil","Save profile"))}}
 "team"->{rows.forEach{x->Text(x.optString("label")+" · "+x.optString("role_code")+" · "+x.optString("job_title"));Text(x.optString("skills"));OutlinedButton(enabled=allowed,onClick={values=mapOf("member_id" to x.optString("id"),"job_title" to x.optString("job_title"),"skills" to x.optString("skills"))}){Text(t("Modifier le dossier","Edit record"))}}
 PortalSelect(t("Employé","Employee"),options,v("member_id"),allowed){set("member_id",it)}
 OutlinedTextField(v("job_title"),{set("job_title",it.take(120))},label={Text(t("Poste occupé","Job title"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 OutlinedTextField(v("skills"),{set("skills",it.take(500))},label={Text(t("Compétences","Skills"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 Button(enabled=allowed&&manage&&v("member_id").isNotBlank()&&v("job_title").isNotBlank(),onClick={write("team_save",JSONObject().put("member_id",v("member_id")).put("job_title",v("job_title")).put("skills",v("skills")))}){Text(t("Enregistrer le dossier","Save record"))}}
 "notifications"->{if(rows.isEmpty())Text(t("Aucune notification.","No notifications."));rows.forEach{x->Text(x.optString("label")+" · "+if(x.optBoolean("is_read"))t("Lu","Read")else t("Nouveau","New"));OutlinedButton(enabled=allowed&&!x.optBoolean("is_read"),onClick={write("inbox_read",JSONObject().put("event_key",x.optString("event_key")))}){Text(t("Marquer comme lu","Mark as read"))}}}
 "intelligence"->{Text(t("Analyse explicable, sans assistant génératif connecté.","Explainable analytics, no connected generative assistant."));data?.optJSONObject("metrics")?.let{x->listOf("recorded_xaf" to t("Ventes FCFA","Sales XAF"),"expenses_xaf" to t("Dépenses FCFA","Expenses XAF"),"current_low_stock" to t("Stocks au seuil","Low stocks"),"current_late_orders" to t("Commandes en retard","Late orders"),"uncosted_receipts" to t("Coûts manquants","Missing costs"),"absolute_cash_variance_xaf" to t("Écarts de caisse FCFA","Cash variance XAF")).forEach{(k,l)->Text(l+" : "+x.optString(k))};Text(x.optString("start")+" — "+x.optString("end"))}}
 else->if(kind!=null){
 if(page=="tickets"){Text(t("FAQ : récupération du compte, validation du stock et des reçus. Les tickets sont traités dans votre établissement, pas par un agent ZIPPLE externe.","FAQ: account recovery, stock validation and receipts. Tickets are handled within your establishment, not by an external ZIPPLE agent."))}
 if(manage||page=="tickets"){
 OutlinedTextField(v("title"),{set("title",it.take(160))},label={Text(t("Intitulé","Title"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 OutlinedTextField(v("detail"),{set("detail",it.take(1000))},label={Text(t("Description","Description"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 OutlinedTextField(v("category"),{set("category",it.take(80))},label={Text(t("Catégorie","Category"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 PortalSelect(t("Priorité","Priority"),listOf("normal" to t("Normale","Normal"),"urgent" to t("Urgente","Urgent")),v("priority").ifBlank{"normal"},allowed){set("priority",it)}
 if(manage)PortalSelect(t("Employé affecté","Assigned employee"),options,v("assignee_id"),allowed){set("assignee_id",it)}
 if(page=="planning")OutlinedTextField(v("starts_at"),{set("starts_at",it)},label={Text(t("Début AAAA-MM-JJTHH:MM (Douala)","Start YYYY-MM-DDTHH:MM (Douala)"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 if(page!="tickets")OutlinedTextField(v("due_at"),{set("due_at",it)},label={Text(t("Échéance AAAA-MM-JJTHH:MM (Douala)","Due YYYY-MM-DDTHH:MM (Douala)"))},modifier=Modifier.fillMaxWidth(),enabled=allowed)
 val datesOk=runCatching{(page=="tickets"||date("due_at")!=null)&&(page!="planning"||date("starts_at")!=null)}.getOrDefault(false)
 Button(enabled=allowed&&v("title").isNotBlank()&&v("detail").isNotBlank()&&v("category").isNotBlank()&&datesOk&&(page=="tickets"||v("assignee_id").isNotBlank()),onClick={write("work_create",JSONObject().put("kind",kind).put("title",v("title")).put("detail",v("detail")).put("category",v("category")).put("priority",v("priority").ifBlank{"normal"}).put("assignee_id",v("assignee_id").ifBlank{null}).put("starts_at",date("starts_at")).put("due_at",date("due_at")))}){Text(t("Créer","Create"))}
 }
 Text(t("Historique","History"));rows.forEach{x->Text(x.optString("title")+" · "+state(x.optString("state")));Text(x.optString("detail")+" · "+x.optString("assignee"));OutlinedButton(enabled=allowed,onClick={selected=x.optString("id");reply=""}){Text(t("Ouvrir le dossier","Open record"))}}
 if(row!=null){Text(row.optString("title"));row.rows("messages").forEach{Text(it.optString("author")+" · "+it.optString("body"))}
 val st=row.optString("state");if(st in listOf("open","in_progress")){OutlinedTextField(reply,{reply=it.take(1000)},label={Text(t("Message ou observation","Message or note"))},modifier=Modifier.fillMaxWidth(),enabled=allowed);Button(enabled=allowed&&reply.isNotBlank(),onClick={write("work_reply",JSONObject().put("work_id",selected).put("body",reply))}){Text(t("Envoyer","Send"))}
 if(manage)for(next in if(st=="open")listOf("in_progress","cancelled") else listOf("done","cancelled"))OutlinedButton(enabled=allowed,onClick={write("work_state",JSONObject().put("work_id",selected).put("expected_state",st).put("state",next))}){Text(state(next))}
 }}
 }
 }
}
