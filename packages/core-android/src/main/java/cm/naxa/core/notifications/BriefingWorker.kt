package cm.naxa.core.notifications
import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
class BriefingWorker(context:Context,params:WorkerParameters):Worker(context,params) {
 override fun doWork():Result {
  val title=inputData.getString("title")?:return Result.failure(); val body=inputData.getString("body")?:return Result.failure()
  val icon=inputData.getInt("icon",0); val channel=inputData.getString("channel")?:NotificationChannels.OPERATIONS
  val hour=inputData.getInt("hour",7); val minute=inputData.getInt("minute",0)
  if(icon!=0)NotificationChannels.post(applicationContext,channel,channel.hashCode(),title,body,icon)
  BriefingScheduler.schedule(applicationContext,hour,minute,title,body,icon,channel,replace=false)
  return Result.success()
 }
}
