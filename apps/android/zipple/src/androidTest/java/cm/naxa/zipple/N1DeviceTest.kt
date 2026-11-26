package cm.naxa.zipple
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.*
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class N1DeviceTest {
 @get:Rule val compose=createAndroidComposeRule<MainActivity>()
 private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
 @Test fun loginFormNative(){
  compose.onNodeWithText("Votre restaurant, bien piloté").assertExists()
  compose.onNodeWithText("Se connecter").assertIsNotEnabled()
  compose.onNodeWithText("Identifiant").performTextInput("fixture")
  compose.onNodeWithText("Mot de passe",substring=false).performTextInput("test-only")
  compose.onNodeWithText("Se connecter").assertIsEnabled().performClick()
  compose.waitUntil(10000){compose.onAllNodesWithText("Connexion indisponible ou refusée").fetchSemanticsNodes().isNotEmpty()}
  compose.onNodeWithText("EN",substring=false).performClick()
  compose.onNodeWithText("Manage your restaurant").assertExists()
 }
 @Test fun pinAndVault(){
  val pin=LocalAccessPinManager(context)
  val one=UUID.randomUUID().toString();val two=UUID.randomUUID().toString()
  assertEquals(LocalAccessPinCode.SUCCESS,pin.enroll(one,"1234").code)
  assertEquals(LocalAccessPinCode.NOT_CONFIGURED,pin.verify(two,"1234").code)
  assertEquals(LocalAccessPinCode.SUCCESS,pin.verify(one,"1234").code)
  repeat(4){assertEquals(LocalAccessPinCode.INVALID,pin.verify(one,"9999").code)}
  assertEquals(LocalAccessPinCode.LOCKED,pin.verify(one,"9999").code)
  assertEquals(LocalAccessPinCode.LOCKED,pin.verify(one,"1234").code)
  val vault=SessionVault(context);val token="synthetic-"+UUID.randomUUID()
  try{vault.save(token);assertEquals(token,vault.loadRefreshToken());assertFalse(context.getSharedPreferences("zipple_secure_session",0).all.values.any{it.toString().contains(token)})}finally{vault.clear()}
  assertNull(vault.loadRefreshToken())
 }
 @Test fun roomQueueAndMigration()=runBlocking{
  val name="zipple-test-"+UUID.randomUUID()+".db"
  val helper=FrameworkSQLiteOpenHelperFactory().create(SupportSQLiteOpenHelper.Configuration.builder(context).name(name).callback(object:SupportSQLiteOpenHelper.Callback(1){
   override fun onCreate(db:androidx.sqlite.db.SupportSQLiteDatabase){db.execSQL("CREATE TABLE offline_events(eventId TEXT NOT NULL PRIMARY KEY, appId TEXT NOT NULL, aggregateType TEXT NOT NULL, payloadJson TEXT NOT NULL, deviceSequence INTEGER NOT NULL, createdAtEpochMs INTEGER NOT NULL, state TEXT NOT NULL)");db.execSQL("INSERT INTO offline_events VALUES ('legacy','ZIPPLE','test','{}',1,1,'queued')")}
   override fun onUpgrade(db:androidx.sqlite.db.SupportSQLiteDatabase,oldVersion:Int,newVersion:Int){}
  }).build())
  helper.writableDatabase;helper.close()
  val db=Room.databaseBuilder(context,OfflineQueueDb::class.java,name).addMigrations(OfflineQueueDb.MIGRATION_1_2).build()
  try{
   val dao=db.events()
   val legacy=db.openHelper.readableDatabase.query("SELECT count(*) FROM offline_events_unscoped_legacy");legacy.use{assertTrue(it.moveToFirst());assertEquals(1,it.getInt(0))}
   assertTrue(dao.queued("org","m","s").isEmpty())
   val e=OfflineEvent(eventId="e",organizationId="org",memberId="m",siteId="s",aggregateType="test",payloadJson="{}",deviceSequence=1,createdAtEpochMs=1)
   assertTrue(dao.enqueue(e));assertFalse(dao.enqueue(e));assertTrue(dao.queued("other","m","s").isEmpty());assertTrue(dao.queued("org","other","s").isEmpty());assertTrue(dao.queued("org","m","other").isEmpty())
   assertFalse(dao.applyReceipt("e","other","m","s","acknowledged"));assertTrue(dao.applyReceipt("e","org","m","s","conflict"));assertEquals(1,dao.blocked("org","m","s"));assertTrue(dao.queued("org","m","s").isEmpty())
  }finally{db.close();context.deleteDatabase(name)}
 }
}
