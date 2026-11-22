package cm.naxa.bootik.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface BootikDraftDao {
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertWorkspace(draft: BootikWorkspaceDraftEntity)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertActivity(draft: BootikActivityDraftEntity)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSite(draft: BootikSiteDraftEntity)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun linkSiteToActivity(link: BootikSiteActivityDraftEntity)

    @Query("SELECT * FROM bk_workspace_drafts ORDER BY updatedAtEpochMs DESC")
    fun observeWorkspaceDrafts(): Flow<List<BootikWorkspaceDraftEntity>>
}
