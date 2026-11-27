package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
import java.time.LocalDate
internal fun bounds(period:String):Pair<String,String>{val d=LocalDate.parse(dayKey());val first=when(period){"semaine"->d.minusDays((d.dayOfWeek.value-1).toLong());"mois"->d.withDayOfMonth(1);"annee"->d.withDayOfYear(1);else->d};return first.toString() to d.toString()}
@Composable internal fun ConnectedGrillad(appearance:String,onAppearance:(String)->Unit){
 val api=remember{ConnectedApi(BuildConfig.GRILLAD_API_URL,BuildConfig.GRILLAD_PUBLIC_KEY)}
 val scope=rememberCoroutineScope();val installation=remember{UUID.randomUUID().toString()}
 var session by remember{mutableStateOf<JSONObject?>(null)};var site by remember{mutableStateOf<JSONObject?>(null)};var data by remember{mutableStateOf<JSONObject?>(null)}
 var pending by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 var phone by remember{mutableStateOf("")};var password by remember{mutableStateOf("")}
 var page by remember{mutableStateOf("Accueil")};var period by remember{mutableStateOf("jour")}
 var name by remember(page,site){mutableStateOf("")};var amount by remember(page,site){mutableStateOf("")};var cost by remember(page,site){mutableStateOf("")};var selected by remember(page,site){mutableStateOf("")};var family by remember(page){mutableStateOf(families.first())};var reason by remember(page,site){mutableStateOf("")}
 fun reset(){session=null;site=null;data=null;pending=null;password="";page="Accueil"}
 suspend fun call(body:JSONObject):Any{val s=session;return try{api.call(body,s?.optString("access"))}catch(e:GrilladApiError){if(e.status!=401||s==null||body.optString("action") in listOf("login","refresh","logout"))throw e;val next=api.call(obj("action" to "refresh","refresh" to s.optString("refresh"))) as JSONObject;session=next;api.call(body,next.optString("access"))}}
 fun run(action:suspend ()->Unit){if(busy)return;busy=true;msg="";scope.launch{try{action()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){msg=e.message?:"Opération refusée";if(e is GrilladApiError&&e.status in listOf(401,403)){data=null;if(e.status==401)reset()}}finally{busy=false}}}
 suspend fun load(s:JSONObject,p:String=period){data=null;val (from,to)=bounds(p);val snapshot=call(obj("action" to "snapshot","org" to s.optString("org"),"site" to s.optString("site"),"from" to from,"to" to to)) as JSONObject;val attendance=try{call(obj("action" to "attendance_status","org" to s.optString("org"),"site" to s.optString("site"))) as JSONObject}catch(e:GrilladApiError){if(e.status in listOf(401,403))throw e;null};snapshot.put("attendance",attendance?:JSONObject.NULL);data=snapshot}
 suspend fun submit(req:JSONObject){pending=req;try{call(req);pending=null;msg="Opération confirmée par le serveur";site?.let{load(it)}}catch(e:GrilladApiError){if(e.status in listOf(400,401,403))pending=null;throw e}}
 fun mutate(operation:String,payload:JSONObject){val s=site?:return;if(pending!=null){msg="Vérifier la requête en attente";return};run{submit(obj("action" to "mutate","org" to s.optString("org"),"site" to s.optString("site"),"event" to UUID.randomUUID().toString(),"operation" to operation,"payload" to payload))}}
 if(!validGrilladConfig(BuildConfig.GRILLAD_API_URL,BuildConfig.GRILLAD_PUBLIC_KEY)){Text("Configuration GRILLAD invalide. Aucun accès.");return}
 if(session==null){Column(Modifier.fillMaxSize().padding(24.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("GrillaD",style=MaterialTheme.typography.headlineLarge);Text("Connexion professionnelle");OutlinedTextField(phone,{phone=it},label={Text("Téléphone (+237…)")},modifier=Modifier.fillMaxWidth());OutlinedTextField(password,{password=it},label={Text("Mot de passe")},visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth());Button({run{val s=api.call(obj("action" to "login","phone" to phone,"password" to password,"installation" to installation,"platform" to "android")) as JSONObject;password="";val first=rows(s.optJSONArray("sites")).firstOrNull()?:error("Aucun point autorisé");session=s;site=first;load(first)}},enabled=!busy,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text("Se connecter")};TextButton({run{api.call(obj("action" to "recovery","phone" to phone));msg="Demande transmise au support"}},enabled=!busy){Text("Mot de passe oublié")};if(msg.isNotBlank())Text(msg)};return}
 val manager=site?.optString("role")!="seller";val groups=if(manager)linkedMapOf("Accueil" to listOf("Accueil"),"Vente" to listOf("Ventes","Préparations","Catalogue"),"Activité" to listOf("Caisse","Dépenses","Rapports","Prévisions","Point journalier"),"Plus" to listOf("Équipe","Notifications","Vidéosurveillance","ZIPPLE Connect","Abonnement","Profil"))else linkedMapOf("Accueil" to listOf("Accueil"),"Vente" to listOf("Ventes","Préparations"),"Plus" to listOf("Équipe","Notifications","Profil"))
 val group=groups.entries.firstOrNull{page in it.value}?.key?:"Accueil"
 Scaffold(bottomBar={NavigationBar{groups.forEach{(g,p)->NavigationBarItem(selected=group==g,onClick={page=p.first()},enabled=!busy,icon={Text(g.take(1))},label={Text(g)})}}}){insets->
 Column(Modifier.fillMaxSize().padding(insets).padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("GrillaD",style=MaterialTheme.typography.headlineMedium);TextButton({run{try{api.call(obj("action" to "logout"),session?.optString("access"))}finally{reset()}}},enabled=!busy){Text("Déconnexion")}}
  Row(Modifier.horizontalScroll(rememberScrollState())){rows(session?.optJSONArray("sites")).forEach{s->OutlinedButton({if(pending==null)run{site=s;page="Accueil";load(s)}},enabled=!busy&&pending==null){Text((if(s.optString("site")==site?.optString("site"))"✓ " else "")+s.optString("name"))}}}
  if(group!="Accueil")Row(Modifier.horizontalScroll(rememberScrollState())){groups.getValue(group).forEach{p->TextButton({page=p},enabled=!busy){Text(p)}}}
  Text(page,style=MaterialTheme.typography.headlineSmall);if(msg.isNotBlank())Text(msg)
  if(pending!=null){Text("Confirmation incertaine — aucune nouvelle opération.");Button({val req=pending; if(req!=null)run{submit(req)}},enabled=!busy){Text("Vérifier la même requête")}}
  TextButton({site?.let{s->run{load(s)}}},enabled=!busy&&pending==null){Text("Actualiser")}
  val d=data;val enabled=!busy&&pending==null&&d!=null
  if(d==null){Text("Pas de données confirmées.");return@Column}
  val items=rows(d.optJSONArray("items"));val f=d.optJSONObject("finance");val cash=d.optJSONObject("cash")
  Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)){
   Text("Actualisé : "+d.optString("generated_at"),style=MaterialTheme.typography.bodySmall)
   when(page){
    "Accueil","Rapports","Point journalier"->{if(f!=null){GrilladHero(f.optLong("ca"),d.optLong("target"));GrilladMetric("Ventes",f.optString("sales_count"),Modifier.fillMaxWidth());GrilladMetric("Dépenses",f.optString("charges")+" F",Modifier.fillMaxWidth());GrilladMetric("Résultat indicatif",if(f.isNull("cost"))"Non calculable" else (f.optLong("ca")-f.optLong("cost")-f.optLong("charges")).toString()+" F",Modifier.fillMaxWidth())};if(page=="Rapports")Row(Modifier.horizontalScroll(rememberScrollState())){listOf("jour","semaine","mois","annee").forEach{p->TextButton({period=p;site?.let{s->run{load(s,p)}}},enabled=enabled){Text(if(period==p)"✓ "+p else p)}}};if(page=="Accueil")Button({page="Ventes"},enabled=enabled,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text("Nouvelle vente")};if(page=="Point journalier")Text("Synthèse à la demande, non clôturée automatiquement.")}
    "Catalogue"->{OutlinedTextField(name,{name=it},label={Text("Nom de l’article")});Row(Modifier.horizontalScroll(rememberScrollState())){families.forEach{v->TextButton({family=v}){Text(if(family==v)"✓ "+v else v)}}};OutlinedTextField(amount,{amount=it},label={Text("Prix")});OutlinedTextField(cost,{cost=it},label={Text("Coût facultatif")});Button({mutate("add_item",obj("name" to name,"family" to family,"price" to amount.toLongOrNull(),"cost" to cost.toLongOrNull()))},enabled=enabled){Text("Ajouter l’article")};items.forEach{x->OutlinedButton({selected=x.optString("id")}){Text((if(selected==x.optString("id"))"✓ " else "")+x.optString("name")+" · "+x.optString("price")+" F")}};if(selected.isNotBlank()){OutlinedTextField(reason,{reason=it},label={Text("Motif de changement du prix")});Button({mutate("change_price",obj("item" to selected,"price" to amount.toLongOrNull(),"reason" to reason))},enabled=enabled){Text("Modifier le prix sélectionné")}}}
    "Ventes","Préparations"->{items.forEach{x->OutlinedButton({selected=x.optString("id")},modifier=Modifier.fillMaxWidth()){Text((if(selected==x.optString("id"))"✓ " else "")+x.optString("name")+" · "+x.optString("remaining")+" disponibles")}};OutlinedTextField(amount,{amount=it},label={Text("Quantité")});Button({mutate(if(page=="Ventes")"sell" else "prepare",obj("item" to selected,"qty" to amount.toLongOrNull()))},enabled=enabled&&selected.isNotBlank()){Text(if(page=="Ventes")"Enregistrer la vente" else "Enregistrer la préparation")};if(page=="Ventes"){if(manager)OutlinedTextField(reason,{reason=it},label={Text("Motif d’annulation")});rows(d.optJSONArray("sales")).forEach{x->OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){Text(x.optString("qty")+" unités · "+x.optString("total")+" F");if(x.optBoolean("cancelled"))Text("Annulée")else if(manager&&cash!=null)TextButton({mutate("cancel_sale",obj("sale" to x.optString("id"),"reason" to reason))},enabled=enabled){Text("Annuler cette vente")}}}}}}
    "Caisse"->{if(cash!=null){GrilladMetric("Attendu",cash.optString("expected")+" F");OutlinedTextField(reason,{reason=it},label={Text("Justification si écart")})};OutlinedTextField(amount,{amount=it},label={Text(if(cash==null)"Fonds initial" else "Montant compté")});Button({mutate(if(cash==null)"open_cash" else "close_cash",if(cash==null)obj("opening" to amount.toLongOrNull())else obj("counted" to amount.toLongOrNull(),"reason" to reason))},enabled=enabled){Text(if(cash==null)"Ouvrir la caisse" else "Clôturer")}}
    "Dépenses"->{OutlinedTextField(name,{name=it},label={Text("Libellé")});OutlinedTextField(amount,{amount=it},label={Text("Montant")});Button({mutate("expense",obj("label" to name,"value" to amount.toLongOrNull()))},enabled=enabled){Text("Enregistrer")};rows(d.optJSONArray("expenses")).forEach{x->Text(x.optString("label")+" · "+x.optString("value")+" F")}}
    "Prévisions"->{rows(d.optJSONArray("forecasts")).forEach{x->Text(x.optString("name")+" · "+if(x.isNull("quantity"))"Historique insuffisant" else x.optString("quantity")+" unités estimées")}}
    "Notifications"->{rows(d.optJSONArray("notices")).forEach{x->Text(x.optString("text"))};Text("Push distant à qualifier.")}
    "Équipe"->{GrilladAttendance(d.optJSONObject("attendance"),enabled){proof->val s=site;if(s!=null&&pending==null)run{proof.put("action","attendance_capture").put("org",s.optString("org")).put("site",s.optString("site")).put("event",UUID.randomUUID().toString());submit(proof)}}}
    "Vidéosurveillance"->Text("Passerelle NAXA SECURITY non configurée.")
    "ZIPPLE Connect"->Text("Partenariat ZIPPLE Snack-Bar non raccordé.")
    "Abonnement"->Text("ACCÈS : 2 000 F/mois ou 24 000 F/an. PREMIUM : 6 000 F/mois ou 60 000 F/an.")
    "Profil"->listOf("Système","Clair","Sombre").forEach{m->OutlinedButton({onAppearance(m)}){Text(if(appearance==m)"✓ "+m else m)}}
   }
  }
 }
 }
}
