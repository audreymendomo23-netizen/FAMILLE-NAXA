package cm.naxa.grillad
import android.content.Context
import android.app.PendingIntent
import android.content.Intent
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.google.android.gms.tasks.Tasks
import cm.naxa.core.notifications.NotificationChannels
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit
internal object GrilladPush{
 private const val NAME="grillad"
 private fun app(context:Context):FirebaseApp? {
  val key=BuildConfig.GRILLAD_FIREBASE_API_KEY;val id=BuildConfig.GRILLAD_FIREBASE_APP_ID;val project=BuildConfig.GRILLAD_FIREBASE_PROJECT;val sender=BuildConfig.GRILLAD_FIREBASE_SENDER
  if(key.isBlank()||id.isBlank()||project.isBlank()||sender.isBlank())return null
  return FirebaseApp.getApps(context).firstOrNull{it.name=="[DEFAULT]"}?.takeIf{it.options.applicationId==id&&it.options.projectId==project}?:runCatching{FirebaseApp.initializeApp(context,FirebaseOptions.Builder().setApiKey(key).setApplicationId(id).setProjectId(project).setGcmSenderId(sender).build())}.getOrNull()
 }
 suspend fun token(context:Context):String=withContext(Dispatchers.IO){
  require(app(context)!=null){"Configuration Firebase GRILLAD absente ou invalide"}
  val t=Tasks.await(FirebaseMessaging.getInstance().token,20,TimeUnit.SECONDS)
  require(t.length in 30..4096&&!t.any(Char::isWhitespace)){"Jeton Firebase invalide"};t
 }
 suspend fun delete(context:Context){withContext(Dispatchers.IO){if(app(context)!=null)Tasks.await(FirebaseMessaging.getInstance().deleteToken(),20,TimeUnit.SECONDS)}}
 fun optedIn(context:Context)=context.getSharedPreferences("grillad-push-v1",0).getBoolean("enabled",false)
 fun setOptIn(context:Context,enabled:Boolean){context.getSharedPreferences("grillad-push-v1",0).edit().putBoolean("enabled",enabled).apply()}
}
class GrilladMessagingService:FirebaseMessagingService(){
 override fun onNewToken(token:String){ // Registration must be refreshed under a live GRILLAD session, never in anonymous background.
  GrilladPush.setOptIn(this,false)
 }
 override fun onMessageReceived(message:RemoteMessage){
  if(!GrilladPush.optedIn(this)||message.data["app"]!="grillad"||message.data["kind"]!="inbox")return
  NotificationChannels.create(this)
  val intent=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
  // No amounts, photos, names or remote URLs in notification previews.
  NotificationChannels.post(this,NotificationChannels.OPERATIONS,201,"GrillaD","Une nouvelle information est disponible. Ouvrez l’application.",android.R.drawable.ic_dialog_info,intent)
 }
}
