package cm.naxa.bootik.data

import androidx.room.Database
import androidx.room.RoomDatabase
import cm.naxa.bootik.BootikOfflineEvent
import cm.naxa.bootik.BootikOfflineEventDao

@Database(
    entities = [
        BootikWorkspaceDraftEntity::class,
        BootikActivityDraftEntity::class,
        BootikSiteDraftEntity::class,
        BootikSiteActivityDraftEntity::class,
        BootikOfflineEvent::class
    ],
    version = 1,
    exportSchema = false
)
abstract class BootikLocalDatabase : RoomDatabase() {
    abstract fun drafts(): BootikDraftDao
    abstract fun offlineEvents(): BootikOfflineEventDao
}
