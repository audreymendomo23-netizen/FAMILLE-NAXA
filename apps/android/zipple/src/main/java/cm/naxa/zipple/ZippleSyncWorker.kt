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
  WorkManager.getInstance(context).enqueueUniqueWork("zipple-scoped-outbox",ExistingWorkPolicy.KEEP,work)
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
     val state=api.sync(session,event)
     if(ZippleSyncSession.current!==session)return Result.success()
     if(!dao.applyReceipt(event.eventId,session.organization,session.member,site.id,state))return Result.retry()
     // Conflict/rejected records are retained and block later mutations for review.
     if(state!="acknowledged")return Result.success()
    }
   }
   return Result.success()
  }catch(e:kotlinx.coroutines.CancellationException){throw e}catch(_:Exception){return Result.retry()}
 }
}
