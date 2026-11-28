package cm.naxa.grillad
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.json.JSONArray
import java.net.URL
import java.net.HttpURLConnection
internal class GrilladApiError(val status:Int,message:String):Exception(message)
internal fun obj(vararg pairs:Pair<String,Any?>)=JSONObject().apply{pairs.forEach{(k,v)->put(k,v?:JSONObject.NULL)}}
internal fun rows(a:JSONArray?)=if(a==null)emptyList() else (0 until a.length()).mapNotNull{a.optJSONObject(it)}
internal fun validGrilladConfig(url:String,key:String):Boolean=runCatching{
 val u=URL(url)
 require((BuildConfig.DEBUG&&BuildConfig.GRILLAD_LOCAL_RECIPE&&url=="http://127.0.0.1:4182/functions/v1/grillad")||(u.protocol=="https"&&u.host.endsWith(".supabase.co")&&u.path=="/functions/v1/grillad"&&u.port==-1&&u.userInfo==null&&u.query==null&&u.ref==null))
 key.startsWith("sb_publishable_")||JSONObject(String(Base64.decode(key.split(".")[1],Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING))).optString("role")=="anon"
}.getOrDefault(false)
internal class ConnectedApi(private val url:String,private val key:String){
 suspend fun call(body:JSONObject,access:String?=null):Any=withContext(Dispatchers.IO){
  require(validGrilladConfig(url,key)){"Configuration GRILLAD invalide"}
  val c=URL(url).openConnection() as HttpURLConnection
  try{
   c.requestMethod="POST";c.instanceFollowRedirects=false;c.connectTimeout=15000;c.readTimeout=20000;c.doOutput=true;c.useCaches=false
   c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("apikey",key);access?.let{c.setRequestProperty("Authorization","Bearer "+it)}
   c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
   val code=c.responseCode;val stream=if(code in 200..299)c.inputStream else c.errorStream
   val raw=stream?.bufferedReader()?.use{it.readText()}?:"";val result=runCatching{JSONObject(raw)}.getOrNull()
   if(code !in 200..299||result==null||!result.has("result"))throw GrilladApiError(code,result?.optString("error")?.takeIf{it.isNotBlank()}?:"SERVICE_UNAVAILABLE")
   result.get("result")
  }catch(e:GrilladApiError){throw e}catch(e:java.io.IOException){throw GrilladApiError(0,"Connexion indisponible — vérifier avant de répéter")}finally{c.disconnect()}
 }
}
