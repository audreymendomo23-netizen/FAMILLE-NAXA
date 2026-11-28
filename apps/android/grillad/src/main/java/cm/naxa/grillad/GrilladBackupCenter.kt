package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import javax.crypto.spec.GCMParameterSpec
private fun encryptedBackup(data:JSONObject,password:String):ByteArray{
 require(data.optString("format") in listOf("grillad-business-export-v1","grillad-business-export-v2")&&password.length>=12)
 val random=SecureRandom();val salt=ByteArray(16).also{random.nextBytes(it)};val iv=ByteArray(12).also{random.nextBytes(it)}
 val spec=PBEKeySpec(password.toCharArray(),salt,600000,256);val key=try{SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded}finally{spec.clearPassword()}
 val cipher=Cipher.getInstance("AES/GCM/NoPadding");val bytes=try{cipher.init(Cipher.ENCRYPT_MODE,SecretKeySpec(key,"AES"),GCMParameterSpec(128,iv));cipher.updateAAD("grillad-backup-v1".toByteArray(Charsets.UTF_8));cipher.doFinal(data.toString().toByteArray(Charsets.UTF_8))}finally{key.fill(0)}
 fun b64(b:ByteArray)=android.util.Base64.encodeToString(b,android.util.Base64.NO_WRAP)
 return obj("format" to "grillad-backup-v1","kdf" to "PBKDF2-SHA256","iterations" to 600000,"salt" to b64(salt),"iv" to b64(iv),"ciphertext" to b64(bytes)).toString().toByteArray(Charsets.UTF_8)
}

private fun inspectEncryptedBackup(raw:ByteArray,password:String,org:String,site:String):String{
 require(raw.size<=6500000&&password.length>=12)
 val a=JSONObject(raw.toString(Charsets.UTF_8));require(a.optString("format")=="grillad-backup-v1"&&a.optString("kdf")=="PBKDF2-SHA256"&&a.optInt("iterations")==600000)
 fun b64(s:String)=android.util.Base64.decode(s,android.util.Base64.NO_WRAP)
 val salt=b64(a.getString("salt"));val iv=b64(a.getString("iv"));require(salt.size==16&&iv.size==12)
 val spec=PBEKeySpec(password.toCharArray(),salt,600000,256);val key=try{SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded}finally{spec.clearPassword()}
 val cipher=Cipher.getInstance("AES/GCM/NoPadding");val bytes=try{cipher.init(Cipher.DECRYPT_MODE,SecretKeySpec(key,"AES"),GCMParameterSpec(128,iv));cipher.updateAAD("grillad-backup-v1".toByteArray(Charsets.UTF_8));cipher.doFinal(b64(a.getString("ciphertext")))}finally{key.fill(0)}
 try{val d=JSONObject(bytes.toString(Charsets.UTF_8));require(d.optString("format") in listOf("grillad-business-export-v1","grillad-business-export-v2")&&d.optString("org")==org&&d.optString("site")==site);val t=d.getJSONObject("tables");val base=listOf("items","cash","cash_recounts","preparations","stock_adjustments","sales","cash_receipts","expenses","purchases","targets","dimension_targets","service_policy","service_revisions","daily_summary");val names=if(d.optString("format")=="grillad-business-export-v2")base+listOf("attendance_policy","attendance","attendance_corrections","missing_departures","missing_arrivals","notice_preference","notice_read") else base;require(t.length()==names.size);var count=0;for(n in names){val rows=t.getJSONArray(n);require(rows.length()<=10000);for(i in 0 until rows.length()){val row=rows.getJSONObject(i);require(row.optString("org")==org&&row.optString("site")==site);if(n=="attendance")require(row.has("photo")&&row.isNull("photo"))};count+=rows.length()};return "Archive vérifiée : "+count+" lignes, "+names.size+" tables. Aucun changement de base. Restauration intégrale non autorisée."}finally{bytes.fill(0)}
}

@Composable internal fun GrilladBackupCenter(enabled:Boolean,org:String,site:String,request:suspend(JSONObject)->Any){
 val ctx=LocalContext.current;val scope=rememberCoroutineScope()
 var freq by remember{mutableStateOf("off")};var hour by remember{mutableStateOf("06:00")};var weekday by remember{mutableStateOf("1")};var monthday by remember{mutableStateOf("1")};var password by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var status by remember{mutableStateOf("")};var loaded by remember{mutableStateOf(false)};var archive by remember{mutableStateOf<ByteArray?>(null)};var drive by remember{mutableStateOf<JSONObject?>(null)};var confirmDisconnect by remember{mutableStateOf(false)}
 val inspect=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null&&enabled&&!busy){val phrase=password;busy=true;scope.launch{try{status=withContext(Dispatchers.IO){val raw=ctx.contentResolver.openInputStream(uri)?.use{input->val out=java.io.ByteArrayOutputStream();val buf=ByteArray(8192);while(true){val n=input.read(buf);if(n<0)break;require(out.size()+n<=6500000);out.write(buf,0,n)};out.toByteArray()}?:error("archive");try{inspectEncryptedBackup(raw,phrase,org,site)}finally{raw.fill(0)}};password=""}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status="Archive refusée : phrase, intégrité ou point incorrect."}finally{busy=false}}}}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")){uri->val bytes=archive;archive=null;if(uri!=null&&bytes!=null)scope.launch{try{withContext(Dispatchers.IO){ctx.contentResolver.openOutputStream(uri,"w")?.use{it.write(bytes)}?:error("destination")};status="Archive chiffrée écrite dans la destination choisie."}catch(e:Exception){status="Écriture non confirmée."}finally{bytes.fill(0)}}else bytes?.fill(0)}
 fun prefs(write:Boolean){if(!enabled||busy)return;val h=hour.split(":");val hh=h.getOrNull(0)?.toIntOrNull();val mm=h.getOrNull(1)?.toIntOrNull();if(write&&(hh==null||mm==null||hh !in 0..23||mm !in 0..59)){status="Heure invalide";return};busy=true;scope.launch{try{val q=obj("action" to "backup_preferences");if(write)q.put("frequency",freq).put("minute",hh!!*60+mm!!).put("weekday",weekday.toInt()).put("monthday",monthday.toInt());val r=request(q) as JSONObject;freq=r.optString("frequency");hour=(r.optInt("minute")/60).toString().padStart(2,'0')+":"+(r.optInt("minute")%60).toString().padStart(2,'0');weekday=r.optInt("weekday").toString();monthday=r.optInt("monthday").toString();loaded=true;status="Préférences de programmation chargées ou enregistrées."}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status="Réglage indisponible."}finally{busy=false}}}
 fun cloud(op:String){if(!enabled||busy)return;busy=true;scope.launch{try{if(op=="connect"){val r=request(obj("action" to "drive_begin","password" to password)) as JSONObject;val uri=android.net.Uri.parse(r.optString("url"));check(uri.scheme=="https"&&uri.host=="accounts.google.com");password="";ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW,uri))}else{drive=request(obj("action" to "drive_control","operation" to op)) as JSONObject;status=if(drive?.optBoolean("connected")==true)"Drive autorisé : "+drive?.optString("status") else "Drive non connecté"}}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status="Action Drive non confirmée."}finally{busy=false}}}
 Text("Sauvegarde et restauration",style=MaterialTheme.typography.titleMedium);Text("Archive chiffrée des tables métier de ce point, hors comptes, secrets, photos et opérations non synchronisées. Restauration automatique non disponible.")
 OutlinedTextField(password,{password=it},label={Text("Phrase secrète (12 caractères minimum)")},visualTransformation=PasswordVisualTransformation(),enabled=enabled&&!busy)
 Button({busy=true;scope.launch{try{val d=request(obj("action" to "backup_export")) as JSONObject;val phrase=password;archive=withContext(Dispatchers.Default){encryptedBackup(d,phrase).also{bytes->try{inspectEncryptedBackup(bytes,phrase,org,site)}catch(e:Exception){bytes.fill(0);throw e}}};password="";save.launch("grillad-sauvegarde-"+dayKey()+".grillad.json")}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){status="Export indisponible."}finally{busy=false}}},enabled=enabled&&!busy&&password.length>=12&&archive==null){Text("Exporter vers un fichier / Drive")}
 OutlinedButton({inspect.launch(arrayOf("application/json","application/octet-stream"))},enabled=enabled&&!busy&&password.length>=12){Text("Vérifier une archive avant restauration")}
 Text("Programmation Google Drive");OutlinedButton({prefs(false)},enabled=enabled&&!busy){Text("Charger les préférences")}
 if(loaded){Row(Modifier.horizontalScroll(rememberScrollState())){listOf("off" to "Non","daily" to "Jour","weekly" to "Semaine","monthly" to "Mois").forEach{(k,v)->TextButton({freq=k},enabled=enabled&&!busy){Text(if(freq==k)"✓ "+v else v)}}};OutlinedTextField(hour,{hour=it},label={Text("Heure du Cameroun HH:mm")});if(freq=="weekly")OutlinedTextField(weekday,{weekday=it},label={Text("Jour 1–7")});if(freq=="monthly")OutlinedTextField(monthday,{monthday=it},label={Text("Jour 1–28")});Button({prefs(true)},enabled=enabled&&!busy){Text("Enregistrer la programmation")}}
 Text("Choisissez Drive dans le sélecteur Android si disponible. La sauvegarde automatique nécessite le service cloud. Conservez votre phrase de sauvegarde.");OutlinedButton({cloud("connect")},enabled=enabled&&!busy&&password.length in 12..128){Text("Autoriser Google Drive")};OutlinedButton({cloud("status")},enabled=enabled&&!busy){Text("État Google Drive")};if(drive?.optBoolean("connected")==true){Text("Dernière sauvegarde : "+drive?.optString("last_success","Aucune"));OutlinedButton({cloud("now")},enabled=enabled&&!busy){Text("Sauvegarder maintenant sur Drive")};OutlinedButton({confirmDisconnect=true},enabled=enabled&&!busy){Text("Déconnecter Drive")}};if(confirmDisconnect)AlertDialog(onDismissRequest={confirmDisconnect=false},title={Text("Déconnecter Drive ?")},text={Text("Les fichiers existants sont conservés.")},confirmButton={TextButton({confirmDisconnect=false;cloud("disconnect")}){Text("Confirmer")}},dismissButton={TextButton({confirmDisconnect=false}){Text("Annuler")}});if(status.isNotBlank())Text(status)
}
