package cm.naxa.widemeet
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import cm.naxa.widemeet.auth.AuthGateway
import cm.naxa.widemeet.auth.Session
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

private const val Channel="widemeet-notices"
private fun prefs(context:Context)=context.getSharedPreferences("wm-push-consent",Context.MODE_PRIVATE)
private fun scopeKey(s:Session)=s.memberId+":"+s.activeWorkspaceId
private fun permission(context:Context)=Build.VERSION.SDK_INT<33||ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED
private fun configured()=BuildConfig.WIDEMEET_PUSH_ENABLED&&BuildConfig.WM_FIREBASE_PROJECT_ID=="naxameet"&&BuildConfig.WM_FIREBASE_SENDER_ID=="404923635551"&&BuildConfig.WM_FIREBASE_APP_ID=="1:404923635551:android:6d8d1bc318ef1c72ab88ea"&&BuildConfig.WM_FIREBASE_API_KEY.isNotBlank()
private fun channel(context:Context){context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(Channel,"WideMeet",NotificationManager.IMPORTANCE_DEFAULT))}
internal fun messaging(context:Context):FirebaseMessaging{
 require(configured())
 val app=FirebaseApp.getApps(context).firstOrNull{it.name==FirebaseApp.DEFAULT_APP_NAME}?:FirebaseApp.initializeApp(context,FirebaseOptions.Builder().setApiKey(BuildConfig.WM_FIREBASE_API_KEY).setApplicationId(BuildConfig.WM_FIREBASE_APP_ID).setProjectId(BuildConfig.WM_FIREBASE_PROJECT_ID).setGcmSenderId(BuildConfig.WM_FIREBASE_SENDER_ID).build())
 require(app.options.projectId==BuildConfig.WM_FIREBASE_PROJECT_ID&&app.options.applicationId==BuildConfig.WM_FIREBASE_APP_ID)
 channel(context);return FirebaseMessaging.getInstance()
}
@Composable fun PushPreferences(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current.applicationContext;val scope=rememberCoroutineScope();val store=prefs(context);val k=scopeKey(session)
 var enabled by remember(k){mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 suspend fun register(){
  require(permission(context)&&configured())
  val token=withContext(Dispatchers.IO){Tasks.await(messaging(context).token,15,TimeUnit.SECONDS)}
  require(gateway.push(session,"register",token).optBoolean("enabled"));store.edit().putBoolean(k,true).putBoolean("device-enabled",true).apply();enabled=true
 }
 fun enable(){if(busy)return;busy=true;error=false;scope.launch{try{register()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 val ask=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){granted->if(granted)enable()else error=true}
 LaunchedEffect(session.accessToken){
  try{enabled=gateway.push(session,"status").optBoolean("enabled");while(true){
   if(!busy&&store.getBoolean(k,false)){
    if(permission(context)&&configured()){try{register();error=false}catch(e:CancellationException){throw e}catch(e:Exception){enabled=false;error=true}}
    else{gateway.push(session,"revoke");store.edit().putBoolean(k,false).putBoolean("device-enabled",false).apply();enabled=false}
   };delay(60000)
  }}catch(e:CancellationException){throw e}catch(e:Exception){error=true}
 }
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){
  Text(tr("Notifications push","Push notifications"),style=MaterialTheme.typography.titleMedium)
  Text(if(enabled)tr("Activées pour cette session","Enabled for this session")else tr("Désactivées","Disabled"))
  if(!configured())Text(tr("Configuration WideMeet indisponible.","WideMeet configuration unavailable."))
  if(error)Text(tr("Activation ou révocation non confirmée.","Activation or revocation unconfirmed."),color=MaterialTheme.colorScheme.error)
  Button(enabled=!busy&&configured()&&!enabled,onClick={if(permission(context))enable()else ask.launch(Manifest.permission.POST_NOTIFICATIONS)}){Text(tr("Activer","Enable"))}
  TextButton(enabled=!busy,onClick={busy=true;scope.launch{try{
    store.edit().putBoolean(k,false).putBoolean("device-enabled",false).apply()
    require(gateway.push(session,"revoke").optBoolean("revoked"));enabled=false
    context.getSystemService(NotificationManager::class.java).cancelAll()
    if(configured())withContext(Dispatchers.IO){runCatching{Tasks.await(messaging(context).deleteToken(),15,TimeUnit.SECONDS)}}
   }catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}){Text(tr("Désactiver","Disable"))}
 }}
}
class WideMeetMessagingService:FirebaseMessagingService(){
 override fun onMessageReceived(message:RemoteMessage){
  if(!configured()||!permission(this)||!prefs(this).getBoolean("device-enabled",false)||message.data["app_id"]!="WIDEMEET")return
  val id=message.data["notification_id"]?:return
  if(!id.matches(Regex("^[0-9a-f-]{36}$")))return
  channel(this);val intent=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val n=Notification.Builder(this,Channel).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("WideMeet").setContentText("Nouvelle notification / New notification").setContentIntent(intent).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build()
  getSystemService(NotificationManager::class.java).notify(id,1,n)
 }
}
