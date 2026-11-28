package cm.naxa.grillad

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import kotlinx.coroutines.flow.MutableStateFlow

/** Foreground notification for a single consented media projection. No capture or token persistence here. */
class GrilladProjectionService:Service(){
 companion object{internal val ready=MutableStateFlow(false);private const val CHANNEL="grillad_screen_support"}
 override fun onBind(intent:Intent?):IBinder?=null
 override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int{
  if(intent==null){stopSelf();return START_NOT_STICKY}
  val manager=getSystemService(NotificationManager::class.java)
  manager.createNotificationChannel(NotificationChannel(CHANNEL,"GRILLAD · Assistance écran",NotificationManager.IMPORTANCE_LOW))
  val notice=Notification.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.ic_menu_view).setContentTitle("GRILLAD · Partage d’écran").setContentText("Assistance en cours. Terminez l’appel dans GRILLAD pour arrêter.").setOngoing(true).setCategory(Notification.CATEGORY_SERVICE).build()
  try{if(Build.VERSION.SDK_INT>=29)startForeground(4172,notice,ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)else startForeground(4172,notice);ready.value=true}
  catch(e:Exception){ready.value=false;stopSelf()}
  return START_NOT_STICKY
 }
 override fun onDestroy(){ready.value=false;super.onDestroy()}
}
