package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject

@Composable private fun MissionChoice(label:String,options:List<Pair<String,String>>,value:String,enabled:Boolean,change:(String)->Unit){
 var open by remember{mutableStateOf(false)};Box{OutlinedButton(enabled=enabled&&options.isNotEmpty(),onClick={open=true}){Text(label+" : "+(options.find{it.first==value}?.second?:"—"))};DropdownMenu(open,{open=false}){options.forEach{(id,name)->DropdownMenuItem(text={Text(name)},onClick={change(id);open=false})}}}
}
@Composable internal fun ZippleMissionWorkspace(api:ZippleBusiness,session:Session,site:String,en:Boolean){
 val t:(String,String)->String={fr,eng->if(en)eng else fr};val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
 var data by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")};var zone by remember{mutableStateOf("")};var reference by remember{mutableStateOf("")};var subtotal by remember{mutableStateOf("")};var courier by remember{mutableStateOf<Map<String,String>>(emptyMap())};var reason by remember{mutableStateOf<Map<String,String>>(emptyMap())}
 suspend fun load(){data=api.call(session,site,"connection_snapshot",JSONObject().put("page","missions")) as? JSONObject?:error("DATA")}
 fun run(block:suspend()->Unit){if(busy||!session.permits(site))return;busy=true;msg="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 fun write(op:String,p:JSONObject){if(data==null)return;run{val x=api.call(session,site,"connection_write",keys.apply(op,JSONObject().put("operation",op).put("payload",p))) as? JSONObject?:error("DATA");require(x.optBoolean("confirmed"));keys.confirmed(op);if(op=="mission_create"){reference="";subtotal=""};try{load();msg=t("Opération enregistrée","Operation saved")}catch(c:CancellationException){throw c}catch(_:Exception){data=null;msg=t("Opération confirmée ; actualisation requise","Operation confirmed; refresh required")}}}
 LaunchedEffect(session.member,site){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Données indisponibles","Data unavailable")}}
 Text(t("Missions livraison — simulation interne","Delivery missions — internal rehearsal"),style=MaterialTheme.typography.titleLarge);Text(t("Restaurant uniquement. Aucun client, GPS, commande, déplacement réel ni paiement déclenché.","Restaurant only. No customer, GPS, order, real trip or payment triggered."))
 OutlinedButton(enabled=!busy,onClick={run{load()}}){Text(t("Actualiser les missions","Refresh missions"))};if(msg.isNotBlank())Text(msg)
 val d=data?:return;if(!d.optBoolean("restaurant")){Text(t("Snack-Bar : service sur place uniquement.","Snack-Bar: on-site service only."));return}
 val owner=d.optBoolean("can_configure");val zones=d.rows("zones");val couriers=d.rows("couriers");val z=zones.find{it.optString("id")==zone};val amount=subtotal.toLongOrNull();val fee=z?.optLong("fee_xaf")
 if(owner){Text(t("Nouvelle mission de simulation","New rehearsal mission"));MissionChoice(t("Zone de simulation","Rehearsal zone"),zones.map{it.optString("id") to (it.optString("label")+" · "+it.optString("fee_xaf")+" FCFA")},zone,!busy){zone=it}
 OutlinedTextField(reference,{reference=it.take(80)},label={Text(t("Référence de test sans donnée personnelle","Test reference without personal data"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
 OutlinedTextField(subtotal,{subtotal=it.take(10)},label={Text(t("Sous-total simulé FCFA","Simulated subtotal XAF"))},enabled=!busy)
 if(amount!=null&&fee!=null&&amount>0)Text(t("Total simulé","Simulated total")+" : "+(amount+fee)+" FCFA")
 Button(enabled=!busy&&amount!=null&&amount in 1..2147483647L&&fee!=null&&amount+fee<=2147483647L&&reference.matches(Regex("[A-Za-z0-9_-]{4,80}")),onClick={write("mission_create",JSONObject().put("zone_id",zone).put("reference",reference).put("subtotal_xaf",amount).put("fee_xaf",fee))}){Text(t("Créer la mission de simulation","Create rehearsal mission"))}}
 val states=mapOf("draft" to t("Brouillon","Draft"),"preparing" to t("Préparation simulée","Simulated preparation"),"ready" to t("Prête au retrait","Ready for pickup"),"assigned" to t("Affectée","Assigned"),"accepted" to t("Acceptée","Accepted"),"picked_up" to t("Prise en charge simulée","Simulated pickup"),"en_route" to t("En route simulée","Simulated transit"),"handed_over" to t("Remise simulée","Simulated handoff"),"closed" to t("Clôturée","Closed"),"cancelled" to t("Annulée","Cancelled"))
 val transitions=mapOf("assigned" to "accepted","accepted" to "picked_up","picked_up" to "en_route","en_route" to "handed_over")
 d.rows("missions").forEach{x->val id=x.optString("id");val state=x.optString("state");Text(x.optString("reference")+" · "+x.optString("zone_label")+" · "+(states[state]?:state)+" · "+x.optString("total_xaf")+" FCFA")
 if(owner&&state in listOf("draft","preparing"))Button(enabled=!busy,onClick={write("mission_prepare",JSONObject().put("mission_id",id).put("next",if(state=="draft")"preparing" else "ready"))}){Text(if(state=="draft")t("Démarrer la préparation","Start preparation")else t("Confirmer prête au retrait","Confirm ready for pickup"))}
 if(owner&&state in listOf("ready","assigned","accepted")){MissionChoice(t("Livreur de simulation","Rehearsal courier"),couriers.map{it.optString("id") to it.optString("label")},courier[id].orEmpty(),!busy){courier=courier+(id to it)};if(state!="ready")OutlinedTextField(reason[id].orEmpty(),{reason=reason+(id to it.take(200))},label={Text(t("Motif de réaffectation","Reassignment reason"))},enabled=!busy);Button(enabled=!busy&&!courier[id].isNullOrBlank()&&(state=="ready"||reason[id].orEmpty().trim().length>=5),onClick={write("mission_assign",JSONObject().put("mission_id",id).put("courier_id",courier[id]).put("reason",reason[id].orEmpty()))}){Text(t("Affecter la mission","Assign mission"))}}
 val next=transitions[state];if(d.optBoolean("can_courier")&&x.optBoolean("mine")&&next!=null)Button(enabled=!busy,onClick={write("mission_step",JSONObject().put("mission_id",id).put("next",next))}){Text(states[next]?:next)}
 if(owner&&state in listOf("draft","preparing","ready","assigned","accepted")){OutlinedTextField(reason[id].orEmpty(),{reason=reason+(id to it.take(200))},label={Text(t("Motif d’annulation","Cancellation reason"))},enabled=!busy);OutlinedButton(enabled=!busy&&reason[id].orEmpty().trim().length>=5,onClick={write("mission_cancel",JSONObject().put("mission_id",id).put("reason",reason[id]))}){Text(t("Annuler la mission","Cancel mission"))}}
 if(owner&&state=="handed_over"&&!x.optBoolean("mine")){OutlinedTextField(reason[id].orEmpty(),{reason=reason+(id to it.take(200))},label={Text(t("Confirmation indépendante de remise simulée","Independent simulated handoff confirmation"))},enabled=!busy);Button(enabled=!busy&&reason[id].orEmpty().trim().length>=5,onClick={write("mission_close",JSONObject().put("mission_id",id).put("reason",reason[id]))}){Text(t("Clôturer la simulation","Close rehearsal"))}}
 x.rows("events").forEach{e->Text((states[e.optString("to_state")]?:e.optString("to_state"))+" · "+e.optString("created_at")+" "+e.optString("reason"))}
 }
}
