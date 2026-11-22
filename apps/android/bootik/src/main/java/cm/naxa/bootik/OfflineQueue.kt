package cm.naxa.bootik

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.Index
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query

/**
 * BOOTIK-owned local outbox. It deliberately uses its own Room table and DB;
 * do not share NAXA Services' ns_* storage or queue implementation.
 */
@Entity(
    tableName = "bk_offline_events",
    indices = [Index(value = ["state", "deviceSequence"])]
)
data class BootikOfflineEvent(
    @PrimaryKey val eventId: String,
    val appCode: String = "bootik",
    val aggregateType: String,
    val aggregateId: String,
    val payloadJson: String,
    val deviceSequence: Long,
    val createdAtEpochMs: Long,
    val state: String = "queued"
)

@Dao
interface BootikOfflineEventDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun enqueue(event: BootikOfflineEvent): Long

    @Query("SELECT * FROM bk_offline_events WHERE state = 'queued' ORDER BY deviceSequence")
    suspend fun queued(): List<BootikOfflineEvent>

    @Query("UPDATE bk_offline_events SET state = :state WHERE eventId = :eventId")
    suspend fun updateState(eventId: String, state: String): Int
}
