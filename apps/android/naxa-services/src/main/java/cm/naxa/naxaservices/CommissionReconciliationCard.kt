package cm.naxa.naxaservices

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.findViewTreeLifecycleOwner
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

private fun commissionUuid(value:String):String=UUID.fromString(value.trim()).toString().also{require(it.equals(value.trim(),ignoreCase=true))}
internal fun nativeCommissionAllocation(text:String):JSONArray {
 val rows=text.lineSequence().filter{it.isNotBlank()}.map{line->
  val parts=line.trim().split(Regex("\\s+"));require(parts.size>=2)
  val row=JSONObject().put("line_id",commissionUuid(parts[0])).put("appointment_id",commissionUuid(parts[1]))
  if(parts.size>2){
   val shares=parts.drop(2).map{part->val pair=part.split(":");require(pair.size==2);val bps=pair[1].toInt();require(bps in 1..10000);commissionUuid(pair[0]) to bps}.sortedBy{it.first}
   require(shares.size in 2..20&&shares.map{it.first}.distinct().size==shares.size&&shares.sumOf{it.second}==10000)
   row.put("shares",JSONArray(shares.map{JSONObject().put("member_id",it.first).put("share_bps",it.second)}))
  }
  row
 }.toList().sortedBy{it.getString("line_id")}
 require(rows.size in 1..30&&rows.map{it.getString("line_id")}.distinct().size==rows.size&&rows.map{it.getString("appointment_id")}.distinct().size==rows.size)
 return JSONArray(rows)
}
internal fun nativeCommissionRefund(text:String):JSONArray{
 val rows=text.lineSequence().filter{it.isNotBlank()}.map{line->
  val p=line.trim().split(Regex("\\s+"));require(p.size==3)
  val base=p[1].toLong();val delta=p[2].toLong();require(base in 1..999999999999999L&&delta in 0..999999999999999L)
  JSONObject().put("entry_id",commissionUuid(p[0])).put("refund_base_xaf",base).put("commission_xaf",delta)
 }.toList().sortedBy{it.getString("entry_id")}
 require(rows.size in 1..100&&rows.map{it.getString("entry_id")}.distinct().size==rows.size)
 return JSONArray(rows)
}
@Composable
internal fun CommissionReconciliationCard(session:AuthSession,siteId:String){
 if(!BuildConfig.COMMISSION_RECONCILIATION_ENABLED||siteId.isBlank()||session.account.roleCode!="promoter"||session.requirePasswordChange||session.accessToken.isBlank())return
 key(session.account.organizationId,session.account.memberId,session.deviceId,siteId){
  val currentSession by rememberUpdatedState(session)
  val owner=LocalView.current.findViewTreeLifecycleOwner()
  val scope=rememberCoroutineScope()
  var foreground by remember(owner){mutableStateOf(owner?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED)==true)}
  var job by remember{mutableStateOf<Job?>(null)}
  var generation by remember{mutableStateOf(0)}
  var busy by remember{mutableStateOf(false)}
  var failure by remember{mutableStateOf(false)}
  var confirmed by remember{mutableStateOf(false)}
  var enabled by remember{mutableStateOf(false)}
  var plans by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var entries by remember{mutableStateOf<List<JSONObject>>(emptyList())}
  var sourceKind by remember{mutableStateOf("appointment")}
  var sourceId by remember{mutableStateOf("")}
  var sourceService by remember{mutableStateOf("")}
  var sourceMember by remember{mutableStateOf("")}
  var sale by remember{mutableStateOf("")}
  var allocation by remember{mutableStateOf("")}
  var reason by remember{mutableStateOf("")}
  var payment by remember{mutableStateOf("")}
  var refund by remember{mutableStateOf("")}
  var pending by remember{mutableStateOf<Pair<String,String>?>(null)}
  var confirmAction by remember{mutableStateOf<Triple<String,String,String>?>(null)}
  fun tr(fr:String,en:String,ff:String)=when(session.account.defaultLocale){"en"->en;"ff-CM"->ff;else->fr}
  fun clear(){generation++;job?.cancel();job=null;busy=false;failure=false;confirmed=false;enabled=false;plans=emptyList();entries=emptyList();sale="";sourceKind="appointment";sourceId="";sourceService="";sourceMember="";allocation="";reason="";payment="";refund="";confirmAction=null}
  DisposableEffect(owner){
   val observer=LifecycleEventObserver{_,event->when(event){Lifecycle.Event.ON_RESUME->foreground=true;Lifecycle.Event.ON_PAUSE,Lifecycle.Event.ON_STOP->{foreground=false;clear()};else->Unit}}
   owner?.lifecycle?.addObserver(observer)
   onDispose{owner?.lifecycle?.removeObserver(observer);job?.cancel()}
  }
  fun run(action:String,id:String="",decision:String=""){
   if(!foreground||busy)return
   val g=++generation;busy=true;failure=false;confirmed=false
   job=scope.launch{
    try{
     suspend fun rpc(name:String,body:JSONObject=JSONObject(),withSite:Boolean=true):String{
      body.put("p_org",currentSession.account.organizationId);if(withSite)body.put("p_site",siteId)
      return StaffRosterApi.call(currentSession,"rpc/"+name,body)
     }
     fun event(key:String):String{if(pending?.first!=key)pending=key to UUID.randomUUID().toString();return pending!!.second}
     when(action){
      "register"->{require(enabled);if(sourceKind!="appointment"){val source=commissionUuid(sourceId);val service=commissionUuid(sourceService);val member=commissionUuid(sourceMember);val saleId=if(sourceKind=="work")commissionUuid(sale) else null;val shares=if(allocation.isBlank())JSONObject.NULL else nativeCommissionAllocation(source+" "+service+" "+allocation.trim()).getJSONObject(0).getJSONArray("shares");val body=JSONObject().put("p_kind",sourceKind).put("p_source",source).put("p_sale",saleId?:JSONObject.NULL).put("p_service",service).put("p_member",member).put("p_shares",shares);val eid=event("source:"+body);val r=JSONObject(rpc("ns_register_source_commission_plan",body.put("p_id",eid)));require(r.getString("id")==eid&&r.getString("state") in setOf("waiting","processed","review_required"))}else{val saleId=commissionUuid(sale);val rows=nativeCommissionAllocation(allocation);val key="register:"+saleId+":"+rows;val eid=event(key);val r=JSONObject(rpc("ns_register_commission_plan",JSONObject().put("p_sale",saleId).put("p_id",eid).put("p_allocations",rows)));require(r.getString("id")==eid&&r.getString("state") in setOf("waiting","processed","review_required"))}}
      "process"->{require(enabled);val pid=commissionUuid(id);val r=JSONObject(rpc("ns_process_commission_plan",JSONObject().put("p_id",pid)));require(r.getString("id")==pid&&r.getString("state") in setOf("waiting","processed","review_required"))}
      "review"->{require(decision in setOf("approve","reject","reverse_refund")&&reason.trim().length in 4..500);val entry=commissionUuid(id);val eid=event("review:"+entry+":"+decision+":"+reason.trim());val r=JSONObject(rpc("ns_review_settled_commission",JSONObject().put("p_entry",entry).put("p_event",eid).put("p_decision",decision).put("p_reason",reason.trim())));require(r.getString("entry_id")==entry&&r.getString("status")==if(decision=="approve")"approved" else "reversed")}
      "partial"->{require(reason.trim().length in 4..500);val pay=commissionUuid(payment);val rows=nativeCommissionRefund(refund);val eid=event("refund:"+pay+":"+rows+":"+reason.trim());val r=JSONObject(rpc("ns_reverse_partial_commissions",JSONObject().put("p_payment",pay).put("p_event",eid).put("p_allocations",rows).put("p_reason",reason.trim())));require(r.getString("id")==eid&&r.getString("status")=="recorded")}
     }
     if(!foreground||generation!=g)return@launch
     if(action!="load"){pending=null;confirmed=true}
     val catalog=JSONObject(rpc("ns_automatic_commission_catalog",withSite=false))
     val active=catalog.getJSONObject("settings").getBoolean("enabled")
     val p=JSONArray(rpc("ns_list_commission_plans"));val e=JSONArray(rpc("ns_settled_commission_queue"))
     require(p.length()<=100&&e.length()<=100)
     val nextPlans=(0 until p.length()).map{i->p.getJSONObject(i).also{commissionUuid(it.getString("id"));require(it.getString("state") in setOf("waiting","processed","review_required"))}}
     val nextEntries=(0 until e.length()).map{i->e.getJSONObject(i).also{commissionUuid(it.getString("id"));require(it.getString("status") in setOf("pending_approval","approved","paid","reversed")&&briefingCount(it.opt("commission_xaf"))>=0&&briefingCount(it.opt("base_amount_xaf"))>=0)}}
     if(foreground&&generation==g){enabled=active;plans=nextPlans;entries=nextEntries}
    }catch(c:CancellationException){throw c}catch(_:Exception){if(foreground&&generation==g){failure=true;enabled=false;plans=emptyList();entries=emptyList()}}finally{if(generation==g)busy=false}
   }
  }
  Card(Modifier.fillMaxWidth()){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
   Text(tr("Commissions automatiques","Automatic commissions","Komiisiyoŋaji otomatik"),style=MaterialTheme.typography.titleMedium)
   Text(tr("Rapprochement et décisions comptables, aucun versement automatique.","Reconciliation and accounting decisions only; no automatic payout.","Kawrital e konte tan; alaa njoɓdi otomatik."))
   Button(onClick={run("load")},enabled=foreground&&!busy){Text(tr("Charger","Load","Loow"))}
   if(enabled){
    listOf("appointment" to tr("Rendez-vous","Appointment","Kawrital"),"work" to tr("Ordre de travail","Work order","Golle"),"pressing" to tr("Ticket pressing","Pressing ticket","Tiket")).forEach{(k,l)->TextButton(onClick={sourceKind=k;allocation=""},enabled=!busy){Text((if(k==sourceKind)"✓ " else "")+l)}}
    if(sourceKind!="appointment"){OutlinedTextField(sourceId,{sourceId=it},Modifier.fillMaxWidth(),enabled=!busy,label={Text(tr("ID du travail ou ticket","Work or ticket ID","ID golle"))});OutlinedTextField(sourceService,{sourceService=it},Modifier.fillMaxWidth(),enabled=!busy,label={Text(tr("ID prestation","Service ID","ID golle"))});OutlinedTextField(sourceMember,{sourceMember=it},Modifier.fillMaxWidth(),enabled=!busy,label={Text(tr("ID exécutant","Executor ID","ID gollotooɗo"))})}
    if(sourceKind!="pressing")OutlinedTextField(sale,{sale=it},Modifier.fillMaxWidth(),enabled=!busy,label={Text(tr("ID de vente","Sale ID","ID jaaygol"))})
    OutlinedTextField(allocation,{allocation=it},Modifier.fillMaxWidth(),enabled=!busy,minLines=3,label={Text(if(sourceKind=="appointment")tr("Ligne UUID, rendez-vous UUID, parts facultatives membre:points (10 000)","Line UUID, appointment UUID, optional member:bps shares (10,000)","ID gorol, ID kawrital, geɗal gollotooɗo") else tr("Parts facultatives membre:points (10 000)","Optional member:bps shares (10,000)","Geɗal gollotooɗo"))})
    OutlinedButton(onClick={run("register")},enabled=!busy&&(if(sourceKind=="appointment")sale.isNotBlank()&&allocation.isNotBlank() else sourceId.isNotBlank()&&sourceService.isNotBlank()&&sourceMember.isNotBlank()&&(sourceKind=="pressing"||sale.isNotBlank()))){Text(tr("Enregistrer l'association","Register allocation","Winndin kawrital"))}
   }
   plans.forEach{p->Text(p.getString("sale_number")+" · "+p.getString("state"));if(enabled&&p.getString("state")=="waiting")TextButton(onClick={run("process",p.getString("id"))},enabled=!busy){Text(tr("Traiter si éligible","Process if eligible","Gollu so jaɓaama"))}}
   OutlinedTextField(reason,{reason=it.take(500)},Modifier.fillMaxWidth(),enabled=!busy,label={Text(tr("Motif","Reason","Dalilu"))})
   entries.forEach{e->Text(e.getString("member_name")+" · "+e.getString("sale_number")+" · "+e.getLong("commission_xaf")+" FCFA · "+e.getString("status"));Text(e.getString("id"),style=MaterialTheme.typography.bodySmall)
    val status=e.getString("status");val decisions=when(status){"pending_approval"->listOf("approve" to tr("Approuver","Approve","Jaɓ"),"reject" to tr("Refuser","Reject","Sal"));"approved","paid"->listOf("reverse_refund" to tr("Extourne intégrale","Full reversal","Ruttin"));else->emptyList()}
    decisions.forEach{(d,label)->TextButton(onClick={confirmAction=Triple("review",e.getString("id"),d)},enabled=!busy&&reason.trim().length>=4){Text(label)}}
   }
   if(entries.any{it.getString("status") in setOf("approved","paid")}){
    OutlinedTextField(payment,{payment=it},Modifier.fillMaxWidth(),enabled=!busy,label={Text(tr("ID du paiement remboursé","Refunded payment ID","ID njoɓdi ruttinaaɗo"))})
    OutlinedTextField(refund,{refund=it},Modifier.fillMaxWidth(),enabled=!busy,minLines=3,label={Text(tr("ID commission, base remboursée, commission à extourner (FCFA)","Entry ID, refunded base, commission reversal (XAF)","ID komiisiyoŋ e ceede ruttinaaɗe"))})
    OutlinedButton(onClick={confirmAction=Triple("partial","","")},enabled=!busy&&reason.trim().length>=4&&payment.isNotBlank()&&refund.isNotBlank()){Text(tr("Extourne partielle","Partial reversal","Ruttinol seeɗa"))}
   }
   if(confirmed)Text(tr("Action confirmée","Action confirmed","Kuugal tabbitii"))
   if(failure)Text(tr("Action refusée ou indisponible","Action refused or unavailable","Kuugal salaama"),color=MaterialTheme.colorScheme.error)
  }}
  confirmAction?.let{a->AlertDialog(onDismissRequest={confirmAction=null},title={Text(tr("Confirmer la décision","Confirm decision","Tabbitin kuugal"))},text={Text(tr("Aucun paiement n'est déclenché.","No payment will be initiated.","Njoɓdi fuɗɗotaako."))},confirmButton={TextButton(onClick={confirmAction=null;run(a.first,a.second,a.third)}){Text(tr("Confirmer","Confirm","Tabbitin"))}},dismissButton={TextButton(onClick={confirmAction=null}){Text(tr("Annuler","Cancel","Haaytu"))}})}
 }
}
