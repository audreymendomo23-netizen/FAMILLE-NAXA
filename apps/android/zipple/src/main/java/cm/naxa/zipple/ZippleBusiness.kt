package cm.naxa.zipple
import org.json.JSONObject
import java.net.URI

/** Reuses the NAXA-family N1 HTTPS transport and session; server owns prices, stock and rights. */
object ZippleBusinessPolicy {
    private const val hosted="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-business"
    private val actions=setOf("snapshot","quote","referral_claim","mode","menu_add","table_create","table_open","table_close","order_create","line_advance","delay","cancel","cash_open","cash_record","cash_close","cash_desks_snapshot","cash_desk_add","cash_desk_open","cash_record_mixed","split_snapshot","split_collect","cash_outflows_snapshot","cash_outflow_record","treasury_snapshot","treasury_reconcile","commercial_snapshot","credit_note_record","sale_return_record","erp_snapshot","ledger_snapshot","ledger_mapping_snapshot","ledger_mapping_set","ledger_post_mapped","ledger_account_add","ledger_post","ledger_post_split","ledger_correct","ledger_classify","ledger_statement","ledger_group_statement","ledger_close","ingredient_add","lot_receive","conversion_add","lot_receive_converted","recipe_define","recipe_revise","direct_sale_set","direct_sale_snapshot","produce","intermediate_snapshot","intermediate_convert","offline_erp_apply","erp_review_snapshot","erp_review_discard","braise_snapshot","weighted_rule_set","weighted_produce","weighted_snapshot","braise_measure","braise_discard","preparation_expiry_snapshot","preparation_expiry_set","preparation_expiry_discard","expense_record","finance_documents_snapshot","finance_document_add","finance_document_read","finance_document_review","procurement_snapshot","supplier_add","purchase_create","purchase_batch_create","purchase_create_converted","purchase_receive_converted","purchase_conversion_snapshot","purchase_receive","supplier_pay","count_lot","erp_control_snapshot","erp_control_set","purchase_decide","purchase_receive_checked","expense_submit","expense_decide","expense_apply","supplier_return_snapshot","supplier_return","supplier_refund","tax_snapshot","tax_rule_set","tax_report","inventory_gain_snapshot","inventory_gain_request","inventory_gain_decide","crm_snapshot","credit_snapshot","credit_account_add","credit_authorize","credit_collect","credit_limit_revise","credit_followup","customer_add","customer_attach","followup_create","followup_complete","transfer_snapshot","prepared_transfer_snapshot","prepared_transfer_request","prepared_transfer_decide","prepared_transfer_dispatch","prepared_transfer_receive","transfer_request","transfer_decide","transfer_dispatch","transfer_receive","container_account","container_move","container_snapshot","container_finance_record","pilotage","zone_add","table_config","reserve_table","reservation_transition","catalog_update","floor_snapshot","station_grant","substation_configure","substation_assign","substation_grant","substation_snapshot","station_snapshot","station_availability","table_bill","table_rotate_qr","formula_define","formula_snapshot","group_pay","pickup_create","waitlist_add","waitlist_transition","category_set","catalog_channels","price_schedule","catalog_rules","formula_groups_define","capacity_set","capacity_snapshot","order_priority","call_number","operational_grant","bill_transfer","station_limit","catalog_base_set","station_window","no_show","order_support_snapshot","order_support_reply","attendance_record","attendance_snapshot","workspace_snapshot","workspace_write","loyalty_snapshot","loyalty_write","connection_snapshot","connection_write","hr_snapshot","hr_write")
    fun endpoint(value:String,debug:Boolean):String? {
        if(value==hosted)return value
        if(!debug)return null
        val uri=runCatching{URI(value)}.getOrNull()?:return null
        return value.takeIf{uri.scheme=="https"&&uri.host in setOf("127.0.0.1","localhost")&&uri.port in 1..65535&&uri.path=="/zipple-business"&&uri.rawQuery==null&&uri.rawFragment==null&&uri.rawUserInfo==null}
    }
    fun allowed(action:String)=action in actions
}
class ZippleBusiness(endpoint:String,debug:Boolean=false){
    private val transport=ZippleAuth(requireNotNull(ZippleBusinessPolicy.endpoint(endpoint,debug)))
    suspend fun call(session:Session,site:String,action:String,payload:JSONObject=JSONObject()):Any? {
        require(session.permits(site)&&ZippleBusinessPolicy.allowed(action))
        require(!payload.has("site_id")&&!payload.has("app_id"))
        val body=JSONObject(payload.toString()).put("site_id",site)
        val value=transport.request(action,body,session.token)
        return value.opt("data").takeUnless{it==JSONObject.NULL}
    }
}
