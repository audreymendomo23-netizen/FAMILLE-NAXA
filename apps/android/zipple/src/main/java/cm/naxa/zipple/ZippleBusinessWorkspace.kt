package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID

private fun JSONObject.rows(key:String):List<JSONObject> {
    val rows=optJSONArray(key)?:return emptyList()
    return (0 until rows.length()).mapNotNull{rows.optJSONObject(it)}
}

@Composable
fun ZippleBusinessWorkspace(api:ZippleBusiness,session:Session,site:String,en:Boolean){
    val tr:(String,String)->String={fr,eng->if(en)eng else fr}
    val scope=rememberCoroutineScope()
    var snapshot by remember { mutableStateOf<JSONObject?>(null) }
    var erp by remember { mutableStateOf<JSONObject?>(null) }
    var tab by remember { mutableStateOf("orders") }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var cart by remember { mutableStateOf<Map<String,Int>>(emptyMap()) }
    var orderKey by remember { mutableStateOf(UUID.randomUUID().toString()) }
    var quoteKey by remember { mutableStateOf(UUID.randomUUID().toString()) }
    var plan by remember { mutableStateOf("ACCESS") }
    var cadence by remember { mutableStateOf("monthly") }
    var provider by remember { mutableStateOf("mtn_momo") }
    var quoted by remember { mutableStateOf<JSONObject?>(null) }
    val canManage=session.role in setOf("promoteur","manager")
    suspend fun load(){snapshot=api.call(session,site,"snapshot") as? JSONObject}
    suspend fun loadErp(){erp=api.call(session,site,"erp_snapshot") as? JSONObject}
    fun run(block:suspend ()->Unit){if(busy||!session.permits(site))return;busy=true;message="";scope.launch{
        try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}
    }}
    LaunchedEffect(session.token,site){
        try{load()}catch(c:CancellationException){throw c}catch(_:Exception){snapshot=null}
    }
    val canWrite=canManage&&!busy&&session.permits(site)
    Text(tr("Gestion ZIPPLE","ZIPPLE management"),style=MaterialTheme.typography.titleLarge)
    Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){
        OutlinedButton(onClick={tab="orders"}){Text(tr("Commandes","Orders"))}
        OutlinedButton(onClick={tab="stock";run{loadErp()}}){Text(tr("Stock","Stock"))}
    }
    Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){
        OutlinedButton(onClick={tab="billing"}){Text(tr("Abonnement","Subscription"))}
        OutlinedButton(enabled=!busy,onClick={run{if(tab=="stock")loadErp() else load()}}){Text(tr("Actualiser","Refresh"))}
    }
    when(tab){
        "billing"->{
            Text(tr("Offre et période","Plan and period"))
            Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("ACCESS","PREMIUM").forEach{p->OutlinedButton(onClick={plan=p;quoteKey=UUID.randomUUID().toString();quoted=null}){Text((if(plan==p)"✓ " else "")+p)}}}
            Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("monthly","annual").forEach{c->OutlinedButton(onClick={cadence=c;quoteKey=UUID.randomUUID().toString();quoted=null}){Text((if(cadence==c)"✓ " else "")+if(c=="monthly")tr("Mensuel","Monthly")else tr("Annuel","Annual"))}}}
            Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("mtn_momo","orange_money").forEach{p->OutlinedButton(onClick={provider=p;quoteKey=UUID.randomUUID().toString();quoted=null}){Text((if(provider==p)"✓ " else "")+if(p=="mtn_momo")"MTN" else "Orange")}}}
            Button(enabled=!busy&&session.role=="promoteur",onClick={run{quoted=api.call(session,site,"quote",JSONObject().put("plan",plan).put("cadence",cadence).put("provider",provider).put("request_id",quoteKey)) as? JSONObject}}){Text(tr("Devis serveur","Server quote"))}
            quoted?.let{Text(it.optLong("amount_xaf").toString()+" FCFA");Text(tr("Intention en attente : aucun débit effectué.","Pending intent: no charge made."))}
        }
        "stock"->{
            Text(tr("Matières disponibles","Available ingredients"))
            erp?.rows("ingredients")?.forEach{i->
                val qty=i.optLong("available_milli");Text(i.optString("name")+" · "+java.math.BigDecimal.valueOf(qty,3).stripTrailingZeros().toPlainString()+" "+i.optString("unit"))
                if(qty<=i.optLong("reorder_milli"))Text(tr("Seuil atteint","Reorder threshold reached"))
            }
            erp?.let{Text(tr("Encaissements enregistrés","Recorded receipts")+" : "+it.optLong("recorded_sales_xaf")+" FCFA");Text(tr("Charges enregistrées","Recorded expenses")+" : "+it.optLong("recorded_expenses_xaf")+" FCFA");Text(tr("Marge non déterminée sans coût des ventes.","Margin unavailable without cost of sales."))}
        }
        else->{
            val current=snapshot
            if(current==null){Text(tr("Droits métier non confirmés. Consultez Abonnement.","Business rights unconfirmed. See Subscription."))}
            else if(current.isNull("mode")){Text(tr("Configurer l'établissement sur le Web.","Configure the site on Web."))}
            else{
                Text(tr("Commande au comptoir","Counter order"),style=MaterialTheme.typography.titleMedium)
                val items=current.rows("items").filter{it.optBoolean("active")&&it.optInt("available_qty")>0}
                items.forEach{i->
                    val id=i.optString("id");val count=cart[id]?:0;Text(i.optString("name")+" · "+i.optLong("price_xaf")+" FCFA")
                    Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){
                        OutlinedButton(enabled=canWrite&&count>0,onClick={cart=cart+(id to (count-1));orderKey=UUID.randomUUID().toString()}){Text("−")}
                        Text(count.toString(),modifier=Modifier.padding(top=14.dp))
                        OutlinedButton(enabled=canWrite&&count<minOf(1000,i.optInt("available_qty")),onClick={cart=cart+(id to (count+1));orderKey=UUID.randomUUID().toString()}){Text("+")}
                    }
                }
                val selected=items.filter{(cart[it.optString("id")]?:0)>0}
                Text(tr("Total indicatif","Estimated total")+" : "+selected.sumOf{it.optLong("price_xaf")*(cart[it.optString("id")]?:0)}+" FCFA")
                Button(enabled=canWrite&&selected.isNotEmpty(),onClick={run{
                    val lines=JSONArray();selected.forEach{val id=it.optString("id");lines.put(JSONObject().put("item_id",id).put("qty",cart[id]))}
                    val result=api.call(session,site,"order_create",JSONObject().put("channel","counter").put("request_id",orderKey).put("lines",lines)) as? JSONObject?:error("Missing receipt")
                    message=tr("Commande confirmée","Order confirmed")+" : "+result.getLong("total_xaf")+" FCFA"
                    cart=emptyMap();orderKey=UUID.randomUUID().toString();load()
                }}){Text(tr("Envoyer en préparation","Send to preparation"))}
                Text(tr("Tickets et préparation","Tickets and preparation"),style=MaterialTheme.typography.titleMedium)
                current.rows("orders").forEach{o->
                    Text(o.optString("status")+" · "+o.optLong("total_xaf")+" FCFA")
                    o.rows("lines").forEach{l->
                        val state=l.optString("state");val next=mapOf("received" to "preparing","preparing" to "ready","ready" to "served")[state]
                        Text(l.optString("name")+" × "+l.optInt("qty")+" · "+l.optString("post")+" · "+state)
                        if(next!=null&&o.optString("status")!="cancelled")OutlinedButton(enabled=canWrite,onClick={run{
                            api.call(session,site,"line_advance",JSONObject().put("order_id",o.optString("id")).put("item_id",l.optString("item_id")).put("next",next));load()
                        }}){Text(tr("Étape suivante","Next step"))}
                    }
                    HorizontalDivider()
                }
            }
        }
    }
    if(message.isNotBlank())Text(message)
}
