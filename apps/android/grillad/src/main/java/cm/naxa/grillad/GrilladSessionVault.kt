package cm.naxa.grillad
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Opt-in only; never persists access tokens, passwords, cached business data or PIN. */
internal class GrilladSessionVault(context:Context){
 private val prefs=context.getSharedPreferences("grillad_session_v1",Context.MODE_PRIVATE)
 private val alias="grillad_session_aes_v1"
 private fun key(create:Boolean):SecretKey{val ks=KeyStore.getInstance("AndroidKeyStore").apply{load(null)};(ks.getKey(alias,null) as? SecretKey)?.let{return it};check(create){"Session locale inaccessible"};return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply{init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())}.generateKey()}
 private fun aad(installation:String)=("grillad-remember-v1:"+installation).toByteArray(Charsets.UTF_8)
 @Synchronized fun save(s:JSONObject,installation:String){val user=s.getString("user_id");val refresh=s.getString("refresh");require(user.isNotBlank()&&refresh.isNotBlank());val c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key(true));c.updateAAD(aad(installation));val bytes=c.doFinal(obj("user_id" to user,"refresh" to refresh).toString().toByteArray(Charsets.UTF_8));check(prefs.edit().putString("session",obj("iv" to Base64.encodeToString(c.iv,Base64.NO_WRAP),"cipher" to Base64.encodeToString(bytes,Base64.NO_WRAP)).toString()).commit())}
 @Synchronized fun read(installation:String):JSONObject?{val raw=prefs.getString("session",null)?:return null;return runCatching{val r=JSONObject(raw);val c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(false),GCMParameterSpec(128,Base64.decode(r.getString("iv"),Base64.NO_WRAP)));c.updateAAD(aad(installation));JSONObject(String(c.doFinal(Base64.decode(r.getString("cipher"),Base64.NO_WRAP)),Charsets.UTF_8))}.getOrElse{clear();null}}
 @Synchronized fun clear(){check(prefs.edit().remove("session").commit()){"Effacement de session impossible"}}
}
