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
 var label by remember{mutableStateOf("")};var post by remember{mutableStateOf("kitchen")};var slots by remember{mutableStateOf("1")};var configuration by remember{mutableStateOf(false)}
 suspend fun load(){data=api.call(session,site,"station_snapshot") as? JSONObject}
 suspend fun loadConfig(){config=api.call(session,site,"substation_snapshot") as? JSONObject}
 fun run(block:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 LaunchedEffect(session.token,site){while(true){if(!busy)try{load()}catch(c:CancellationException){throw c}catch(_:Exception){data=null};delay(5000)}}
 Text(tr("Postes de préparation","Preparation stations"),style=MaterialTheme.typography.titleLarge)
 if(message.isNotBlank())Text(message)
 OutlinedButton(enabled=!busy,onClick={run{load();if(configuration)loadConfig()}}){Text(tr("Actualiser les postes","Refresh stations"))}
 data?.rows("lines")?.forEach{l->
  val state=l.optString("state");val next=mapOf("received" to "preparing","preparing" to "ready","ready" to "served")[state]
  Text("#"+l.optString("number")+" · "+l.optString("name")+" × "+l.optInt("qty")+" · "+l.optString("substation_label").takeUnless{it.isBlank()||it=="null"}.orEmpty().ifBlank{l.optString("post")}+" · "+state)
  ZippleServerClock(l,data?.optString("server_now").orEmpty(),en)
  if(next=="served"&&!l.optBoolean("handoff_allowed",true))Text(tr("Prête — remise par le personnel de salle","Ready — handoff by service staff"))
  else if(next!=null)Button(enabled=!busy,onClick={run{api.call(session,site,"line_advance",JSONObject().put("order_id",l.optString("order_id")).put("item_id",l.optString("item_id")).put("next",next));load()}}){Text(tr("Étape suivante","Next step"))}
  HorizontalDivider()
 }
 if(data==null)Text(tr("Postes non synchronisés","Stations not synchronized"))
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
