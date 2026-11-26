package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

private data class CachedSaleItem(val balanceId:String,val name:String,val available:Double,val price:Long)
private fun decodeItems(a:JSONArray):List<CachedSaleItem> = (0 until a.length()).map{
 val j=a.getJSONObject(it);CachedSaleItem(j.getString("balance_id"),j.getString("display_name"),j.getDouble("available"),j.getLong("unit_price_fcfa")).also{v->require(v.balanceId.isNotBlank()&&v.available.isFinite()&&v.price>=0)}
}
@Composable fun BootikSalesPanel(api:BootikApi,dao:BootikScopedDao,session:BootikSession,site:String){
 val org=session.organization;val member=session.member;val scope=rememberCoroutineScope()
 var items by remember(org,member,site){mutableStateOf<List<CachedSaleItem>>(emptyList())}
 var events by remember(org,member,site){mutableStateOf<List<BootikScopedEvent>>(emptyList())}
 var selected by remember(site){mutableStateOf("")};var quantity by remember(site){mutableStateOf("1")}
 var status by remember(site){mutableStateOf("")};var busy by remember(site){mutableStateOf(false)};var cacheTime by remember(site){mutableStateOf(0L)}
 suspend fun reload(){events=dao.events(org,member,site)}
 LaunchedEffect(org,member,site){try{dao.catalog(org,member,site)?.let{items=decodeItems(JSONArray(it.itemsJson));cacheTime=it.updatedAt};reload()}catch(e:Exception){if(e is kotlinx.coroutines.CancellationException)throw e;status="Stockage local indisponible"}}
 fun task(block:suspend ()->Unit){if(busy)return;busy=true;scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status="Opération non confirmée. Vérifiez la connexion et les droits."}finally{try{reload()}catch(e:Exception){if(e is kotlinx.coroutines.CancellationException)throw e};busy=false}}}
 Text("Catalogue, caisse et synchronisation",style=MaterialTheme.typography.titleMedium)
 Text(if(cacheTime>0)"Catalogue local disponible" else "Aucun catalogue local")
 Button(enabled=!busy,onClick={task{val a=api.operation(session,site,"catalog",JSONObject()).getJSONArray("items");val decoded=decodeItems(a);val now=System.currentTimeMillis();dao.cache(BootikCatalogCache(org,member,site,a.toString(),now));items=decoded;cacheTime=now;selected="";status="Catalogue actualisé"}}){Text("Actualiser le catalogue")}
 items.take(100).forEach{i->Row{RadioButton(selected==i.balanceId,{selected=i.balanceId},enabled=!busy);Text(i.name+" • "+i.price+" FCFA • stock "+i.available)}}
 OutlinedTextField(quantity,{quantity=it},label={Text("Quantité")},singleLine=true,enabled=!busy)
 val n=quantity.toDoubleOrNull();val item=items.firstOrNull{it.balanceId==selected}
 Button(enabled=!busy&&n!=null&&n.isFinite()&&n>0&&item!=null,onClick={task{require(session.permits(site));val id=UUID.randomUUID().toString();val payload=JSONObject().put("balance_id",item!!.balanceId).put("quantity",n!!).put("unit_price_fcfa",item.price).put("idempotency_key",id);dao.enqueue(BootikScopedEvent(id,org,member,site,System.currentTimeMillis(),payload.toString()));status="Vente en attente, aucune confirmation serveur"}}){Text("Mettre la vente en file")}
 Button(enabled=!busy,onClick={task{val all=dao.events(org,member,site);if(all.any{it.state in setOf("conflict","rejected")}){status="Corrigez le conflit avant de synchroniser";return@task};var count=0;for(e in all.filter{it.state=="queued"}){if(!session.permits(site))break;val state=api.syncSale(session,site,e);check(dao.acknowledge(e.eventId,org,member,site,state)==1);count++;if(state!="acknowledged")break};status="$count réponse(s) traitée(s)"}}){Text("Synchroniser les ventes")}
 Text(events.count{it.state=="queued"}.toString()+" en attente")
 events.takeLast(20).reversed().forEach{e->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(6.dp)){Text(e.eventId.take(8)+" • "+when(e.state){"acknowledged"->"Confirmée";"queued"->"En attente";"discarded"->"Abandonnée";else->"Conflit / refus"});if(e.state in setOf("conflict","rejected"))TextButton(enabled=!busy,onClick={task{check(dao.discard(e.eventId,org,member,site)==1);status="Conflit abandonné localement"}}){Text("Abandonner")}}}
 Text(status)
}
