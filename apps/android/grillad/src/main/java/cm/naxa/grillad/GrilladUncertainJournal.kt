package cm.naxa.grillad
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
// Durable uncertain operation only. Credentials and sessions are not persisted here.
internal class GrilladUncertainJournal(context:Context){
 private val prefs=context.getSharedPreferences("grillad-uncertain-v1",Context.MODE_PRIVATE)
 private val alias="cm.naxa.grillad.uncertain.v1"
 private fun account(user:String)=UUID.fromString(user).toString().also{require(it.equals(user,true))}
 private fun valid(req:JSONObject):JSONObject{require(req.optString("action") in listOf("mutate","attendance_capture","connect_transition","renewal_action","offline_batch"));listOf("org","site","event").forEach{account(req.getString(it))};return req}
 private fun key(create:Boolean):SecretKey{val ks=KeyStore.getInstance("AndroidKeyStore").apply{load(null)};val existing=ks.getKey(alias,null) as? SecretKey;if(existing!=null)return existing;check(create){"Journal local illisible"};return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply{init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())}.generateKey()}
 private fun aad(user:String,event:String)="GRILLAD:$user:$event".toByteArray(Charsets.UTF_8)
 private fun enc(b:ByteArray)=Base64.encodeToString(b,Base64.NO_WRAP)
 private fun dec(s:String)=Base64.decode(s,Base64.NO_WRAP)
 @Synchronized fun read(user:String):JSONObject?{val id=account(user);val raw=prefs.getString(id,null)?:return null;val row=JSONObject(raw);val event=row.getString("event");val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(false),GCMParameterSpec(128,dec(row.getString("iv"))));cipher.updateAAD(aad(id,event));val req=valid(JSONObject(String(cipher.doFinal(dec(row.getString("cipher"))),Charsets.UTF_8)));check(req.getString("event")==event);return req}
 @Synchronized fun reserve(user:String,req:JSONObject){val id=account(user);valid(req);val previous=read(id);if(previous!=null){check(previous.toString()==req.toString()){"Une autre opération attend confirmation"};return};val event=req.getString("event");val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key(true));cipher.updateAAD(aad(id,event));val row=JSONObject().put("event",event).put("iv",enc(cipher.iv)).put("cipher",enc(cipher.doFinal(req.toString().toByteArray(Charsets.UTF_8))));check(prefs.edit().putString(id,row.toString()).commit()){"Écriture locale impossible"}}
 @Synchronized fun clear(user:String,event:String){val id=account(user);val row=prefs.getString(id,null)?:return;check(JSONObject(row).getString("event")==event){"Requête différente"};check(prefs.edit().remove(id).commit()){"Effacement local impossible"}}
}
