package cm.naxa.zipple
import android.content.Context
import androidx.work.*
import java.util.concurrent.TimeUnit

object ReceiptPolicy {
 fun verify(eventId:String,org:String,site:String,returnedId:String,returnedOrg:String,returnedSite:String,app:String,state:String):String {
  require(app=="ZIPPLE"&&eventId==returnedId&&org==returnedOrg&&site==returnedSite&&state in setOf("acknowledged","conflict","rejected")){"INVALID_RECEIPT"}
  return state
 }
}
// Never put tokens into WorkManager input or disk. A stopped process retains its queue.
object ZippleSyncSession {
 @Volatile var current:Session?=null
 fun schedule(context:Context){
  val work=OneTimeWorkRequestBuilder<ZippleSyncWorker>().setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build()
  WorkManager.getInstance(context).enqueueUniqueWork("zipple-scoped-outbox",ExistingWorkPolicy.APPEND_OR_REPLACE,work)
 }
}
class ZippleSyncWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
 override suspend fun doWork():Result {
  val session=ZippleSyncSession.current?:return Result.success()
  if(session.expiresAt<=System.currentTimeMillis())return Result.success()
  val dao=OfflineQueueDb.get(applicationContext).events()
  val api=ZippleAuth(BuildConfig.ZIPPLE_API_URL)
  try {
   for(site in session.sites){
    if(dao.blocked(session.organization,session.member,site.id)>0)continue
    for(event in dao.queued(session.organization,session.member,site.id)){
     if(ZippleSyncSession.current!==session||!session.permits(site.id))return Result.success()
     val state=if(event.aggregateType in setOf("erp_produce","erp_lot_receive","erp_expense_record","erp_count_lot")){
      val business=ZippleBusiness(BuildConfig.ZIPPLE_BUSINESS_API_URL,BuildConfig.DEBUG)
      val payload=org.json.JSONObject().put("organization_id",session.organization).put("member_id",session.member).put("event_id",event.eventId).put("action",event.aggregateType.removePrefix("erp_")).put("payload",org.json.JSONObject(event.payloadJson))
      val receipt=business.call(session,site.id,"offline_erp_apply",payload) as? org.json.JSONObject?:error("INVALID_RECEIPT")
      ReceiptPolicy.verify(event.eventId,session.organization,site.id,receipt.getString("event_id"),receipt.getString("organization_id"),receipt.getString("site_id"),receipt.getString("app_id"),receipt.getString("state"))
     }else api.sync(session,event)
     if(ZippleSyncSession.current!==session)return Result.success()
     if(!dao.applyReceipt(event.eventId,session.organization,session.member,site.id,state))return Result.retry()
     // Conflict/rejected records are retained and block later mutations for review.
     if(state!="acknowledged")break
    }
   }
   return Result.success()
  }catch(e:kotlinx.coroutines.CancellationException){throw e}catch(_:Exception){return Result.retry()}
 }
}
