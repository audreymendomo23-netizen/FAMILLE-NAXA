package cm.naxa.zipple
import android.os.SystemClock
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.Instant

@Composable internal fun ZippleServerClock(order:JSONObject,serverNow:String,en:Boolean){
 val target=runCatching{Instant.parse(order.optString("promised_at")).toEpochMilli()}.getOrNull()?:return
 if(order.optString("status")=="cancelled")return
 val end=runCatching{Instant.parse(order.optString("guest_served_at")).toEpochMilli()}.getOrNull()?:runCatching{Instant.parse(order.optString("served_at")).toEpochMilli()}.getOrNull()
 val base=remember(serverNow){runCatching{Instant.parse(serverNow).toEpochMilli()}.getOrNull()}
 val anchor=remember(serverNow){SystemClock.elapsedRealtime()};var elapsed by remember(serverNow){mutableStateOf(0L)}
 LaunchedEffect(serverNow){while(true){elapsed=SystemClock.elapsedRealtime()-anchor;delay(1000)}}
 if(end==null&&(base==null||elapsed>15000)){Text(if(en)"Service time — awaiting synchronization" else "Délai de service — synchronisation attendue");return}
 val remaining=target-(end?:((base?:return)+elapsed));val n=(kotlin.math.abs(remaining)+999)/1000
 val label=if(end!=null){if(remaining>=0){if(en)"Served early" else "Service en avance"}else if(en)"Served late" else "Service en retard"}else if(remaining>0){if(en)"Remaining" else "Temps restant"}else if(en)"Delay" else "Retard"
 Text(label+" : "+(n/60)+" min "+(n%60)+" s")
}
@Composable internal fun ZippleNativeStations(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr};val scope=rememberCoroutineScope()
 val manager=session.role in setOf("promoteur","manager")
 var data by remember{mutableStateOf<JSONObject?>(null)};var config by remember{mutableStateOf<JSONObject?>(null)}
 var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 var filter by remember(session.member,site){mutableStateOf("active")};var search by remember(session.member,site){mutableStateOf("")};var postFilter by remember(session.member,site){mutableStateOf("all")}
 var itemSearch by remember(session.member,site){mutableStateOf("")};var showAvailability by remember(session.member,site){mutableStateOf(false)}
 var limits by remember(session.member,site){mutableStateOf<Map<String,String>>(emptyMap())};var windows by remember(session.member,site){mutableStateOf<Map<String,Pair<String,String>>>(emptyMap())}
 var label by remember{mutableStateOf("")};var post by remember{mutableStateOf("kitchen")};var slots by remember{mutableStateOf("1")};var configuration by remember{mutableStateOf(false)}
 suspend fun load(){data=api.call(session,site,"station_snapshot") as? JSONObject}
 suspend fun loadConfig(){config=api.call(session,site,"substation_snapshot") as? JSONObject}
 fun run(block:suspend()->Unit){if(busy||!session.permits(site))return;busy=true;message="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 LaunchedEffect(session.token,site){while(true){if(!busy)try{load()}catch(c:CancellationException){throw c}catch(_:Exception){data=null};delay(5000)}}
 Text(tr("Postes de préparation","Preparation stations"),style=MaterialTheme.typography.titleLarge)
 if(message.isNotBlank())Text(message)
 OutlinedButton(enabled=!busy,onClick={run{load();if(configuration)loadConfig()}}){Text(tr("Actualiser les postes","Refresh stations"))}
 val lines=data?.rows("lines").orEmpty();fun station(l:JSONObject)=l.optString("substation_label").takeUnless{it.isBlank()||it=="null"}?:l.optString("post")
 if(data!=null){
 Text(tr("Reçues","Received")+" · "+lines.count{it.optString("state")=="received"}+" / "+tr("En préparation","Preparing")+" · "+lines.count{it.optString("state")=="preparing"}+" / "+tr("Prêtes","Ready")+" · "+lines.count{it.optString("state")=="ready"})
 OutlinedTextField(search,{search=it.take(100)},label={Text(tr("Rechercher une préparation","Search preparation"))},modifier=Modifier.fillMaxWidth())
 Text(tr("État de préparation","Preparation status"));listOf("active" to tr("Actives","Active"),"all" to tr("Toutes","All"),"received" to tr("Reçues","Received"),"preparing" to tr("En préparation","Preparing"),"ready" to tr("Prêtes","Ready"),"served" to tr("Servies","Served")).forEach{(k,label)->OutlinedButton(onClick={filter=k},enabled=filter!=k){Text(label)}}
 Text(tr("Poste de préparation","Preparation station"));(listOf("all" to tr("Tous","All"))+lines.map{station(it)}.filter{it.isNotBlank()}.distinct().map{it to it}).forEach{(k,label)->OutlinedButton(onClick={postFilter=k},enabled=postFilter!=k){Text(label)}}
 OutlinedButton(onClick={search="";filter="active";postFilter="all"}){Text(tr("Réinitialiser les filtres","Reset filters"))}
 }
 val visible=lines.filter{l->val state=l.optString("state");(filter=="all"||(if(filter=="active")state in listOf("received","preparing","ready") else state==filter))&&(postFilter=="all"||station(l)==postFilter)&&listOf("number","name").any{l.optString(it).contains(search.trim(),ignoreCase=true)}}
 if(data!=null&&visible.isEmpty())Text(tr("Aucune préparation correspondante.","No matching preparation."))
 visible.forEach{l->
  val state=l.optString("state");val next=mapOf("received" to "preparing","preparing" to "ready","ready" to "served")[state]
  Text("#"+l.optString("number")+" · "+l.optString("name")+" × "+l.optInt("qty")+" · "+l.optString("substation_label").takeUnless{it.isBlank()||it=="null"}.orEmpty().ifBlank{l.optString("post")}+" · "+state)
  ZippleServerClock(l,data?.optString("server_now").orEmpty(),en)
  l.rows("instructions").forEach{n->Text(n.optString("qty")+" × "+n.optString("note"))}
  if(next=="served"&&!l.optBoolean("handoff_allowed",true))Text(tr("Prête — remise par le personnel de salle","Ready — handoff by service staff"))
  else if(next!=null)Button(enabled=!busy,onClick={run{api.call(session,site,"line_advance",JSONObject().put("order_id",l.optString("order_id")).put("item_id",l.optString("item_id")).put("next",next));load()}}){Text(tr("Étape suivante","Next step"))}
  HorizontalDivider()
 }
 if(data==null)Text(tr("Postes non synchronisés","Stations not synchronized"))
 if(data!=null){OutlinedButton(onClick={showAvailability=!showAvailability}){Text(tr("Disponibilité des produits","Product availability"))}
 if(showAvailability){
  OutlinedTextField(itemSearch,{itemSearch=it.take(160)},label={Text(tr("Rechercher un produit","Search product"))},modifier=Modifier.fillMaxWidth())
  data?.rows("categories").orEmpty().forEach{c->val name=c.optString("category");Text(name);OutlinedButton(enabled=!busy&&session.permits(site),onClick={run{api.call(session,site,"category_set",JSONObject().put("category",name).put("active",!c.optBoolean("active")));load()}}){Text(if(c.optBoolean("active"))tr("Suspendre la catégorie","Suspend category")else tr("Réactiver la catégorie","Reactivate category"))}}
  val items=data?.rows("items").orEmpty().filter{it.optString("name").contains(itemSearch.trim(),ignoreCase=true)}
  if(items.isEmpty())Text(tr("Aucun produit correspondant.","No matching product."))
  items.forEach{i->val id=i.optString("id");key(id){
   Text(i.optString("name")+" · "+i.optInt("available_qty"))
   OutlinedButton(enabled=!busy&&session.permits(site),onClick={run{api.call(session,site,"station_availability",JSONObject().put("item_id",id).put("active",!i.optBoolean("active")));load()}}){Text(if(i.optBoolean("active"))tr("Suspendre","Suspend")else tr("Réactiver","Reactivate"))}
   fun hour(k:String)=i.optString(k).takeUnless{it=="null"}.orEmpty().take(5)
   val w=windows[id]?: (hour("available_from") to hour("available_until"))
   OutlinedTextField(w.first,{windows=windows+(id to (it.take(5) to w.second))},label={Text(tr("Disponible dès HH:MM","Available from HH:MM"))},enabled=!busy)
   OutlinedTextField(w.second,{windows=windows+(id to (w.first to it.take(5)))},label={Text(tr("Disponible jusqu’à HH:MM","Available until HH:MM"))},enabled=!busy)
   val valid=(w.first.isBlank()&&w.second.isBlank())||(listOf(w.first,w.second).all{Regex("(?:[01][0-9]|2[0-3]):[0-5][0-9]").matches(it)})
   OutlinedButton(enabled=!busy&&valid&&session.permits(site),onClick={run{api.call(session,site,"station_window",JSONObject().put("item_id",id).put("available_from",w.first.takeIf{it.isNotBlank()}?:JSONObject.NULL).put("available_until",w.second.takeIf{it.isNotBlank()}?:JSONObject.NULL));windows=windows-id;load()}}){Text(tr("Enregistrer les horaires (Douala)","Save hours (Douala)"))}
   if(i.optString("kind")!="formula"){val limit=limits[id]?:i.optString("sale_limit").takeUnless{it=="null"}.orEmpty();OutlinedTextField(limit,{limits=limits+(id to it.filter(Char::isDigit).take(10))},label={Text(tr("Portions vendables limitées","Temporary sellable limit"))},enabled=!busy)
    OutlinedButton(enabled=!busy&&session.permits(site)&&(limit.isBlank()||limit.toIntOrNull()?.let{it in 0..i.optInt("available_qty")}==true),onClick={run{api.call(session,site,"station_limit",JSONObject().put("item_id",id).put("limit",limit.toIntOrNull()?:JSONObject.NULL));limits=limits-id;load()}}){Text(tr("Enregistrer la limite (vide = aucune)","Save limit (empty = none)"))}}
   HorizontalDivider()
  }}
 }}
 if(manager){
  OutlinedButton(enabled=!busy,onClick={configuration=!configuration;if(configuration)run{loadConfig()}}){Text(tr("Configurer les sous-postes","Configure substations"))}
  if(configuration){
   OutlinedTextField(label,{label=it.take(80)},label={Text(tr("Nom du sous-poste","Substation name"))})
   listOf("kitchen","bar","snack").forEach{p->OutlinedButton(enabled=!busy,onClick={post=p}){Text((if(post==p)"✓ " else "")+p)}}
   OutlinedTextField(slots,{slots=it.filter(Char::isDigit).take(3)},label={Text(tr("Capacité simultanée","Parallel capacity"))})
   Button(enabled=!busy&&label.trim().length>=2&&slots.toIntOrNull()?.let{it in 1..100}==true,onClick={run{api.call(session,site,"substation_configure",JSONObject().put("post",post).put("label",label.trim()).put("parallel_slots",slots.toInt()));label="";loadConfig();load()}}){Text(tr("Enregistrer le sous-poste","Save substation"))}
   val stations=config?.rows("stations").orEmpty()
   config?.rows("items")?.forEach{i->
    Text(i.optString("name"))
    OutlinedButton(enabled=!busy,onClick={run{api.call(session,site,"substation_assign",JSONObject().put("item_id",i.optString("id")).put("substation_id",JSONObject.NULL));loadConfig();load()}}){Text(tr("Poste principal","Parent station"))}
    stations.filter{it.optString("post")==i.optString("post")}.forEach{s->OutlinedButton(enabled=!busy,onClick={run{api.call(session,site,"substation_assign",JSONObject().put("item_id",i.optString("id")).put("substation_id",s.optString("id")));loadConfig();load()}}){Text((if(i.optString("substation_id")==s.optString("id"))"✓ " else "")+s.optString("label"))}}
   }
   if(session.role=="promoteur")config?.rows("staff")?.forEach{m->Text(m.optString("login"));stations.forEach{s->val sid=s.optString("id");val a=m.optJSONArray("stations");val enabled=a!=null&&(0 until a.length()).any{a.optString(it)==sid};Row{Checkbox(checked=enabled,enabled=!busy,onCheckedChange={v->run{api.call(session,site,"substation_grant",JSONObject().put("member_id",m.optString("id")).put("substation_id",sid).put("enabled",v));loadConfig()}});Text(s.optString("label"))}}}
  }
 }
}
