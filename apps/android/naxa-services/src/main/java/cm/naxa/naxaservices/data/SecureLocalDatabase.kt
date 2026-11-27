package cm.naxa.naxaservices.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.system.Os
import android.util.AtomicFile
import androidx.room.Room
import net.zetetic.database.DatabaseErrorHandler
import net.zetetic.database.sqlcipher.SQLiteDatabase
import cm.naxa.naxaservices.data.PreservingCipherFactory
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** One database configuration for the UI and both workers. Open off the main thread. */
internal object SecureLocalDatabase {
    private const val NAME = "naxa-services-local.db"
    private const val ALIAS = "naxa-services-local-db-wrap-v1"
    private val sqliteHeader = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)
    private val preserveOnCorruption = DatabaseErrorHandler { _, error -> throw error }

    @Synchronized
    fun open(context:Context, name:String=NAME):NsServicesDatabase {
        require(name.matches(Regex("[a-zA-Z0-9_.-]+")) && !name.startsWith("."))
        val app=context.applicationContext
        System.loadLibrary("sqlcipher")
        val file=app.getDatabasePath(name)
        check(file.parentFile!!.exists() || file.parentFile!!.mkdirs())
        val plaintext=file.exists() && isPlaintext(file)
        val passphrase=passphrase(app,name,file.exists()&&!plaintext)
        if(plaintext) encryptExisting(file,passphrase)
        if(file.exists()){
            // Verify the key without letting a default corruption callback remove the file.
            SQLiteDatabase.openDatabase(file.absolutePath,passphrase,null,SQLiteDatabase.OPEN_READONLY,preserveOnCorruption,null).use { db ->
                check(scalar(db,"SELECT count(*) FROM sqlite_master")>=0)
            }
        }
        val db=Room.databaseBuilder(app,NsServicesDatabase::class.java,name)
            .openHelperFactory(PreservingCipherFactory(passphrase))
            .addMigrations(NS_SERVICES_MIGRATION_1_2,NS_SERVICES_MIGRATION_2_3,NS_SERVICES_MIGRATION_3_4,
                NS_SERVICES_MIGRATION_4_5,NS_SERVICES_MIGRATION_5_6,NS_SERVICES_MIGRATION_6_7,
                NS_SERVICES_MIGRATION_7_8,NS_SERVICES_MIGRATION_8_9,NS_SERVICES_MIGRATION_9_10,
                NS_SERVICES_MIGRATION_10_11,NS_SERVICES_MIGRATION_11_12,NS_SERVICES_MIGRATION_12_13,
                NS_SERVICES_MIGRATION_13_14,NS_SERVICES_MIGRATION_14_15,NS_SERVICES_MIGRATION_15_16,NS_SERVICES_MIGRATION_16_17)
            .build()
        try { db.openHelper.writableDatabase; return db }
        catch(failure:Exception){db.close();throw failure}
    }

    private fun isPlaintext(file:File):Boolean = file.inputStream().use { input ->
        val header=ByteArray(sqliteHeader.size)
        input.read(header)==header.size && header.contentEquals(sqliteHeader)
    }

    private fun passphrase(context:Context,name:String,encryptedExists:Boolean):ByteArray {
        val wrapped=AtomicFile(File(context.noBackupFilesDir,"$name.wrapped-key"))
        val stored=try { wrapped.readFully() } catch(missing:java.io.FileNotFoundException) { null }
        if(stored!=null){
            check(stored.size>28) { "LOCAL_DB_KEY_INVALID" }
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE,wrappingKey(false),GCMParameterSpec(128,stored.copyOfRange(0,12)))
            cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
            return cipher.doFinal(stored.copyOfRange(12,stored.size)).also { check(it.size==64) }
        }
        check(!encryptedExists) { "LOCAL_DB_KEY_MISSING" }
        // A hex passphrase has 256 bits of randomness; no password or device identifier is used.
        val random=ByteArray(32).also { SecureRandom().nextBytes(it) }
        val secret=random.joinToString("") { "%02x".format(it.toInt() and 0xff) }.toByteArray(Charsets.US_ASCII)
        random.fill(0)
        val cipher=Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE,wrappingKey(true))
        cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
        val stream=wrapped.startWrite()
        try { stream.write(cipher.iv+cipher.doFinal(secret)); wrapped.finishWrite(stream) }
        catch(failure:Exception){wrapped.failWrite(stream);throw failure}
        return secret
    }

    private fun wrappingKey(allowCreate:Boolean):SecretKey {
        val store=KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS,null) as? SecretKey)?.let { return it }
        check(allowCreate) { "LOCAL_DB_WRAP_KEY_MISSING" }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }

    private fun scalar(db:SQLiteDatabase,sql:String):Long =
        db.rawQuery(sql,emptyArray<String>()).use { check(it.moveToFirst());it.getLong(0) }

    private fun quoted(name:String):String = "\"" + name.replace("\"","\"\"") + "\""

    /** The original remains intact until a complete, verified export can atomically replace it. */
    private fun encryptExisting(source:File,passphrase:ByteArray) {
        val stage=File(source.parentFile,source.name+".encrypted-stage")
        fun clearStage(){
            listOf("", "-wal","-shm","-journal").forEach { suffix ->
                val file=File(stage.path+suffix)
                check(!file.exists()||file.delete()) { "LOCAL_DB_STAGE_BUSY" }
            }
        }
        clearStage()
        try {
            // ATTACH inherits the source connection's CREATE flag. Prepare the target
            // explicitly with its key; never let ATTACH silently create a plaintext target.
            check(source.isFile)
            SQLiteDatabase.openDatabase(stage.absolutePath,passphrase,null,SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY,preserveOnCorruption,null).use { target ->
                target.execSQL("PRAGMA user_version = 0")
            }
            SQLiteDatabase.openDatabase(source.absolutePath,"",null,SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY,preserveOnCorruption,null).use { plain ->
                plain.rawQuery("PRAGMA wal_checkpoint(TRUNCATE)",emptyArray<String>()).use { c ->
                    check(c.moveToFirst() && c.getInt(0)==0) { "LOCAL_DB_WAL_BUSY" }
                }
                plain.rawQuery("PRAGMA journal_mode=DELETE",emptyArray<String>()).use { c ->
                    check(c.moveToFirst() && c.getString(0).equals("delete",true))
                }
                val version=plain.version
                val tables=plain.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",emptyArray<String>()).use { c ->
                    buildList { while(c.moveToNext()) add(c.getString(0)) }
                }
                val counts=tables.associateWith { scalar(plain,"SELECT count(*) FROM "+quoted(it)) }
                plain.execSQL("ATTACH DATABASE ? AS encrypted KEY ?",arrayOf<Any>(stage.absolutePath,String(passphrase,Charsets.US_ASCII)))
                plain.rawQuery("SELECT sqlcipher_export('encrypted')",emptyArray<String>()).use { check(it.moveToFirst()) }
                plain.execSQL("PRAGMA encrypted.user_version = "+version)
                plain.execSQL("DETACH DATABASE encrypted")
                SQLiteDatabase.openDatabase(stage.absolutePath,passphrase,null,SQLiteDatabase.OPEN_READONLY,preserveOnCorruption,null).use { encrypted ->
                    check(encrypted.version==version)
                    check(!isPlaintext(stage))
                    encrypted.rawQuery("PRAGMA integrity_check",emptyArray<String>()).use { c -> check(c.moveToFirst() && c.getString(0)=="ok" && !c.moveToNext()) }
                    counts.forEach { (table,count) -> check(scalar(encrypted,"SELECT count(*) FROM "+quoted(table))==count) }
                }
            }
            listOf("-wal","-shm","-journal").forEach { suffix ->
                check(!File(source.path+suffix).exists()) { "LOCAL_DB_SOURCE_BUSY" }
                check(!File(stage.path+suffix).exists()) { "LOCAL_DB_STAGE_BUSY" }
            }
            FileOutputStream(stage,true).use { it.fd.sync() }
            Os.rename(stage.absolutePath,source.absolutePath)
        } finally { clearStage() }
    }
}
