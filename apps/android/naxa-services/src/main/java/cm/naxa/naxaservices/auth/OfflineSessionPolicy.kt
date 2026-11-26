package cm.naxa.naxaservices.auth

import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

/** Bounded continuation of a previously authenticated, paid solo session; not a new login. */
internal object OfflineSessionPolicy {
    const val MAX_MS=3_600_000L
    fun expiresAt(session:AuthSession,access:JSONObject,jwtExpiryMs:Long,now:Long):Long? {
        val a=session.account
        if(session.requirePasswordChange||a.businessMode!="solo"||a.roleCode!="promoter"||
           a.activeSiteIds.size!=1||a.activityProfile.isNullOrBlank()||!a.discoveryCompleted||!a.tourCompleted||
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
