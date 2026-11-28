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
 private fun encryptedRows(id:String):List<JSONObject>{val raw=prefs.getString(id,null)?:return emptyList();val row=JSONObject(raw);val q=row.optJSONArray("queue")?:return listOf(row);check(q.length() in 1..20);return (0 until q.length()).map{q.getJSONObject(it)}}
 private fun decrypt(id:String,row:JSONObject):JSONObject{val event=row.getString("event");val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(false),GCMParameterSpec(128,dec(row.getString("iv"))));cipher.updateAAD(aad(id,event));val req=valid(JSONObject(String(cipher.doFinal(dec(row.getString("cipher"))),Charsets.UTF_8)));check(req.getString("event")==event);return req}
 private fun encrypt(id:String,req:JSONObject):JSONObject{valid(req);val event=req.getString("event");val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key(true));cipher.updateAAD(aad(id,event));return JSONObject().put("event",event).put("iv",enc(cipher.iv)).put("cipher",enc(cipher.doFinal(req.toString().toByteArray(Charsets.UTF_8))))}
 private fun write(id:String,q:List<JSONObject>){val edit=prefs.edit();if(q.isEmpty())edit.remove(id)else edit.putString(id,JSONObject().put("queue",org.json.JSONArray(q)).toString());check(edit.commit()){"Écriture locale impossible"}}
 @Synchronized fun count(user:String):Int=encryptedRows(account(user)).size
 @Synchronized fun read(user:String):JSONObject?{val id=account(user);return encryptedRows(id).firstOrNull()?.let{decrypt(id,it)}}
 @Synchronized fun reserve(user:String,req:JSONObject){val id=account(user);valid(req);val q=encryptedRows(id);if(q.isNotEmpty()){check(decrypt(id,q.first()).toString()==req.toString()){"Une autre opération attend confirmation"};return};write(id,listOf(encrypt(id,req)))}
 // Only locally composed, unconfirmed batches may be appended. FIFO, one scope/day/cash; no mutation bypass.
 @Synchronized fun appendDraft(user:String,req:JSONObject){val id=account(user);valid(req);require(req.optString("action")=="offline_batch"&&req.optString("day").matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}")));val lines=req.getJSONArray("lines");require(lines.length() in 1..30);val q=encryptedRows(id);val decoded=q.map{decrypt(id,it)};val same=decoded.firstOrNull{it.getString("event")==req.getString("event")};if(same!=null){check(same.toString()==req.toString()){"Requête différente"};return};check(q.size<20){"Vingt lots en attente : synchronisez avant de poursuivre"};check(decoded.all{it.optString("action")=="offline_batch"&&listOf("org","site","day","cash").all{k->it.optString(k)==req.optString(k)}}){"Lot d’un autre périmètre ou opération en attente"};val newIds=rows(lines).map{account(it.getString("event"))};check(newIds.size==lines.length()&&newIds.toSet().size==newIds.size);val oldIds=decoded.flatMap{rows(it.getJSONArray("lines")).map{x->x.getString("event")}};check(newIds.none{it in oldIds}){"Ligne déjà enregistrée"};write(id,q+encrypt(id,req))}
 @Synchronized fun clear(user:String,event:String){val id=account(user);val q=encryptedRows(id);if(q.isEmpty())return;check(decrypt(id,q.first()).getString("event")==event){"Requête différente"};write(id,q.drop(1))}
}
