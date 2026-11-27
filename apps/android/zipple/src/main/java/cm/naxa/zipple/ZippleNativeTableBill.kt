package cm.naxa.zipple

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray

/** Same server contracts as FloorWorkspace on Web. No locally invented payment or table state. */
@Composable internal fun ZippleNativeTableBill(api:ZippleBusiness,session:Session,site:String,en:Boolean,canTransfer:Boolean,canCash:Boolean){
    val tr:(String,String)->String={fr,english->if(en)english else fr}
    val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
    var snapshot by remember{mutableStateOf<JSONObject?>(null)}
    var bill by remember{mutableStateOf<JSONObject?>(null)}
    var source by remember{mutableStateOf("")};var target by remember{mutableStateOf("")}
    var moveOrder by remember{mutableStateOf("")};var reason by remember{mutableStateOf("")}
    var selected by remember{mutableStateOf<Set<String>>(emptySet())}
    var method by remember{mutableStateOf("cash")};var reference by remember{mutableStateOf("")}
    var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
    suspend fun reload(){
        snapshot=api.call(session,site,"snapshot") as? JSONObject?:error("SNAPSHOT")
        val active=snapshot?.rows("tables").orEmpty().any{!it.isNull("session_id")&&it.optString("session_id")==source}
        bill=if(active&&source.isNotBlank())api.call(session,site,"table_bill",JSONObject().put("table_session_id",source)) as? JSONObject else null
        selected=emptySet();moveOrder="";target="";reason=""
    }
    fun run(block:suspend()->Unit){
        if(busy||!session.permits(site))return
        busy=true;message=""
        scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:ZippleHttpException){message=when(e.status){403->tr("Action non autorisée","Action not authorized");409->tr("Addition modifiée ou indisponible — actualisez.","Bill changed or unavailable — refresh.");else->tr("Opération non confirmée","Operation unconfirmed")}}catch(_:Exception){message=tr("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}
    }
    LaunchedEffect(session.member,site){run{reload()}}
    val enabled=!busy&&session.permits(site)
    val tables=snapshot?.rows("tables").orEmpty().filter{!it.isNull("session_id")&&it.optString("session_id").isNotBlank()}
    val cash=snapshot?.optJSONObject("cash_session")?.optString("id").orEmpty()
    Text(tr("Additions par table","Bills by table"),style=MaterialTheme.typography.titleLarge)
    OutlinedButton(enabled=enabled,onClick={run{reload()}}){Text(tr("Actualiser les additions","Refresh bills"))}
    FloorChoice(tr("Table source","Source table"),tables.map{it.optString("session_id") to it.optString("label")},source,enabled){id->
        source=id;bill=null;selected=emptySet();moveOrder="";target="";reason="";run{reload()}
    }
    bill?.let{b->
        Text(tr("Total : ","Total: ")+b.optLong("total_xaf")+" FCFA")
        Text(tr("Reste à régler : ","Outstanding: ")+b.optLong("unpaid_xaf")+" FCFA")
        val orders=b.rows("orders")
        val payable=orders.filter{it.optString("status")=="served"&&it.optString("payment_status")=="unpaid"&&!it.optBoolean("settled")}
        orders.forEach{o->
            val id=o.optString("id");val number=o.optString("number")
            val label=when(o.optString("payment_status")){
                "paid"->tr("Réglée","Paid");"partial_due"->tr("Partielle","Partial");"credit_due"->tr("À crédit","On credit");else->tr("Non réglée","Unpaid")
            }
            Text("#"+number+" · "+o.optLong("total_xaf")+" FCFA · "+label)
            if(canCash&&cash.isNotBlank()&&payable.any{it.optString("id")==id}){
                FilterChip(selected=id in selected,onClick={selected=if(id in selected)selected-id else selected+id},enabled=enabled&&(id in selected||selected.size<50),label={Text(tr("Sélectionner #","Select #")+number)})
            }
        }
        if(canTransfer){
            Text(tr("Transfert d'addition","Bill transfer"),style=MaterialTheme.typography.titleMedium)
            val movable=orders.filter{it.optString("payment_status")=="unpaid"&&!it.optBoolean("settled")}
            val destinations=tables.filter{it.optString("session_id")!=source&&it.optString("kind")!="pickup"}
            FloorChoice(tr("Commande à transférer","Order to transfer"),movable.map{it.optString("id") to ("#"+it.optString("number"))},moveOrder,enabled){moveOrder=it}
            FloorChoice(tr("Table destinataire","Destination table"),destinations.map{it.optString("session_id") to it.optString("label")},target,enabled){target=it}
            OutlinedTextField(reason,{reason=it.take(500)},label={Text(tr("Motif du transfert","Transfer reason"))},enabled=enabled)
            Button(enabled=enabled&&movable.any{it.optString("id")==moveOrder}&&destinations.any{it.optString("session_id")==target}&&reason.trim().length>=5,onClick={run{
                val payload=JSONObject().put("order_id",moveOrder).put("source_session_id",source).put("target_session_id",target).put("reason",reason.trim())
                require(api.call(session,site,"bill_transfer",keys.apply("bill_transfer",payload))==true)
                keys.confirmed("bill_transfer");reload();message=tr("Transfert confirmé","Transfer confirmed")
            }}){Text(tr("Transférer l’addition","Transfer bill"))}
        }
        if(canCash&&cash.isNotBlank()){
            val amount=payable.filter{it.optString("id") in selected}.sumOf{it.optLong("total_xaf")}
            Text(tr("Total sélectionné : ","Selected total: ")+amount+" FCFA")
            FloorChoice(tr("Moyen reçu","Payment received"),listOf("cash","mtn_momo","orange_money","bank","card").map{it to it},method,enabled){method=it;reference=""}
            if(method!="cash")OutlinedTextField(reference,{reference=it.take(160)},label={Text(tr("Référence externe","External reference"))},enabled=enabled)
            Button(enabled=enabled&&selected.isNotEmpty()&&amount in 1L..2147483647L&&payable.count{it.optString("id") in selected}==selected.size&&(method=="cash"||reference.trim().length>=4),onClick={run{
                val payload=JSONObject().put("cash_id",cash).put("table_session_id",source).put("order_ids",JSONArray(selected.sorted())).put("method",method).put("amount_xaf",amount).put("reference",if(method=="cash")JSONObject.NULL else reference.trim())
                val result=api.call(session,site,"group_pay",keys.apply("group_pay",payload))
                require(result is String&&result.isNotBlank());keys.confirmed("group_pay");reference="";reload();message=tr("Règlement groupé confirmé","Group payment confirmed")
            }}){Text(tr("Confirmer le règlement groupé reçu","Confirm received group payment"))}
        }
    }
    if(message.isNotBlank())Text(message)
}
