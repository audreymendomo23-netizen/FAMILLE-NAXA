package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

private data class CachedSaleItem(val balanceId:String,val name:String,val available:Double,val price:Long,val onHand:Double,val version:String,val sku:String,val barcode:String,val lot:String,val location:String,val activity:String,val expiry:String,val serialized:Boolean,val activityId:String,val itemId:String,val baseUnit:String,val units:List<Pair<String,Double>>,val unitCost:String?)
private fun decodeItems(a:JSONArray):List<CachedSaleItem> = (0 until a.length()).map{
 val j=a.getJSONObject(it);CachedSaleItem(j.getString("balance_id"),j.getString("display_name"),j.getDouble("available"),j.getLong("unit_price_fcfa"),j.optDouble("quantity_on_hand",Double.NaN),j.optString("stock_version",""),j.optString("sku",""),j.optString("barcode",""),j.optString("lot_code",""),j.optString("storage_label",""),j.optString("activity_name",""),j.optString("expires_at",""),j.optBoolean("is_serialized",false),j.optString("activity_id",""),j.optString("item_id",""),j.optString("base_unit_code",""),j.optJSONArray("sale_units")?.let{u->(0 until u.length()).map{n->val x=u.getJSONObject(n);x.getString("unit_code") to x.getDouble("factor")}}?:emptyList(),if(j.isNull("unit_cost_fcfa"))null else j.optString("unit_cost_fcfa")).also{v->require(v.balanceId.isNotBlank()&&v.available.isFinite()&&v.price>=0)}
}
@Composable fun BootikSalesPanel(api:BootikApi,dao:BootikScopedDao,session:BootikSession,site:String){
 val context=LocalContext.current
 val binding=remember(session,site,dao,api){BootikSyncScope(api,dao,session,site)}
 var automatic by remember(session.member,site){mutableStateOf(false)}
 DisposableEffect(binding){BootikSync.activate(binding);onDispose{BootikSync.deactivate(binding)}}
 val org=session.organization;val member=session.member;val cacheMember=member+"@"+session.scopeStamp;val scope=rememberCoroutineScope()
 var items by remember(org,cacheMember,site){mutableStateOf<List<CachedSaleItem>>(emptyList())}
 var events by remember(org,member,site){mutableStateOf<List<BootikScopedEvent>>(emptyList())}
 var saleUnit by remember(site){mutableStateOf("")};var setupKind by remember(site){mutableStateOf("lot")};var setupCode by remember(site){mutableStateOf("")};var setupExpiry by remember(site){mutableStateOf("")};var setupOrigin by remember(site){mutableStateOf("")};var setupFactor by remember(site){mutableStateOf("1")}
 var search by remember(org,member,site){mutableStateOf("")};var page by remember(org,member,site){mutableStateOf(0)}
 val matches=remember(items,search){items.filter{v->listOf(v.name,v.sku,v.barcode,v.lot,v.location,v.activity).any{BootikCatalogSearch.matches(it,search)}}}
 var selected by remember(site){mutableStateOf("")};var quantity by remember(site){mutableStateOf("1")}
 var stockKind by remember(site){mutableStateOf("receipt")};var reason by remember(site){mutableStateOf("")};var landedCost by remember(site){mutableStateOf("")};var health by remember(site){mutableStateOf<List<JSONObject>>(emptyList())}
 var batch by remember(org,member,site){mutableStateOf<List<JSONObject>>(emptyList())};var batchReason by remember(site){mutableStateOf("")}
 var dest by remember(site){mutableStateOf("")};var transfers by remember(site){mutableStateOf<List<JSONObject>>(emptyList())};var transferId by remember(site){mutableStateOf("")};var transferQty by remember(site){mutableStateOf("")};var transferReason by remember(site){mutableStateOf("")}
 val requests=remember(org,member,site){mutableMapOf<String,Pair<String,String>>()}
 fun requestId(kind:String,p:JSONObject):String{val fp=p.toString();val old=requests[kind];if(old?.first==fp)return old.second;val id=UUID.randomUUID().toString();requests[kind]=fp to id;return id}
 var status by remember(site){mutableStateOf("")};var busy by remember(site){mutableStateOf(false)};var cacheTime by remember(site){mutableStateOf(0L)}
 suspend fun reload(){events=dao.events(org,member,site)}
 LaunchedEffect(org,member,site){dao.observeEvents(org,member,site).collect{events=it}}
 LaunchedEffect(binding,automatic){BootikSync.setAutomatic(binding,automatic);if(automatic)BootikSync.schedule(context,binding)}
 LaunchedEffect(org,cacheMember,site){try{dao.purgeCatalogVersions(org,member,cacheMember);if(session.permitsOffline(site))dao.catalog(org,cacheMember,site)?.let{items=decodeItems(JSONArray(it.itemsJson));cacheTime=it.updatedAt};reload()}catch(e:Exception){if(e is kotlinx.coroutines.CancellationException)throw e;status="Stockage local indisponible"}}
 fun task(block:suspend ()->Unit){if(busy)return;busy=true;scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status="Opération non confirmée. Vérifiez la connexion et les droits."}finally{try{reload()}catch(e:Exception){if(e is kotlinx.coroutines.CancellationException)throw e};busy=false}}}
 Text("Catalogue, caisse et synchronisation",style=MaterialTheme.typography.titleMedium)
 LaunchedEffect(session,site){while(session.permitsOffline(site))kotlinx.coroutines.delay(1000);items=emptyList();selected="";cacheTime=0}
 Text(if(cacheTime>0)"Catalogue local disponible" else "Aucun catalogue local")
 Button(enabled=!busy,onClick={task{val a=api.fetchCatalog(session,site);val decoded=decodeItems(a);val now=System.currentTimeMillis();dao.cache(BootikCatalogCache(org,cacheMember,site,a.toString(),now));items=decoded;cacheTime=now;selected="";search="";page=0;status="Catalogue actualisé"}}){Text("Actualiser le catalogue")}
 OutlinedTextField(search,{search=it;page=0;selected=""},label={Text("Nom, SKU, code-barres ou emplacement")},singleLine=true,enabled=!busy)
 Text("${matches.size} référence(s) • page ${page+1} / ${maxOf(1,(matches.size+99)/100)}")
 Row{TextButton(enabled=page>0&&!busy,onClick={page--;selected=""}){Text("Précédent")};TextButton(enabled=(page+1)*100<matches.size&&!busy,onClick={page++;selected=""}){Text("Suivant")}}
 matches.drop(page*100).take(100).forEach{i->Row{RadioButton(selected==i.balanceId,{selected=i.balanceId;saleUnit=""},enabled=!busy);Text(i.name+(if(i.lot.isNotBlank()&&i.lot!="null")" / "+i.lot else "")+" • "+i.price+" FCFA • stock "+i.available)}}
 OutlinedTextField(quantity,{quantity=it},label={Text("Quantité")},singleLine=true,enabled=!busy)
 val n=quantity.toDoubleOrNull();val item=items.firstOrNull{it.balanceId==selected}
 val chosenUnit=item?.units?.firstOrNull{it.first==saleUnit}?.first?:item?.baseUnit.orEmpty();val groupSale=item!=null&&item.itemId.isNotBlank()&&chosenUnit.isNotBlank()&&((item.lot.isNotBlank()&&item.lot!="null")||chosenUnit!=item.baseUnit||items.count{it.itemId==item.itemId}>1)
 item?.units?.forEach{(code,factor)->Row{RadioButton(chosenUnit==code,{saleUnit=code},enabled=!busy);Text("$code × $factor")}}
 if(groupSale)Text("Allocation automatique FEFO. Mouvements et transferts en unité de base.")
 if(item!=null)Text("SKU : ${item.sku} • Activité : ${item.activity} • Lot : ${item.lot} • Péremption : ${item.expiry} • Emplacement : ${item.location}")
 Button(enabled=!busy&&n!=null&&n.isFinite()&&n>0&&item!=null&&!item.serialized,onClick={task{require(session.permitsOffline(site));val id=UUID.randomUUID().toString();val payload=JSONObject().put("quantity",n!!).put("unit_price_fcfa",item!!.price).put("idempotency_key",id);if(groupSale){payload.put("item_id",item.itemId).put("unit_code",chosenUnit)}else payload.put("balance_id",item.balanceId);dao.enqueue(BootikScopedEvent(id,org,member,site,System.currentTimeMillis(),payload.toString()));status="Vente en attente, aucune confirmation serveur";if(automatic)BootikSync.schedule(context,binding)}}){Text("Mettre la vente en file")}
 if(session.role!="staff"&&item!=null&&item.itemId.isNotBlank()){
  Text("Lots et conditionnements",style=MaterialTheme.typography.titleMedium)
  listOf("lot" to "Nouveau lot","unit" to "Unité de vente").forEach{(k,label)->Row{RadioButton(setupKind==k,{setupKind=k},enabled=!busy);Text(label)}}
  OutlinedTextField(setupCode,{setupCode=it},label={Text("Code")},enabled=!busy,singleLine=true)
  if(setupKind=="lot"){OutlinedTextField(setupExpiry,{setupExpiry=it},label={Text("Péremption AAAA-MM-JJ")},enabled=!busy,singleLine=true);OutlinedTextField(setupOrigin,{setupOrigin=it},label={Text("Origine")},enabled=!busy,singleLine=true)}else OutlinedTextField(setupFactor,{setupFactor=it},label={Text("Nombre d’unités de base")},enabled=!busy,singleLine=true)
  Button(enabled=!busy&&setupCode.isNotBlank()&&!item.serialized,onClick={task{val p=JSONObject().put("kind",setupKind).put("item_id",item.itemId);if(setupKind=="lot")p.put("lot_code",setupCode.trim()).put("expiry",setupExpiry).put("origin",setupOrigin)else p.put("unit_code",setupCode.trim()).put("factor",setupFactor.toDouble());val id=requestId("setup",p);p.put("request_id",id);check(api.operation(session,site,"stock-setup",p).getString("setup_id").isNotBlank());requests.remove("setup");setupCode="";status="Configuration confirmée. Actualisez le catalogue."}}){Text("Enregistrer la configuration")}
 }
 if(session.role!="staff"){
  Text("Réceptions, pertes et comptages",style=MaterialTheme.typography.titleMedium)
  Text("Sélectionnez un article, actualisez le stock si nécessaire. Quantité ci-dessus ; aucune modification avant confirmation serveur.")
  if(item!=null&&item.version.isNotBlank())Text("Quantité physique de référence : "+item.onHand+" • Coût moyen : "+(item.unitCost?.let{"$it FCFA"}?:"Non renseigné"))
  listOf("receipt" to "Réception physique", "loss" to "Perte", "count" to "Comptage").forEach{(kind,label)->Row{RadioButton(stockKind==kind,{stockKind=kind},enabled=!busy);Text(label)}}
  if(stockKind=="receipt")OutlinedTextField(landedCost,{landedCost=it},label={Text("Coût total rendu FCFA (facultatif)")},enabled=!busy,singleLine=true)
  OutlinedTextField(reason,{if(it.length<=500)reason=it},label={Text("Motif / référence de stock")},enabled=!busy)
  Button(enabled=!busy&&item!=null&&item.version.isNotBlank()&&n!=null&&n.isFinite()&&n>=0&&(stockKind=="count"||n>0)&&reason.trim().length>=3&&(stockKind!="receipt"||landedCost.isBlank()||(landedCost.toLongOrNull()?.let{it>=0}==true)),onClick={task{
   require(session.permitsOffline(site));val id=UUID.randomUUID().toString()
   val payload=JSONObject().put("balance_id",item!!.balanceId).put("quantity",n!!).put("stock_kind",stockKind).put("expected_version",item.version).put("reason",reason.trim()).put("idempotency_key",id)
   if(stockKind=="receipt"&&landedCost.isNotBlank())payload.put("landed_cost_fcfa",landedCost.toLong());dao.enqueue(BootikScopedEvent(id,org,member,site,System.currentTimeMillis(),payload.toString()));reason="";landedCost="";status="Mouvement en attente, aucun stock confirmé";if(automatic)BootikSync.schedule(context,binding)
  }}){Text("Mettre le mouvement en file")}
 }
 if(session.role!="staff"){
  Text("Indicateurs et valorisation du stock",style=MaterialTheme.typography.titleMedium)
  Button(enabled=!busy,onClick={task{val a=api.operation(session,site,"stock-health",JSONObject()).getJSONArray("items");health=(0 until a.length()).map{a.getJSONObject(it)}}}){Text("Actualiser les alertes stock")}
  Text("${health.size} articles • ${health.count{it.optBoolean("low_stock")}} seuils atteints")
  health.filter{it.optBoolean("low_stock")||it.optInt("expiring_balances")>0||it.optInt("blocked_balances")>0||it.optInt("uncosted_balances")>0}.take(100).forEach{x->Text(x.getString("display_name")+" • disponible "+x.getString("available")+" • réassort "+x.optString("suggested_quantity","—")+" • lots proches échéance "+x.optInt("expiring_balances")+" • valeur "+if(x.isNull("valuation_fcfa"))"inconnue" else x.getString("valuation_fcfa")+" FCFA")}
  Text("Inventaire groupé (30 lignes maximum)",style=MaterialTheme.typography.titleMedium)
  Button(enabled=!busy&&item!=null&&item.activityId.isNotBlank()&&item.version.isNotBlank()&&!item.serialized&&n!=null&&n.isFinite()&&n>=0&&batch.size<30&&batch.none{it.optString("balance_id")==item.balanceId}&&(batch.isEmpty()||batch.first().optString("activity_id")==item.activityId),onClick={val it=item!!;batch=batch+JSONObject().put("balance_id",it.balanceId).put("activity_id",it.activityId).put("event_id",UUID.randomUUID().toString()).put("quantity",n!!).put("expected_version",it.version).put("name",it.name)}){Text("Ajouter au comptage groupé")}
  batch.forEach{x->Row{Text(x.getString("name")+" : "+x.getString("quantity"));TextButton(enabled=!busy,onClick={batch=batch.filter{it.getString("balance_id")!=x.getString("balance_id")}}){Text("Retirer")}}}
  OutlinedTextField(batchReason,{batchReason=it},label={Text("Motif inventaire groupé")},enabled=!busy)
  Button(enabled=!busy&&batch.isNotEmpty()&&batchReason.trim().length>=3,onClick={task{val lines=JSONArray();batch.forEach{x->lines.put(JSONObject(x.toString()).apply{remove("name");remove("activity_id")})};val p=JSONObject().put("activity_id",batch.first().getString("activity_id")).put("reason",batchReason.trim()).put("lines",lines);val id=requestId("batch",p);p.put("batch_id",id);check(api.operation(session,site,"count-batch",p).getString("batch_id")==id);requests.remove("batch");batch=emptyList();batchReason="";status="Inventaire groupé confirmé. Actualisez le catalogue."}}){Text("Valider le comptage groupé")}
  Text("Transferts inter-sites",style=MaterialTheme.typography.titleMedium)
  session.sites.filter{it.id!=site}.forEach{s->Row{RadioButton(dest==s.id,{dest=s.id},enabled=!busy);Text(s.name)}}
  OutlinedTextField(transferReason,{transferReason=it},label={Text("Motif transfert")},enabled=!busy)
  Button(enabled=!busy&&dest.isNotBlank()&&item!=null&&item.version.isNotBlank()&&!item.serialized&&n!=null&&n.isFinite()&&n>0&&transferReason.trim().length>=3,onClick={task{val p=JSONObject().put("destination_site",dest).put("balance_id",item!!.balanceId).put("quantity",n!!).put("expected_version",item.version).put("reason",transferReason.trim());val id=requestId("ship",p);p.put("transfer_id",id);check(api.operation(session,site,"transfer-ship",p).getString("transfer_id")==id);requests.remove("ship");transferReason="";status="Expédition confirmée, stock en transit. Actualisez le catalogue."}}){Text("Expédier la quantité sélectionnée")}
  Button(enabled=!busy,onClick={task{val a=api.operation(session,site,"transfers",JSONObject()).getJSONArray("transfers");transfers=(0 until a.length()).map{a.getJSONObject(it)};transferId=""}}){Text("Afficher les transferts")}
  transfers.forEach{x->Text(x.getString("display_name")+" • "+x.getString("source_name")+" → "+x.getString("destination_name")+" • "+x.getString("received")+"/"+x.getString("quantity"));if(x.getString("destination_site")==site&&x.getDouble("received")<x.getDouble("quantity"))Row{RadioButton(transferId==x.getString("id"),{transferId=x.getString("id")},enabled=!busy);Text("Réceptionner")}}
  OutlinedTextField(transferQty,{transferQty=it},label={Text("Quantité reçue")},enabled=!busy)
  Button(enabled=!busy&&transferId.isNotBlank()&&(transferQty.toDoubleOrNull()?.let{it.isFinite()&&it>0}==true)&&transferReason.trim().length>=3,onClick={task{val p=JSONObject().put("transfer_id",transferId).put("quantity",transferQty.toDouble()).put("reason",transferReason.trim());val id=requestId("receive",p);p.put("receipt_id",id);check(api.operation(session,site,"transfer-receive",p).getString("receipt_id")==id);requests.remove("receive");transfers=emptyList();transferId="";transferQty="";transferReason="";status="Réception confirmée. Actualisez le catalogue et les transferts."}}){Text("Confirmer la réception")}
 }
 Button(enabled=!busy,onClick={task{val all=dao.events(org,member,site);if(all.any{it.state in setOf("conflict","rejected")}){status="Corrigez le conflit avant de synchroniser";return@task};val count=BootikSync.flush(binding);status="$count réponse(s) traitée(s)"}}){Text("Synchroniser les ventes")}
 Row{Checkbox(automatic,{automatic=it;BootikSync.setAutomatic(binding,it)},enabled=!busy);Text("Synchroniser automatiquement au retour du réseau")}
 Text(events.count{it.state=="queued"}.toString()+" en attente")
 events.takeLast(20).reversed().forEach{e->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(6.dp)){Text(e.eventId.take(8)+" • "+when(e.state){"acknowledged"->"Confirmée";"queued"->"En attente";"discarded"->"Abandonnée";else->"Conflit / refus"});if(e.state in setOf("conflict","rejected"))TextButton(enabled=!busy,onClick={task{check(dao.discard(e.eventId,org,member,site)==1);status="Conflit abandonné localement"}}){Text("Abandonner")}}}
 Text(status)
}
