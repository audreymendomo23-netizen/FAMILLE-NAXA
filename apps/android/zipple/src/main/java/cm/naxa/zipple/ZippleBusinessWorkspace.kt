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

internal fun JSONObject.rows(key:String):List<JSONObject> {
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
    var opening by remember { mutableStateOf("") };var counted by remember { mutableStateOf("") };var cashMethod by remember { mutableStateOf("cash") };var cashRef by remember { mutableStateOf("") };var closeResult by remember { mutableStateOf<JSONObject?>(null) }
    val settlementKeys=remember { mutableMapOf<String,Pair<String,String>>() }
    var channel by remember { mutableStateOf("counter") };var tableSession by remember { mutableStateOf("") }
    val canManage=session.role in setOf("promoteur","manager")
    suspend fun load(){snapshot=api.call(session,site,"snapshot") as? JSONObject}
    suspend fun loadErp(){erp=api.call(session,site,"erp_snapshot") as? JSONObject}
    fun run(block:suspend ()->Unit){if(busy||!session.permits(site))return;busy=true;message="";scope.launch{
        try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}
    }}
    LaunchedEffect(session.token,site){
        try{load()}catch(c:CancellationException){throw c}catch(_:Exception){snapshot=null}
    }
    val operationalRoles=snapshot?.optJSONArray("operation_roles")
    val canServe=canManage||(operationalRoles!=null&&(0 until operationalRoles.length()).any{operationalRoles.optString(it) in setOf("server","floor")})
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
    Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){
        OutlinedButton(onClick={tab="tables";run{load()}}){Text(tr("Tables","Tables"))}
        OutlinedButton(onClick={tab="cash";run{load()}}){Text(tr("Caisse","Cash"))}
    }
    Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){
        OutlinedButton(onClick={tab="erp_write"}){Text(tr("Opérations stock","Stock operations"))}
        OutlinedButton(onClick={tab="crm"}){Text(tr("Clients","Customers"))}
    }
    if(canManage)OutlinedButton(onClick={tab="bulk3"}){Text(tr("ERP 360° — gestion complète","ERP 360° — management"))}
    if(canServe)OutlinedButton(onClick={tab="support"}){Text(tr("Assistance commandes","Order assistance"))}
    if(canManage)OutlinedButton(onClick={tab="pilotage"}){Text(tr("Performance service","Service performance"))}
    if(canManage)OutlinedButton(onClick={tab="documents"}){Text(tr("Justificatifs","Documents"))}
    when(tab){
        "support"->{key(session.member,site){ZippleNativeOrderSupport(api,session,site,en)}}
        "pilotage"->{key(session.member,site){ZippleNativeServicePerformance(api,session,site,en)}}
        "documents"->{key(session.member,site){ZippleNativeDocuments(api,session,site,en)}}
        "bulk3"->{key(session.member,site){ZippleNativeBulk3(api,session,site,en)}}
        "erp_write","crm"->{key(tab){ZippleNativeErp(api,session,site,en,tab)}}
        "tables"->{
            Text(tr("Tables et sessions","Tables and sessions"))
            snapshot?.rows("tables")?.forEach{x->
                val active=x.optString("session_id").takeIf{it.isNotBlank()&&it!="null"}
                Text(x.optString("label")+" · "+if(active!=null)tr("Ouverte","Open")else tr("Libre","Free"))
                OutlinedButton(enabled=canWrite,onClick={run{
                    if(active==null)api.call(session,site,"table_open",JSONObject().put("table_id",x.optString("id")))
                    else api.call(session,site,"table_close",JSONObject().put("table_session_id",active))
                    load()
                }}){Text(if(active==null)tr("Ouvrir","Open")else tr("Fermer","Close"))}
            }
            Text(tr("Création des tables et QR sur le Web.","Create tables and QR on Web."))
        }
        "cash"->{
            Text(tr("Caisse et clôture","Cash session and closing"))
            val cash=snapshot?.optJSONObject("cash_session")?.optString("id").orEmpty()
            if(cash.isBlank()){
                OutlinedTextField(opening,{opening=it.filter(Char::isDigit).take(10)},label={Text(tr("Fond initial FCFA","Opening cash XAF"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number))
                Button(enabled=canWrite&&opening.toLongOrNull()?.let{it in 0..2147483647L}==true,onClick={run{api.call(session,site,"cash_open",JSONObject().put("opening_xaf",opening.toLong()));load()}}){Text(tr("Ouvrir la caisse","Open cash session"))}
            }else{
                Text(tr("Caisse ouverte","Cash session open"))
                Text(tr("Règlement déjà reçu, aucun débit API.","Payment already received, no API charge."))
                listOf("cash","mtn_momo","orange_money","bank","card").forEach{method->OutlinedButton(enabled=canWrite,onClick={cashMethod=method;cashRef=""}){Text((if(cashMethod==method)"✓ " else "")+method)}}
                if(cashMethod!="cash")OutlinedTextField(cashRef,{cashRef=it.take(160)},label={Text(tr("Référence","Reference"))})
                snapshot?.rows("orders")?.filter{it.optString("status")=="served"&&!it.optBoolean("settled",it.optBoolean("paid"))}?.forEach{o->
                    val oid=o.optString("id")
                    Text(o.optLong("total_xaf").toString()+" FCFA")
                    Button(enabled=canWrite&&(cashMethod=="cash"||cashRef.trim().length>=4),onClick={run{
                        val body=JSONObject().put("cash_id",cash).put("order_id",oid).put("method",cashMethod).put("amount_xaf",o.optLong("total_xaf")).put("reference",if(cashMethod=="cash")JSONObject.NULL else cashRef.trim())
                        val encoded=body.toString();val saved=settlementKeys[oid];val request=if(saved?.first==encoded)saved.second else UUID.randomUUID().toString().also{settlementKeys[oid]=encoded to it}
                        api.call(session,site,"cash_record",body.put("request_id",request));settlementKeys.remove(oid);cashRef="";load()
                    }}){Text(tr("Confirmer le règlement reçu","Confirm payment received"))}
                }
                OutlinedTextField(counted,{counted=it.filter(Char::isDigit).take(10)},label={Text(tr("Espèces comptées","Counted cash"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number))
                Button(enabled=canWrite&&counted.toLongOrNull()?.let{it in 0..2147483647L}==true,onClick={run{closeResult=api.call(session,site,"cash_close",JSONObject().put("cash_id",cash).put("counted_xaf",counted.toLong())) as? JSONObject;load()}}){Text(tr("Clôturer","Close cash session"))}
            }
            closeResult?.let{Text(tr("Écart de caisse","Cash variance")+" : "+it.optLong("variance_xaf")+" FCFA")}
        }
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
            erp?.let{Text(tr("Ventes enregistrées","Recorded sales")+" : "+it.optLong("recorded_sales_xaf")+" FCFA");Text(tr("Encaissements enregistrés","Recorded collections")+" : "+it.optLong("recorded_receipts_xaf",it.optLong("recorded_sales_xaf"))+" FCFA");Text(tr("Charges enregistrées","Recorded expenses")+" : "+it.optLong("recorded_expenses_xaf")+" FCFA");if(it.isNull("recorded_cost_xaf"))Text(tr("Marge non déterminée sans coût des ventes.","Margin unavailable without cost of sales."))else{Text(tr("Coût des ventes enregistrées","Cost of recorded sales")+" : "+it.optLong("recorded_cost_xaf")+" FCFA");Text(tr("Marge brute enregistrée","Recorded gross margin")+" : "+(it.optLong("recorded_sales_xaf")-it.optLong("recorded_cost_xaf"))+" FCFA")}}
        }
        else->{
            val current=snapshot
            if(current==null){Text(tr("Droits métier non confirmés. Consultez Abonnement.","Business rights unconfirmed. See Subscription."))}
            else if(current.isNull("mode")){Text(tr("Configurer l'établissement sur le Web.","Configure the site on Web."))}
            else{
                Text(tr("Nouvelle commande","New order"),style=MaterialTheme.typography.titleMedium)
                listOf("counter","takeaway","table").forEach{c->OutlinedButton(enabled=canWrite,onClick={channel=c;tableSession="";orderKey=UUID.randomUUID().toString()}){Text((if(channel==c)"✓ " else "")+when(c){"counter"->tr("Comptoir","Counter");"takeaway"->tr("À emporter","Takeaway");else->tr("À table","Table")})}}
                if(channel=="table")current.rows("tables").filter{!it.isNull("session_id")&&it.optString("kind")!="pickup"}.forEach{x->val ts=x.optString("session_id");OutlinedButton(enabled=canWrite,onClick={tableSession=ts;orderKey=UUID.randomUUID().toString()}){Text((if(tableSession==ts)"✓ " else "")+x.optString("label"))}}
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
                Button(enabled=canWrite&&selected.isNotEmpty()&&(channel!="table"||tableSession.isNotBlank()),onClick={run{
                    val lines=JSONArray();selected.forEach{val id=it.optString("id");lines.put(JSONObject().put("item_id",id).put("qty",cart[id]))}
                    val result=api.call(session,site,"order_create",JSONObject().put("channel",channel).put("table_session_id",if(channel=="table")tableSession else JSONObject.NULL).put("request_id",orderKey).put("lines",lines)) as? JSONObject?:error("Missing receipt")
                    message=tr("Commande confirmée","Order confirmed")+" : "+result.getLong("total_xaf")+" FCFA"
                    cart=emptyMap();orderKey=UUID.randomUUID().toString();load()
                }}){Text(tr("Envoyer en préparation","Send to preparation"))}
                Text(tr("Tickets et préparation","Tickets and preparation"),style=MaterialTheme.typography.titleMedium)
                current.rows("orders").forEach{o->
                    Text("#"+o.optString("number")+" · "+o.optString("status")+" · "+o.optLong("total_xaf")+" FCFA")
                    if(o.optString("channel")=="table")Text(tr("Table : ","Table: ")+(current.rows("tables").find{it.optString("session_id")==o.optString("table_session_id")}?.optString("label")?:"—"))
                    o.rows("lines").forEach{l->
                        val state=l.optString("state");val next=mapOf("received" to "preparing","preparing" to "ready","ready" to "served")[state]
                        Text(l.optString("name")+" × "+l.optInt("qty")+" · "+l.optString("post")+" · "+state)
                        if(next!=null&&o.optString("status")!="cancelled"&&(canManage||(canServe&&next=="served")))OutlinedButton(enabled=!busy&&session.permits(site),onClick={run{
                            api.call(session,site,"line_advance",JSONObject().put("order_id",o.optString("id")).put("item_id",l.optString("item_id")).put("next",next));load()
                        }}){Text(if(current.optJSONObject("mode")?.optString("space")=="snack_bar"&&o.optString("channel")=="table"&&next=="served")tr("Remettre au client","Hand to customer")else tr("Étape suivante","Next step"))}
                    }
                    HorizontalDivider()
                }
            }
        }
    }
    if(message.isNotBlank())Text(message)
}
