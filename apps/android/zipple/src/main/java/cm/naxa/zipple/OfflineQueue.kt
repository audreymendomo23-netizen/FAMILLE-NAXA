package cm.naxa.zipple
import androidx.room.*
import android.content.Context
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
@Entity(tableName="offline_events", indices=[Index(value=["organizationId","memberId","siteId","deviceSequence"])])
data class OfflineEvent(@PrimaryKey val eventId:String,val appId:String="ZIPPLE",val organizationId:String,val memberId:String,val siteId:String,val aggregateType:String,val payloadJson:String,val deviceSequence:Long,val createdAtEpochMs:Long,val state:String="queued")
@Dao interface OfflineEventDao {
 @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun insert(event:OfflineEvent):Long
 @Query("SELECT * FROM offline_events WHERE eventId=:id") suspend fun get(id:String):OfflineEvent?
 @Query("SELECT * FROM offline_events WHERE appId='ZIPPLE' AND organizationId=:org AND memberId=:member AND siteId=:site AND state='queued' ORDER BY deviceSequence,eventId") suspend fun queued(org:String,member:String,site:String):List<OfflineEvent>
 @Query("SELECT COUNT(*) FROM offline_events WHERE appId='ZIPPLE' AND organizationId=:org AND memberId=:member AND siteId=:site AND state IN ('conflict','rejected')") suspend fun blocked(org:String,member:String,site:String):Int
 @Transaction suspend fun enqueue(event:OfflineEvent):Boolean{
  require(event.appId=="ZIPPLE"&&event.organizationId.isNotBlank()&&event.memberId.isNotBlank()&&event.siteId.isNotBlank()&&event.eventId.isNotBlank()&&event.deviceSequence>=0&&event.state=="queued")
  val inserted=insert(event)
  if(inserted!=-1L)return true
  val old=get(event.eventId)?:error("EVENT_MISSING")
  require(old.copy(state="queued")==event){"EVENT_CONFLICT"}
  return false
 }
 @Query("UPDATE offline_events SET state=:state WHERE eventId=:id AND appId='ZIPPLE' AND organizationId=:org AND memberId=:member AND siteId=:site AND state='queued'") suspend fun updateReceipt(id:String,org:String,member:String,site:String,state:String):Int
 @Transaction suspend fun applyReceipt(id:String,org:String,member:String,site:String,state:String):Boolean {require(state in setOf("acknowledged","conflict","rejected"));return updateReceipt(id,org,member,site,state)==1}
}
@Database(entities=[OfflineEvent::class],version=2,exportSchema=false)
abstract class OfflineQueueDb:RoomDatabase(){abstract fun events():OfflineEventDao
 companion object {
  @Volatile private var db:OfflineQueueDb?=null
  // V1 lacked tenant/site/member; retain legacy rows for authorized review, never replay blindly.
  val MIGRATION_1_2=object:Migration(1,2){override fun migrate(db:SupportSQLiteDatabase){
   db.execSQL("ALTER TABLE offline_events RENAME TO offline_events_unscoped_legacy")
   db.execSQL("CREATE TABLE offline_events (eventId TEXT NOT NULL PRIMARY KEY, appId TEXT NOT NULL, organizationId TEXT NOT NULL, memberId TEXT NOT NULL, siteId TEXT NOT NULL, aggregateType TEXT NOT NULL, payloadJson TEXT NOT NULL, deviceSequence INTEGER NOT NULL, createdAtEpochMs INTEGER NOT NULL, state TEXT NOT NULL)")
   db.execSQL("CREATE INDEX index_offline_events_organizationId_memberId_siteId_deviceSequence ON offline_events(organizationId,memberId,siteId,deviceSequence)")
  }}
  fun get(context:Context):OfflineQueueDb=db?:synchronized(this){db?:Room.databaseBuilder(context.applicationContext,OfflineQueueDb::class.java,"zipple-offline.db").addMigrations(MIGRATION_1_2).build().also{db=it}}
 }
}
