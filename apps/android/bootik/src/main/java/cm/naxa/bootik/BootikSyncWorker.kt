package cm.naxa.bootik

import android.content.Context
import androidx.work.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.TimeUnit

// Adapted from ZippleSyncWorker: credentials stay in memory; WorkManager stores no tokens.
internal data class BootikSyncScope(val api:BootikApi,val dao:BootikScopedDao,val session:BootikSession,val site:String)
internal object BootikSync {
 @Volatile private var active:BootikSyncScope?=null
 private val lock=Mutex()
 fun activate(scope:BootikSyncScope){active=scope}
 fun deactivate(scope:BootikSyncScope){if(active===scope)active=null}
 fun authorized(scope:BootikSyncScope)=active===scope&&scope.session.permits(scope.site)
 fun schedule(context:Context,scope:BootikSyncScope){
  if(!authorized(scope))return
  val request=OneTimeWorkRequestBuilder<BootikSyncWorker>()
   .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
   .setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build()
  WorkManager.getInstance(context).enqueueUniqueWork("bootik-scoped-outbox",ExistingWorkPolicy.APPEND_OR_REPLACE,request)
 }
 suspend fun flush(scope:BootikSyncScope):Int=lock.withLock{
  if(!authorized(scope))return@withLock 0
  val s=scope.session;val site=scope.site
  val all=scope.dao.events(s.organization,s.member,site)
  if(all.any{it.state in setOf("conflict","rejected")})return@withLock 0
  var count=0
  for(event in all.filter{it.state=="queued"}){
   if(!authorized(scope))break
   val state=scope.api.syncSale(s,site,event)
   if(!authorized(scope))break
   check(scope.dao.acknowledge(event.eventId,s.organization,s.member,site,state)==1)
   count++;if(state!="acknowledged")break
  }
  count
 }
 suspend fun runActive():Boolean{
  val scope=active?:return true
  if(!authorized(scope))return true
  return try{flush(scope);true}catch(e:CancellationException){throw e}catch(_:Exception){!authorized(scope)}
 }
}
class BootikSyncWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
 override suspend fun doWork():Result=if(BootikSync.runActive())Result.success() else Result.retry()
}
