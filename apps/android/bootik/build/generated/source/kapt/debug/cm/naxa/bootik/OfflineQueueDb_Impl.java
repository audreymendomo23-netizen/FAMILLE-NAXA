package cm.naxa.bootik;

import androidx.annotation.NonNull;
import androidx.room.DatabaseConfiguration;
import androidx.room.InvalidationTracker;
import androidx.room.RoomDatabase;
import androidx.room.RoomOpenHelper;
import androidx.room.migration.AutoMigrationSpec;
import androidx.room.migration.Migration;
import androidx.room.util.DBUtil;
import androidx.room.util.TableInfo;
import androidx.sqlite.db.SupportSQLiteDatabase;
import androidx.sqlite.db.SupportSQLiteOpenHelper;
import java.lang.Class;
import java.lang.Override;
import java.lang.String;
import java.lang.SuppressWarnings;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.annotation.processing.Generated;

@Generated("androidx.room.RoomProcessor")
@SuppressWarnings({"unchecked", "deprecation"})
public final class OfflineQueueDb_Impl extends OfflineQueueDb {
  private volatile OfflineEventDao _offlineEventDao;

  @Override
  @NonNull
  protected SupportSQLiteOpenHelper createOpenHelper(@NonNull final DatabaseConfiguration config) {
    final SupportSQLiteOpenHelper.Callback _openCallback = new RoomOpenHelper(config, new RoomOpenHelper.Delegate(1) {
      @Override
      public void createAllTables(@NonNull final SupportSQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS `offline_events` (`eventId` TEXT NOT NULL, `appId` TEXT NOT NULL, `aggregateType` TEXT NOT NULL, `payloadJson` TEXT NOT NULL, `deviceSequence` INTEGER NOT NULL, `createdAtEpochMs` INTEGER NOT NULL, `state` TEXT NOT NULL, PRIMARY KEY(`eventId`))");
        db.execSQL("CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)");
        db.execSQL("INSERT OR REPLACE INTO room_master_table (id,identity_hash) VALUES(42, '50f8f71eb48c151ba5b9facf3edf21bb')");
      }

      @Override
      public void dropAllTables(@NonNull final SupportSQLiteDatabase db) {
        db.execSQL("DROP TABLE IF EXISTS `offline_events`");
        final List<? extends RoomDatabase.Callback> _callbacks = mCallbacks;
        if (_callbacks != null) {
          for (RoomDatabase.Callback _callback : _callbacks) {
            _callback.onDestructiveMigration(db);
          }
        }
      }

      @Override
      public void onCreate(@NonNull final SupportSQLiteDatabase db) {
        final List<? extends RoomDatabase.Callback> _callbacks = mCallbacks;
        if (_callbacks != null) {
          for (RoomDatabase.Callback _callback : _callbacks) {
            _callback.onCreate(db);
          }
        }
      }

      @Override
      public void onOpen(@NonNull final SupportSQLiteDatabase db) {
        mDatabase = db;
        internalInitInvalidationTracker(db);
        final List<? extends RoomDatabase.Callback> _callbacks = mCallbacks;
        if (_callbacks != null) {
          for (RoomDatabase.Callback _callback : _callbacks) {
            _callback.onOpen(db);
          }
        }
      }

      @Override
      public void onPreMigrate(@NonNull final SupportSQLiteDatabase db) {
        DBUtil.dropFtsSyncTriggers(db);
      }

      @Override
      public void onPostMigrate(@NonNull final SupportSQLiteDatabase db) {
      }

      @Override
      @NonNull
      public RoomOpenHelper.ValidationResult onValidateSchema(
          @NonNull final SupportSQLiteDatabase db) {
        final HashMap<String, TableInfo.Column> _columnsOfflineEvents = new HashMap<String, TableInfo.Column>(7);
        _columnsOfflineEvents.put("eventId", new TableInfo.Column("eventId", "TEXT", true, 1, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsOfflineEvents.put("appId", new TableInfo.Column("appId", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsOfflineEvents.put("aggregateType", new TableInfo.Column("aggregateType", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsOfflineEvents.put("payloadJson", new TableInfo.Column("payloadJson", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsOfflineEvents.put("deviceSequence", new TableInfo.Column("deviceSequence", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsOfflineEvents.put("createdAtEpochMs", new TableInfo.Column("createdAtEpochMs", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsOfflineEvents.put("state", new TableInfo.Column("state", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        final HashSet<TableInfo.ForeignKey> _foreignKeysOfflineEvents = new HashSet<TableInfo.ForeignKey>(0);
        final HashSet<TableInfo.Index> _indicesOfflineEvents = new HashSet<TableInfo.Index>(0);
        final TableInfo _infoOfflineEvents = new TableInfo("offline_events", _columnsOfflineEvents, _foreignKeysOfflineEvents, _indicesOfflineEvents);
        final TableInfo _existingOfflineEvents = TableInfo.read(db, "offline_events");
        if (!_infoOfflineEvents.equals(_existingOfflineEvents)) {
          return new RoomOpenHelper.ValidationResult(false, "offline_events(cm.naxa.bootik.OfflineEvent).\n"
                  + " Expected:\n" + _infoOfflineEvents + "\n"
                  + " Found:\n" + _existingOfflineEvents);
        }
        return new RoomOpenHelper.ValidationResult(true, null);
      }
    }, "50f8f71eb48c151ba5b9facf3edf21bb", "661eba01799c43e9fca42fd11cfda03b");
    final SupportSQLiteOpenHelper.Configuration _sqliteConfig = SupportSQLiteOpenHelper.Configuration.builder(config.context).name(config.name).callback(_openCallback).build();
    final SupportSQLiteOpenHelper _helper = config.sqliteOpenHelperFactory.create(_sqliteConfig);
    return _helper;
  }

  @Override
  @NonNull
  protected InvalidationTracker createInvalidationTracker() {
    final HashMap<String, String> _shadowTablesMap = new HashMap<String, String>(0);
    final HashMap<String, Set<String>> _viewTables = new HashMap<String, Set<String>>(0);
    return new InvalidationTracker(this, _shadowTablesMap, _viewTables, "offline_events");
  }

  @Override
  public void clearAllTables() {
    super.assertNotMainThread();
    final SupportSQLiteDatabase _db = super.getOpenHelper().getWritableDatabase();
    try {
      super.beginTransaction();
      _db.execSQL("DELETE FROM `offline_events`");
      super.setTransactionSuccessful();
    } finally {
      super.endTransaction();
      _db.query("PRAGMA wal_checkpoint(FULL)").close();
      if (!_db.inTransaction()) {
        _db.execSQL("VACUUM");
      }
    }
  }

  @Override
  @NonNull
  protected Map<Class<?>, List<Class<?>>> getRequiredTypeConverters() {
    final HashMap<Class<?>, List<Class<?>>> _typeConvertersMap = new HashMap<Class<?>, List<Class<?>>>();
    _typeConvertersMap.put(OfflineEventDao.class, OfflineEventDao_Impl.getRequiredConverters());
    return _typeConvertersMap;
  }

  @Override
  @NonNull
  public Set<Class<? extends AutoMigrationSpec>> getRequiredAutoMigrationSpecs() {
    final HashSet<Class<? extends AutoMigrationSpec>> _autoMigrationSpecsSet = new HashSet<Class<? extends AutoMigrationSpec>>();
    return _autoMigrationSpecsSet;
  }

  @Override
  @NonNull
  public List<Migration> getAutoMigrations(
      @NonNull final Map<Class<? extends AutoMigrationSpec>, AutoMigrationSpec> autoMigrationSpecs) {
    final List<Migration> _autoMigrations = new ArrayList<Migration>();
    return _autoMigrations;
  }

  @Override
  public OfflineEventDao events() {
    if (_offlineEventDao != null) {
      return _offlineEventDao;
    } else {
      synchronized(this) {
        if(_offlineEventDao == null) {
          _offlineEventDao = new OfflineEventDao_Impl(this);
        }
        return _offlineEventDao;
      }
    }
  }
}
