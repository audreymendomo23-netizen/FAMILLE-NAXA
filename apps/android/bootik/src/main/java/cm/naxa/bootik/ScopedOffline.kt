package cm.naxa.bootik
import androidx.room.*

@Entity(tableName="bk_scoped_outbox",indices=[Index(value=["organizationId","memberId","siteId","state","sequence"])])
data class BootikScopedEvent(@PrimaryKey val eventId:String,val organizationId:String,val memberId:String,val siteId:String,val sequence:Long,val payload:String,val state:String="queued")

@Entity(tableName="bk_catalog_cache",primaryKeys=["organizationId","memberId","siteId"])
data class BootikCatalogCache(val organizationId:String,val memberId:String,val siteId:String,val itemsJson:String,val updatedAt:Long)

@Dao
interface BootikScopedDao{
 @Insert(onConflict=OnConflictStrategy.ABORT) suspend fun enqueue(event:BootikScopedEvent)
 @Query("SELECT * FROM bk_scoped_outbox WHERE organizationId=:org AND memberId=:member AND siteId=:site ORDER BY sequence,eventId") suspend fun events(org:String,member:String,site:String):List<BootikScopedEvent>
 @Query("UPDATE bk_scoped_outbox SET state=:next WHERE eventId=:id AND organizationId=:org AND memberId=:member AND siteId=:site AND state='queued'") suspend fun acknowledge(id:String,org:String,member:String,site:String,next:String):Int
 @Query("UPDATE bk_scoped_outbox SET state='discarded' WHERE eventId=:id AND organizationId=:org AND memberId=:member AND siteId=:site AND state IN ('conflict','rejected')") suspend fun discard(id:String,org:String,member:String,site:String):Int
 @Insert(onConflict=OnConflictStrategy.REPLACE) suspend fun cache(value:BootikCatalogCache)
 @Query("SELECT * FROM bk_catalog_cache WHERE organizationId=:org AND memberId=:member AND siteId=:site") suspend fun catalog(org:String,member:String,site:String):BootikCatalogCache?
}
object BootikReceiptPolicy{
 fun valid(app:String,org:String,member:String,site:String,event:String,action:String,state:String,expected:BootikScopedEvent)=app=="BOOTIK"&&org==expected.organizationId&&member==expected.memberId&&site==expected.siteId&&event==expected.eventId&&action=="sync-sale"&&state in setOf("acknowledged","conflict","rejected")
}
