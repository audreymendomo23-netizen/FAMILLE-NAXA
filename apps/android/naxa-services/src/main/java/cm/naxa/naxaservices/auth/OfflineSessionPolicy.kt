package cm.naxa.naxaservices.auth

import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

/** Bounded continuation of a previously authenticated, paid session; not a new login. */
internal object OfflineSessionPolicy {
    const val MAX_MS=3_600_000L
    fun scopeAllowed(account:AuthAccount,proof:JSONObject?,jwtSessionId:String?):Boolean {
        val ids=account.activeSiteIds
        if(ids.isEmpty()||ids.any{it.isBlank()}||ids.distinct().size!=ids.size)return false
        if(account.businessMode=="solo")return account.roleCode=="promoter"&&ids.size==1
        if(account.businessMode !in setOf("single_site_multi_workstation","multi_site_network")||
            account.roleCode !in setOf("promoter","network_manager")||
            (account.businessMode=="single_site_multi_workstation"&&ids.size!=1))return false
        if(proof==null||jwtSessionId.isNullOrBlank()||proof.optInt("version",0)!=1||proof.optString("level")!="organization"||
            proof.optString("member_id")!=account.memberId||proof.optString("organization_id")!=account.organizationId||
            proof.optString("role_code")!=account.roleCode||proof.optString("business_mode")!=account.businessMode||
            proof.optString("session_id")!=jwtSessionId)return false
        val arr=proof.optJSONArray("site_ids")?:return false
        val proven=(0 until arr.length()).map{arr.optString(it)}
        return proven.size==ids.size&&proven.toSet()==ids.toSet()
    }
    fun expiresAt(session:AuthSession,access:JSONObject,jwtExpiryMs:Long,now:Long,jwtSessionId:String?=null):Long? {
        val a=session.account
        if(session.requirePasswordChange||!scopeAllowed(a,access.optJSONObject("offline_scope"),jwtSessionId)||
           a.activityProfile.isNullOrBlank()||!a.discoveryCompleted||!a.tourCompleted||
           !a.acceptedLegalDocs.containsAll(setOf("terms:2026-11-v1","privacy:2026-11-v1"))||
           session.deviceId.isBlank()||a.organizationId.isBlank()||a.memberId.isBlank()||
           access.opt("paid_access")!=true||access.opt("erp_access")!=true||access.optString("state")!="active")return null
        val end=runCatching{LocalDate.parse(access.getString("period_end_exclusive")).atStartOfDay(ZoneId.of("Africa/Douala")).toInstant().toEpochMilli()}.getOrNull()?:return null
        return minOf(jwtExpiryMs,end,now+MAX_MS).takeIf{it>now}
    }
    fun valid(wall:Long,elapsed:Long,boot:Int,expires:Long,now:Long,tick:Long,currentBoot:Int):Boolean{
        if(boot<0||boot!=currentBoot||wall<=0||elapsed<0||tick<elapsed||now<wall||expires<=wall||expires-wall>MAX_MS)return false
        return tick-elapsed<expires-wall&&now<expires&&kotlin.math.abs((now-wall)-(tick-elapsed))<=120_000L
    }
}
