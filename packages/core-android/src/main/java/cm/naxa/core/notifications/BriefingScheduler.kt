package cm.naxa.core.notifications
import android.content.Context
import androidx.work.*
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.concurrent.TimeUnit
object BriefingScheduler {
 fun schedule(context:Context,hour:Int,minute:Int,title:String,body:String,iconRes:Int,channel:String=NotificationChannels.OPERATIONS,replace:Boolean=true) {
  require(hour in 0..23 && minute in 0..59)
  val now=LocalDateTime.now(); var next=now.toLocalDate().atTime(LocalTime.of(hour,minute)); if(!next.isAfter(now))next=next.plusDays(1)
  val data=workDataOf("title" to title,"body" to body,"icon" to iconRes,"channel" to channel,"hour" to hour,"minute" to minute)
  val request=OneTimeWorkRequestBuilder<BriefingWorker>().setInputData(data).setInitialDelay(Duration.between(now,next).toMillis().coerceAtLeast(0),TimeUnit.MILLISECONDS).build()
  val name="naxa-briefing-$channel"; val manager=WorkManager.getInstance(context); if(replace)manager.cancelUniqueWork(name)
  manager.enqueueUniqueWork(name,if(replace)ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.APPEND_OR_REPLACE,request)
 }
}
