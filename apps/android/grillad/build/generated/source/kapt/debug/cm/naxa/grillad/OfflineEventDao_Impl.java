package cm.naxa.grillad;

import android.database.Cursor;
import android.os.CancellationSignal;
import androidx.annotation.NonNull;
import androidx.room.CoroutinesRoom;
import androidx.room.EntityInsertionAdapter;
import androidx.room.RoomDatabase;
import androidx.room.RoomSQLiteQuery;
import androidx.room.SharedSQLiteStatement;
import androidx.room.util.CursorUtil;
import androidx.room.util.DBUtil;
import androidx.sqlite.db.SupportSQLiteStatement;
import java.lang.Class;
import java.lang.Exception;
import java.lang.Integer;
import java.lang.Long;
import java.lang.Object;
import java.lang.Override;
import java.lang.String;
import java.lang.SuppressWarnings;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.Callable;
import javax.annotation.processing.Generated;
import kotlin.coroutines.Continuation;

@Generated("androidx.room.RoomProcessor")
@SuppressWarnings({"unchecked", "deprecation"})
public final class OfflineEventDao_Impl implements OfflineEventDao {
  private final RoomDatabase __db;

  private final EntityInsertionAdapter<OfflineEvent> __insertionAdapterOfOfflineEvent;

  private final SharedSQLiteStatement __preparedStmtOfUpdateState;

  public OfflineEventDao_Impl(@NonNull final RoomDatabase __db) {
    this.__db = __db;
    this.__insertionAdapterOfOfflineEvent = new EntityInsertionAdapter<OfflineEvent>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR IGNORE INTO `offline_events` (`eventId`,`appId`,`aggregateType`,`payloadJson`,`deviceSequence`,`createdAtEpochMs`,`state`) VALUES (?,?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final OfflineEvent entity) {
        if (entity.getEventId() == null) {
          statement.bindNull(1);
        } else {
          statement.bindString(1, entity.getEventId());
        }
        if (entity.getAppId() == null) {
          statement.bindNull(2);
        } else {
          statement.bindString(2, entity.getAppId());
        }
        if (entity.getAggregateType() == null) {
          statement.bindNull(3);
        } else {
          statement.bindString(3, entity.getAggregateType());
        }
        if (entity.getPayloadJson() == null) {
          statement.bindNull(4);
        } else {
          statement.bindString(4, entity.getPayloadJson());
        }
        statement.bindLong(5, entity.getDeviceSequence());
        statement.bindLong(6, entity.getCreatedAtEpochMs());
        if (entity.getState() == null) {
          statement.bindNull(7);
        } else {
          statement.bindString(7, entity.getState());
        }
      }
    };
    this.__preparedStmtOfUpdateState = new SharedSQLiteStatement(__db) {
      @Override
      @NonNull
      public String createQuery() {
        final String _query = "UPDATE offline_events SET state=? WHERE eventId=?";
        return _query;
      }
    };
  }

  @Override
  public Object enqueue(final OfflineEvent event, final Continuation<? super Long> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Long>() {
      @Override
      @NonNull
      public Long call() throws Exception {
        __db.beginTransaction();
        try {
          final Long _result = __insertionAdapterOfOfflineEvent.insertAndReturnId(event);
          __db.setTransactionSuccessful();
          return _result;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object updateState(final String eventId, final String state,
      final Continuation<? super Integer> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Integer>() {
      @Override
      @NonNull
      public Integer call() throws Exception {
        final SupportSQLiteStatement _stmt = __preparedStmtOfUpdateState.acquire();
        int _argIndex = 1;
        if (state == null) {
          _stmt.bindNull(_argIndex);
        } else {
          _stmt.bindString(_argIndex, state);
        }
        _argIndex = 2;
        if (eventId == null) {
          _stmt.bindNull(_argIndex);
        } else {
          _stmt.bindString(_argIndex, eventId);
        }
        try {
          __db.beginTransaction();
          try {
            final Integer _result = _stmt.executeUpdateDelete();
            __db.setTransactionSuccessful();
            return _result;
          } finally {
            __db.endTransaction();
          }
        } finally {
          __preparedStmtOfUpdateState.release(_stmt);
        }
      }
    }, $completion);
  }

  @Override
  public Object queued(final Continuation<? super List<OfflineEvent>> $completion) {
    final String _sql = "SELECT * FROM offline_events WHERE state='queued' ORDER BY deviceSequence";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<List<OfflineEvent>>() {
      @Override
      @NonNull
      public List<OfflineEvent> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfEventId = CursorUtil.getColumnIndexOrThrow(_cursor, "eventId");
          final int _cursorIndexOfAppId = CursorUtil.getColumnIndexOrThrow(_cursor, "appId");
          final int _cursorIndexOfAggregateType = CursorUtil.getColumnIndexOrThrow(_cursor, "aggregateType");
          final int _cursorIndexOfPayloadJson = CursorUtil.getColumnIndexOrThrow(_cursor, "payloadJson");
          final int _cursorIndexOfDeviceSequence = CursorUtil.getColumnIndexOrThrow(_cursor, "deviceSequence");
          final int _cursorIndexOfCreatedAtEpochMs = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAtEpochMs");
          final int _cursorIndexOfState = CursorUtil.getColumnIndexOrThrow(_cursor, "state");
          final List<OfflineEvent> _result = new ArrayList<OfflineEvent>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final OfflineEvent _item;
            final String _tmpEventId;
            if (_cursor.isNull(_cursorIndexOfEventId)) {
              _tmpEventId = null;
            } else {
              _tmpEventId = _cursor.getString(_cursorIndexOfEventId);
            }
            final String _tmpAppId;
            if (_cursor.isNull(_cursorIndexOfAppId)) {
              _tmpAppId = null;
            } else {
              _tmpAppId = _cursor.getString(_cursorIndexOfAppId);
            }
            final String _tmpAggregateType;
            if (_cursor.isNull(_cursorIndexOfAggregateType)) {
              _tmpAggregateType = null;
            } else {
              _tmpAggregateType = _cursor.getString(_cursorIndexOfAggregateType);
            }
            final String _tmpPayloadJson;
            if (_cursor.isNull(_cursorIndexOfPayloadJson)) {
              _tmpPayloadJson = null;
            } else {
              _tmpPayloadJson = _cursor.getString(_cursorIndexOfPayloadJson);
            }
            final long _tmpDeviceSequence;
            _tmpDeviceSequence = _cursor.getLong(_cursorIndexOfDeviceSequence);
            final long _tmpCreatedAtEpochMs;
            _tmpCreatedAtEpochMs = _cursor.getLong(_cursorIndexOfCreatedAtEpochMs);
            final String _tmpState;
            if (_cursor.isNull(_cursorIndexOfState)) {
              _tmpState = null;
            } else {
              _tmpState = _cursor.getString(_cursorIndexOfState);
            }
            _item = new OfflineEvent(_tmpEventId,_tmpAppId,_tmpAggregateType,_tmpPayloadJson,_tmpDeviceSequence,_tmpCreatedAtEpochMs,_tmpState);
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @NonNull
  public static List<Class<?>> getRequiredConverters() {
    return Collections.emptyList();
  }
}
