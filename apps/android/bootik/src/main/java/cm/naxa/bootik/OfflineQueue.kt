package cm.naxa.bootik
import androidx.room.*
@Entity(tableName="offline_events")
data class OfflineEvent(@PrimaryKey val eventId:String,val appId:String,val aggregateType:String,val payloadJson:String,val deviceSequence:Long,val createdAtEpochMs:Long,val state:String="queued")
@Dao interface OfflineEventDao {
 @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun enqueue(event:OfflineEvent):Long
 @Query("SELECT * FROM offline_events WHERE state='queued' ORDER BY deviceSequence") suspend fun queued():List<OfflineEvent>
 @Query("UPDATE offline_events SET state=:state WHERE eventId=:eventId") suspend fun updateState(eventId:String,state:String):Int
}
@Database(entities=[OfflineEvent::class],version=1,exportSchema=false)
abstract class OfflineQueueDb:RoomDatabase(){abstract fun events():OfflineEventDao}
