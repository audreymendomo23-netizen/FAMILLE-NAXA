package cm.naxa.zipple
import androidx.room.*
@Entity(tableName="offline_events", indices=[Index(value=["organizationId","memberId","siteId","deviceSequence"])])
data class OfflineEvent(@PrimaryKey val eventId:String,val appId:String="ZIPPLE",val organizationId:String,val memberId:String,val siteId:String,val aggregateType:String,val payloadJson:String,val deviceSequence:Long,val createdAtEpochMs:Long,val state:String="queued")
@Dao interface OfflineEventDao {
 @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun insert(event:OfflineEvent):Long
 @Query("SELECT * FROM offline_events WHERE eventId=:id") suspend fun get(id:String):OfflineEvent?
 @Query("SELECT * FROM offline_events WHERE appId='ZIPPLE' AND organizationId=:org AND memberId=:member AND siteId=:site AND state='queued' ORDER BY deviceSequence,eventId") suspend fun queued(org:String,member:String,site:String):List<OfflineEvent>
 @Transaction suspend fun enqueue(event:OfflineEvent):Boolean{
  require(event.appId=="ZIPPLE"&&event.organizationId.isNotBlank()&&event.memberId.isNotBlank()&&event.siteId.isNotBlank()&&event.eventId.isNotBlank()&&event.deviceSequence>=0&&event.state=="queued")
  val inserted=insert(event)
  if(inserted!=-1L)return true
  val old=get(event.eventId)?:error("EVENT_MISSING")
  require(old.copy(state="queued")==event){"EVENT_CONFLICT"}
  return false
 }
 @Query("UPDATE offline_events SET state=:state WHERE eventId=:id AND appId='ZIPPLE' AND organizationId=:org AND memberId=:member AND siteId=:site AND state='queued'") suspend fun applyReceipt(id:String,org:String,member:String,site:String,state:String):Int
}
@Database(entities=[OfflineEvent::class],version=2,exportSchema=false)
abstract class OfflineQueueDb:RoomDatabase(){abstract fun events():OfflineEventDao}
