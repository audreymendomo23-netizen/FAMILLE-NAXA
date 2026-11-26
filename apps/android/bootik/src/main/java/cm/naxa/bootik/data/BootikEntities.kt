package cm.naxa.bootik.data

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Device-local configuration draft only. It is not a Famille NAXA organization,
 * authenticated tenant, subscription, or server-side account.
 */
@Entity(
    tableName = "bk_workspace_drafts",
    indices = [Index(value = ["updatedAtEpochMs"])]
)
data class BootikWorkspaceDraftEntity(
    @PrimaryKey val id: String,
    val displayName: String,
    val universeCode: String = "retailer",
    val syncState: String = "local_only",
    val createdAtEpochMs: Long,
    val updatedAtEpochMs: Long
)

@Entity(
    tableName = "bk_activity_drafts",
    foreignKeys = [
        ForeignKey(
            entity = BootikWorkspaceDraftEntity::class,
            parentColumns = ["id"],
            childColumns = ["workspaceId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["workspaceId"]), Index(value = ["workspaceId", "profileCode"])]
)
data class BootikActivityDraftEntity(
    @PrimaryKey val id: String,
    val workspaceId: String,
    val profileCode: String,
    val displayName: String,
    val statusCode: String = "draft",
    val createdAtEpochMs: Long
)

@Entity(
    tableName = "bk_site_drafts",
    foreignKeys = [
        ForeignKey(
            entity = BootikWorkspaceDraftEntity::class,
            parentColumns = ["id"],
            childColumns = ["workspaceId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["workspaceId"]), Index(value = ["workspaceId", "code"], unique = true)]
)
data class BootikSiteDraftEntity(
    @PrimaryKey val id: String,
    val workspaceId: String,
    val code: String,
    val displayName: String,
    val createdAtEpochMs: Long
)

@Entity(
    tableName = "bk_site_activity_drafts",
    primaryKeys = ["siteId", "activityId"],
    foreignKeys = [
        ForeignKey(
            entity = BootikSiteDraftEntity::class,
            parentColumns = ["id"],
            childColumns = ["siteId"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = BootikActivityDraftEntity::class,
            parentColumns = ["id"],
            childColumns = ["activityId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["activityId"])]
)
data class BootikSiteActivityDraftEntity(
    val siteId: String,
    val activityId: String,
    val isPrimary: Boolean = true
)
