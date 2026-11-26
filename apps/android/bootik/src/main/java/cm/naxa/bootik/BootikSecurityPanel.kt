package cm.naxa.bootik
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
@Composable fun BootikSecurityPanel(api:BootikApi,session:BootikSession,site:String){
 val scope=rememberCoroutineScope();val promoter=session.role=="promoteur"
 var sessions by remember{mutableStateOf<List<JSONObject>>(emptyList())};var siteDevices by remember{mutableStateOf<List<JSONObject>>(emptyList())};var siteLimit by remember{mutableStateOf("2")};var offlineMinutes by remember{mutableStateOf("15")};var members by remember{mutableStateOf<List<JSONObject>>(emptyList())};var memberRequests by remember{mutableStateOf<List<JSONObject>>(emptyList())};var resources by remember{mutableStateOf<List<JSONObject>>(emptyList())};var resourceKind by remember{mutableStateOf("register")};var resourceIds by remember{mutableStateOf<Set<String>>(emptySet())};var createKind by remember{mutableStateOf("workstation")};var resourceActivity by remember{mutableStateOf("")};var resourceCode by remember{mutableStateOf("")};var resourceLabel by remember{mutableStateOf("")};var linkRegister by remember{mutableStateOf("")};var linkStation by remember{mutableStateOf("")};var newMember by remember{mutableStateOf("")};var newActs by remember{mutableStateOf<Set<String>>(emptySet())};var acts by remember{mutableStateOf<List<JSONObject>>(emptyList())};var events by remember{mutableStateOf<List<JSONObject>>(emptyList())};var recoveries by remember{mutableStateOf<List<JSONObject>>(emptyList())};var recovery by remember{mutableStateOf("")};var note by remember{mutableStateOf("")};var temporary by remember{mutableStateOf("")}
 var target by remember{mutableStateOf("")};var selected by remember{mutableStateOf<Set<String>>(emptySet())};var profile by remember{mutableStateOf("cashier")};var reason by remember{mutableStateOf("")};var limit by remember{mutableStateOf("2")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 var approvals by remember{mutableStateOf<List<JSONObject>>(emptyList())};var policies by remember{mutableStateOf<List<JSONObject>>(emptyList())};var approvalActivity by remember{mutableStateOf("")};var approvalKind by remember{mutableStateOf("purchase-pay")};var threshold by remember{mutableStateOf("")}
 val pending=remember{mutableMapOf<String,Pair<String,String>>()}
 fun rows(a:JSONArray)=(0 until a.length()).map{a.getJSONObject(it)}
 suspend fun call(action:String,p:JSONObject)=api.operation(session,site,action,p)
 suspend fun loadApprovals(){val x=call("approval-state",JSONObject());approvals=rows(x.getJSONArray("requests"));policies=rows(x.getJSONArray("policies"))}
 suspend fun refresh(){val v=call("security-state",JSONObject());sessions=rows(v.getJSONArray("sessions"));limit=v.getString("max_sessions");siteDevices=rows(v.getJSONArray("site_devices"));siteLimit=v.getString("max_site_devices");offlineMinutes=v.getString("offline_minutes");if(promoter){members=rows(call("team",JSONObject()).getJSONArray("members"));acts=rows(call("activities",JSONObject()).getJSONArray("activities"));events=rows(call("security-audit",JSONObject()).getJSONArray("events"));recoveries=rows(call("recovery-list",JSONObject()).getJSONArray("requests"));memberRequests=rows(call("member-requests",JSONObject()).getJSONArray("requests"));resources=rows(call("resource-state",JSONObject()).getJSONArray("resources"))}}
 fun task(f:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{f()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération de sécurité non confirmée. Vérifiez vos droits."}finally{busy=false}}}
 suspend fun change(kind:String,p:JSONObject){p.put("kind",kind).put("reason",reason.trim());val fp=p.toString();val old=pending[kind];val id=if(old?.first==fp)old.second else UUID.randomUUID().toString().also{pending[kind]=fp to it};p.put("request_id",id);check(call("admin-action",p).length()>0);pending.remove(kind);message="Modification de sécurité confirmée.";try{refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){sessions=emptyList();members=emptyList();events=emptyList();message="Modification confirmée ; rechargez la liste."}}
 Text("Sessions et délégations",style=MaterialTheme.typography.titleMedium)
 Button(enabled=!busy,onClick={task{refresh()}}){Text("Actualiser la sécurité")}
 OutlinedTextField(reason,{reason=it},label={Text("Motif de sécurité")},enabled=!busy)
 sessions.forEach{x->Text((if(x.optBoolean("current"))"Session actuelle" else "Autre session")+" • "+x.getString("device_session_id").take(8));if(!x.optBoolean("current"))Button(enabled=!busy&&reason.trim().length>=3,onClick={task{change("session-revoke",JSONObject().put("device_session_id",x.getString("device_session_id")))}}){Text("Révoquer cette session")}}
 if(promoter){
 Text("Approbations financières")
 Button(enabled=!busy,onClick={task{acts=rows(call("activities",JSONObject()).getJSONArray("activities"));loadApprovals()}}){Text("Charger les approbations")}
 acts.forEach{x->Row{RadioButton(approvalActivity==x.getString("id"),{approvalActivity=x.getString("id")},enabled=!busy);Text(x.getString("display_name"))}}
 listOf("purchase-pay" to "Règlement fournisseur","cash-movement" to "Sortie ou dépense caisse").forEach{(k,n)->Row{RadioButton(approvalKind==k,{approvalKind=k},enabled=!busy);Text(n)}}
 OutlinedTextField(threshold,{threshold=it},label={Text("Seuil FCFA")},enabled=!busy)
 Button(enabled=!busy&&approvalActivity.isNotBlank()&&(threshold.toLongOrNull()?.let{it in 0..9007199254740991L}==true)&&reason.trim().length>=3,onClick={task{call("approval-admin",JSONObject().put("kind","policy").put("request_id",UUID.randomUUID().toString()).put("activity_id",approvalActivity).put("operation_kind",approvalKind).put("threshold_fcfa",threshold.toLong()).put("reason",reason.trim()));loadApprovals();message="Seuil confirmé."}}){Text("Enregistrer le seuil")}
 policies.forEach{x->Text(x.getString("kind")+" • "+x.getString("threshold_fcfa")+" FCFA")}
 approvals.forEach{x->Text(x.getString("kind")+" • "+x.getString("amount_fcfa")+" FCFA • "+x.getJSONObject("payload").toString());listOf("approved" to "Approuver","refused" to "Refuser").forEach{(d,n)->Button(enabled=!busy&&reason.trim().length>=3,onClick={task{call("approval-admin",JSONObject().put("kind","decide").put("request_id",UUID.randomUUID().toString()).put("approval_id",x.getString("id")).put("decision",d).put("reason",reason.trim()));loadApprovals();message="Décision enregistrée ; finalisation par le délégataire."}}){Text(n)}}}
 Text("Appareils du site")
 siteDevices.forEach{x->Text(x.optString("platform")+" • "+x.getString("installation_id").take(8)+" • "+x.getString("user_id").take(8));if(!x.optBoolean("current"))Button(enabled=!busy&&reason.trim().length>=3,onClick={task{change("session-revoke",JSONObject().put("device_session_id",x.getString("device_session_id")))}}){Text("Révoquer appareil du site")}}
 OutlinedTextField(siteLimit,{siteLimit=it},label={Text("Plafond d’appareils du site")},enabled=!busy)
 Button(enabled=!busy&&reason.trim().length>=3&&(siteLimit.toIntOrNull()?:0) in 1..50,onClick={task{change("site-device-limit",JSONObject().put("limit",siteLimit.toInt()))}}){Text("Enregistrer le plafond du site")}
 OutlinedTextField(offlineMinutes,{offlineMinutes=it},label={Text("Durée offline maximale (minutes)")},enabled=!busy)
 Button(enabled=!busy&&reason.trim().length>=3&&(offlineMinutes.toIntOrNull()?:0) in 1..15,onClick={task{change("offline-policy",JSONObject().put("minutes",offlineMinutes.toInt()))}}){Text("Enregistrer la politique offline")}
 Text("Appliquée au prochain login ou renouvellement.")
 OutlinedTextField(limit,{limit=it},label={Text("Plafond de sessions par membre")},enabled=!busy)
 Button(enabled=!busy&&reason.trim().length>=3&&(limit.toIntOrNull()?:0) in 1..50,onClick={task{change("session-limit",JSONObject().put("limit",limit.toInt()))}}){Text("Enregistrer le plafond")}
 Text("Employé à déléguer")
 members.filter{it.getString("user_id")!=session.member&&it.getString("role")!="promoteur"&&it.optBoolean("active")}.forEach{x->Row{RadioButton(target==x.getString("user_id"),{target=x.getString("user_id");selected=emptySet()},enabled=!busy);Text(x.getString("user_id").take(8)+" • "+x.optString("function_code",x.getString("role")))}}
 listOf("director" to "Directeur","site_manager" to "Responsable site","stock_manager" to "Stock","buyer" to "Achats","cashier" to "Caissier","accountant" to "Comptable","auditor" to "Auditeur","delivery" to "Livreur","territory_manager" to "Territoire","sales" to "Commercial","picker" to "Préparateur","collection" to "Recouvrement","crm" to "CRM").forEach{(k,n)->Row{RadioButton(profile==k,{profile=k},enabled=!busy);Text(n)}}
 Button(enabled=!busy&&target.isNotBlank()&&reason.trim().length>=3,onClick={task{change("member-role",JSONObject().put("member_id",target).put("function_code",profile))}}){Text("Attribuer la fonction")}
 Text("Activités autorisées (liste vide = aucun accès métier)")
 acts.forEach{x->val id=x.getString("id");Row{Checkbox(id in selected,{selected=if(it)selected+id else selected-id},enabled=!busy&&target.isNotBlank());Text(x.getString("display_name"))}}
 Button(enabled=!busy&&target.isNotBlank()&&reason.trim().length>=3,onClick={task{change("member-scope",JSONObject().put("member_id",target).put("activities",JSONArray(selected.toList())))}}){Text("Enregistrer les activités autorisées")}
 Button(enabled=!busy&&target.isNotBlank()&&reason.trim().length>=3,onClick={task{change("member-disable",JSONObject().put("member_id",target))}}){Text("Désactiver le compte")}
 Text("Postes, caisses, zones et territoires")
 Text("Une affectation restreint les droits existants. Les territoires n'ouvrent pas les opérations B2B avant B05.")
 acts.forEach{x->Row{RadioButton(resourceActivity==x.getString("id"),{resourceActivity=x.getString("id")},enabled=!busy);Text(x.getString("display_name"))}}
 listOf("workstation" to "Poste","territory" to "Territoire").forEach{(k,label)->Row{RadioButton(createKind==k,{createKind=k},enabled=!busy);Text(label)}}
 OutlinedTextField(resourceCode,{resourceCode=it},label={Text("Code ressource")},enabled=!busy);OutlinedTextField(resourceLabel,{resourceLabel=it},label={Text("Libellé ressource")},enabled=!busy)
 suspend fun resourceAction(kind:String,p:JSONObject){p.put("kind",kind).put("reason",reason).put("request_id",UUID.randomUUID().toString());check(call("resource-admin",p).length()>0);message="Ressource confirmée.";resources=rows(call("resource-state",JSONObject()).getJSONArray("resources"))}
 Button(enabled=!busy&&resourceActivity.isNotBlank()&&resourceCode.isNotBlank()&&resourceLabel.trim().length>=2&&reason.trim().length>=3,onClick={task{resourceAction(createKind,JSONObject().put("activity_id",resourceActivity).put("code",resourceCode).put("label",resourceLabel));resourceCode="";resourceLabel=""}}){Text("Créer la ressource")}
 Text("Caisse à lier");resources.filter{it.getString("kind")=="register"}.forEach{x->Row{RadioButton(linkRegister==x.getString("id"),{linkRegister=x.getString("id")},enabled=!busy);Text(x.getString("label"))}}
 Text("Poste de caisse");resources.filter{it.getString("kind")=="workstation"}.forEach{x->Row{RadioButton(linkStation==x.getString("id"),{linkStation=x.getString("id")},enabled=!busy);Text(x.getString("label"))}}
 Button(enabled=!busy&&linkRegister.isNotBlank()&&linkStation.isNotBlank()&&reason.trim().length>=3,onClick={task{resourceAction("link-register",JSONObject().put("register_id",linkRegister).put("workstation_id",linkStation))}}){Text("Lier la caisse au poste")}
 listOf("register" to "Caisse","workstation" to "Poste","storage" to "Zone de stock","territory" to "Territoire").forEach{(k,label)->Row{RadioButton(resourceKind==k,{resourceKind=k;resourceIds=emptySet()},enabled=!busy);Text(label)}}
 resources.filter{it.getString("kind")==resourceKind}.forEach{x->val id=x.getString("id");Row{Checkbox(id in resourceIds,{resourceIds=if(it)resourceIds+id else resourceIds-id},enabled=!busy&&target.isNotBlank());Text(x.getString("label"))}}
 Button(enabled=!busy&&target.isNotBlank()&&reason.trim().length>=3,onClick={task{resourceAction("assign",JSONObject().put("member_id",target).put("resource_kind",resourceKind).put("resources",JSONArray(resourceIds.sorted())));message="Affectation confirmée. Sessions de l’employé révoquées."}}){Text("Enregistrer le périmètre ressource")}
 Text("Demande de compte employé");Text("La demande n'accorde aucun accès avant traitement central.")
 OutlinedTextField(newMember,{newMember=it},label={Text("Nom de l'employé à créer")},enabled=!busy)
 Text("Fonction sélectionnée : "+profile)
 acts.forEach{x->val id=x.getString("id");Row{Checkbox(id in newActs,{newActs=if(it)newActs+id else newActs-id},enabled=!busy);Text(x.getString("display_name"))}}
 Button(enabled=!busy&&newMember.trim().length>=2&&newActs.isNotEmpty()&&reason.trim().length>=3,onClick={task{val p=JSONObject().put("name",newMember.trim()).put("function_code",profile).put("activities",JSONArray(newActs.sorted())).put("reason",reason.trim());val fp=p.toString();val old=pending["provision"];val id=if(old?.first==fp)old.second else UUID.randomUUID().toString().also{pending["provision"]=fp to it};p.put("request_id",id);check(call("member-request",p).getString("request_id")==id);pending.remove("provision");newMember="";newActs=emptySet();message="Demande enregistrée, en attente de l’administration centrale.";memberRequests=rows(call("member-requests",JSONObject()).getJSONArray("requests"))}}){Text("Demander la création du compte")}
 memberRequests.forEach{x->Text(x.getString("display_name")+" • "+x.getString("function_code")+" • "+x.getString("state"))}
 Text("Récupération interne");Text("Vérifiez l’identité en personne. Le secret provisoire n’est affiché qu’une fois.")
 recoveries.forEach{x->Row{RadioButton(recovery==x.getString("id"),{recovery=x.getString("id");temporary=""},enabled=!busy);Text(x.getString("identifier"))}}
 OutlinedTextField(note,{note=it},label={Text("Preuve de vérification interne")},enabled=!busy)
 Button(enabled=!busy&&recovery.isNotBlank()&&note.trim().length>=10,onClick={task{temporary="";val v=call("recovery-complete",JSONObject().put("recovery_id",recovery).put("method","in_person").put("note",note.trim()));if(v.getBoolean("completed")){temporary=v.getString("temporary_password");message="Récupération confirmée."}else message="Demande déjà traitée.";recovery="";note="";try{refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){recoveries=emptyList()}}}){Text("Confirmer la récupération vérifiée")}
 if(temporary.isNotBlank()){Text("Mot de passe temporaire : "+temporary);TextButton(onClick={temporary=""}){Text("Masquer définitivement le secret")}}
 Text("Journal de sécurité");events.take(30).forEach{Text(it.getString("action")+" • "+it.getString("created_at"))}
 };Text(message)
}
