package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import org.json.JSONArray

private fun entries(a:JSONArray?):List<JSONObject> = if(a==null)emptyList() else (0 until a.length()).mapNotNull{a.optJSONObject(it)}
@Composable fun IdentityPanel(english:Boolean,gateway:AuthGateway,session:Session,mode:String,onLocale:(Boolean)->Unit={}){
 fun tr(fr:String,en:String)=if(english)en else fr
 fun roleLabel(role:String)=when(role){"owner"->tr("Propriétaire","Owner");"promoteur"->tr("Promoteur","Promoter");"manager"->tr("Responsable","Manager");else->tr("Collaborateur","Staff")}
 var profile by remember{mutableStateOf<JSONObject?>(null)}
 var billing by remember{mutableStateOf<JSONObject?>(null)}
 var dashboard by remember{mutableStateOf<JSONObject?>(null)}
 var contacts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var invitations by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var name by remember{mutableStateOf("")};var language by remember{mutableStateOf(if(english)"en" else "fr")}
 var identifier by remember{mutableStateOf("")};var inviteManager by remember{mutableStateOf(false)}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var notice by remember{mutableStateOf("")}
 var revokeTarget by remember{mutableStateOf<String?>(null)}
 val scope=rememberCoroutineScope()
 suspend fun load(){
 val p=gateway.identity(session,"profile");profile=p;name=p.getString("display_name");language=p.getString("locale")
 if(mode in setOf("contacts","company","team"))contacts=entries(gateway.identity(session,"contacts").optJSONArray("contacts"))
 if(mode in setOf("profile","company","team"))invitations=entries(gateway.identity(session,"invitations").optJSONArray("invitations"))
 if(mode=="dashboard")dashboard=gateway.identity(session,"dashboard")
 if(mode=="billing")billing=gateway.identity(session,"billing")
 }
 LaunchedEffect(session.deviceId,mode){busy=true;error=false;try{load()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 fun mutate(action:String,data:JSONObject,message:String){
 if(busy)return;busy=true;error=false;notice=""
 val selectedLanguage=language
 scope.launch{try{gateway.identity(session,action,data);load();notice=message;if(action=="profile-update")onLocale(selectedLanguage=="en")}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 }
 val p=profile
 val owner=p?.optString("role")=="promoteur"
 val manager=p?.optString("workspace_kind")=="enterprise"&&(p.optString("role") in setOf("promoteur","manager"))
 val lessons=listOf(tr("Retrouvez votre prochaine réunion et vos raccourcis.","Find your next meeting and shortcuts."),tr("Consultez vos invitations et programmez vos réunions selon vos droits.","View invitations and schedule meetings according to your permissions."),tr("Échangez avec les participants pendant vos réunions.","Communicate with participants during meetings."),tr("Consultez les contenus autorisés lorsqu’ils sont disponibles.","View authorized content when available."),tr("Gérez vos informations, vos espaces et votre sécurité.","Manage your details, workspaces and security."))
 val titles=listOf(tr("Accueil","Home"),tr("Agenda","Calendar"),"Chat","Archives",tr("Profil","Profile"))
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Action non confirmée. Réessayez.","Action not confirmed. Try again."),color=MaterialTheme.colorScheme.error)
 if(notice.isNotEmpty())Text(notice)
 if(mode=="dashboard")dashboard?.let{d->Text(tr("Bonjour","Good day")+" "+d.optString("display_name"),style=MaterialTheme.typography.titleLarge);Text(roleLabel(d.optString("role")));Text(tr("Réunions à venir","Upcoming meetings")+": "+d.optInt("upcoming_count"));Text(tr("Réunions ouvertes","Open meetings")+": "+d.optInt("active_count"));Text(d.optJSONObject("next_meeting")?.optString("title")?:tr("Aucune prochaine réunion","No upcoming meeting"));if(!d.optBoolean("subscription_active"))Text(tr("Aucun abonnement actif","No active subscription"))}
 if(mode=="profile"&&p!=null){Text(p.getString("login_id"));Text(p.getString("workspace_name")+" · "+roleLabel(p.getString("role")));OutlinedTextField(name,{name=it.take(120)},label={Text(tr("Nom affiché","Display name"))},modifier=Modifier.fillMaxWidth());Row{RadioButton(language=="fr",{language="fr"});Text("Français",Modifier.padding(top=12.dp));RadioButton(language=="en",{language="en"});Text("English",Modifier.padding(top=12.dp))};Button(enabled=!busy&&name.isNotBlank(),onClick={mutate("profile-update",JSONObject().put("display_name",name).put("locale",language),tr("Profil enregistré","Profile saved"))}){Text(tr("Enregistrer","Save"))}}
 if(mode in setOf("profile","dashboard")&&p!=null){val step=p.optInt("onboarding_step").coerceIn(0,5);if(step<5){Text(tr("Découverte des cinq onglets","Discover the five tabs")+" — "+(step+1)+"/5",style=MaterialTheme.typography.titleMedium);Text(titles[step]);Text(lessons[step]);Button(enabled=!busy,onClick={mutate("onboarding-step",JSONObject().put("step",step+1),tr("Progression enregistrée","Progress saved"))}){Text(if(step==4)tr("Terminer","Finish")else tr("Suivant","Next"))}}}
 if(mode in setOf("contacts","company","team")){Text(tr("Contacts","Contacts"),style=MaterialTheme.typography.titleLarge);if(contacts.isEmpty()&&!busy)Text(tr("Aucun contact dans cet espace","No contacts in this workspace"));contacts.forEach{c->val id=c.getString("member_id");Text(c.getString("display_name")+" · "+roleLabel(c.getString("role")));TextButton(enabled=!busy,onClick={mutate("favorite",JSONObject().put("member_id",id).put("enabled",!c.optBoolean("favorite")),tr("Favoris actualisés","Favorites updated"))}){Text(if(c.optBoolean("favorite"))tr("Retirer des favoris","Remove favorite")else tr("Ajouter aux favoris","Add favorite"))};if(owner&&mode!="contacts"&&c.getString("role") in setOf("manager","staff")){TextButton(enabled=!busy,onClick={mutate("member-role",JSONObject().put("member_id",id).put("role",if(c.getString("role")=="manager")"staff" else "manager"),tr("Rôle actualisé","Role updated"))}){Text(if(c.getString("role")=="staff")tr("Nommer responsable","Appoint manager")else tr("Rétablir collaborateur","Set staff"))};TextButton(enabled=!busy,onClick={revokeTarget=id}){Text(tr("Retirer le membre","Remove member"))}}}}
 if(mode in setOf("company","team")&&manager){Text(tr("Inviter un collaborateur","Invite a colleague"));OutlinedTextField(identifier,{identifier=it.take(27)},label={Text(tr("Identifiant WideMeet","WideMeet ID"))},modifier=Modifier.fillMaxWidth());if(owner)Row{Checkbox(inviteManager,{inviteManager=it});Text(tr("Responsable","Manager"),Modifier.padding(top=12.dp))};Button(enabled=!busy&&Regex("^WM-[A-Z0-9]{8,24}$").matches(identifier.trim().uppercase()),onClick={mutate("invite",JSONObject().put("login_id",identifier.trim().uppercase()).put("role",if(owner&&inviteManager)"manager" else "staff"),tr("Demande d’invitation prise en compte","Invitation request received"))}){Text(tr("Inviter","Invite"))}}
 if(mode in setOf("profile","company","team")){Text(tr("Invitations reçues","Received invitations"));invitations.forEach{i->Text(i.getString("workspace_name")+" · "+roleLabel(i.getString("role")));Row{TextButton(enabled=!busy,onClick={mutate("respond-invite",JSONObject().put("id",i.getString("id")).put("accept",true),tr("Invitation acceptée. Reconnectez-vous pour accéder au nouvel espace.","Invitation accepted. Sign in again to access the new workspace."))}){Text(tr("Accepter","Accept"))};TextButton(enabled=!busy,onClick={mutate("respond-invite",JSONObject().put("id",i.getString("id")).put("accept",false),tr("Invitation refusée","Invitation declined"))}){Text(tr("Refuser","Decline"))}}}}
 if(mode=="billing")billing?.let{b->Text(tr("Abonnement","Subscription"),style=MaterialTheme.typography.titleLarge);Text(if(b.isNull("plan"))tr("Aucun abonnement actif","No active subscription")else b.optString("plan").uppercase());if(!b.isNull("valid_until"))Text(tr("Valable jusqu’au","Valid until")+" "+b.optString("valid_until").take(10));if(b.optString("kind")=="enterprise"){Text("Access : 5 000 FCFA/"+tr("mois","month")+" · 50 000 FCFA/"+tr("an","year"));Text("Premium : 10 000 FCFA/"+tr("mois","month")+" · 100 000 FCFA/"+tr("an","year"));Text(tr("Grande équipe : sur devis, maximum 20 000 FCFA/mois.","Large team: quote, maximum 20,000 FCFA/month."))}else{Text(tr("Pass Premium","Premium pass")+" : 1 000 FCFA (≤20), 3 000 FCFA (21–50), 5 000 FCFA (51–100)");Text(tr("Validité maximale de 24 heures, une réunion.","Maximum 24-hour validity, one meeting."))};Text(tr("Paiement en ligne momentanément indisponible.","Online payment currently unavailable."))}
 }}
 revokeTarget?.let{id->AlertDialog(onDismissRequest={revokeTarget=null},title={Text(tr("Retirer ce membre ?","Remove this member?"))},confirmButton={TextButton(onClick={revokeTarget=null;mutate("revoke-member",JSONObject().put("member_id",id),tr("Accès retiré","Access removed"))}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={revokeTarget=null}){Text(tr("Annuler","Cancel"))}})}
}
