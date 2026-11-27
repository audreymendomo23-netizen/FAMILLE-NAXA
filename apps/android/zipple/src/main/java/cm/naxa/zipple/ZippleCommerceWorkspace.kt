package cm.naxa.zipple
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
internal val commercePages=listOf(PortalPage("loyalty","Fidélité et parrainage","Loyalty and referrals",true),PortalPage("delivery","Livraison Restaurant","Restaurant delivery",true),PortalPage("connections","NAXA SECURITY et partenaires","NAXA SECURITY and partners",true))
@Composable private fun CommerceChoice(label:String,options:List<Pair<String,String>>,value:String,enabled:Boolean,onChange:(String)->Unit){
 var open by remember{mutableStateOf(false)}
 Box{OutlinedButton(enabled=enabled&&options.isNotEmpty(),onClick={open=true}){Text(label+" : "+(options.find{it.first==value}?.second?:"—"))};DropdownMenu(expanded=open,onDismissRequest={open=false}){options.forEach{(id,name)->DropdownMenuItem(text={Text(name)},onClick={onChange(id);open=false})}}}
}
@Composable private fun CommerceField(label:String,value:String,enabled:Boolean,onChange:(String)->Unit){OutlinedTextField(value,{onChange(it.take(500))},label={Text(label)},enabled=enabled,modifier=Modifier.fillMaxWidth())}
@Composable internal fun ZippleCommerceWorkspace(api:ZippleBusiness,session:Session,site:String,en:Boolean,page:String){
 val t:(String,String)->String={a,b->if(en)b else a};val scope=rememberCoroutineScope();val keys=remember{RequestKeys()};val loyal=page=="loyalty"
 var data by remember{mutableStateOf<JSONObject?>(null)};var values by remember{mutableStateOf<Map<String,String>>(emptyMap())};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 fun v(k:String)=values[k].orEmpty()
 fun set(k:String,x:String){values=values+(k to x)}
 val allowed=session.permits(site)&&!busy;val owner=data?.optBoolean("can_configure")==true
 fun number(k:String)=v(k).toIntOrNull()
 suspend fun load(){val d=api.call(session,site,if(loyal)"loyalty_snapshot" else "connection_snapshot",if(loyal)JSONObject() else JSONObject().put("page",page)) as? JSONObject?:error("DATA");data=d;if(loyal)d.optJSONObject("policy")?.let{p->values=values+listOf("step_xaf","points_per_step","referrer_points","new_customer_points").associateWith{p.optString(it)}+("enabled" to if(p.optBoolean("enabled"))"yes" else "no")}}
 fun run(block:suspend()->Unit){if(!allowed)return;busy=true;msg="";scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}}
 fun write(op:String,payload:JSONObject){run{val body=JSONObject().put("operation",op).put("payload",payload);val res=api.call(session,site,if(loyal)"loyalty_write" else "connection_write",keys.apply(op,body)) as? JSONObject?:error("DATA");require(res.optBoolean("confirmed"));keys.confirmed(op);load();msg=t("Opération enregistrée","Operation saved")}}
 LaunchedEffect(session.member,site,page){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Données indisponibles","Data unavailable")}}
 val spec=commercePages.first{it.id==page};Text(if(en)spec.en else spec.fr,style=MaterialTheme.typography.titleLarge)
 OutlinedButton(enabled=allowed,onClick={run{load()}}){Text(t("Actualiser","Refresh"))};if(msg.isNotBlank())Text(msg)
 val d=data?:return;val yesNo=listOf("yes" to t("Oui","Yes"),"no" to t("Non","No"))
 when(page){
 "loyalty"->{
 Text(t("Points non monétaires ; avantages sur commande ultérieure réglée.","Non-cash points; benefits on a later paid order."))
 if(owner){
 for((k,label) in listOf("step_xaf" to t("Tranche FCFA","XAF step"),"points_per_step" to t("Points par tranche","Points per step"),"referrer_points" to t("Bonus du parrain","Referrer bonus"),"new_customer_points" to t("Bonus du filleul","New customer bonus")))CommerceField(label,v(k),allowed){set(k,it)}
 CommerceChoice(t("Activer le barème","Enable policy"),yesNo,v("enabled").ifBlank{"no"},allowed){set("enabled",it)}
 CommerceField(t("Référence de validation","Approval reference"),v("reason"),allowed){set("reason",it)}
 Button(enabled=allowed&&(number("step_xaf")?:0)>0&&listOf("points_per_step","referrer_points","new_customer_points").all{(number(it)?:-1)>=0}&&v("reason").trim().length>=5,onClick={write("configure",JSONObject().put("expected_version",d.optJSONObject("policy")?.optInt("version")?:0).put("step_xaf",number("step_xaf")).put("points_per_step",number("points_per_step")).put("referrer_points",number("referrer_points")).put("new_customer_points",number("new_customer_points")).put("enabled",v("enabled")=="yes").put("reason",v("reason")))}){Text(t("Valider le barème","Approve policy"))}
 }
 val customers=d.rows("customers");CommerceChoice(t("Client","Customer"),customers.map{it.optString("id") to it.optString("label")},v("customer_id"),allowed){set("customer_id",it)}
 val customer=customers.find{it.optString("id")==v("customer_id")}
 if(customer!=null){Text(customer.optString("label")+" · "+customer.optString("points")+" "+t("points disponibles","available points"))
 Button(enabled=allowed,onClick={write("issue_card",JSONObject().put("customer_id",v("customer_id")))}){Text(t("Générer la carte de fidélité","Generate loyalty card"))}
 if(!customer.isNull("card")){val code=customer.optString("card");Text(code);ZippleOpaqueQr(code,t("QR de carte de fidélité","Loyalty card QR"));key(code){ZippleQrActions(code,true,en,allowed)};if(owner)OutlinedButton(enabled=allowed,onClick={write("revoke_card",JSONObject().put("customer_id",v("customer_id")))}){Text(t("Révoquer la carte","Revoke card"))}}
 Button(enabled=allowed,onClick={write("issue_code",JSONObject().put("customer_id",v("customer_id")))}){Text(t("Générer le code personnel","Generate personal code"))}
 if(!customer.isNull("code")){val code=customer.optString("code");Text(code);ZippleOpaqueQr(code,t("QR de parrainage","Referral QR"));key(code){ZippleQrActions(code,false,en,allowed)};if(owner)OutlinedButton(enabled=allowed,onClick={write("revoke_code",JSONObject().put("customer_id",v("customer_id")))}){Text(t("Révoquer le code","Revoke code"))}}
 CommerceField(t("Code du parrain","Referrer code"),v("code"),allowed){set("code",it)}
 Button(enabled=allowed&&v("code").isNotBlank(),onClick={write("apply_code",JSONObject().put("customer_id",v("customer_id")).put("code",v("code").trim()))}){Text(t("Rattacher le parrain","Link referrer"))}}
 CommerceChoice(t("Reçu réglé à qualifier","Paid receipt to qualify"),d.rows("receipts").map{it.optString("id") to (it.optString("label")+" · "+it.optString("amount_xaf")+" FCFA")},v("receipt_id"),allowed){set("receipt_id",it)}
 Button(enabled=allowed&&v("receipt_id").isNotBlank(),onClick={write("claim_receipt",JSONObject().put("receipt_id",v("receipt_id")))}){Text(t("Attribuer les points vérifiés","Award verified points"))}
 Text(t("Avantages de fidélité","Loyalty benefits"))
 if(owner){CommerceField(t("Nom de l’avantage","Benefit name"),v("benefit_label"),allowed){set("benefit_label",it)};CommerceField(t("Points requis","Required points"),v("benefit_points"),allowed){set("benefit_points",it)};CommerceChoice(t("Avantage actif","Benefit enabled"),yesNo,v("benefit_enabled").ifBlank{"yes"},allowed){set("benefit_enabled",it)};CommerceField(t("Motif de validation","Approval reason"),v("benefit_reason"),allowed){set("benefit_reason",it)}
 Button(enabled=allowed&&v("benefit_label").isNotBlank()&&(number("benefit_points")?:0) in 1..1000000&&v("benefit_reason").trim().length>=5,onClick={write("benefit_configure",JSONObject().put("label",v("benefit_label")).put("points",number("benefit_points")).put("enabled",v("benefit_enabled")!="no").put("reason",v("benefit_reason")))}){Text(t("Enregistrer l’avantage","Save benefit"))}}
 CommerceChoice(t("Avantage à remettre","Benefit to deliver"),d.rows("benefits").filter{it.optBoolean("enabled")}.map{it.optString("id") to (it.optString("label")+" · "+it.optString("points")+" pts")},v("benefit_id"),allowed){set("benefit_id",it)}
 val eligible=d.rows("redeemable_receipts").filter{it.optString("customer_id")==v("customer_id")}
 CommerceChoice(t("Commande ultérieure réglée","Later paid order"),eligible.map{it.optString("id") to (it.optString("label")+" · "+it.optString("amount_xaf")+" FCFA")},v("redeem_receipt"),allowed){set("redeem_receipt",it)}
 CommerceField(t("Preuve de remise de l’avantage","Benefit delivery evidence"),v("redeem_proof"),allowed){set("redeem_proof",it)}
 Button(enabled=allowed&&v("benefit_id").isNotBlank()&&eligible.any{it.optString("id")==v("redeem_receipt")}&&v("redeem_proof").trim().length>=5,onClick={write("redeem",JSONObject().put("receipt_id",v("redeem_receipt")).put("benefit_id",v("benefit_id")).put("proof",v("redeem_proof")))}){Text(t("Confirmer la remise et utiliser les points","Confirm delivery and spend points"))}
 d.rows("redemptions").forEach{x->val id=x.optString("id");Text(x.optString("label")+" · "+x.optString("benefit")+" · "+x.optString("points")+" pts · "+if(!x.isNull("restore_reason"))t("Restitué","Restored")else if(!x.isNull("review_reason"))t("À examiner","Review required")else t("Utilisé","Used"));Text(x.optString("proof"));if(owner&&!x.isNull("review_reason")&&x.isNull("restore_reason")){CommerceField(t("Motif de restitution","Restoration reason"),v("restore_"+id),allowed){set("restore_"+id,it)};Button(enabled=allowed&&v("restore_"+id).trim().length>=5,onClick={write("restore",JSONObject().put("redemption_id",id).put("reason",v("restore_"+id)))}){Text(t("Restituer les points après contrôle","Restore points after review"))}}}
 d.rows("referrals").forEach{Text(it.optString("referrer")+" → "+it.optString("label")+" · "+if(it.optBoolean("qualified"))t("Qualifié","Qualified")else t("En attente","Pending"))}
 d.rows("awards").forEach{Text(it.optString("label")+" · "+it.optString("points")+" · "+if(it.isNull("reversal"))t("Acquis","Earned")else t("Repris","Reversed"))}
 }
 "delivery"->{Text(if(d.optBoolean("restaurant"))t("Préparation des zones et livreurs ; commande externe non activée.","Prepare zones and couriers; external ordering not active.") else t("Snack-Bar : service sur place.","Snack-Bar: on-site service."))
 if(owner&&d.optBoolean("restaurant")){
 CommerceField(t("Nom de zone","Zone name"),v("label"),allowed){set("label",it)}
 CommerceField(t("Périmètre et consignes","Area and instructions"),v("instructions"),allowed){set("instructions",it)}
 CommerceField(t("Frais FCFA","Fee XAF"),v("fee_xaf"),allowed){set("fee_xaf",it)}
 CommerceChoice(t("Zone active dans le projet","Zone active in draft"),yesNo,v("zone_enabled").ifBlank{"yes"},allowed){set("zone_enabled",it)}
 Button(enabled=allowed&&v("label").isNotBlank()&&v("instructions").isNotBlank()&&(number("fee_xaf")?:-1)>=0,onClick={write("zone_save",JSONObject().put("label",v("label")).put("instructions",v("instructions")).put("fee_xaf",number("fee_xaf")).put("enabled",v("zone_enabled")!="no"))}){Text(t("Enregistrer la zone","Save zone"))}
 CommerceChoice(t("Livreur de l'établissement","Site courier"),d.rows("members").map{it.optString("id") to it.optString("label")},v("member_id"),allowed){set("member_id",it)}
 CommerceChoice(t("Affectation préparée","Prepared assignment"),yesNo,v("courier_enabled").ifBlank{"yes"},allowed){set("courier_enabled",it)}
 Button(enabled=allowed&&v("member_id").isNotBlank(),onClick={write("courier_set",JSONObject().put("member_id",v("member_id")).put("enabled",v("courier_enabled")!="no"))}){Text(t("Enregistrer le livreur","Save courier"))}
 }
 d.rows("zones").forEach{x->
 Text(x.optString("label")+" · "+x.optString("fee_xaf")+" FCFA · "+x.optString("instructions")+" · "+if(x.optBoolean("active"))t("Configurée","Configured")else t("Inactive","Inactive"))
 if(owner&&d.optBoolean("restaurant"))OutlinedButton(enabled=allowed,onClick={values=values+mapOf("label" to x.optString("label"),"instructions" to x.optString("instructions"),"fee_xaf" to x.optString("fee_xaf"),"zone_enabled" to if(x.optBoolean("active"))"yes" else "no")}){Text(t("Modifier la zone","Edit zone")+" : "+x.optString("label"))}
 };d.rows("members").filter{it.optBoolean("enabled")}.forEach{x->
 Text(t("Livreur affecté","Assigned courier")+" : "+x.optString("label"))
 if(owner&&d.optBoolean("restaurant"))OutlinedButton(enabled=allowed,onClick={write("courier_set",JSONObject().put("member_id",x.optString("id")).put("enabled",false))}){Text(t("Retirer l’affectation","Remove assignment")+" : "+x.optString("label"))}
 }
 }
 "connections"->{Text(t("Demande enregistrée localement ; aucun flux vidéo ou accès externe ouvert.","Local request only; no video or external access opened."))
 if(owner){CommerceChoice(t("Solution","Solution"),listOf("naxa_security" to "NAXA SECURITY","naxa_hotel" to "NAXA HOTEL","grillad" to "GRILLAD"),v("partner"),allowed){set("partner",it)}
 CommerceField(t("Référence de l'établissement partenaire","Partner site reference"),v("external_reference"),allowed){set("external_reference",it)}
 CommerceField(t("Motif du raccordement","Link reason"),v("reason"),allowed){set("reason",it)}
 Button(enabled=allowed&&v("partner").isNotBlank()&&v("external_reference").trim().length>=4&&v("reason").trim().length>=5,onClick={write("request_link",JSONObject().put("partner",v("partner")).put("external_reference",v("external_reference")).put("reason",v("reason")))}){Text(t("Enregistrer la demande de raccordement","Save link request"))}}
 d.rows("rows").forEach{x->Text(x.optString("partner")+" · "+x.optString("external_reference")+" · "+if(x.optString("state")=="requested")t("Demande enregistrée — non connectée","Request saved — not connected")else t("Annulée","Cancelled"));if(owner&&x.optString("state")=="requested")OutlinedButton(enabled=allowed,onClick={write("cancel_link",JSONObject().put("link_id",x.optString("id")))}){Text(t("Annuler la demande","Cancel request"))}}
 }
 }
}
