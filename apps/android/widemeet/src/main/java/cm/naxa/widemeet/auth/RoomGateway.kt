package cm.naxa.widemeet.auth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URI
import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.ensureActive
import kotlin.coroutines.coroutineContext
import java.util.UUID

class RoomGateway(private val authBase:String){
 private fun endpoint(action:String):URI{
  val u=URI(authBase)
  require(u.scheme=="https"&&!u.host.isNullOrBlank()&&u.userInfo==null&&u.query==null&&u.fragment==null&&u.path.trimEnd('/').endsWith("/widemeet-auth"))
  require(action in setOf("list","contacts","pass-list","read","create","command","media-grant","minutes","tasks","series-create","series-cancel","presence","recordings","recording-download","notices","external-invite"))
  return URI(u.scheme,u.authority,u.path.trimEnd('/').removeSuffix("/widemeet-auth")+"/widemeet-room/"+action,null,null)
 }
 suspend fun request(action:String,body:JSONObject,session:Session):Any=withContext(Dispatchers.IO){
  require(action!="recording-download")
  require(Regex("^[a-f0-9]{64}$").matches(session.accessToken))
  val c=endpoint(action).toURL().openConnection() as HttpURLConnection
  try{
   c.requestMethod="POST";c.instanceFollowRedirects=false;c.connectTimeout=15000;c.readTimeout=15000;c.useCaches=false;c.doOutput=true
   c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("Cache-Control","no-store");c.setRequestProperty("Authorization","Bearer "+session.accessToken)
   body.put("app_id","WIDEMEET");c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
   require(c.responseCode in 200..299){"request_rejected"}
   val raw=c.inputStream.bufferedReader().use{it.readText()};require(raw.length<=1048576)
   if(action in setOf("list","contacts","pass-list"))JSONArray(raw) else JSONObject(raw)
  }finally{c.disconnect()}
 }
 suspend fun downloadRecording(roomId:String,item:JSONObject,session:Session,cacheDir:File):File=withContext(Dispatchers.IO){
  val size=item.getLong("bytes");val expected=item.getString("sha256");require(size in 1000L..(128L*1024*1024)&&Regex("^[a-f0-9]{64}$").matches(expected)&&Regex("^[a-f0-9-]{36}$").matches(item.getString("recording_id")))
  require(Regex("^[a-f0-9]{64}$").matches(session.accessToken))
  val file=File.createTempFile("wm-audio-",".ogg",cacheDir);val c=endpoint("recording-download").toURL().openConnection() as HttpURLConnection
  try{
   c.requestMethod="POST";c.instanceFollowRedirects=false;c.connectTimeout=15000;c.readTimeout=30000;c.useCaches=false;c.doOutput=true
   c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("Cache-Control","no-store");c.setRequestProperty("Authorization","Bearer "+session.accessToken)
   val data=JSONObject().put("app_id","WIDEMEET").put("room_id",roomId).put("recording_id",item.getString("recording_id")).put("request_id",UUID.randomUUID().toString())
   c.outputStream.use{it.write(data.toString().toByteArray(Charsets.UTF_8))}
   require(c.responseCode==200&&c.contentType?.substringBefore(";")=="audio/ogg")
   val digest=MessageDigest.getInstance("SHA-256");var read=0L
   c.inputStream.use{input->file.outputStream().use{out->val buf=ByteArray(32768);while(true){coroutineContext.ensureActive();val n=input.read(buf);if(n<0)break;read+=n;require(read<=size);digest.update(buf,0,n);out.write(buf,0,n)}}}
   val hash=digest.digest().joinToString(""){"%02x".format(it.toInt() and 255)};require(read==size&&hash==expected)
   file
  }catch(e:Throwable){file.delete();throw e}finally{c.disconnect()}
 }
}
