package cm.naxa.naxaservices

import cm.naxa.naxaservices.data.*
import org.json.JSONObject
import java.time.Instant

private fun JSONObject.sText(key:String, fallback:String=""):String {
    val v=optString(key); return if(v.isBlank()||v=="null") fallback else v
}
private fun JSONObject.sLong(key:String, fallback:Long=0L)=if(isNull(key)) fallback else optLong(key,fallback)
private fun JSONObject.sDouble(key:String, fallback:Double=0.0)=if(isNull(key)) fallback else optDouble(key,fallback)
private fun JSONObject.sMillis(key:String, fallback:Long):Long {
    val v=sText(key); return if(v.isBlank()) fallback else runCatching{Instant.parse(v).toEpochMilli()}.getOrElse{v.toLongOrNull()?:fallback}
}
private fun JSONObject.sOptional(key:String)=sText(key).takeIf{it.isNotBlank()}

/** Applies peer changes to typed Room projections. DAO-only by design: inbound events never enqueue. */
internal object NaxaServicesPeerSyncApplier {
    suspend fun apply(dao:NaxaServicesDao, change:LocalRemoteChange):Boolean {
        val p=runCatching{JSONObject(change.projectionJson)}.getOrNull()?:return false
        val result=p.optJSONObject("server_result")?:JSONObject()
        val org=change.orgId
        val site=change.siteId?:p.sOptional("site_id")
        val actor=p.sText("actor_member_id")
        val now=p.sMillis("updated_at",p.sMillis("created_at",p.sMillis("occurred_at",change.receivedAtEpochMs)))
        val id=change.aggregateId
        when(change.actionCode) {
            "supplier.saved" -> {
                if(site==null||actor.isBlank())return false
                val sid=p.sText("supplier_id",id);val name=p.sText("name")
                if(sid.isBlank()||name.length !in 2..120)return false
                val old=dao.findSupplier(sid,org,site)
                dao.upsertRemoteSupplier(LocalSupplier(
                    sid,org,site,name,name.trim().lowercase().replace(Regex("\\s+")," "),
                    p.sText("phone"),p.sText("whatsapp"),p.sText("email"),p.sText("address"),
                    p.optInt("payment_terms_days").coerceIn(0,365),p.sText("notes"),p.optBoolean("active",true),
                    old?.createdByMemberId?:actor,old?.createdAtMillis?:now,now
                ));return true
            }
            "inventory_item.created","inventory_item.imported","inventory_item.import_updated","inventory_item.supplier_whatsapp_updated" -> {
                if(site==null)return false
                val iid=p.sText("inventory_item_id",id);val name=p.sText("name");val unit=p.sText("unit")
                if(iid.isBlank()||name.isBlank()||unit.isBlank())return false
                val old=dao.findInventoryItem(iid,org,site)
                dao.upsertRemoteInventoryItem(LocalInventoryItem(
                    iid,org,site,p.sText("sku"),name,unit,old?.quantity?:p.sDouble("quantity"),
                    p.sDouble("reorder_level"),p.optBoolean("active",old?.active?:true),
                    old?.createdAtMillis?:now,p.sText("supplier_whatsapp")
                ));return true
            }
            "inventory_movement.created","inventory_movement.import_initial","inventory_movement.import_adjustment" -> {
                if(site==null||actor.isBlank())return false
                val mid=p.sText("movement_id",id);val iid=p.sText("inventory_item_id")
                val kind=p.sText("movement_type");val delta=p.sDouble("quantity_delta",Double.NaN);val reason=p.sText("reason")
                if(mid.isBlank()||iid.isBlank()||kind !in setOf("in","consumption","loss","adjustment")||!delta.isFinite()||delta==0.0||reason.isBlank())return false
                val item=dao.findInventoryItem(iid,org,site)?:return false
                if(dao.countInventoryMovementById(org,mid)==0){
                    if(item.quantity+delta<0.0)return false
                    dao.upsertRemoteInventoryMovement(LocalInventoryMovement(mid,org,site,iid,kind,delta,reason,actor,now))
                    dao.upsertRemoteInventoryItem(item.copy(quantity=item.quantity+delta))
                };return true
            }
            "inventory_valuation.imported","inventory_valuation.import_updated","inventory_valuation.updated" -> {
                if(site==null)return false
                val iid=p.sText("inventory_item_id",id);if(iid.isBlank()||dao.findInventoryItem(iid,org,site)==null)return false
                dao.upsertInventoryValuation(LocalInventoryValuation(
                    p.sText("valuation_id",iid),org,site,iid,p.sLong("unit_cost_xaf"),p.sLong("selling_price_xaf"),now
                ));return true
            }
            "service.created","service.updated","service.configuration_updated" -> {
                if(site==null)return false
                val sid=p.sText("service_id",id);val old=dao.findService(org,site,sid)
                val code=p.sText("code",old?.code.orEmpty());val activity=p.sText("activity",old?.activity.orEmpty());val name=p.sText("name",old?.name.orEmpty())
                if(sid.isBlank()||code.isBlank()||activity.isBlank()||name.isBlank())return false
                dao.upsertRemoteService(LocalService(
                    sid,org,site,code,activity,name,
                    if(p.isNull("duration_minutes"))old?.durationMinutes else p.optInt("duration_minutes"),
                    p.sLong("price_xaf",old?.priceXaf?:0L),p.optBoolean("active",old?.active?:true),
                    old?.createdAtMillis?:now,p.sText("category",old?.category?:"general"),
                    p.sText("description",old?.description.orEmpty()),
                    p.optJSONArray("provider_member_ids")?.toString()?:old?.providerMemberIdsJson?:"[]",
                    p.optJSONArray("required_workstation_kinds")?.toString()?:old?.requiredWorkstationKindsJson?:"[]",
                    if(p.isNull("package_sessions"))old?.packageSessions else p.optInt("package_sessions")
                ));return true
            }
            "customer.created","customer.updated" -> {
                if(site==null)return false
                val cid=p.sText("customer_id",id);val name=p.sText("display_name");if(cid.isBlank()||name.isBlank())return false
                val old=dao.findCustomer(cid,org,site)
                dao.upsertRemoteCustomer(LocalCustomer(
                    cid,org,site,name,p.sText("phone_contact"),"",
                    p.optBoolean("contact_consent",old?.contactConsent?:false),old?.createdAtMillis?:now,
                    p.sText("address_line"),p.sText("neighborhood"),p.sText("landmark"),
                    if(p.isNull("latitude"))null else p.optDouble("latitude"),
                    if(p.isNull("longitude"))null else p.optDouble("longitude"),
                    null,old?.locationCapturedAtMillis,
                    p.sOptional("location_consent_at")?.let{runCatching{Instant.parse(it).toEpochMilli()}.getOrNull()}
                ));return true
            }
            "customer_followup.created" -> {
                if(site==null||actor.isBlank())return false
                val fid=p.sText("followup_id",id);val cid=p.sText("customer_id");val title=p.sText("title")
                if(fid.isBlank()||cid.isBlank()||title.isBlank()||dao.findCustomer(cid,org,site)==null)return false
                dao.upsertRemoteCustomerFollowUp(LocalCustomerFollowUp(
                    fid,org,site,cid,title,p.sText("frequency"),p.sText("channel"),p.sText("notes"),
                    p.sMillis("next_due_at",now),p.sText("status","active"),actor,now,now,null
                ));return true
            }
            "customer_followup.completed" -> {
                if(site==null)return false
                val old=dao.findCustomerFollowUp(p.sText("followup_id",id),org,site)?:return false
                dao.updateCustomerFollowUp(old.copy(status="completed",updatedAtMillis=now,lastCompletedAtMillis=p.sMillis("completed_at",now)));return true
            }
            "pressing_order.created" -> {
                if(site==null||actor.isBlank())return false
                val oid=p.sText("order_id",id);val ticket=p.sText("ticket_number");val customer=p.sText("customer_name")
                if(oid.isBlank()||ticket.isBlank()||customer.isBlank())return false
                val old=dao.findPressingOrder(oid,org,site);val deposit=p.sLong("deposit_xaf");val method=p.sOptional("deposit_payment_method")
                val depositStatus=if(deposit<=0L)"none" else if(method=="cash"&&p.sOptional("cash_session_id")!=null)"confirmed" else "pending"
                dao.upsertRemotePressingOrder(LocalPressingOrder(
                    oid,org,site,p.sOptional("workstation_id"),ticket,customer,p.sText("customer_phone"),
                    p.sText("items_summary"),p.sLong("total_xaf"),deposit,p.sMillis("promised_at",now),
                    p.sText("status","received"),method,p.sOptional("cash_session_id"),depositStatus,
                    actor,old?.createdAtMillis?:now,now
                ));return true
            }
            "pressing_order.status_changed:in_progress","pressing_order.status_changed:ready","pressing_order.status_changed:picked_up" -> {
                if(site==null||actor.isBlank())return false
                val oid=p.sText("order_id",id);val old=dao.findPressingOrder(oid,org,site)?:return false
                val next=change.actionCode.substringAfter(':')
                dao.upsertRemotePressingOrder(old.copy(status=next,updatedAtMillis=now))
                dao.upsertRemotePressingStatusEvent(LocalPressingStatusEvent(
                    change.eventId,oid,org,site,p.sText("from_status",old.status),next,actor,now,p.sText("reason")
                ));return true
            }
            "appointment.created" -> {
                if(site==null||actor.isBlank())return false
                val aid=p.sText("appointment_id",id);val customer=p.sText("customer_reference_or_name")
                val service=p.sText("service_reference_or_name");val assigned=p.sText("assigned_member_id")
                val start=p.sMillis("starts_at",0);val end=p.sMillis("ends_at",0)
                if(aid.isBlank()||customer.isBlank()||service.isBlank()||assigned.isBlank()||start<=0||end<=start)return false
                val old=dao.findAppointment(org,site,aid)
                dao.upsertRemoteAppointment(LocalAppointment(
                    aid,org,site,p.sOptional("workstation_id"),customer,service,assigned,start,end,
                    p.sLong("deposit_xaf",old?.depositXaf?:0L),p.sText("status",old?.status?:"booked"),
                    actor,old?.createdAtMillis?:now
                ));return true
            }
            "appointment.created_from_waitlist" -> return false
            "appointment.status_changed","appointment.rescheduled" -> {
                if(site==null)return false
                val old=dao.findAppointment(org,site,p.sText("appointment_id",id))?:return false
                val updated=if(change.actionCode=="appointment.rescheduled"){
                    val start=p.sMillis("starts_at",old.startsAtMillis);val end=p.sMillis("ends_at",old.endsAtMillis)
                    if(end<=start)return false
                    old.copy(startsAtMillis=start,endsAtMillis=end,assignedMemberId=p.sText("assigned_member_id",old.assignedMemberId))
                }else old.copy(status=p.sText("to_status",old.status))
                dao.upsertRemoteAppointment(updated);return true
            }
            "cash_session.opened" -> {
                if(site==null||actor.isBlank())return false
                val sid=p.sText("cash_session_id",id);val register=p.sText("register_id");val name=p.sText("register_name")
                if(sid.isBlank()||register.isBlank()||name.isBlank())return false
                val old=dao.findCashSession(sid,org,site)
                dao.upsertRemoteCashSession(LocalCashSession(
                    sid,org,site,register,name,p.sLong("opening_float_xaf"),p.sText("opened_by_member_id",actor),
                    p.sMillis("opened_at",now),old?.status?:"open",old?.closedByMemberId,old?.closedAtMillis,
                    old?.countedCloseXaf,old?.varianceXaf,old?.varianceReason
                ));return true
            }
            "cash_session.closed" -> {
                if(site==null)return false
                val old=dao.findCashSession(p.sText("cash_session_id",id),org,site)?:return false
                dao.upsertRemoteCashSession(old.copy(
                    status="closed",closedByMemberId=actor.ifBlank{old.closedByMemberId},closedAtMillis=p.sMillis("closed_at",now),
                    countedCloseXaf=p.sLong("counted_close_xaf",old.countedCloseXaf?:0L),
                    varianceXaf=p.sLong("variance_xaf",old.varianceXaf?:0L),varianceReason=p.sText("variance_reason",old.varianceReason.orEmpty()).ifBlank{old.varianceReason}
                ));return true
            }
            "sale.created" -> {
                if(site==null||actor.isBlank())return false
                val sid=p.sText("sale_id",id);val cash=p.sText("cash_session_id");val number=p.sText("sale_number");val desc=p.sText("description")
                if(sid.isBlank()||cash.isBlank()||number.isBlank()||desc.isBlank())return false
                dao.upsertRemoteSale(LocalSale(
                    sid,org,site,cash,number,desc,p.sLong("total_xaf"),p.sText("payment_method"),p.sText("status"),
                    actor,p.sMillis("created_at",now),p.sOptional("inventory_item_id"),
                    if(p.isNull("stock_quantity"))null else p.optDouble("stock_quantity"),
                    p.sLong("unit_cost_at_sale_xaf"),p.sLong("cost_of_goods_xaf"),p.optBoolean("cost_snapshot_complete")
                ));return true
            }
            "sale.mobile_money_cancelled" -> {
                if(site==null)return false
                val old=dao.findSale(org,site,p.sText("sale_id",id))?:return false
                dao.upsertRemoteSale(old.copy(status="cancelled"));return true
            }
            "expense.created" -> {
                if(site==null||actor.isBlank())return false
                val eid=p.sText("expense_id",id);val cash=p.sText("cash_session_id")
                if(eid.isBlank()||cash.isBlank())return false
                dao.upsertRemoteExpense(LocalExpense(eid,org,site,cash,p.sText("category"),p.sText("description"),p.sLong("amount_xaf"),actor,p.sMillis("occurred_at",now)));return true
            }
            "support_request.created" -> {
                val rid=p.sText("request_id",id);if(rid.isBlank())return false
                dao.upsertRemoteSupportRequest(LocalSupportRequest(rid,org,site,p.sText("subject"),p.sText("description"),p.sText("priority","normal"),"open",p.sMillis("created_at",now)));return true
            }
            "recurring_charge.saved" -> {
                if(site==null||actor.isBlank())return false
                val cid=p.sText("charge_id",id);val name=p.sText("name");if(cid.isBlank()||name.isBlank())return false
                val old=dao.findRecurringCharge(cid,org,site)
                dao.upsertRemoteRecurringCharge(LocalRecurringCharge(
                    cid,org,site,name,p.sText("category"),p.sLong("amount_xaf"),p.sText("recurrence"),
                    p.sMillis("next_due_at",now),p.optInt("reminder_days",old?.reminderDays?:0),p.optBoolean("active",true),
                    p.sText("created_by_member_id",old?.createdByMemberId?:actor),old?.createdAtMillis?:p.sMillis("created_at",now),now,null
                ));return true
            }
            "recurring_charge.deactivated" -> {
                if(site==null)return false
                val old=dao.findRecurringCharge(p.sText("charge_id",id),org,site)?:return false
                dao.upsertRemoteRecurringCharge(old.copy(active=false,updatedAtMillis=now,lastReminderAtMillis=null));return true
            }
            "recurring_charge.payment_recorded" -> {
                if(site==null||actor.isBlank())return false
                val pid=p.sText("payment_id");val cid=p.sText("charge_id",id);if(pid.isBlank()||cid.isBlank())return false
                dao.upsertRemoteChargePayment(LocalChargePayment(
                    pid,org,site,cid,p.sMillis("reference_due_at",now),p.sMillis("paid_at",now),p.sLong("amount_xaf"),actor
                ));return true
            }
            "loyalty_program.updated" -> {
                if(actor.isBlank())return false
                val pid=p.sText("program_id",id);val profile=p.sText("activity_profile");val code=p.sText("program_code");val name=p.sText("name")
                if(pid.isBlank()||profile.isBlank()||code.isBlank()||name.isBlank())return false
                val old=dao.findLoyaltyProgram(org,profile,code)
                dao.upsertLoyaltyProgram(LocalLoyaltyProgram(
                    pid,org,profile,code,name,p.sText("description"),p.sText("metric_code"),p.sLong("unit_amount_xaf"),
                    p.sLong("target_value"),p.sText("reward_description"),p.optInt("window_days"),p.optBoolean("active",true),
                    old?.createdAtMillis?:now,now
                ));return true
            }
            "loyalty_activity.recorded" -> {
                if(site==null||actor.isBlank())return false
                val eid=p.sText("activity_event_id",id);val program=p.sText("program_id");val customer=p.sText("customer_id")
                val delta=result.optLong("metric_delta",p.optLong("metric_delta",-1))
                if(eid.isBlank()||program.isBlank()||customer.isBlank()||delta<0)return false
                dao.upsertRemoteLoyaltyEvent(LocalLoyaltyEvent(
                    eid,org,site,program,customer,"activity",p.sLong("amount_xaf"),delta,null,null,null,
                    p.sText("description","Activité synchronisée"),actor,p.sMillis("occurred_at",now)
                ));return true
            }
            "loyalty_reward.redeemed" -> {
                if(site==null)return false
                val old=dao.findLoyaltyEventById(org,p.sText("reward_event_id",id))?:return false
                dao.upsertRemoteLoyaltyEvent(old.copy(rewardStatus="redeemed"));return true
            }
            "purchase.ordered" -> {
                if(site==null||actor.isBlank())return false
                val pid=p.sText("purchase_id",id);val supplierId=p.sText("supplier_id");val reference=p.sText("reference")
                val lines=p.optJSONArray("lines")?:return false;val supplier=dao.findSupplier(supplierId,org,site)?:return false
                if(pid.isBlank()||reference.isBlank()||lines.length()==0)return false
                var subtotal=0L;val prepared=mutableListOf<LocalPurchaseLine>()
                for(i in 0 until lines.length()){
                    val row=lines.optJSONObject(i)?:return false
                    val lid=row.sText("line_id");val qty=row.sDouble("quantity_ordered",Double.NaN);val cost=row.sLong("unit_cost_xaf")
                    if(lid.isBlank()||!qty.isFinite()||qty<=0.0||cost<=0L)return false
                    val lineCost=kotlin.math.floor(qty*cost.toDouble()+0.5).toLong()
                    if(subtotal>Long.MAX_VALUE-lineCost)return false;subtotal+=lineCost
                    prepared+=LocalPurchaseLine(lid,org,site,pid,row.sOptional("inventory_item_id"),row.sText("description"),row.sText("item_type","stock"),row.sText("unit","unité"),qty,0.0,cost,now)
                }
                val old=dao.findPurchaseDocument(pid,org,site)
                dao.upsertRemotePurchaseDocument(LocalPurchaseDocument(
                    pid,org,site,supplierId,supplier.name,reference,p.sText("supplier_invoice_number"),"ordered",subtotal,
                    p.sLong("recoverable_tax_xaf"),p.sLong("non_recoverable_tax_xaf"),p.sLong("shipping_xaf"),p.sLong("other_fees_xaf"),
                    old?.receivedBaseXaf?:0L,old?.recognizedNonRecoverableXaf?:0L,old?.recognizedRecoverableTaxXaf?:0L,
                    old?.receivedTotalXaf?:0L,old?.paidTotalXaf?:0L,
                    p.sOptional("due_at")?.let{runCatching{Instant.parse(it).toEpochMilli()}.getOrNull()},
                    p.sText("notes"),actor,old?.createdAtMillis?:now,now
                ))
                prepared.forEach{dao.upsertRemotePurchaseLine(it)};return true
            }
            "purchase.receipt.confirmed" -> {
                if(site==null||actor.isBlank())return false
                val pid=p.sText("purchase_id");val lid=p.sText("line_id");val key=p.sText("idempotency_key")
                val receiptId=result.sText("receipt_id",p.sText("receipt_id",key));val qty=p.sDouble("quantity",Double.NaN)
                if(pid.isBlank()||lid.isBlank()||key.isBlank()||receiptId.isBlank()||!qty.isFinite()||qty<=0.0)return false
                val purchase=dao.findPurchaseDocument(pid,org,site)?:return false;val line=dao.findPurchaseLine(org,site,pid,lid)?:return false
                val base=kotlin.math.floor(qty*line.unitCostXaf.toDouble()+0.5).toLong()
                val receivedBase=purchase.receivedBaseXaf+base;if(purchase.subtotalXaf<=0||receivedBase>purchase.subtotalXaf)return false
                val nr=kotlin.math.floor((purchase.nonRecoverableTaxXaf+purchase.shippingXaf+purchase.otherFeesXaf).toDouble()*receivedBase/purchase.subtotalXaf+0.5).toLong()
                val rec=kotlin.math.floor(purchase.recoverableTaxXaf.toDouble()*receivedBase/purchase.subtotalXaf+0.5).toLong()
                val nrDelta=(nr-purchase.recognizedNonRecoverableXaf).coerceAtLeast(0L);val recDelta=(rec-purchase.recognizedRecoverableTaxXaf).coerceAtLeast(0L)
                val receivedTotal=purchase.receivedTotalXaf+base+nrDelta+recDelta
                val stockItem = if (line.itemType=="stock" && line.inventoryItemId!=null)
                    dao.findInventoryItem(line.inventoryItemId,org,site) ?: return false else null
                dao.upsertRemotePurchaseLine(line.copy(quantityReceived=line.quantityReceived+qty))
                val complete=dao.countPurchaseLinesNotFullyReceived(org,site,pid)==0
                dao.upsertRemotePurchaseDocument(purchase.copy(
                    receivedBaseXaf=receivedBase,recognizedNonRecoverableXaf=nr,recognizedRecoverableTaxXaf=rec,
                    receivedTotalXaf=receivedTotal,status=if(complete&&purchase.paidTotalXaf>=receivedTotal)"closed" else if(complete)"received" else "partially_received",updatedAtMillis=now
                ))
                dao.upsertRemotePurchaseReceipt(LocalPurchaseReceipt(
                    receiptId,org,site,pid,lid,qty,base,nrDelta,recDelta,actor,p.sMillis("received_at",now),key
                ))
                if(stockItem!=null){
                    val movementId=result.sText("inventory_movement_id",receiptId)
                    if(dao.countInventoryMovementById(org,movementId)==0){
                        dao.upsertRemoteInventoryItem(stockItem.copy(quantity=stockItem.quantity+qty))
                        dao.upsertRemoteInventoryMovement(LocalInventoryMovement(movementId,org,site,stockItem.id,"in",qty,"Réception fournisseur "+purchase.reference,actor,now))
                    }
                }
                return true
            }
            "supplier.payment.recorded" -> {
                if(site==null||actor.isBlank())return false
                val paymentId=result.sText("payment_id",p.sText("payment_id",p.sText("idempotency_key")))
                val pid=p.sText("purchase_id");val key=p.sText("idempotency_key");val amount=p.sLong("amount_xaf")
                if(paymentId.isBlank()||pid.isBlank()||key.isBlank()||amount<=0L)return false
                val purchase=dao.findPurchaseDocument(pid,org,site)?:return false
                val paid=purchase.paidTotalXaf+amount
                dao.upsertRemoteSupplierPayment(LocalSupplierPayment(paymentId,org,site,pid,purchase.supplierId,p.sOptional("cash_session_id"),amount,p.sText("payment_method"),p.sText("payment_reference"),key,actor,p.sMillis("paid_at",now)))
                dao.upsertRemotePurchaseDocument(purchase.copy(paidTotalXaf=paid,status=if(purchase.receivedBaseXaf>=purchase.subtotalXaf-1&&paid>=purchase.receivedTotalXaf)"closed" else purchase.status,updatedAtMillis=now))
                return true
            }
            "inventory_transfer.requested","inventory_transfer.received_at_destination","inventory_transfer.status_changed" -> {
                val tid=p.sText("transfer_id",p.sText("record_id",id));if(tid.isBlank())return false
                val sourceSite=p.sText("source_site_id",site.orEmpty());val destinationSite=p.sText("destination_site_id")
                val old=dao.findManagementRecordAcrossSites(org,tid)
                var sourceItem: LocalInventoryItem? = null
                var destinationItem: LocalInventoryItem? = null
                var destinationNewId = ""
                val transferQty = if(change.actionCode=="inventory_transfer.received_at_destination") p.sDouble("quantity",Double.NaN) else 0.0
                if(change.actionCode=="inventory_transfer.received_at_destination"){
                    val iid=p.sText("inventory_item_id");val sku=p.sText("sku_snapshot")
                    if(iid.isBlank()||!transferQty.isFinite()||transferQty<=0||destinationSite.isBlank())return false
                    sourceItem=dao.findInventoryItem(iid,org,sourceSite)?:return false
                    val matches=dao.findInventoryItemsBySku(org,destinationSite,sku)
                    if(matches.size>1||sourceItem.quantity<transferQty)return false
                    destinationItem=matches.singleOrNull()
                    destinationNewId=p.sText("destination_inventory_item_id_if_created")
                    if(destinationItem==null&&destinationNewId.isBlank())return false
                }
                val status=when(change.actionCode){"inventory_transfer.received_at_destination"->"received";"inventory_transfer.status_changed"->p.sText("to_status",old?.status?:"open");else->p.sText("status","open")}
                val meta=JSONObject(old?.metadataJson?:"{}");val it=p.keys();while(it.hasNext()){val k=it.next();meta.put(k,p.get(k))}
                dao.upsertRemoteManagementRecord(LocalManagementRecord(
                    tid,org,old?.siteId?:sourceSite,"inventory_transfer",p.sText("reference",old?.reference?:tid),
                    p.sText("title",old?.title?:p.sText("item_name_snapshot",p.sText("sku_snapshot","Transfert"))),
                    p.sText("counterparty",old?.counterparty?:destinationSite),old?.amountXaf?:0L,old?.paidXaf?:0L,old?.dueAtMillis,
                    status,meta.toString(),actor.ifBlank{old?.actorMemberId.orEmpty()},old?.createdAtMillis?:now,null
                ))
                if(sourceItem!=null){
                    dao.upsertRemoteInventoryItem(sourceItem.copy(quantity=sourceItem.quantity-transferQty))
                    if(destinationItem!=null) dao.upsertRemoteInventoryItem(destinationItem.copy(quantity=destinationItem.quantity+transferQty))
                    else dao.upsertRemoteInventoryItem(LocalInventoryItem(destinationNewId,org,destinationSite,p.sText("sku_snapshot"),p.sText("item_name_snapshot",p.sText("sku_snapshot")),p.sText("unit","unité"),transferQty,p.sDouble("reorder_level_snapshot"),true,now))
                }
                return true
            }
            else -> {
                val staff=change.actionCode.startsWith("staff_")&&change.actionCode.endsWith(".recorded")
                val created=change.actionCode.endsWith(".created")&&p.has("record_type")
                val transitioned=change.actionCode.endsWith(".status_changed")&&p.has("record_type")
                if(site==null||actor.isBlank())return false
                if(staff){
                    val tid=p.sText("time_event_id",id);val type=change.actionCode.removeSuffix(".recorded");val name=p.sText("staff_name_snapshot")
                    if(tid.isBlank()||name.isBlank())return false
                    val metadata=JSONObject().put("staff_member_id",p.sText("staff_member_id")).put("workstation_id",p.sText("workstation_id")).put("occurred_at",p.sText("occurred_at"))
                    dao.upsertRemoteManagementRecord(LocalManagementRecord(tid,org,site,type,"TIME-"+tid.take(8),type.replace('_',' '),name,0L,0L,null,"recorded",metadata.toString(),actor,now,p.sOptional("workstation_id")))
                    return true
                }
                if(created){
                    val rid=p.sText("record_id",id);val type=p.sText("record_type");if(rid.isBlank()||type.isBlank())return false
                    val metadata=p.optJSONObject("metadata_json")?.toString()?:p.sText("metadata_json","{}")
                    dao.upsertRemoteManagementRecord(LocalManagementRecord(
                        rid,org,site,type,p.sText("reference",rid),p.sText("title",type),p.sText("counterparty"),
                        p.sLong("amount_xaf"),p.sLong("paid_xaf"),p.sOptional("due_at")?.let{runCatching{Instant.parse(it).toEpochMilli()}.getOrNull()},
                        p.sText("status","open"),metadata,actor,p.sMillis("created_at",now),p.sOptional("workstation_id")
                    ));return true
                }
                if(transitioned){
                    val rid=p.sText("record_id",id);val old=dao.findManagementRecord(org,site,rid)?:return false
                    val meta=JSONObject(old.metadataJson);val delta=p.optJSONObject("metadata_json_delta")
                    if(delta!=null){val it=delta.keys();while(it.hasNext()){val k=it.next();meta.put(k,delta.get(k))}}
                    val next=p.sText("to_status",old.status)
                    dao.updateManagementRecord(old.copy(status=next,metadataJson=meta.toString()))
                    dao.upsertRemoteWorkflowEvent(LocalWorkflowEvent(change.eventId,org,site,p.sText("record_type",old.recordType),rid,p.sText("from_status",old.status),next,p.sText("reason"),actor,now))
                    return true
                }
                false
            }
        }
    }
}
