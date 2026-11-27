package cm.naxa.widemeet
import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.gms.tasks.Tasks
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class LiveFcmInstrumentedTest {
 @Test fun actualFcmReceivesOnProductionMessagingService(){
  assumeTrue(BuildConfig.WIDEMEET_PUSH_ENABLED)
  val context=InstrumentationRegistry.getInstrumentation().targetContext
  val identity=InstrumentationRegistry.getArguments().getString("wmCiOidc") ?: error("qualification identity missing")
  assertTrue(identity.length>100)
  assertEquals(PackageManager.PERMISSION_GRANTED,context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS))
  val prefs=context.getSharedPreferences("wm-push-consent",Context.MODE_PRIVATE)
  val manager=context.getSystemService(NotificationManager::class.java)
  val app=ActivityScenario.launch(MainActivity::class.java)
  val fcm=messaging(context)
  try{
   prefs.edit().putBoolean("device-enabled",true).commit();manager.cancelAll()
   val token=Tasks.await(fcm.token,60,TimeUnit.SECONDS);assertTrue(token.length>=30)
   val conn=URL("https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/widemeet-push-ci").openConnection() as HttpsURLConnection
   val id=try{
    conn.requestMethod="POST";conn.connectTimeout=10000;conn.readTimeout=35000;conn.instanceFollowRedirects=false;conn.doOutput=true
    conn.setRequestProperty("Authorization","Bearer "+identity);conn.setRequestProperty("Content-Type","application/json")
    conn.outputStream.use{it.write(JSONObject().put("kind","android").put("token",token).toString().toByteArray(Charsets.UTF_8))}
    assertEquals("FCM qualification sender HTTP",200,conn.responseCode)
    val j=JSONObject(conn.inputStream.bufferedReader().use{it.readText()});assertEquals("accepted",j.getString("provider_status"));j.getString("notification_id")
   }finally{conn.disconnect()}
   assertTrue(id.matches(Regex("^[a-f0-9-]{36}$")))
   val until=SystemClock.elapsedRealtime()+100000
   var seen=false
   while(SystemClock.elapsedRealtime()<until){
    if(manager.activeNotifications.any{it.tag==id&&it.id==1&&it.notification.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()=="WideMeet"}){seen=true;break}
    SystemClock.sleep(250)
   }
   assertTrue("Real FCM receipt in WideMeetMessagingService",seen)
  }finally{
   prefs.edit().remove("device-enabled").commit();manager.cancelAll()
   try{Tasks.await(fcm.deleteToken(),30,TimeUnit.SECONDS)}finally{app.close()}
  }
 }
}
