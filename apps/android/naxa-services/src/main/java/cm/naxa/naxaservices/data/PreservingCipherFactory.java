package cm.naxa.naxaservices.data;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.sqlite.db.SupportSQLiteDatabase;
import androidx.sqlite.db.SupportSQLiteOpenHelper;
import net.zetetic.database.sqlcipher.SQLiteDatabase;
import net.zetetic.database.sqlcipher.SQLiteOpenHelper;

/** SQLCipher's default corruption handler can delete a database; never delete pending ERP data. */
public final class PreservingCipherFactory implements SupportSQLiteOpenHelper.Factory {
    private final byte[] password;
    public PreservingCipherFactory(byte[] password) { this.password = password.clone(); }
    @NonNull @Override public SupportSQLiteOpenHelper create(@NonNull SupportSQLiteOpenHelper.Configuration c) {
        SQLiteOpenHelper helper = new SQLiteOpenHelper(c.context, c.name, password, null,
                c.callback.version, 0, (database, error) -> { throw error; }, null, false) {
            @Override public void onCreate(SQLiteDatabase db) { c.callback.onCreate(db); }
            @Override public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) { c.callback.onUpgrade(db, oldVersion, newVersion); }
            @Override public void onDowngrade(SQLiteDatabase db, int oldVersion, int newVersion) { c.callback.onDowngrade(db, oldVersion, newVersion); }
            @Override public void onOpen(SQLiteDatabase db) { c.callback.onOpen(db); }
            @Override public void onConfigure(SQLiteDatabase db) { c.callback.onConfigure(db); }
        };
        return new SupportSQLiteOpenHelper() {
            @Nullable @Override public String getDatabaseName() { return helper.getDatabaseName(); }
            @Override public void setWriteAheadLoggingEnabled(boolean enabled) { helper.setWriteAheadLoggingEnabled(enabled); }
            @NonNull @Override public SupportSQLiteDatabase getWritableDatabase() { return helper.getWritableDatabase(); }
            @NonNull @Override public SupportSQLiteDatabase getReadableDatabase() { return helper.getReadableDatabase(); }
            @Override public void close() { helper.close(); }
        };
    }
}
