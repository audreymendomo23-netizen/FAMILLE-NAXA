package cm.naxa.widemeet.auth

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

/** Local app gate, not a substitute for server authentication or device integrity.
 * Five failed attempts erase the remembered session and require normal sign-in.
 * Only a keyed HMAC of a salted PIN is stored; the key is non-exportable.
 */
class LocalUnlock(context:Context){
 private val prefs=context.getSharedPreferences("widemeet-local-unlock",Context.MODE_PRIVATE)
 private val vault=SessionVault(context)
 private val alias="widemeet-local-pin-v1"
 private fun key():SecretKey{
  val store=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
  (store.getKey(alias,null) as? SecretKey)?.let{return it}
  val generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256,"AndroidKeyStore")
  generator.init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY).setDigests(KeyProperties.DIGEST_SHA256).build())
  return generator.generateKey()
 }
 private fun encode(bytes:ByteArray)=Base64.encodeToString(bytes,Base64.NO_WRAP)
 private fun decode(value:String)=Base64.decode(value,Base64.NO_WRAP)
 private fun mac(pin:String,salt:ByteArray):ByteArray=Mac.getInstance("HmacSHA256").apply{init(key());update(salt)}.doFinal(pin.toByteArray(Charsets.UTF_8))
 fun configured():Boolean=prefs.contains("salt")&&prefs.contains("tag")
 @Synchronized fun configure(pin:String){
  require(Regex("^[0-9]{4}$").matches(pin))
  val salt=ByteArray(32).also{SecureRandom().nextBytes(it)}
  check(prefs.edit().putString("salt",encode(salt)).putString("tag",encode(mac(pin,salt))).putInt("failures",0).commit())
 }
 @Synchronized fun verify(pin:String):Boolean{
  if(!configured())return false
  val previous=prefs.getInt("failures",0)
  if(previous>=5){clear();return false}
  // Record attempt before comparison. A process kill cannot reset the counter.
  if(!prefs.edit().putInt("failures",previous+1).commit()){clear();return false}
  val ok=runCatching{Regex("^[0-9]{4}$").matches(pin)&&MessageDigest.isEqual(decode(prefs.getString("tag","")!!),mac(pin,decode(prefs.getString("salt","")!!)))}.getOrDefault(false)
  if(ok){if(!prefs.edit().putInt("failures",0).commit()){clear();return false};return true}
  if(previous+1>=5)clear()
  return false
 }
 @Synchronized fun clear(){
  vault.clear();prefs.edit().clear().commit()
  runCatching{KeyStore.getInstance("AndroidKeyStore").apply{load(null);deleteEntry(alias)}}
 }
}
