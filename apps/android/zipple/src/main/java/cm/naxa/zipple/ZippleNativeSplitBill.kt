package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID

@Composable internal fun ZippleNativeSplitBill(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr};val scope=rememberCoroutineScope()
 var d by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf("")}
 var cash by remember{mutableStateOf("")};var order by remember{mutableStateOf("")};var payer by remember{mutableStateOf("")};var mode by remember{mutableStateOf("items")}
 var amount by remember{mutableStateOf("")};var qty by remember{mutableStateOf<Map<Int,String>>(emptyMap())};var method by remember{mutableStateOf("cash")};var reference by remember{mutableStateOf("")};var result by remember{mutableStateOf<JSONObject?>(null)}
 var pending by remember{mutableStateOf<Pair<String,String>?>(null)}
 suspend fun load(){d=api.call(session,site,"split_snapshot") as? JSONObject}
 suspend fun send(p:Pair<String,String>){try{result=api.call(session,site,"split_collect",JSONObject(p.first).put("request_id",p.second)) as? JSONObject;pending=null;payer="";amount="";reference="";qty=emptyMap();load()}catch(e:ZippleHttpException){if(e.status in 400..499)pending=null;throw e}}
 fun run(block:suspend ()->Unit){if(busy||!session.permits(site))return;busy=true;error="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){error=tr("Opération non confirmée. Réessayez avec les mêmes données.","Operation unconfirmed. Retry with the same details.")}finally{busy=false}}}
 LaunchedEffect(session.token,site){run{load()}}
 val active=d?.rows("orders")?.find{it.optString("id")==order};val effective=active?.optString("split_mode")?.takeIf{it in setOf("items","amount")}?:mode
 Text(tr("Addition fractionnée","Split bill"));if(error.isNotBlank())Text(error)
 OutlinedButton(enabled=!busy,onClick={run{load()}}){Text(tr("Actualiser les additions","Refresh split bills"))}
 d?.rows("cash_sessions")?.forEach{c->OutlinedButton(enabled=!busy,onClick={cash=c.optString("id")}){Text((if(cash==c.optString("id"))"✓ " else "")+c.optString("label"))}}
 d?.rows("orders")?.forEach{o->OutlinedButton(enabled=!busy,onClick={order=o.optString("id");qty=emptyMap();amount="";result=null}){Text((if(order==o.optString("id"))"✓ " else "")+"#"+o.optString("number")+" · "+o.optLong("balance_xaf")+" FCFA")}}
 if(active!=null){
  Text(tr("Reste à régler","Outstanding")+" : "+active.optLong("balance_xaf")+" FCFA")
  if(active.isNull("split_mode"))listOf("items","amount").forEach{m->OutlinedButton(enabled=!busy,onClick={mode=m}){Text((if(mode==m)"✓ " else "")+if(m=="items")tr("Articles et quantités","Items and quantities")else tr("Montant libre","Amount"))}}
  OutlinedTextField(payer,{payer=it.take(80)},label={Text(tr("Personne ou groupe","Person or group"))})
  val lines=active.rows("lines")
  if(effective=="items")lines.forEach{l->val n=l.optInt("line_no");OutlinedTextField(qty[n].orEmpty(),{v->qty=qty+(n to v.filter(Char::isDigit).take(4))},label={Text(l.optString("name")+" · "+l.optInt("remaining_qty")+" · "+l.optLong("price_xaf")+" FCFA")})}
  else OutlinedTextField(amount,{amount=it.filter(Char::isDigit).take(10)},label={Text(tr("Montant partiel FCFA","Partial amount XAF"))})
  val validQty=lines.all{l->(qty[l.optInt("line_no")]?.toIntOrNull()?:0) in 0..l.optInt("remaining_qty")}
  val total=if(effective=="items")lines.sumOf{l->(qty[l.optInt("line_no")]?.toLongOrNull()?:0L)*l.optLong("price_xaf")}else amount.toLongOrNull()?:0L
  Text(tr("Part sélectionnée","Selected share")+" : "+total+" FCFA")
  listOf("cash","mtn_momo","orange_money","bank","card").forEach{m->OutlinedButton(enabled=!busy,onClick={method=m}){Text((if(method==m)"✓ " else "")+m)}}
  if(method!="cash")OutlinedTextField(reference,{reference=it.take(160)},label={Text(tr("Référence du règlement","Payment reference"))})
  Button(enabled=!busy&&pending==null&&cash.isNotBlank()&&payer.isNotBlank()&&total>0&&total<=active.optLong("balance_xaf")&&(effective!="items"||validQty)&&(method=="cash"||reference.trim().length>=4),onClick={run{
   val arr=JSONArray();if(effective=="items")lines.forEach{l->val n=l.optInt("line_no");val q=qty[n]?.toIntOrNull()?:0;if(q>0)arr.put(JSONObject().put("line_no",n).put("qty",q))}
   val body=JSONObject().put("cash_id",cash).put("order_id",order).put("payer",payer.trim()).put("amount_xaf",total).put("method",method).put("reference",if(method=="cash")JSONObject.NULL else reference.trim()).put("allocations",arr)
   val p=body.toString() to UUID.randomUUID().toString();pending=p;send(p)
  }}){Text(tr("Confirmer le règlement partiel reçu","Confirm partial payment received"))}
  active.rows("parts").forEach{p->Text(p.optString("payer")+" · "+p.optLong("amount_xaf")+" FCFA")}
 }
 pending?.let{p->OutlinedButton(enabled=!busy,onClick={run{send(p)}}){Text(tr("Réessayer le même règlement","Retry same payment"))}}
 result?.let{Text(tr("Règlement confirmé — solde","Payment confirmed — balance")+" : "+it.optLong("balance_xaf")+" FCFA")}
}
