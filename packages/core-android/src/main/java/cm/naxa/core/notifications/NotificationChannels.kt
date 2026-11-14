package cm.naxa.core.notifications
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
object NotificationChannels {
 const val CRITICAL="critical"; const val OPERATIONS="operations"; const val SUBSCRIPTION="subscription"; const val INFORMATION="information"; const val AI_COACHING="ai_coaching"
 fun create(context:Context) { if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.O) { val m=context.getSystemService(NotificationManager::class.java); m.createNotificationChannels(listOf(NotificationChannel(CRITICAL,"Critique",NotificationManager.IMPORTANCE_HIGH),NotificationChannel(OPERATIONS,"Opérations",NotificationManager.IMPORTANCE_DEFAULT),NotificationChannel(SUBSCRIPTION,"Abonnement",NotificationManager.IMPORTANCE_HIGH),NotificationChannel(INFORMATION,"Information",NotificationManager.IMPORTANCE_LOW),NotificationChannel(AI_COACHING,"Coaching IA",NotificationManager.IMPORTANCE_DEFAULT))) } }
 fun post(context:Context,channel:String,id:Int,title:String,body:String,smallIcon:Int,intent:PendingIntent?=null):Boolean { if(Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return false; return try { val b=NotificationCompat.Builder(context,channel).setSmallIcon(smallIcon).setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)).setAutoCancel(true); if(intent!=null)b.setContentIntent(intent); NotificationManagerCompat.from(context).notify(id,b.build()); true } catch(_:SecurityException){false} }
}
