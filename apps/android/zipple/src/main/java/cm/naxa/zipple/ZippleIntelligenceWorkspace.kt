package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.Instant
import kotlin.math.abs
import kotlin.math.roundToLong

@Composable internal fun ZippleIntelligenceWorkspace(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val t:(String,String)->String={fr,eng->if(en)eng else fr}
 val today=LocalDate.now(ZoneId.of("Africa/Douala"));val scope=rememberCoroutineScope()
 var mode by remember{mutableStateOf("morning")};var horizon by remember{mutableStateOf(7)}
 var data by remember{mutableStateOf<Map<String,JSONObject>>(emptyMap())};var busy by remember{mutableStateOf(false)}
 var cost by remember{mutableStateOf("")};var price by remember{mutableStateOf("")};var target by remember{mutableStateOf("30")}
 suspend fun load(){busy=true;data=emptyMap();try{
  for((key,action,body) in listOf(Triple("erp","erp_snapshot",JSONObject()),Triple("credit","credit_snapshot",JSONObject()),Triple("morning","pilotage",JSONObject().put("start",today.minusDays(1).toString()).put("end",today.minusDays(1).toString())),Triple("evening","pilotage",JSONObject().put("start",today.toString()).put("end",today.toString())))){
   try{val x=api.call(session,site,action,body) as? JSONObject?:continue;data=data+(key to x)}catch(c:CancellationException){throw c}catch(_:Exception){}
  }
 }finally{busy=false}}
 LaunchedEffect(session.member,site){if(session.permits(site))load()}
 Text(t("Briefing opérationnel","Operational briefing"),style=MaterialTheme.typography.titleLarge)
 OutlinedButton(enabled=!busy&&session.permits(site),onClick={scope.launch{load()}}){Text(t("Actualiser le briefing","Refresh briefing"))}
 Row{OutlinedButton(enabled=mode!="morning",onClick={mode="morning"}){Text(t("Matin — veille","Morning — previous day"))};OutlinedButton(enabled=mode!="evening",onClick={mode="evening"}){Text(t("Soir — aujourd’hui","Evening — today"))}}
 Text((if(mode=="morning")today.minusDays(1) else today).toString()+" · Africa/Douala")
 if(busy)Text(t("Chargement des sources…","Loading sources…"))
 val m=data[mode]
 if(m!=null){listOf("recorded_xaf" to t("Ventes brutes","Gross sales"),"collected_xaf" to t("Encaissements","Collections"),"expenses_xaf" to t("Charges","Expenses"),"gross_margin_xaf" to t("Marge brute connue","Known gross margin"),"absolute_cash_variance_xaf" to t("Écarts absolus de caisse","Absolute cash variances")).forEach{(k,l)->Text(l+" : "+if(m.isNull(k))"—" else m.optString(k)+" FCFA")};Text(t("Commandes actuellement en retard","Currently overdue orders")+" : "+m.optString("current_late_orders"))}else Text(t("Indicateurs de période indisponibles","Period metrics unavailable"))
 Text(t("Plan de réapprovisionnement et péremption","Replenishment and expiry plan"),style=MaterialTheme.typography.titleMedium)
 val erp=data["erp"]
 if(erp!=null){
  val items=erp.rows("ingredients");val low=items.filter{!it.isNull("available_milli")&&!it.isNull("reorder_milli")&&it.optLong("available_milli")<=it.optLong("reorder_milli")}
  fun qty(n:Long)=java.math.BigDecimal.valueOf(n,3).stripTrailingZeros().toPlainString()
  Text(t("Matières au seuil","Ingredients at threshold")+" : "+low.size)
  low.forEach{i->Text(i.optString("name")+" · "+qty(i.optLong("available_milli"))+" "+i.optString("unit")+" · "+t("Manque pour atteindre le seuil","Shortfall to threshold")+" : "+qty((i.optLong("reorder_milli")-i.optLong("available_milli")).coerceAtLeast(0)))}
  Text(t("Horizon péremption (jours)","Expiry horizon (days)"));Row{listOf(0,7,14,30).forEach{n->OutlinedButton(enabled=horizon!=n,onClick={horizon=n}){Text(n.toString())}}}
  val lots=erp.rows("lots").mapNotNull{l->val item=items.find{it.optString("id")==l.optString("ingredient_id")}?:return@mapNotNull null;val date=runCatching{LocalDate.parse(l.optString("expires_on"))}.getOrNull();val time=runCatching{Instant.parse(l.optString("usable_until")).atZone(ZoneId.of("Africa/Douala")).toLocalDate()}.getOrNull();val expiry=listOfNotNull(date,time).minOrNull()?:return@mapNotNull null;if(l.optLong("remaining_milli")<=0||expiry>today.plusDays(horizon.toLong()))null else Triple(expiry,l,item)}.sortedBy{it.first}
  if(lots.isEmpty())Text(t("Aucun lot daté correspondant parmi les lots reçus.","No matching dated lot in received lots."))
  lots.forEach{(expiry,l,i)->Text(i.optString("name")+" · "+l.optString("lot_label")+" · "+qty(l.optLong("remaining_milli"))+" "+i.optString("unit")+" · "+expiry)}
  Text(t("Seuil ≠ commande recommandée ; lots reçus limités à 200.","Threshold is not a purchase recommendation; received lots capped at 200."))
 }else Text(t("Stock indisponible","Stock unavailable"))
 Text(t("Créances à traiter","Receivables to review"),style=MaterialTheme.typography.titleMedium)
 val credit=data["credit"];if(credit!=null){val rows=credit.rows("sales").filter{it.optLong("balance_xaf")>0&&runCatching{LocalDate.parse(it.optString("due_on"))}.isSuccess};Text(t("Aujourd’hui","Today")+" : "+rows.filter{it.optString("due_on")==today.toString()}.sumOf{it.optLong("balance_xaf")}+" FCFA · "+t("En retard","Overdue")+" : "+rows.filter{it.optString("due_on")<today.toString()}.sumOf{it.optLong("balance_xaf")}+" FCFA")}else Text(t("Créances indisponibles","Receivables unavailable"))
 Text(t("Prévision et erreur historique","Forecast and historical error"),style=MaterialTheme.typography.titleMedium)
 val history=data["morning"]?.rows("history_28").orEmpty();val map=history.associate{it.optString("day") to it.optLong("recorded_xaf",-1)};val values=(28 downTo 1).map{map[today.minusDays(it.toLong()).toString()]}
 if(history.size==28&&values.all{it!=null&&it>=0}){val v=values.filterNotNull();val errors=(7..27).sumOf{i->abs(v.subList(i-7,i).average()-v[i])};val actual=v.drop(7).sum();Text(v.takeLast(7).average().roundToLong().toString()+" FCFA/j · "+t("Erreur absolue moyenne (21 prévisions)","Mean absolute error (21 forecasts)")+" : "+(errors/21).roundToLong()+" FCFA · WAPE "+(if(actual>0) "%.1f".format(java.util.Locale.ROOT,errors/actual*100)+" %" else "—"))}else Text(t("28 jours consécutifs observés nécessaires.","28 consecutive observed days required."))
 Text(t("Projection indicative, moyenne glissante 7 jours.","Indicative projection, 7-day rolling mean."))
 Text(t("Simulateur de prix et marge","Price and margin simulator"),style=MaterialTheme.typography.titleMedium)
 OutlinedTextField(cost,{cost=it.filter(Char::isDigit).take(10)},label={Text(t("Coût complet unitaire FCFA","Full unit cost XAF"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(price,{price=it.filter(Char::isDigit).take(10)},label={Text(t("Prix unitaire envisagé FCFA","Proposed unit price XAF"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(target,{target=it.filter(Char::isDigit).take(2)},label={Text(t("Marge cible sur prix (%)","Target margin on price (%)"))},modifier=Modifier.fillMaxWidth())
 val c=cost.toLongOrNull();val p=price.toLongOrNull();val g=target.toIntOrNull()
 if(c!=null&&p!=null&&g!=null&&c in 0..2147483647L&&p in 1..2147483647L&&g in 0..99){val suggested=(c*100+99-g)/(100-g);if(suggested<=2147483647L){Text(t("Marge unitaire simulée","Simulated unit margin")+" : "+(p-c)+" FCFA · "+"%.2f".format(java.util.Locale.ROOT,(p-c)*100.0/p)+" %");Text(t("Prix minimum pour la cible","Minimum price for target")+" : "+suggested+" FCFA")}}
 Text(t("Hypothèses manuelles, aucune modification automatique du catalogue.","Manual assumptions, no automatic catalogue change."))
}
