package cm.naxa.naxasecurity
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/** Adaptation du coffre NAXA SERVICES. Le stockage est volontaire, jamais de mot de passe. */
internal class SecuritySessionVault(context:Context){
 private val prefs=context.getSharedPreferences("naxa_security_session_v1",Context.MODE_PRIVATE)
 private val alias="naxa-security-session-v1"
 private fun key(create:Boolean):SecretKey?{
  val store=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
  (store.getKey(alias,null) as? SecretKey)?.let{return it}
  if(!create)return null
  return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply{init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())}.generateKey()
 }
 @Synchronized fun save(member:String,org:String,device:String,refresh:String,consent:Boolean):Boolean{
  if(!consent){clear();return false}
  if(listOf(member,org,device,refresh).any{it.isBlank()}||refresh.length<20)return false
  return runCatching{
   val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key(true)!!);cipher.updateAAD(alias.toByteArray())
   val data=JSONObject().put("app","naxa-security").put("member",member).put("org",org).put("device",device).put("refresh",refresh).toString()
   prefs.edit().putString("sealed",Base64.encodeToString(cipher.iv+cipher.doFinal(data.toByteArray(Charsets.UTF_8)),Base64.NO_WRAP)).commit()
  }.getOrDefault(false)
 }
 @Synchronized fun refreshToken(member:String,org:String,device:String):String?=runCatching{
  val bytes=Base64.decode(prefs.getString("sealed",null)?:return null,Base64.NO_WRAP)
  require(bytes.size>28);val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(false)?:return null,GCMParameterSpec(128,bytes.copyOfRange(0,12)));cipher.updateAAD(alias.toByteArray())
  val j=JSONObject(String(cipher.doFinal(bytes.copyOfRange(12,bytes.size)),Charsets.UTF_8))
  require(j.getString("app")=="naxa-security"&&j.getString("member")==member&&j.getString("org")==org&&j.getString("device")==device)
  j.getString("refresh")
 }.getOrNull()
 @Synchronized fun clear(){prefs.edit().clear().commit()}
}
