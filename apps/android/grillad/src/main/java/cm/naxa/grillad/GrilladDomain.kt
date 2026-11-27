package cm.naxa.grillad
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
internal val families=listOf("Porc","Poulet","Poisson","Brochettes","Omelettes")
internal fun planPrice(plan:String,annual:Boolean):Long=when(plan){"ACCESS"->if(annual)24000L else 2000L;"PREMIUM"->if(annual)60000L else 6000L;else->error("Formule invalide")}
internal data class Item(val id:String,val site:String,val name:String,val family:String,val price:Long,val cost:Long?,val prepared:Long=0,val sold:Long=0)
internal data class Sale(val id:String,val site:String,val item:String,val qty:Long,val total:Long,val cost:Long?,val at:Long=System.currentTimeMillis(),val actor:String="manager-demo",val cancelled:Boolean=false,val reason:String?=null)
internal data class Expense(val site:String,val label:String,val value:Long,val at:Long=System.currentTimeMillis())
internal data class Cash(val site:String,val opening:Long,val salesStart:Int,val expensesStart:Int)
internal data class Summary(val ca:Long,val charges:Long,val result:Long?,val count:Int)
internal fun dayKey(at:Long=System.currentTimeMillis())=Instant.ofEpochMilli(at).atZone(ZoneId.of("Africa/Douala")).toLocalDate().toString()
internal class Ledger {
 val sites=mutableListOf("Point de vente démo")
 val items=mutableListOf<Item>();val sales=mutableListOf<Sale>();val expenses=mutableListOf<Expense>();val cash=mutableMapOf<String,Cash>();val closings=mutableListOf<Pair<String,Long>>();val staff=mutableListOf<Pair<String,String>>()
 var plan="ACCESS";val targets=mutableMapOf<String,Long>()
 fun site(name:String){require(plan=="PREMIUM"&&name.isNotBlank()&&name !in sites){"Point non autorisé ou déjà existant"};sites.add(name)}
 fun item(site:String,name:String,family:String,price:Long,cost:Long?){require(site in sites&&name.isNotBlank()&&family in families&&price>0&&(cost==null||cost>=0)){"Article invalide"};items.add(Item(UUID.randomUUID().toString(),site,name,family,price,cost))}
 fun prepare(site:String,id:String,qty:Long){val n=items.indexOfFirst{it.site==site&&it.id==id};require(n>=0&&qty>0){"Quantité ou article invalide"};val x=items[n];items[n]=x.copy(prepared=Math.addExact(x.prepared,qty))}
 fun open(site:String,opening:Long){require(site in sites&&opening>=0&&site !in cash){"Caisse déjà ouverte ou fonds invalides"};cash[site]=Cash(site,opening,sales.size,expenses.size)}
 fun sell(site:String,id:String,qty:Long,key:String,actor:String="manager-demo"){require(qty>0&&key.isNotBlank());require(actor=="manager-demo"||staff.any{it.first==site&&it.second==actor}){"Vendeur hors site"};val old=sales.firstOrNull{it.id==key};if(old!=null){require(old.site==site&&old.item==id&&old.qty==qty&&old.actor==actor){"Conflit de requête"};return};val n=items.indexOfFirst{it.site==site&&it.id==id};require(n>=0&&site in cash){"Article ou caisse indisponible"};val x=items[n];require(qty<=x.prepared-x.sold){"Quantité insuffisante"};val total=Math.multiplyExact(qty,x.price);val cost=x.cost?.let{Math.multiplyExact(qty,it)};sales.add(Sale(key,site,id,qty,total,cost,actor=actor));items[n]=x.copy(sold=x.sold+qty)}
 fun expense(site:String,label:String,value:Long){require(site in cash&&label.isNotBlank()&&value>0){"Caisse ouverte, libellé et montant requis"};expenses.add(Expense(site,label,value))}
 fun expected(site:String):Long{val c=cash[site]?:error("Caisse fermée");return c.opening+sales.drop(c.salesStart).filter{it.site==site&&!it.cancelled}.sumOf{it.total}-expenses.drop(c.expensesStart).filter{it.site==site}.sumOf{it.value}}
 fun close(site:String,counted:Long,reason:String=""){require(counted>=0);val diff=counted-expected(site);require(diff==0L||reason.isNotBlank()){"Justification requise pour un écart"};closings.add(site to diff);cash.remove(site)}
 fun cancel(site:String,id:String,reason:String){require(reason.isNotBlank()){"Motif requis"};val c=cash[site]?:error("Caisse fermée");val n=sales.indexOfFirst{it.id==id&&it.site==site&&!it.cancelled};require(n>=c.salesStart&&n>=0){"Vente non annulable dans cette caisse"};val sale=sales[n];val p=items.indexOfFirst{it.site==site&&it.id==sale.item};require(p>=0&&items[p].sold>=sale.qty);items[p]=items[p].copy(sold=items[p].sold-sale.qty);sales[n]=sale.copy(cancelled=true,reason=reason)}
 fun report(site:String?,day:String?=null,period:String="jour"):Summary{val s=sales.filter{(site==null||it.site==site)&&!it.cancelled&&(day==null||periodMatch(dayKey(it.at),day,period))};val e=expenses.filter{(site==null||it.site==site)&&(day==null||periodMatch(dayKey(it.at),day,period))};val ca=s.sumOf{it.total};val charges=e.sumOf{it.value};return Summary(ca,charges,if(s.any{it.cost==null})null else ca-s.sumOf{it.cost?:0L}-charges,s.size)}
}

internal fun periodMatch(key:String,end:String,period:String):Boolean{val date=java.time.LocalDate.parse(key);val last=java.time.LocalDate.parse(end);return when(period){"jour"->date==last;"semaine"->!date.isBefore(last.minusDays((last.dayOfWeek.value-1).toLong()))&&!date.isAfter(last);"mois"->date.year==last.year&&date.month==last.month&&!date.isAfter(last);"annee"->date.year==last.year&&!date.isAfter(last);else->error("Période invalide")}}
