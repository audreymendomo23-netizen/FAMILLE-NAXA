package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import org.json.JSONObject
import java.time.LocalDate
import java.time.Instant
import java.time.ZoneId
import kotlin.math.roundToLong

@Composable internal fun ZippleAdvancedIntelligence(data:Map<String,JSONObject>,today:LocalDate,en:Boolean,mode:String){
 val t:(String,String)->String={fr,eng->if(en)eng else fr};val tz=ZoneId.of("Africa/Douala")
 var item by remember{mutableStateOf("")};var portions by remember{mutableStateOf("10")};var change by remember{mutableStateOf("0")};var shiftDay by remember{mutableStateOf(today.toString())};var expanded by remember{mutableStateOf(false)}
 fun money(v:Long?)=v?.let{"$it FCFA"}?:"—"
 fun num(x:JSONObject?,k:String)=x?.takeUnless{it.isNull(k)}?.optLong(k)
 val erp=data["erp"];val recipes=erp?.rows("recipes").orEmpty();val weighted=data["weighted"];val products=data["catalog"]?.rows("items").orEmpty().filter{i->recipes.any{it.optString("item_id")==i.optString("id")}&&weighted?.rows("rules").orEmpty().none{it.optString("item_id")==i.optString("id")}}
 val selected=products.find{it.optString("id")==item}
 Text(t("Recipe Intelligence — plan de production","Recipe Intelligence — production plan"),style=MaterialTheme.typography.titleMedium)
 Box{OutlinedButton(enabled=products.isNotEmpty()&&weighted!=null,onClick={expanded=true}){Text(t("Produit à préparer","Product to prepare")+" : "+(selected?.optString("name")?:"—"))};DropdownMenu(expanded=expanded,onDismissRequest={expanded=false}){products.forEach{i->DropdownMenuItem(text={Text(i.optString("name"))},onClick={item=i.optString("id");expanded=false})}}}
 OutlinedTextField(portions,{portions=it.take(5)},label={Text(t("Portions à préparer","Portions to prepare"))},modifier=Modifier.fillMaxWidth())
 OutlinedTextField(change,{change=it.take(4)},label={Text(t("Variation simulée des coûts matières (%)","Simulated material cost change (%)"))},modifier=Modifier.fillMaxWidth())
 val count=portions.toIntOrNull();val delta=change.toIntOrNull()
 if(selected!=null&&erp!=null&&weighted!=null&&count!=null&&count in 1..10000&&delta!=null&&delta in -100..500){
  val ingredients=erp.rows("ingredients");val lots=erp.rows("lots");var total=0.0;var complete=true
  for(c in recipes.filter{it.optString("item_id")==item}){
   val i=ingredients.find{it.optString("id")==c.optString("ingredient_id")}
   val needed=c.optLong("qty_milli",-1)*count
   if(i==null||needed<=0||i.isNull("available_milli")){complete=false;continue}
   val available=i.optLong("available_milli")
   val usable=lots.filter{l->l.optString("ingredient_id")==i.optString("id")&&l.optLong("remaining_milli")>0&&!l.isNull("remaining_cost")&&l.optLong("remaining_cost")>=0&&(l.isNull("expires_on")||runCatching{LocalDate.parse(l.optString("expires_on"))>=today}.getOrDefault(false))&&(l.isNull("usable_until")||runCatching{Instant.parse(l.optString("usable_until"))>Instant.now()}.getOrDefault(false))}
   val qty=usable.sumOf{it.optLong("remaining_milli")};val cost=usable.sumOf{it.optLong("remaining_cost")};val estimate=if(qty==available&&qty>=needed&&qty>0&&cost>=0)cost.toDouble()/qty*needed else null
   if(estimate==null)complete=false else total+=estimate
   Text(i.optString("name")+" · "+needed/1000.0+" "+i.optString("unit")+" · "+t("Disponible","Available")+" : "+available/1000.0+" · "+t("Manque","Shortage")+" : "+(needed-available).coerceAtLeast(0)/1000.0+" · "+money(estimate?.roundToLong()))
  }
  val valid=complete&&total.isFinite()&&total<9e15&&total*(1+delta/100.0)<9e15;val unit=if(valid)(total/count).roundToLong() else null;val scenario=if(valid)(total*(1+delta/100.0)/count).roundToLong() else null
  Text(t("Coût matières estimé du lot","Estimated batch material cost")+" : "+money(if(valid)total.roundToLong() else null));Text(t("Coût matières par portion","Material cost per portion")+" : "+money(unit));Text(t("Coût par portion simulé","Simulated cost per portion")+" : "+money(scenario))
  val last=erp.rows("batches").filter{it.optString("item_id")==item&&it.optLong("servings")>0&&!it.isNull("cost_xaf")}.maxByOrNull{it.optString("created_at")}
  Text(t("Dernier coût de production constaté par portion","Last recorded production cost per portion")+" : "+money(last?.let{(it.optLong("cost_xaf").toDouble()/it.optLong("servings")).roundToLong()}))
  val price=num(selected,"price_xaf");Text(t("Prix catalogue de base","Base catalogue price")+" : "+money(price));if(price!=null&&scenario!=null)Text(t("Écart prix de base moins coût matière simulé","Base price less simulated material cost")+" : "+money(price-scenario))
 }else Text(t("Choisir une recette standard et des quantités valides. Préparations au poids exclues.","Choose a standard recipe and valid quantities. Weighted preparations excluded."))
 Text(t("Coût moyen des lots visibles si stock complet ; pas un coût FEFO réel ni une marge nette.","Average visible lot cost when stock is complete; not actual FEFO cost or net margin."))
 val period=if(mode=="morning")today.minusDays(1)else today
 Text(t("Waste Intelligence — pertes et stock à risque","Waste Intelligence — loss and stock at risk"),style=MaterialTheme.typography.titleMedium)
 val expiry=data["expiry"];val losses=expiry?.rows("losses")?.filter{runCatching{Instant.parse(it.optString("created_at")).atZone(tz).toLocalDate()==period}.getOrDefault(false)}
 Text(period.toString()+" · "+t("Pertes de préparations expirées (200 dernières écritures)","Expired preparation losses (latest 200 records)")+" : "+money(losses?.sumOf{it.optLong("loss_cost")})+" · "+(losses?.sumOf{it.optLong("servings")}?.toString()?:"—"))
 val braise=data["braise"]?.rows("yields");Text(t("Pertes de braisage cumulées (historique reçu)","Cumulative braising losses (received history)")+" : "+money(braise?.sumOf{it.optLong("loss_cost")}))
 Text(t("Coût cumulé des pertes d’inventaire","Cumulative inventory loss cost")+" : "+money(num(data["procurement"],"loss_cost_xaf")))
 val risk=expiry?.rows("batches")?.filter{it.optBoolean("expired")};Text(t("Préparations expirées encore en stock","Expired preparations still in stock")+" : "+money(risk?.sumOf{it.optLong("remaining_cost_xaf")}))
 Text(t("Sources et périodes distinctes, sans addition automatique ni destruction de stock.","Distinct sources and periods, no automatic aggregation or disposal."))
 Text(t("Anomalies à examiner","Anomalies to review"),style=MaterialTheme.typography.titleMedium)
 val m=data[mode];for((k,label) in listOf("absolute_cash_variance_xaf" to t("Écarts de caisse","Cash variance"),"refunds_xaf" to t("Remboursements","Refunds"),"credit_notes_xaf" to t("Avoirs","Credit notes"),"uncosted_receipts" to t("Ventes sans coût complet","Sales without full cost"),"current_late_orders" to t("Retards actuels","Current delays")))Text(label+" : "+(if(k.endsWith("_xaf"))money(num(m,k))else num(m,k)?.toString()?:"—"))
 Text(t("Indicateurs de contrôle, pas des preuves de fraude.","Review signals, not proof of fraud."))
 Text(t("Workforce Intelligence — couverture des shifts","Workforce Intelligence — shift coverage"),style=MaterialTheme.typography.titleMedium)
 OutlinedTextField(shiftDay,{shiftDay=it.take(10)},label={Text(t("Jour du planning AAAA-MM-JJ","Schedule day YYYY-MM-DD"))},modifier=Modifier.fillMaxWidth())
 val date=runCatching{LocalDate.parse(shiftDay)}.getOrNull();val planning=data["planning"]
 if(date!=null&&planning!=null){val start=date.atStartOfDay(tz).toInstant();val end=date.plusDays(1).atStartOfDay(tz).toInstant()
  val shifts=planning.rows("rows").mapNotNull{r->val lo=runCatching{Instant.parse(r.optString("starts_at"))}.getOrNull();val hi=runCatching{Instant.parse(r.optString("due_at"))}.getOrNull();val id=r.optString("assignee_id");if(lo!=null&&hi!=null&&id.isNotBlank()&&id!="null"&&r.optString("state") in listOf("open","in_progress","done")&&lo<end&&hi>start&&hi>lo)Triple(id,lo,hi)else null}
  Text(shifts.size.toString()+" "+t("shifts","shifts")+" · "+shifts.map{it.first}.distinct().size+" "+t("employés distincts planifiés","distinct scheduled employees"))
  for(h in 0..23){val lo=start.plusSeconds(h*3600L);val hi=lo.plusSeconds(3600);Text("%02d:00".format(h)+" · "+shifts.filter{it.second<hi&&it.third>lo}.map{it.first}.distinct().size+" "+t("employés planifiés","scheduled staff"))}
 }else Text(t("Planning indisponible","Schedule unavailable"))
 Text(t("Planning reçu limité à 200 dossiers ; pas un pointage réel ni une recommandation d’effectif.","Received schedule capped at 200 records; not actual attendance or staffing recommendation."))
}
