package cm.naxa.bootik.data

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import cm.naxa.bootik.BootikScopedEvent
import cm.naxa.bootik.BootikCatalogCache
import cm.naxa.bootik.BootikScopedDao
import cm.naxa.bootik.BootikOfflineEvent
import cm.naxa.bootik.BootikOfflineEventDao

@Database(
    entities = [
        BootikWorkspaceDraftEntity::class,
        BootikActivityDraftEntity::class,
        BootikSiteDraftEntity::class,
        BootikSiteActivityDraftEntity::class,
        BootikOfflineEvent::class,
        BootikScopedEvent::class,
        BootikCatalogCache::class
    ],
    version = 2,
    exportSchema = false
)
abstract class BootikLocalDatabase : RoomDatabase() {
    abstract fun drafts(): BootikDraftDao
    abstract fun offlineEvents(): BootikOfflineEventDao
    abstract fun scoped(): BootikScopedDao
}

val BOOTIK_MIGRATION_1_2=object:Migration(1,2){
 override fun migrate(db:SupportSQLiteDatabase){
  db.execSQL("CREATE TABLE IF NOT EXISTS bk_scoped_outbox (eventId TEXT NOT NULL PRIMARY KEY, organizationId TEXT NOT NULL, memberId TEXT NOT NULL, siteId TEXT NOT NULL, sequence INTEGER NOT NULL, payload TEXT NOT NULL, state TEXT NOT NULL)")
  db.execSQL("CREATE INDEX IF NOT EXISTS index_bk_scoped_outbox_organizationId_memberId_siteId_state_sequence ON bk_scoped_outbox (organizationId,memberId,siteId,state,sequence)")
  db.execSQL("CREATE TABLE IF NOT EXISTS bk_catalog_cache (organizationId TEXT NOT NULL, memberId TEXT NOT NULL, siteId TEXT NOT NULL, itemsJson TEXT NOT NULL, updatedAt INTEGER NOT NULL, PRIMARY KEY (organizationId,memberId,siteId))")
 }
}
