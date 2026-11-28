package cm.naxa.widemeet
import android.Manifest
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import cm.naxa.widemeet.auth.AuthGateway
import cm.naxa.widemeet.auth.Session
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.UUID

private const val MediaLimit=1048576
private fun boundedRead(input:java.io.InputStream):ByteArray{
 val out=ByteArrayOutputStream();val buf=ByteArray(8192)
 while(true){val n=input.read(buf);if(n<0)break;require(out.size()+n<=MediaLimit);out.write(buf,0,n)}
 return out.toByteArray()
}
internal fun chatMediaDigest(b:ByteArray)=MessageDigest.getInstance("SHA-256").digest(b).joinToString(""){"%02x".format(it.toInt() and 255)}
private fun mediaItems(x:JSONObject):List<JSONObject>{val a=x.getJSONArray("items");return (0 until a.length()).map{a.getJSONObject(it)}}
private class ChatAudio{
 var recorder:MediaRecorder?=null;var capture:File?=null;var player:MediaPlayer?=null;var playback:File?=null
 fun clearPlayer(){runCatching{player?.release()};player=null;playback?.delete();playback=null}
 fun clearRecorder(){val r=recorder;recorder=null;runCatching{r?.stop()};runCatching{r?.release()};capture?.delete();capture=null}
 fun clear(){clearRecorder();clearPlayer()}
}
@Composable fun ChatMediaPanel(english:Boolean,gateway:AuthGateway,session:Session,peerId:String?=null,groupId:String?=null,roomId:String?=null,channel:String?=null,allowUpload:Boolean=true,voiceAllowed:Boolean=true,transport:(suspend (String,JSONObject)->JSONObject)?=null,postId:String?=null){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current;val scope=rememberCoroutineScope();val resources=remember{ChatAudio()}
 var items by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var pending by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var preview by remember{mutableStateOf<Pair<String,Bitmap>?>(null)}
 var recording by remember{mutableStateOf(false)};var playing by remember{mutableStateOf<String?>(null)};var saveBytes by remember{mutableStateOf<ByteArray?>(null)}
 fun scoped(d:JSONObject)=d.apply{if(postId!=null)put("post_id",postId)else if(roomId!=null){put("room_id",roomId);put("channel",channel)}else if(peerId!=null)put("peer_id",peerId)else put("group_id",groupId)}
 suspend fun req(action:String,d:JSONObject=JSONObject())=transport?.invoke(action,scoped(d))?:gateway.chatMedia(session,action,scoped(d))
 fun stopPlayer(){resources.clearPlayer();playing=null}
 fun clearPreview(){preview=null}
 suspend fun refresh(){try{val next=mediaItems(req("list"));items=next;if(playing!=null&&next.none{it.optString("id")==playing})stopPlayer();if(preview!=null&&next.none{it.optString("id")==preview?.first})clearPreview()}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();stopPlayer();clearPreview();pending=null;saveBytes=null;resources.clearRecorder();recording=false;throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 fun prepare(bytes:ByteArray,name:String,mime:String,kind:String){require(bytes.size in 8..MediaLimit);pending=JSONObject().put("id",UUID.randomUUID().toString()).put("kind",kind).put("mime",mime).put("name",name.take(120)).put("content",Base64.encodeToString(bytes,Base64.NO_WRAP))}
 val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri:Uri?->if(uri!=null)work{
  val (bytes,name,mime)=withContext(Dispatchers.IO){
   val resolver=context.contentResolver;val mime=resolver.getType(uri).orEmpty();require(mime in setOf("application/pdf","image/jpeg","image/png"))
   val name=resolver.query(uri,arrayOf(OpenableColumns.DISPLAY_NAME),null,null,null)?.use{if(it.moveToFirst())it.getString(0) else null}?:"document"
   val bytes=resolver.openInputStream(uri)?.use{boundedRead(it)}?:throw IllegalStateException("unavailable")
   Triple(bytes,name,mime)
  };prepare(bytes,name,mime,"file")
 }}
 val saver=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")){uri:Uri?->
  val b=saveBytes;saveBytes=null
  if(uri!=null&&b!=null)work{withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri,"w")?.use{it.write(b)}?:throw IllegalStateException("unavailable")}}
 }
 fun finishRecording(){
  val r=resources.recorder?:return;resources.recorder=null;val f=resources.capture;resources.capture=null
  val stopped=runCatching{r.stop()}.isSuccess;runCatching{r.release()};recording=false
  if(!stopped||f==null){f?.delete();error=true;return}
  work{try{val b=withContext(Dispatchers.IO){f.inputStream().use{boundedRead(it)}};prepare(b,"message-vocal.m4a","audio/mp4","voice")}finally{f.delete()}}
 }
 fun startRecording(){
  if(!allowUpload||!voiceAllowed||busy||pending!=null||recording)return
  try{
   stopPlayer();val f=File.createTempFile("wm-voice-",".m4a",context.cacheDir);resources.capture=f
   @Suppress("DEPRECATION") val r=if(Build.VERSION.SDK_INT>=31)MediaRecorder(context)else MediaRecorder()
   resources.recorder=r
   r.setAudioSource(MediaRecorder.AudioSource.MIC);r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
   r.setAudioEncodingBitRate(32000);r.setAudioSamplingRate(16000);r.setMaxDuration(60000);r.setMaxFileSize(MediaLimit.toLong());r.setOutputFile(f.absolutePath)
   r.setOnInfoListener{_,what,_->if(what==MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED||what==MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED)scope.launch{finishRecording()}}
   r.setOnErrorListener{_,_,_->scope.launch{resources.clearRecorder();recording=false;error=true}}
   r.prepare();r.start();recording=true;error=false
  }catch(e:Exception){resources.clearRecorder();recording=false;error=true}
 }
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){allowed->if(allowed)startRecording()else error=true}
 LaunchedEffect(allowUpload){if(!allowUpload){resources.clearRecorder();recording=false;pending=null}}
 DisposableEffect(session.deviceId,peerId,groupId,roomId,channel,postId){onDispose{resources.clear();saveBytes=null;clearPreview()}}
 LaunchedEffect(session.accessToken,peerId,groupId,roomId,channel,postId,busy){
  if(busy)return@LaunchedEffect
  while(true){try{refresh()}catch(e:CancellationException){throw e}catch(e:Exception){error=true};delay(5000)}
 }
 suspend fun download(m:JSONObject):ByteArray{
  val v=req("download",JSONObject().put("id",m.getString("id")))
  val b=Base64.decode(v.getString("content"),Base64.NO_WRAP)
  require(b.size in 1..MediaLimit&&b.size==m.getInt("bytes")&&v.getInt("bytes")==m.getInt("bytes")&&v.getString("id")==m.getString("id")&&chatMediaDigest(b)==m.getString("sha256")&&v.getString("sha256")==m.getString("sha256"))
  return b
 }
 val content:@Composable ()->Unit={Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
  Text(if(postId!=null)tr("Pièces jointes","Attachments")else when(channel){"agenda"->tr("Documents de l’ordre du jour","Agenda documents");"room-chat"->tr("Fichiers et vocaux de la salle","Room files and voice messages");else->tr("Fichiers et messages vocaux","Files and voice messages")},style=MaterialTheme.typography.titleMedium)
  if(allowUpload)Text(if(postId!=null)tr("PDF, JPEG, PNG. Taille maximale : 1 Mio.","PDF, JPEG, PNG. Maximum size: 1 MiB.")else tr("PDF, JPEG, PNG. Taille maximale : 1 Mio ; message vocal : 60 s.","PDF, JPEG, PNG. Maximum size: 1 MiB; voice message: 60 s."))
  if(error)Text(tr("Accès, format ou transfert non confirmé.","Access, format or transfer unconfirmed."),color=MaterialTheme.colorScheme.error)
  if(allowUpload)TextButton(enabled=!busy&&pending==null&&!recording,onClick={picker.launch(arrayOf("application/pdf","image/jpeg","image/png"))}){Text(tr("Choisir une pièce jointe","Choose attachment"))}
  if(voiceAllowed&&allowUpload&&recording)Button(onClick={finishRecording()}){Text(tr("Terminer l’enregistrement","Stop recording"))}
  else if(voiceAllowed&&allowUpload)TextButton(enabled=!busy&&pending==null,onClick={if(ContextCompat.checkSelfPermission(context,Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)startRecording()else permission.launch(Manifest.permission.RECORD_AUDIO)}){Text(tr("Enregistrer un message vocal","Record voice message"))}
  if(allowUpload)pending?.let{p->Text(p.optString("name"));Button(enabled=!busy,onClick={work{req("upload",p);pending=null;refresh()}}){Text(tr("Envoyer le fichier","Send file"))};TextButton(enabled=!busy,onClick={pending=null}){Text(tr("Abandonner la tentative locale","Discard local retry"))}}
  for(m in items){
   Text(m.optString("name")+" · "+m.optInt("bytes")+" o")
   if(postId!=null&&m.optString("mime") in setOf("image/jpeg","image/png")){
    TextButton(enabled=!busy,onClick={work{val b=download(m);val bitmap=withContext(Dispatchers.Default){
     val bounds=BitmapFactory.Options().apply{inJustDecodeBounds=true};BitmapFactory.decodeByteArray(b,0,b.size,bounds)
     require(bounds.outWidth in 1..16384&&bounds.outHeight in 1..16384)
     var sample=1;while(bounds.outWidth/sample>2048||bounds.outHeight/sample>2048)sample*=2
     BitmapFactory.decodeByteArray(b,0,b.size,BitmapFactory.Options().apply{inSampleSize=sample})?:throw IllegalArgumentException("image")
    };preview=m.getString("id") to bitmap}}){Text(tr("Afficher l’image","View image"))}
    preview?.takeIf{it.first==m.optString("id")}?.let{p->Image(p.second.asImageBitmap(),contentDescription=m.optString("name"),modifier=Modifier.fillMaxWidth().heightIn(max=360.dp),contentScale=ContentScale.Fit);TextButton(onClick={clearPreview()}){Text(tr("Fermer l’aperçu","Close preview"))}}
   }
   TextButton(enabled=!busy&&!recording,onClick={work{
    val b=download(m)
    if(m.optString("kind")=="voice"){
     stopPlayer();val f=File.createTempFile("wm-play-",".audio",context.cacheDir);resources.playback=f
     try{withContext(Dispatchers.IO){f.writeBytes(b)};val player=MediaPlayer();resources.player=player
      player.setDataSource(f.absolutePath);player.setOnCompletionListener{stopPlayer()};player.setOnErrorListener{_,_,_->stopPlayer();error=true;true};player.prepare();playing=m.getString("id");player.start()
     }catch(e:Exception){stopPlayer();throw e}
    }else{saveBytes=b;saver.launch(m.optString("name","document"))}
   }}){Text(if(m.optString("kind")=="voice")tr("Écouter","Listen")else tr("Télécharger","Download"))}
   if(playing==m.optString("id"))TextButton(onClick={stopPlayer()}){Text(tr("Arrêter la lecture","Stop playback"))}
   if(m.optString("sender_id")==session.memberId)TextButton(enabled=!busy,onClick={work{req("revoke",JSONObject().put("id",m.getString("id")));refresh()}}){Text(tr("Révoquer le fichier","Revoke file"))}
  }
 }}
 if(postId!=null)content()else Card(Modifier.fillMaxWidth()){content()}
}
