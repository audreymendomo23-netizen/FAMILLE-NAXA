package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
private data class NativeTender(val method:String="cash",val amount:String="",val reference:String="")

@Composable internal fun ZippleNativeSplitBill(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val tr:(String,String)->String={fr,eng->if(en)eng else fr};val scope=rememberCoroutineScope()
 val context=LocalContext.current;val vault=remember(context){SessionVault(context)};val pendingScope=session.organization+":"+session.member+":"+site
 val restored=remember(pendingScope){runCatching{vault.loadPendingSplit(pendingScope)}};val restoredBody=remember(pendingScope){restored.getOrNull()?.first?.let{JSONObject(it)}}
 var d by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf("")}
 var cash by remember{mutableStateOf(restoredBody?.optString("cash_id").orEmpty())};var order by remember{mutableStateOf(restoredBody?.optString("order_id").orEmpty())};var payer by remember{mutableStateOf("")};var mode by remember{mutableStateOf("items")}
 var amount by remember{mutableStateOf("")};var qty by remember{mutableStateOf<Map<Int,String>>(emptyMap())};var method by remember{mutableStateOf("cash")};var reference by remember{mutableStateOf("")};var result by remember{mutableStateOf<JSONObject?>(null)}
 var pending by remember{mutableStateOf<Pair<String,String>?>(restored.getOrNull())};var tenders by remember{mutableStateOf(listOf(NativeTender(),NativeTender()))}
 suspend fun load(){d=api.call(session,site,"split_snapshot") as? JSONObject}
 fun clearPending(){vault.clearPendingSplit(pendingScope);pending=null}
 suspend fun send(p:Pair<String,String>){try{val body=JSONObject(p.first);val action=body.optString("local_action","split_collect");body.remove("local_action");val response=api.call(session,site,action,body.put("request_id",p.second));result=if(action=="cash_record_mixed")JSONObject().put("receipt_id",response).put("balance_xaf",0)else response as? JSONObject;clearPending();payer="";amount="";reference="";qty=emptyMap();tenders=listOf(NativeTender(),NativeTender());load()}catch(e:ZippleHttpException){if(e.status==400||e.status==409)clearPending();throw e}}
 fun run(block:suspend ()->Unit){if(busy||!session.permits(site))return;busy=true;error="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){error=tr("Opération non confirmée. Réessayez avec les mêmes données.","Operation unconfirmed. Retry with the same details.")}finally{busy=false}}}
 LaunchedEffect(session.token,site){run{load()}}
 val active=d?.rows("orders")?.find{it.optString("id")==order};val effective=active?.optString("split_mode")?.takeIf{it in setOf("items","amount")}?:mode
 Text(tr("Addition fractionnée","Split bill"));if(restored.isFailure)Text(tr("Journal local indisponible : faites vérifier les règlements avant de continuer.","Local journal unavailable: verify payments before continuing."));if(error.isNotBlank())Text(error)
 OutlinedButton(enabled=!busy,onClick={run{load()}}){Text(tr("Actualiser les additions","Refresh split bills"))}
 d?.rows("cash_sessions")?.forEach{c->OutlinedButton(enabled=!busy,onClick={cash=c.optString("id")}){Text((if(cash==c.optString("id"))"✓ " else "")+c.optString("label"))}}
 d?.rows("orders")?.forEach{o->OutlinedButton(enabled=!busy,onClick={order=o.optString("id");qty=emptyMap();amount="";result=null}){Text((if(order==o.optString("id"))"✓ " else "")+"#"+o.optString("number")+" · "+o.optLong("balance_xaf")+" FCFA")}}
 if(active!=null){
  Text(tr("Reste à régler","Outstanding")+" : "+active.optLong("balance_xaf")+" FCFA")
  if(active.isNull("split_mode"))listOf("items","amount","mixed").forEach{m->OutlinedButton(enabled=!busy,onClick={mode=m}){Text((if(mode==m)"✓ " else "")+when(m){"items"->tr("Articles et quantités","Items and quantities");"amount"->tr("Montant libre","Amount");else->tr("Paiement complet multi-moyens","Complete multi-method payment")})}}
  if(effective=="mixed"){
   val methods=listOf("cash","mtn_momo","orange_money","bank","card")
   tenders.forEachIndexed{i,x->
    key(i){var open by remember{mutableStateOf(false)};Box{OutlinedButton(enabled=!busy,onClick={open=true}){Text(tr("Moyen du règlement ","Payment method ")+(i+1)+" : "+x.method)};DropdownMenu(expanded=open,onDismissRequest={open=false}){methods.forEach{m->DropdownMenuItem(text={Text(m)},onClick={open=false;tenders=tenders.mapIndexed{j,y->if(j==i)y.copy(method=m,reference="")else y}})}}}
     OutlinedTextField(x.amount,{v->tenders=tenders.mapIndexed{j,y->if(j==i)y.copy(amount=v.filter(Char::isDigit).take(10))else y}},label={Text(tr("Montant du règlement ","Payment amount ")+(i+1))})
     if(x.method!="cash")OutlinedTextField(x.reference,{v->tenders=tenders.mapIndexed{j,y->if(j==i)y.copy(reference=v.take(160))else y}},label={Text(tr("Référence du règlement ","Payment reference ")+(i+1))})
     if(tenders.size>2)OutlinedButton(enabled=!busy,onClick={tenders=tenders.filterIndexed{j,_->j!=i}}){Text(tr("Retirer le règlement ","Remove payment ")+(i+1))}
    }
   }
   OutlinedButton(enabled=!busy&&tenders.size<5,onClick={tenders=tenders+NativeTender()}){Text(tr("Ajouter un règlement","Add payment"))}
   val total=tenders.sumOf{it.amount.toLongOrNull()?:0L};val refs=tenders.filter{it.method!="cash"}.map{it.method+":"+it.reference.trim()}
   val valid=tenders.size in 2..5&&tenders.all{x->x.amount.toLongOrNull()?.let{it in 1..2147483647L}==true&&(x.method=="cash"||x.reference.trim().length>=4)}&&refs.distinct().size==refs.size&&total==active.optLong("total_xaf")
   Text(tr("Total des règlements","Payment total")+" : "+total+" FCFA")
   Button(enabled=!busy&&restored.isSuccess&&pending==null&&cash.isNotBlank()&&active.isNull("split_mode")&&valid,onClick={run{val arr=JSONArray();tenders.forEach{x->arr.put(JSONObject().put("method",x.method).put("amount_xaf",x.amount.toLong()).put("reference",if(x.method=="cash")JSONObject.NULL else x.reference.trim()))};val body=JSONObject().put("cash_id",cash).put("order_id",order).put("tenders",arr).put("local_action","cash_record_mixed");val p=body.toString() to UUID.randomUUID().toString();vault.savePendingSplit(pendingScope,p.first,p.second);pending=p;send(p)}}){Text(tr("Confirmer le paiement complet reçu","Confirm complete payment received"))}
  }else{
  OutlinedTextField(payer,{payer=it.take(80)},label={Text(tr("Personne ou groupe","Person or group"))})
  val lines=active.rows("lines")
  if(effective=="items")lines.forEach{l->val n=l.optInt("line_no");OutlinedTextField(qty[n].orEmpty(),{v->qty=qty+(n to v.filter(Char::isDigit).take(4))},label={Text(l.optString("name")+" · "+l.optInt("remaining_qty")+" · "+l.optLong("price_xaf")+" FCFA")})}
  else OutlinedTextField(amount,{amount=it.filter(Char::isDigit).take(10)},label={Text(tr("Montant partiel FCFA","Partial amount XAF"))})
  val validQty=lines.all{l->(qty[l.optInt("line_no")]?.toIntOrNull()?:0) in 0..l.optInt("remaining_qty")}
  val total=if(effective=="items")lines.sumOf{l->(qty[l.optInt("line_no")]?.toLongOrNull()?:0L)*l.optLong("price_xaf")}else amount.toLongOrNull()?:0L
  Text(tr("Part sélectionnée","Selected share")+" : "+total+" FCFA")
  listOf("cash","mtn_momo","orange_money","bank","card").forEach{m->OutlinedButton(enabled=!busy,onClick={method=m}){Text((if(method==m)"✓ " else "")+m)}}
  if(method!="cash")OutlinedTextField(reference,{reference=it.take(160)},label={Text(tr("Référence du règlement","Payment reference"))})
  Button(enabled=!busy&&restored.isSuccess&&pending==null&&cash.isNotBlank()&&payer.isNotBlank()&&total>0&&total<=active.optLong("balance_xaf")&&(effective!="items"||validQty)&&(method=="cash"||reference.trim().length>=4),onClick={run{
   val arr=JSONArray();if(effective=="items")lines.forEach{l->val n=l.optInt("line_no");val q=qty[n]?.toIntOrNull()?:0;if(q>0)arr.put(JSONObject().put("line_no",n).put("qty",q))}
   val body=JSONObject().put("cash_id",cash).put("order_id",order).put("payer",payer.trim()).put("amount_xaf",total).put("method",method).put("reference",if(method=="cash")JSONObject.NULL else reference.trim()).put("allocations",arr)
   val p=body.toString() to UUID.randomUUID().toString();vault.savePendingSplit(pendingScope,p.first,p.second);pending=p;send(p)
  }}){Text(tr("Confirmer le règlement partiel reçu","Confirm partial payment received"))}
  }
  active.rows("parts").forEach{p->Text(p.optString("payer")+" · "+p.optLong("amount_xaf")+" FCFA")}
 }
 pending?.let{p->OutlinedButton(enabled=!busy,onClick={run{send(p)}}){Text(tr("Réessayer le même règlement","Retry same payment"))}}
 result?.let{Text(tr("Règlement confirmé — solde","Payment confirmed — balance")+" : "+it.optLong("balance_xaf")+" FCFA")}
}
