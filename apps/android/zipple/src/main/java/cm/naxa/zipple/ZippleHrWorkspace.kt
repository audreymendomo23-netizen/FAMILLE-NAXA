package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import java.time.LocalDate
@Composable internal fun ZippleHrWorkspace(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val t:(String,String)->String={a,b->if(en)b else a};val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
 var data by remember{mutableStateOf<JSONObject?>(null)};var values by remember{mutableStateOf<Map<String,String>>(emptyMap())};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 var filterKind by remember{mutableStateOf("all")};var filterState by remember{mutableStateOf("all")};var filterFrom by remember{mutableStateOf("")};var filterTo by remember{mutableStateOf("")}
 fun v(k:String)=values[k].orEmpty()
 fun set(k:String,x:String){values=values+(k to x)}
 suspend fun load(){data=api.call(session,site,"hr_snapshot") as? JSONObject?:error("DATA")}
 fun run(block:suspend()->Unit){if(busy||!session.permits(site))return;busy=true;msg="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 fun write(op:String,p:JSONObject){run{val body=JSONObject().put("operation",op).put("payload",p);val out=api.call(session,site,"hr_write",keys.apply(op,body)) as? JSONObject?:error("DATA");require(out.optBoolean("confirmed"));keys.confirmed(op);load();msg=t("Opération enregistrée","Operation saved")}}
 LaunchedEffect(session.token,site){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Données indisponibles","Data unavailable")}}
 val names=mapOf("absence" to t("Absence","Leave"),"bonus" to t("Prime","Bonus"),"commission" to t("Commission","Commission"),"advance" to t("Avance","Advance"))
 val states=mapOf("pending" to t("À valider","Pending"),"approved" to t("Approuvé","Approved"),"rejected" to t("Refusé","Rejected"),"cancelled" to t("Annulé","Cancelled"))
 Text(t("Absences et rémunérations","Leave and compensation"),style=MaterialTheme.typography.titleLarge)
 Text(t("Aucun virement ni retenue automatique.","No automatic transfer or pay deduction."));OutlinedButton(enabled=!busy,onClick={run{load()}}){Text(t("Actualiser cet espace","Refresh workspace"))};if(msg.isNotBlank())Text(msg)
 val d=data?:return;val owner=d.optBoolean("can_approve_pay");val manager=d.optBoolean("can_manage");val me=d.optString("member_id");val kind=v("kind").ifBlank{"absence"};val member=v("member_id").ifBlank{me}
 HrChoice(t("Type de demande","Request type"),names.filterKeys{manager||it=="absence"}.toList(),kind,!busy){set("kind",it)}
 if(manager)HrChoice(t("Employé concerné","Employee concerned"),d.rows("members").map{it.optString("id") to it.optString("label")},member,!busy){set("member_id",it)}
 for((key,label) in listOf("from_day" to t("Début AAAA-MM-JJ","From YYYY-MM-DD"),"to_day" to t("Fin AAAA-MM-JJ","To YYYY-MM-DD"))+(if(kind!="absence")listOf("amount_xaf" to t("Montant FCFA","Amount XAF"))else emptyList())+listOf("reason" to t("Motif professionnel","Work reason")))OutlinedTextField(v(key),{set(key,it.take(500))},label={Text(label)},modifier=Modifier.fillMaxWidth(),enabled=!busy)
 val dates=runCatching{val lo=LocalDate.parse(v("from_day"));val hi=LocalDate.parse(v("to_day"));!hi.isBefore(lo)&&hi.toEpochDay()-lo.toEpochDay()<=365}.getOrDefault(false)
 Button(enabled=!busy&&dates&&v("reason").trim().length>=5&&(kind=="absence"||(v("amount_xaf").toIntOrNull()?:0)>0),onClick={write("submit",JSONObject().put("kind",kind).put("member_id",member).put("from_day",v("from_day")).put("to_day",v("to_day")).put("amount_xaf",if(kind=="absence")JSONObject.NULL else v("amount_xaf").toInt()).put("reason",v("reason")))}){Text(t("Soumettre la demande","Submit request"))}
 Text(t("Historique","History"))
 HrChoice(t("Filtrer par type","Filter by type"),listOf("all" to t("Tous","All"))+names.toList(),filterKind,!busy){filterKind=it}
 HrChoice(t("Filtrer par statut","Filter by status"),listOf("all" to t("Tous","All"))+states.toList(),filterState,!busy){filterState=it}
 OutlinedTextField(filterFrom,{filterFrom=it.take(10)},label={Text(t("Période depuis AAAA-MM-JJ","Period from YYYY-MM-DD"))},enabled=!busy)
 OutlinedTextField(filterTo,{filterTo=it.take(10)},label={Text(t("Période jusqu’au AAAA-MM-JJ","Period to YYYY-MM-DD"))},enabled=!busy)
 OutlinedButton(enabled=!busy,onClick={filterKind="all";filterState="all";filterFrom="";filterTo=""}){Text(t("Réinitialiser les filtres","Reset filters"))}
 val validDates=runCatching{val lo=filterFrom.takeIf{it.isNotBlank()}?.let{LocalDate.parse(it)};val hi=filterTo.takeIf{it.isNotBlank()}?.let{LocalDate.parse(it)};lo==null||hi==null||!hi.isBefore(lo)}.getOrDefault(false)
 val filtered=if(validDates)d.rows("rows").filter{x->(filterKind=="all"||x.optString("kind")==filterKind)&&(filterState=="all"||x.optString("state")==filterState)&&(filterFrom.isBlank()||x.optString("to_day")>=filterFrom)&&(filterTo.isBlank()||x.optString("from_day")<=filterTo)}else emptyList()
 Text(filtered.size.toString()+" "+t("demandes affichées (historique reçu, 200 au maximum)","requests displayed (received history, up to 200)"))
 if(!validDates)Text(t("Période invalide.","Invalid period."))
 if(owner)Text(t("Montants approuvés dans cette sélection (hors absences, non versés automatiquement)","Approved amounts in this selection (excluding leave, not automatically paid)")+" : "+filtered.filter{it.optString("state")=="approved"&&it.optString("kind")!="absence"}.sumOf{it.optLong("amount_xaf")}+" FCFA")
 if(filtered.isEmpty())Text(t("Aucune demande correspondante.","No matching request."))
 filtered.forEach{x->val id=x.optString("id");val k=x.optString("kind");val state=x.optString("state");Text((names[k]?:k)+" · "+x.optString("label")+" · "+(states[state]?:state));Text(x.optString("from_day")+" — "+x.optString("to_day")+(if(x.isNull("amount_xaf"))"" else " · "+x.optString("amount_xaf")+" FCFA")+" · "+x.optString("reason"));if(!x.isNull("decision_reason"))Text(x.optString("decision_reason"))
 if(state=="pending"&&(owner||manager&&k=="absence"||x.optString("author_id")==me)){OutlinedTextField(v("why_"+id),{set("why_"+id,it.take(500))},label={Text(t("Motif de décision","Decision reason"))},modifier=Modifier.fillMaxWidth(),enabled=!busy);for(decision in if(owner||manager&&k=="absence")listOf("approved","rejected","cancelled")else listOf("cancelled"))OutlinedButton(enabled=!busy&&v("why_"+id).trim().length>=5,onClick={write("decide",JSONObject().put("id",id).put("decision",decision).put("reason",v("why_"+id)))}){Text(states[decision]?:decision)}}
 }
}
@Composable private fun HrChoice(label:String,options:List<Pair<String,String>>,value:String,enabled:Boolean,change:(String)->Unit){var open by remember{mutableStateOf(false)};Box{OutlinedButton(enabled=enabled&&options.isNotEmpty(),onClick={open=true}){Text(label+" : "+(options.find{it.first==value}?.second?:"—"))};DropdownMenu(expanded=open,onDismissRequest={open=false}){options.forEach{(id,label)->DropdownMenuItem(text={Text(label)},onClick={change(id);open=false})}}}}
