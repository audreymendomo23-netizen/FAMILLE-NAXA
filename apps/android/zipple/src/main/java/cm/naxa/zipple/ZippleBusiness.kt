package cm.naxa.zipple
import org.json.JSONObject
import java.net.URI

/** Reuses the NAXA-family N1 HTTPS transport and session; server owns prices, stock and rights. */
object ZippleBusinessPolicy {
    private const val hosted="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-business"
    private val actions=setOf("snapshot","quote","referral_claim","mode","menu_add","table_create","table_open","table_close","order_create","line_advance","delay","cancel","cash_open","cash_record","cash_close","cash_desks_snapshot","cash_desk_add","cash_desk_open","cash_record_mixed","erp_snapshot","ledger_snapshot","ledger_account_add","ledger_post","ledger_close","ingredient_add","lot_receive","conversion_add","lot_receive_converted","recipe_define","recipe_revise","produce","braise_snapshot","braise_measure","braise_discard","expense_record","procurement_snapshot","supplier_add","purchase_create","purchase_batch_create","purchase_receive","supplier_pay","count_lot","crm_snapshot","credit_snapshot","credit_account_add","credit_authorize","credit_collect","customer_add","customer_attach","followup_create","followup_complete","transfer_snapshot","prepared_transfer_snapshot","prepared_transfer_request","prepared_transfer_decide","prepared_transfer_dispatch","prepared_transfer_receive","transfer_request","transfer_decide","transfer_dispatch","transfer_receive","container_account","container_move","container_snapshot","container_finance_record","pilotage","zone_add","table_config","reserve_table","reservation_transition","catalog_update","floor_snapshot","station_grant","station_snapshot","station_availability","table_bill","table_rotate_qr","formula_define","formula_snapshot","group_pay","pickup_create","waitlist_add","waitlist_transition","category_set","catalog_channels","price_schedule","catalog_rules","formula_groups_define","capacity_set","capacity_snapshot","order_priority","call_number","operational_grant","bill_transfer","station_limit","catalog_base_set","station_window","no_show")
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
