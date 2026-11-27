package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

// Adapted from NAXA Services StockContent and CustomersContent. Server confirmation only.
internal object ZippleErpNumbers{
 fun milli(raw:String):Long?=if(!Regex("[0-9]{1,7}(\\.[0-9]{1,3})?").matches(raw))null else runCatching{BigDecimal(raw).movePointRight(3).longValueExact()}.getOrNull()
 fun integer(raw:String):Long?=raw.takeIf{Regex("[0-9]{1,10}").matches(it)}?.toLongOrNull()?.takeIf{it in 0..2147483647L}
}
// USB/Bluetooth keyboard scanners and manual entry share exact, fail-closed selection.
internal fun resolveInventoryScan(raw:String,lots:List<Triple<String,String,String>>,ingredients:List<Pair<String,String>>):String?{
 val code=raw.trim().uppercase(java.util.Locale.ROOT)
 if(code.isEmpty()||code.length>100)return null
 val sku=ingredients.filter{it.second.trim().uppercase(java.util.Locale.ROOT)==code}.map{it.first}.toSet()
 return lots.filter{it.first.uppercase(java.util.Locale.ROOT)==code||it.second.trim().uppercase(java.util.Locale.ROOT)==code||it.third in sku}.map{it.first}.distinct().singleOrNull()
}
internal class RequestKeys{
 private val requests=mutableMapOf<String,Pair<String,String>>()
 fun apply(action:String,body:JSONObject):JSONObject{
  val encoded=body.toString();val previous=requests[action];val id=if(previous?.first==encoded)previous.second else UUID.randomUUID().toString().also{requests[action]=encoded to it}
  return JSONObject(encoded).put("request_id",id)
 }
 fun confirmed(action:String){requests.remove(action)}
}
@Composable private fun Field(label:String,value:String,change:(String)->Unit,numeric:Boolean=false){
 OutlinedTextField(value,change,modifier=Modifier.fillMaxWidth(),label={Text(label)},singleLine=true,keyboardOptions=KeyboardOptions(keyboardType=if(numeric)KeyboardType.Decimal else KeyboardType.Text))
}
@Composable private fun Choice(label:String,items:List<Pair<String,String>>,selected:String,change:(String)->Unit,enabled:Boolean){
 var open by remember{mutableStateOf(false)}
 Box{
  OutlinedButton(enabled=enabled&&items.isNotEmpty(),onClick={open=true}){Text(label+" : "+(items.firstOrNull{it.first==selected}?.second?:"—"))}
  DropdownMenu(expanded=open,onDismissRequest={open=false}){items.forEach{(id,name)->DropdownMenuItem(text={Text(name)},onClick={change(id);open=false})}}
 }
}
@Composable fun ZippleNativeErp(api:ZippleBusiness,session:Session,site:String,en:Boolean,screen:String){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val scope=rememberCoroutineScope();val keys=remember{RequestKeys()};val context=LocalContext.current.applicationContext
 var data by remember{mutableStateOf<JSONObject?>(null)}
 var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 var tab by remember{mutableStateOf("ingredients")}
 var name by remember{mutableStateOf("")};var sku by remember{mutableStateOf("")};var unit by remember{mutableStateOf("kg")};var threshold by remember{mutableStateOf("0")};var phone by remember{mutableStateOf("")}
 var selected by remember{mutableStateOf("")};var lot by remember{mutableStateOf("")};var supplier by remember{mutableStateOf("")};var quantity by remember{mutableStateOf("")};var cost by remember{mutableStateOf("")};var expiry by remember{mutableStateOf("")}
 var category by remember{mutableStateOf("rent")};var method by remember{mutableStateOf("cash")};var reference by remember{mutableStateOf("")};var date by remember{mutableStateOf(LocalDate.now(ZoneId.of("Africa/Douala")).toString())}
 var customerSearch by remember{mutableStateOf("")};var followFilter by remember{mutableStateOf("pending")};var attachOrder by remember(selected){mutableStateOf("")};var crmOrders by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var historyFilter by remember(selected){mutableStateOf("all")};var contactText by remember(selected){mutableStateOf("")}
 var consent by remember{mutableStateOf(false)};var contactConsent by remember(selected){mutableStateOf(false)};var title by remember{mutableStateOf("")};var channel by remember{mutableStateOf("telephone")};var due by remember{mutableStateOf("")}
 val canWrite=session.role in setOf("promoteur","manager")&&!busy&&session.permits(site)
 suspend fun call(action:String,body:JSONObject=JSONObject())=api.call(session,site,action,body)
 suspend fun write(action:String,body:JSONObject){call(action,keys.apply(action,body));keys.confirmed(action)}
 suspend fun queue(action:String,body:JSONObject){require(session.permits(site)&&ZippleSyncSession.current===session&&session.role in setOf("promoteur","manager"));val dao=OfflineQueueDb.get(context).events();require(dao.blocked(session.organization,session.member,site)==0);val now=System.currentTimeMillis();dao.enqueue(OfflineEvent(eventId=UUID.randomUUID().toString(),organizationId=session.organization,memberId=session.member,siteId=site,aggregateType="erp_"+action,payloadJson=body.toString(),deviceSequence=now,createdAtEpochMs=now));ZippleSyncSession.schedule(context);message=tr("Opération en attente de validation serveur","Operation awaiting server confirmation")}
 suspend fun load(){data=call(if(screen=="crm")"crm_snapshot" else "erp_snapshot") as? JSONObject?:error("DATA");if(screen=="crm"){crmOrders=emptyList();crmOrders=(call("snapshot") as? JSONObject?:error("DATA")).rows("orders")}}
 fun run(block:suspend ()->Unit){if(busy||!session.permits(site))return;busy=true;message="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 LaunchedEffect(screen){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Données indisponibles","Data unavailable")}}
 OutlinedButton(enabled=!busy,onClick={run{load()}}){Text(tr("Actualiser les données","Refresh data"))}
 if(screen=="crm"){
  Text(tr("Relation client","Customer relationship"),style=MaterialTheme.typography.titleLarge)
  Text(tr("Fiche facultative, aucun compte client.","Optional record, no customer account."))
  val today=LocalDate.now(ZoneId.of("Africa/Douala")).toString();val allFollowups=data?.rows("followups").orEmpty();val allCustomers=data?.rows("customers").orEmpty();val pending=allFollowups.filter{it.isNull("completed_at")}
  Text(tr("Agenda des suivis du site","Site follow-up agenda"),style=MaterialTheme.typography.titleMedium)
  Text(pending.size.toString()+" "+tr("suivis ouverts","open follow-ups")+" · "+pending.count{it.optString("due_on")<today}+" "+tr("en retard","overdue")+" · "+pending.count{it.optString("due_on")==today}+" "+tr("aujourd’hui","today"))
  Text(tr("Sur les données reçues (200 suivis au maximum).","Based on received data (up to 200 follow-ups)."))
  Choice(tr("Filtrer les suivis","Filter follow-ups"),listOf("pending" to tr("À faire","Pending"),"late" to tr("En retard","Overdue"),"done" to tr("Terminés","Completed"),"all" to tr("Tous","All")),followFilter,{followFilter=it},!busy)
  val agenda=allFollowups.filter{f->when(followFilter){"all"->true;"done"->!f.isNull("completed_at");"late"->f.isNull("completed_at")&&f.optString("due_on")<today;else->f.isNull("completed_at")}}.sortedBy{it.optString("due_on")}
  if(agenda.isEmpty())Text(tr("Aucun suivi correspondant.","No matching follow-up."))
  agenda.forEach{f->val c=allCustomers.find{it.optString("id")==f.optString("customer_id")};Text(f.optString("title")+" · "+(c?.optString("display_name")?:tr("Client hors liste reçue","Customer outside received list"))+" · "+f.optString("due_on")+" · "+f.optString("channel"));if(c!=null)OutlinedButton(enabled=canWrite,onClick={customerSearch="";selected=c.optString("id");title="";due=""}){Text(tr("Ouvrir la fiche","Open customer"))};if(f.isNull("completed_at"))OutlinedButton(enabled=canWrite,onClick={run{call("followup_complete",JSONObject().put("followup_id",f.optString("id")));load()}}){Text(tr("Marquer le suivi terminé","Mark follow-up complete"))}}
  Field(tr("Nom d'usage","Display name"),name,{name=it.take(160)})
  Field(tr("Téléphone volontaire","Voluntary phone"),phone,{phone=it.take(32)})
  Row{Checkbox(consent,{consent=it},enabled=canWrite);Text(tr("Informations communiquées volontairement","Information voluntarily provided"),modifier=Modifier.padding(top=12.dp))}
  Button(enabled=canWrite&&consent&&name.trim().isNotEmpty(),onClick={run{
   val result=call("customer_add",JSONObject().put("name",name.trim()).put("phone",phone.filter(Char::isDigit))) as? String?:error("No customer")
   selected=result;name="";phone="";consent=false;load()
  }}){Text(tr("Créer la fiche","Create record"))}
  val customers=data?.rows("customers").orEmpty()
  Field(tr("Rechercher un client","Search customer"),customerSearch,{customerSearch=it.take(160);selected="";title="";due=""})
  val matches=customers.filter{c->listOf("display_name","phone").any{c.optString(it).contains(customerSearch.trim(),ignoreCase=true)}};val chosen=customers.find{it.optString("id")==selected};val visible=if(chosen!=null&&matches.none{it.optString("id")==selected})listOf(chosen)+matches else matches
  Text(matches.size.toString()+" / "+customers.size+" "+tr("clients reçus","received customers"))
  Choice(tr("Client","Customer"),visible.map{it.optString("id") to it.optString("display_name")},selected,{selected=it;title="";due=""},canWrite)
  if(selected.isNotBlank()&&customers.any{it.optString("id")==selected}){
   val linked=data?.rows("history").orEmpty().map{it.optString("order_id")}.toSet();val eligible=crmOrders.filter{it.optString("status")!="cancelled"&&!it.optBoolean("paid")&&!it.optBoolean("settled")&&it.optString("id") !in linked}
   Text(tr("Rattacher une commande non réglée","Link an unsettled order"),style=MaterialTheme.typography.titleMedium)
   Choice(tr("Commande à rattacher","Order to link"),eligible.map{it.optString("id") to (it.optString("id").take(8)+" · "+it.optLong("total_xaf")+" FCFA · "+it.optString("status"))},attachOrder,{attachOrder=it},canWrite)
   Button(enabled=canWrite&&eligible.any{it.optString("id")==attachOrder},onClick={run{require(call("customer_attach",JSONObject().put("customer_id",selected).put("order_id",attachOrder))==true);attachOrder="";load();message=tr("Commande rattachée","Order linked")}}){Text(tr("Rattacher la commande","Link order"))}
   Text(tr("Historique du site","Site history"))
   val history=data?.rows("history").orEmpty().filter{it.optString("customer_id")==selected}
   Text(history.size.toString()+" "+tr("commandes reçues","received orders"))
   Choice(tr("État du règlement","Payment status"),listOf("all" to tr("Tous","All"),"paid" to tr("Réglées","Paid"),"credit" to tr("À crédit","On credit"),"unpaid" to tr("Non réglées","Unpaid")),historyFilter,{historyFilter=it},!busy)
   val visibleHistory=history.filter{val credit=it.optString("payment_status")=="credit_due";when(historyFilter){"paid"->!credit&&it.optBoolean("paid");"credit"->credit;"unpaid"->!credit&&!it.optBoolean("paid");else->true}}
   if(visibleHistory.isEmpty())Text(tr("Aucune commande correspondante.","No matching order."))
   visibleHistory.forEach{Text(it.optString("order_id").take(8)+" · "+it.optLong("total_xaf")+" FCFA · "+if(it.optString("payment_status")=="credit_due")tr("À crédit","On credit")else if(it.optBoolean("paid"))tr("Réglée","Paid")else tr("Non réglée","Unpaid"))}
   Field(tr("Objet du suivi","Follow-up subject"),title,{title=it.take(160)})
   Choice(tr("Canal","Channel"),listOf("telephone" to tr("Téléphone","Phone"),"whatsapp" to "WhatsApp","in_person" to tr("Sur place","In person")),channel,{channel=it},canWrite)
   Field(tr("Échéance AAAA-MM-JJ","Due YYYY-MM-DD"),due,{due=it.take(10)})
   Button(enabled=canWrite&&title.isNotBlank()&&runCatching{LocalDate.parse(due)}.isSuccess,onClick={run{
    write("followup_create",JSONObject().put("customer_id",selected).put("title",title.trim()).put("channel",channel).put("due_on",due));title="";due="";load()
   }}){Text(tr("Créer le suivi","Create follow-up"))}
   val rawPhone=customers.firstOrNull{it.optString("id")==selected}?.optString("phone").orEmpty()
   val waPhone=when{Regex("[67][0-9]{8}").matches(rawPhone)->"237"+rawPhone;Regex("237[67][0-9]{8}").matches(rawPhone)->rawPhone;else->null}
   if(waPhone!=null){Row{Checkbox(checked=contactConsent,onCheckedChange={contactConsent=it});Text(tr("Je confirme être autorisé à contacter ce client.","I confirm permission to contact this customer."))}
   if(contactConsent)OutlinedTextField(contactText,{contactText=it.take(500)},label={Text(tr("Message personnalisé (facultatif)","Custom message (optional)"))},modifier=Modifier.fillMaxWidth(),enabled=canWrite)
   OutlinedButton(enabled=canWrite&&contactConsent,onClick={try{val link="https://wa.me/"+waPhone+"?text="+android.net.Uri.encode(contactText.trim().ifBlank{tr("Bonjour, nous vous contactons au sujet de votre demande auprès de notre établissement. Merci.","Hello, we are contacting you about your request with our establishment. Thank you.")});context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW,android.net.Uri.parse(link)).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))}catch(_:Exception){message=tr("WhatsApp indisponible","WhatsApp unavailable")}}){Text(tr("Ouvrir WhatsApp — vérifier avant envoi","Open WhatsApp — review before sending"))}}
   data?.rows("followups")?.filter{it.optString("customer_id")==selected}?.forEach{x->
    Text(x.optString("title")+" · "+x.optString("due_on"))
    if(x.isNull("completed_at"))OutlinedButton(enabled=canWrite,onClick={run{call("followup_complete",JSONObject().put("followup_id",x.optString("id")));load()}}){Text(tr("Clôturer le suivi","Complete follow-up"))}
    else Text(tr("Terminé","Completed"))
   }
  }
 }else{
  Text(tr("Opérations de stock","Inventory operations"),style=MaterialTheme.typography.titleLarge)
  Row(horizontalArrangement=Arrangement.spacedBy(4.dp)){
   OutlinedButton(onClick={tab="ingredients"}){Text(tr("Matières","Ingredients"))}
   OutlinedButton(onClick={tab="receipts"}){Text(tr("Lots","Lots"))}
  }
  OutlinedButton(onClick={tab="production"}){Text(tr("Production et file hors connexion","Production and offline queue"))}
  OutlinedButton(onClick={tab="counts"}){Text(tr("Comptages","Counts"))}
  OutlinedButton(onClick={tab="expenses"}){Text(tr("Dépenses","Expenses"))}
  val ingredients=data?.rows("ingredients").orEmpty()
  when(tab){
   "ingredients"->{
    Field(tr("Nom de la matière","Ingredient name"),name,{name=it.take(160)})
    Field("SKU",sku,{sku=it.take(80)})
    Field(tr("Unité","Unit"),unit,{unit=it.take(40)})
    Field(tr("Seuil","Threshold"),threshold,{threshold=it},true)
    Field("WhatsApp",phone,{phone=it.take(32)})
    Button(enabled=canWrite&&name.isNotBlank()&&unit.isNotBlank()&&ZippleErpNumbers.milli(threshold)!=null,onClick={run{
     call("ingredient_add",JSONObject().put("name",name.trim()).put("sku",sku.trim().uppercase(java.util.Locale.ROOT)).put("unit",unit.trim()).put("reorder_milli",ZippleErpNumbers.milli(threshold)).put("supplier_whatsapp",phone.filter(Char::isDigit)));name="";sku="";load()
    }}){Text(tr("Ajouter la matière","Add ingredient"))}
   }
   "receipts"->{
    Choice(tr("Matière","Ingredient"),ingredients.map{it.optString("id") to (it.optString("name")+" ("+it.optString("unit")+")")},selected,{selected=it},canWrite)
    Field(tr("Numéro de lot","Lot number"),lot,{lot=it.take(100)})
    Field(tr("Fournisseur","Supplier"),supplier,{supplier=it.take(160)})
    Field(tr("Quantité reçue","Received quantity"),quantity,{quantity=it},true)
    Field(tr("Coût total FCFA","Total XAF"),cost,{cost=it},true)
    Field(tr("Péremption AAAA-MM-JJ facultative","Optional expiry YYYY-MM-DD"),expiry,{expiry=it.take(10)})
    Button(enabled=canWrite&&selected.isNotBlank()&&lot.isNotBlank()&&supplier.isNotBlank()&&(ZippleErpNumbers.milli(quantity)?:0)>0&&ZippleErpNumbers.integer(cost)!=null&&(expiry.isBlank()||runCatching{LocalDate.parse(expiry)}.isSuccess),onClick={run{
     write("lot_receive",JSONObject().put("ingredient_id",selected).put("label",lot.trim()).put("supplier",supplier.trim()).put("qty_milli",ZippleErpNumbers.milli(quantity)).put("cost_xaf",ZippleErpNumbers.integer(cost)).put("expires_on",if(expiry.isBlank())JSONObject.NULL else expiry));lot="";quantity="";cost="";load()
    }}){Text(tr("Enregistrer la réception","Record receipt"))}
    OutlinedButton(enabled=canWrite&&selected.isNotBlank()&&lot.isNotBlank()&&supplier.isNotBlank()&&(ZippleErpNumbers.milli(quantity)?:0)>0&&ZippleErpNumbers.integer(cost)!=null&&(expiry.isBlank()||runCatching{LocalDate.parse(expiry)}.isSuccess),onClick={run{
     queue("lot_receive",JSONObject().put("ingredient_id",selected).put("label",lot.trim()).put("supplier",supplier.trim()).put("qty_milli",ZippleErpNumbers.milli(quantity)).put("cost_xaf",ZippleErpNumbers.integer(cost)).put("expires_on",if(expiry.isBlank())JSONObject.NULL else expiry));lot="";quantity="";cost=""
    }}){Text(tr("Mettre la réception en attente","Queue receipt"))}
    data?.rows("lots")?.forEach{Text(it.optString("lot_label")+" · "+BigDecimal.valueOf(it.optLong("remaining_milli"),3).stripTrailingZeros().toPlainString())}
   }
   "counts"->{
    val lots=data?.rows("lots").orEmpty();var counted by remember{mutableStateOf("")};var why by remember{mutableStateOf("")};var selectedLot by remember{mutableStateOf("")};var scanCode by remember{mutableStateOf("")}
    Field(tr("Scanner le code du lot ou SKU","Scan batch code or SKU"),scanCode,{scanCode=it.take(100)})
    OutlinedButton(enabled=!busy&&scanCode.isNotBlank(),onClick={
     val found=resolveInventoryScan(scanCode,lots.map{Triple(it.optString("id"),it.optString("lot_label"),it.optString("ingredient_id"))},ingredients.map{it.optString("id") to it.optString("sku")})
     selectedLot=found.orEmpty();counted="";why=""
     if(found==null)message=tr("Code inconnu ou ambigu : sélectionnez le lot manuellement.","Unknown or ambiguous code: select the batch manually.") else {scanCode="";message=""}
    }){Text(tr("Identifier le lot","Identify batch"))}
    Choice(tr("Lot à compter","Batch to count"),lots.map{it.optString("id") to it.optString("lot_label")},selectedLot,{selectedLot=it;counted=""},canWrite)
    val current=lots.find{it.optString("id")==selectedLot};val q=ZippleErpNumbers.milli(counted)
    current?.let{Text(tr("Stock de référence","Reference stock")+" : "+BigDecimal.valueOf(it.optLong("remaining_milli"),3).stripTrailingZeros().toPlainString())}
    Field(tr("Quantité comptée","Counted quantity"),counted,{counted=it},true);Field(tr("Motif du comptage","Count reason"),why,{why=it.take(500)})
    OutlinedButton(enabled=canWrite&&current!=null&&q!=null&&q>=0&&q<=current.optLong("remaining_milli")&&why.trim().length>=5,onClick={run{queue("count_lot",JSONObject().put("lot_id",selectedLot).put("expected_milli",requireNotNull(current).optLong("remaining_milli")).put("counted_milli",q).put("reason",why.trim()));counted="";why=""}}){Text(tr("Mettre le comptage en attente","Queue count"))}
   }
   "production"->{ZippleNativeProduction(api,session,site,en)}
   else->{
    Field(tr("Libellé","Label"),title,{title=it.take(160)})
    Choice(tr("Catégorie","Category"),listOf("rent" to tr("Loyer","Rent"),"utilities" to tr("Énergie","Utilities"),"transport" to "Transport","staff" to tr("Personnel","Staff"),"maintenance" to "Maintenance","other" to tr("Autre","Other")),category,{category=it},canWrite)
    Choice(tr("Mode de règlement","Payment method"),listOf("cash","mtn_momo","orange_money","bank","card").map{it to it},method,{method=it},canWrite)
    Field(tr("Montant FCFA","Amount XAF"),cost,{cost=it},true)
    Field(tr("Référence justificative","Evidence reference"),reference,{reference=it.take(160)})
    Field("Date AAAA-MM-JJ",date,{date=it.take(10)})
    Button(enabled=canWrite&&title.isNotBlank()&&reference.trim().length>=4&&(ZippleErpNumbers.integer(cost)?:0)>0&&runCatching{LocalDate.parse(date)}.isSuccess,onClick={run{
     write("expense_record",JSONObject().put("label",title.trim()).put("category",category).put("method",method).put("amount_xaf",ZippleErpNumbers.integer(cost)).put("reference",reference.trim()).put("expense_date",date));title="";cost="";reference="";load()
    }}){Text(tr("Enregistrer la dépense","Record expense"))}
    OutlinedButton(enabled=canWrite&&title.isNotBlank()&&reference.trim().length>=4&&(ZippleErpNumbers.integer(cost)?:0)>0&&runCatching{LocalDate.parse(date)}.isSuccess,onClick={run{
     queue("expense_record",JSONObject().put("label",title.trim()).put("category",category).put("method",method).put("amount_xaf",ZippleErpNumbers.integer(cost)).put("reference",reference.trim()).put("expense_date",date));title="";cost="";reference=""
    }}){Text(tr("Mettre la dépense en attente","Queue expense"))}
    OutlinedButton(enabled=canWrite&&title.isNotBlank()&&reference.trim().length>=4&&(ZippleErpNumbers.integer(cost)?:0)>0&&runCatching{LocalDate.parse(date)}.isSuccess,onClick={run{
     queue("expense_submit",JSONObject().put("label",title.trim()).put("category",category).put("method",method).put("amount_xaf",ZippleErpNumbers.integer(cost)).put("reference",reference.trim()).put("expense_date",date));title="";cost="";reference=""
    }}){Text(tr("Soumettre pour approbation hors connexion","Queue for offline approval"))}
    data?.rows("expenses")?.forEach{Text(it.optString("label")+" · "+it.optLong("amount_xaf")+" FCFA")}
   }
  }
  ingredients.forEach{Text(it.optString("name")+" · "+BigDecimal.valueOf(it.optLong("available_milli"),3).stripTrailingZeros().toPlainString()+" "+it.optString("unit"))}
 }
 if(message.isNotBlank())Text(message)
}

@Composable private fun ZippleNativeProduction(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr}
 val context=LocalContext.current.applicationContext;val scope=rememberCoroutineScope()
 val dao=remember(context){OfflineQueueDb.get(context).events()}
 var recipes by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var items by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var selected by remember{mutableStateOf("")};var quantity by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)}
 var message by remember{mutableStateOf("")};var queued by remember{mutableStateOf(0)};var blocked by remember{mutableStateOf(0)}
 suspend fun counts(){queued=dao.queued(session.organization,session.member,site).size;blocked=dao.blocked(session.organization,session.member,site)}
 suspend fun refresh(){
  val erp=api.call(session,site,"erp_snapshot") as? JSONObject?:error("ERP_UNAVAILABLE")
  val snapshot=api.call(session,site,"snapshot") as? JSONObject?:error("ERP_UNAVAILABLE")
  recipes=erp.rows("recipe_versions").groupBy{it.getString("item_id")}.values.mapNotNull{rows->rows.maxByOrNull{it.optInt("version")}}
  items=snapshot.rows("items");counts()
 }
 fun run(block:suspend ()->Unit){if(busy||!session.permits(site))return;busy=true;message="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 LaunchedEffect(session.token,site){try{counts();refresh()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Chargez les recettes avant de travailler hors connexion.","Load recipes before working offline.")}}
 LaunchedEffect(session.token,site){while(true){counts();kotlinx.coroutines.delay(2000)}}
 val recipe=recipes.find{it.optString("item_id")==selected};val count=quantity.toIntOrNull()
 val canQueue=session.role in setOf("promoteur","manager")&&session.permits(site)&&!busy&&blocked==0
 Text(tr("Productions à confirmer","Production awaiting confirmation"),style=MaterialTheme.typography.titleMedium)
 Text(tr("En attente","Pending")+" : "+queued+" · "+tr("À vérifier","Needs review")+" : "+blocked)
 OutlinedButton(enabled=!busy,onClick={run{refresh()}}){Text(tr("Actualiser les recettes","Refresh recipes"))}
 Choice(tr("Article produit","Produced item"),recipes.map{r->val id=r.optString("item_id");id to ((items.find{it.optString("id")==id}?.optString("name")?:id.take(8))+" · V"+r.optInt("version"))},selected,{selected=it},canQueue)
 Field(tr("Portions réellement préparées","Servings actually prepared"),quantity,{quantity=it.filter(Char::isDigit).take(5)},true)
 Button(enabled=canQueue&&recipe!=null&&count!=null&&count in 1..10000,onClick={run{
  val version=recipe?.optInt("version")?:error("VERSION_REQUIRED");val servings=count?:error("QUANTITY_REQUIRED")
  require(version>0&&session.permits(site)&&ZippleSyncSession.current===session)
  val eventId=UUID.randomUUID().toString();val now=System.currentTimeMillis()
  val payload=JSONObject().put("item_id",selected).put("servings",servings).put("expected_version",version)
  dao.enqueue(OfflineEvent(eventId=eventId,organizationId=session.organization,memberId=session.member,siteId=site,aggregateType="erp_produce",payloadJson=payload.toString(),deviceSequence=now,createdAtEpochMs=now))
  quantity="";counts();ZippleSyncSession.schedule(context)
  message=tr("En attente de validation serveur. Stock non modifié localement.","Awaiting server confirmation. Local stock unchanged.")
 }}){Text(tr("Mettre la production en attente","Queue production"))}
 OutlinedButton(enabled=!busy,onClick={run{ZippleSyncSession.schedule(context);counts()}}){Text(tr("Synchroniser les productions","Synchronize production"))}
 if(blocked>0)Text(tr("Une opération nécessite une vérification avant toute nouvelle synchronisation.","An operation requires review before further synchronization."))
 if(message.isNotBlank())Text(message)
}
