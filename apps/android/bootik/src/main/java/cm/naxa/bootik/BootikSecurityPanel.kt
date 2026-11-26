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
 var sessions by remember{mutableStateOf<List<JSONObject>>(emptyList())};var members by remember{mutableStateOf<List<JSONObject>>(emptyList())};var acts by remember{mutableStateOf<List<JSONObject>>(emptyList())};var events by remember{mutableStateOf<List<JSONObject>>(emptyList())};var recoveries by remember{mutableStateOf<List<JSONObject>>(emptyList())};var recovery by remember{mutableStateOf("")};var note by remember{mutableStateOf("")};var temporary by remember{mutableStateOf("")}
 var target by remember{mutableStateOf("")};var selected by remember{mutableStateOf<Set<String>>(emptySet())};var profile by remember{mutableStateOf("cashier")};var reason by remember{mutableStateOf("")};var limit by remember{mutableStateOf("2")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 val pending=remember{mutableMapOf<String,Pair<String,String>>()}
 fun rows(a:JSONArray)=(0 until a.length()).map{a.getJSONObject(it)}
 suspend fun call(action:String,p:JSONObject)=api.operation(session,site,action,p)
 suspend fun refresh(){val v=call("security-state",JSONObject());sessions=rows(v.getJSONArray("sessions"));limit=v.getString("max_sessions");if(promoter){members=rows(call("team",JSONObject()).getJSONArray("members"));acts=rows(call("activities",JSONObject()).getJSONArray("activities"));events=rows(call("security-audit",JSONObject()).getJSONArray("events"));recoveries=rows(call("recovery-list",JSONObject()).getJSONArray("requests"))}}
 fun task(f:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{f()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération de sécurité non confirmée. Vérifiez vos droits."}finally{busy=false}}}
 suspend fun change(kind:String,p:JSONObject){p.put("kind",kind).put("reason",reason.trim());val fp=p.toString();val old=pending[kind];val id=if(old?.first==fp)old.second else UUID.randomUUID().toString().also{pending[kind]=fp to it};p.put("request_id",id);check(call("admin-action",p).length()>0);pending.remove(kind);message="Modification de sécurité confirmée.";try{refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){sessions=emptyList();members=emptyList();events=emptyList();message="Modification confirmée ; rechargez la liste."}}
 Text("Sessions et délégations",style=MaterialTheme.typography.titleMedium)
 Button(enabled=!busy,onClick={task{refresh()}}){Text("Actualiser la sécurité")}
 OutlinedTextField(reason,{reason=it},label={Text("Motif de sécurité")},enabled=!busy)
 sessions.forEach{x->Text((if(x.optBoolean("current"))"Session actuelle" else "Autre session")+" • "+x.getString("device_session_id").take(8));if(!x.optBoolean("current"))Button(enabled=!busy&&reason.trim().length>=3,onClick={task{change("session-revoke",JSONObject().put("device_session_id",x.getString("device_session_id")))}}){Text("Révoquer cette session")}}
 if(promoter){
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
 Text("Récupération interne");Text("Vérifiez l’identité en personne. Le secret provisoire n’est affiché qu’une fois.")
 recoveries.forEach{x->Row{RadioButton(recovery==x.getString("id"),{recovery=x.getString("id");temporary=""},enabled=!busy);Text(x.getString("identifier"))}}
 OutlinedTextField(note,{note=it},label={Text("Preuve de vérification interne")},enabled=!busy)
 Button(enabled=!busy&&recovery.isNotBlank()&&note.trim().length>=10,onClick={task{temporary="";val v=call("recovery-complete",JSONObject().put("recovery_id",recovery).put("method","in_person").put("note",note.trim()));if(v.getBoolean("completed")){temporary=v.getString("temporary_password");message="Récupération confirmée."}else message="Demande déjà traitée.";recovery="";note="";try{refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){recoveries=emptyList()}}}){Text("Confirmer la récupération vérifiée")}
 if(temporary.isNotBlank()){Text("Mot de passe temporaire : "+temporary);TextButton(onClick={temporary=""}){Text("Masquer définitivement le secret")}}
 Text("Journal de sécurité");events.take(30).forEach{Text(it.getString("action")+" • "+it.getString("created_at"))}
 };Text(message)
}
