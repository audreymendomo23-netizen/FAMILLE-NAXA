package cm.naxa.naxaservices

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.io.FileNotFoundException
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/** One immutable, authenticated pending capture per member/device/site/post. Never a validated attendance. */
internal class AttendanceProofJournal(context:Context,org:String,member:String,device:String,site:String,post:String?) {
    private val app=context.applicationContext
    private val scope=listOf(org,member,device,site,post.orEmpty()).joinToString("|")
    private val aad=("ns-attendance-journal-v1|"+scope).toByteArray(Charsets.UTF_8)
    private val file=AtomicFile(File(app.noBackupFilesDir,"attendance-"+MessageDigest.getInstance("SHA-256").digest(aad).joinToString(""){"%02x".format(it.toInt() and 255)}+".pending"))
    private fun key(create:Boolean):SecretKey {
        val ks=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
        (ks.getKey(ALIAS,null) as? SecretKey)?.let{return it}
        check(create){"ATTENDANCE_KEY_MISSING"}
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply{
            init(KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }
    fun boot():Int=Settings.Global.getInt(app.contentResolver,"boot_count",-1)
    fun read():JSONObject?=synchronized(lock){
        val bytes=try{file.readFully()}catch(_:FileNotFoundException){return@synchronized null}
        require(bytes.size in 29..MAX_BYTES)
        val c=Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE,key(false),GCMParameterSpec(128,bytes.copyOfRange(0,12)))
        c.updateAAD(aad)
        val clear=c.doFinal(bytes.copyOfRange(12,bytes.size))
        try{JSONObject(String(clear,Charsets.UTF_8)).also{require(it.getString("scope")==scope)}}finally{clear.fill(0)}
    }
    fun save(value:JSONObject)=synchronized(lock){
        check(read()==null){"ATTENDANCE_PENDING_EXISTS"}
        require(value.getString("id")==UUID.fromString(value.getString("id")).toString())
        val payload=JSONObject(value.toString()).put("scope",scope).put("wall",System.currentTimeMillis())
            .put("tick",SystemClock.elapsedRealtime()).put("boot",boot())
        require(payload.getInt("boot")>=0)
        val clear=payload.toString().toByteArray(Charsets.UTF_8)
        try{
            require(clear.size<MAX_BYTES-28)
            val c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key(true));c.updateAAD(aad)
            val bytes=c.iv+c.doFinal(clear)
            val output=file.startWrite()
            try{output.write(bytes);file.finishWrite(output)}catch(e:Exception){file.failWrite(output);throw e}
        }finally{clear.fill(0)}
    }
    fun remove(expectedId:String)=synchronized(lock){
        val existing=read()?:return@synchronized
        require(existing.getString("id")==expectedId)
        file.delete()
    }
    fun replayable(value:JSONObject):Boolean=valid(value.getLong("wall"),value.getLong("tick"),value.getInt("boot"),value.getLong("occurred_ms"),System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot())
    companion object{
        private const val ALIAS="naxa-services-attendance-journal-v1"
        private const val MAX_BYTES=3_000_000
        private val lock=Any()
        // Existing v21 server window is not widened. Clock discontinuity fails closed.
        fun valid(wall:Long,tick:Long,boot:Int,occurred:Long,now:Long,elapsed:Long,currentBoot:Int):Boolean{
            if(boot<0||boot!=currentBoot||wall<=0||occurred<=0||tick<0||elapsed<tick||now<wall||occurred>wall||wall-occurred>5_000)return false
            val age=now-occurred
            return age in 0..299_000 && elapsed-tick<299_000 && kotlin.math.abs((now-wall)-(elapsed-tick))<=5_000
        }
    }
}
