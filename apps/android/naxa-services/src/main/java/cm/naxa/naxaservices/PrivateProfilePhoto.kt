package cm.naxa.naxaservices

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

internal object PrivateProfilePhotoApi {
    const val MAX_BYTES = 2 * 1024 * 1024
    private val uuid = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    internal data class Paths(val read: String, val write: String, val remove: String, val objectPath: String)
    internal fun paths(endpoint: String, org: String, member: String): Paths {
        val url = URI(endpoint)
        require(url.scheme == "https" && url.host != null && url.userInfo == null &&
            url.path.trimEnd('/') == "/functions/v1/naxa-services-auth" && uuid.matches(org) && uuid.matches(member)) { "Configuration photo invalide." }
        val objectPath = "$org/$member/avatar.jpg"
        val base = "https://" + url.rawAuthority + "/storage/v1/object/"
        return Paths(base+"authenticated/ns-profile-photos/"+objectPath,base+"ns-profile-photos/"+objectPath,base+"ns-profile-photos",objectPath)
    }
    internal fun boundedRead(input: InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            require(total <= MAX_BYTES) { "Photo de 2 Mo maximum." }
            out.write(buffer,0,count)
        }
        return out.toByteArray()
    }
    private fun bitmap(bytes: ByteArray): Bitmap {
        require(bytes.isNotEmpty() && bytes.size <= MAX_BYTES) { "Photo invalide." }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0 && bounds.outWidth.toLong()*bounds.outHeight <= 20_000_000L) { "Dimensions de photo invalides." }
        require(bounds.outMimeType in setOf("image/jpeg","image/png","image/webp")) { "Format photo non accepté." }
        var sample = 1
        while (maxOf(bounds.outWidth,bounds.outHeight)/sample > 1536) sample *= 2
        return BitmapFactory.decodeByteArray(bytes,0,bytes.size,BitmapFactory.Options().apply { inSampleSize=sample }) ?: error("Photo illisible.")
    }
    suspend fun prepare(context:Context,uri:Uri):ByteArray = withContext(Dispatchers.IO) {
        val bytes = context.contentResolver.openInputStream(uri)?.use(::boundedRead) ?: error("Photo illisible.")
        val original = bitmap(bytes)
        try {
            val factor = minOf(1f,768f/maxOf(original.width,original.height))
            val resized = Bitmap.createScaledBitmap(original,maxOf(1,(original.width*factor).toInt()),maxOf(1,(original.height*factor).toInt()),true)
            try {
                val out = ByteArrayOutputStream()
                require(resized.compress(Bitmap.CompressFormat.JPEG,85,out)) { "Photo illisible." }
                out.toByteArray().also { require(it.isNotEmpty() && it.size<=MAX_BYTES) { "Photo trop volumineuse." } }
            } finally { if (resized !== original) resized.recycle() }
        } finally { original.recycle() }
    }
    private fun request(session:AuthSession,method:String,body:ByteArray?=null):ByteArray? {
        val urls=paths(BuildConfig.AUTH_FUNCTION_URL,session.account.organizationId,session.account.memberId)
        require(session.accessToken.isNotBlank() && BuildConfig.SUPABASE_ANON_KEY.isNotBlank() && !session.requirePasswordChange) { "Connexion requise." }
        val endpoint=when(method){"GET"->urls.read;"POST"->urls.write;else->urls.remove}
        val connection=URL(endpoint).openConnection() as HttpURLConnection
        try {
            connection.requestMethod=method;connection.instanceFollowRedirects=false
            connection.connectTimeout=10_000;connection.readTimeout=15_000;connection.useCaches=false
            connection.setRequestProperty("apikey",BuildConfig.SUPABASE_ANON_KEY)
            connection.setRequestProperty("Authorization","Bearer "+session.accessToken)
            connection.setRequestProperty("Cache-Control","no-store")
            if (method != "GET") {
                val payload=if(method=="POST") requireNotNull(body) else JSONObject().put("prefixes",JSONArray().put(urls.objectPath)).toString().toByteArray(Charsets.UTF_8)
                connection.doOutput=true
                connection.setRequestProperty("Content-Type",if(method=="POST") "image/jpeg" else "application/json")
                if(method=="POST")connection.setRequestProperty("x-upsert","true")
                connection.setFixedLengthStreamingMode(payload.size)
                connection.outputStream.use{it.write(payload)}
            }
            val status=connection.responseCode
            if(method=="GET" && status==404)return null
            if(method=="GET" && status==400){
                val data=runCatching{JSONObject(connection.errorStream?.use(::boundedRead)?.toString(Charsets.UTF_8).orEmpty())}.getOrNull()
                if(data?.optString("statusCode")=="404"||data?.optString("error") in setOf("not_found","NoSuchKey"))return null
            }
            require(status in 200..299) { if(status==401||status==403) "Session expirée ou accès refusé." else "Stockage photo indisponible." }
            return if(method=="GET")connection.inputStream.use(::boundedRead) else null
        } finally { connection.disconnect() }
    }
    suspend fun load(session:AuthSession):Bitmap? = withContext(Dispatchers.IO) { request(session,"GET")?.let(::bitmap) }
    suspend fun save(session:AuthSession,bytes:ByteArray):Bitmap = withContext(Dispatchers.IO) {
        request(session,"POST",bytes);request(session,"GET")?.let(::bitmap)?:error("Enregistrement non confirmé.")
    }
    suspend fun remove(session:AuthSession) = withContext(Dispatchers.IO) {
        request(session,"DELETE");require(request(session,"GET")==null) { "Suppression non confirmée." }
    }
}

@Composable
internal fun PrivateProfilePhoto(session:AuthSession) {
    key(session.account.organizationId,session.account.memberId,session.deviceId) {
        val context=LocalContext.current
        val scope=rememberCoroutineScope()
        val latest by rememberUpdatedState(session)
        var photo by remember { mutableStateOf<Bitmap?>(null) }
        var busy by remember { mutableStateOf(true) }
        var message by remember { mutableStateOf("") }
        var confirmDelete by remember { mutableStateOf(false) }
        fun launchChange(action:suspend()->Unit) {
            if(busy)return
            busy=true;message=""
            scope.launch {
                try { action() } catch(cancelled:CancellationException){throw cancelled}
                catch(_:Exception){message="Modification non confirmée. Vérifiez la connexion et réessayez."}
                finally{busy=false}
            }
        }
        LaunchedEffect(Unit) {
            try { photo=PrivateProfilePhotoApi.load(latest) }
            catch(cancelled:CancellationException){throw cancelled}
            catch(_:Exception){message="Photo indisponible. Vérifiez la connexion."}
            finally{busy=false}
        }
        val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){ uri ->
            if(uri!=null)launchChange{
                val bytes=PrivateProfilePhotoApi.prepare(context,uri)
                photo=PrivateProfilePhotoApi.save(latest,bytes);message="Photo enregistrée."
            }
        }
        if(photo!=null) Image(photo!!.asImageBitmap(),contentDescription="Photo de profil",modifier=Modifier.size(88.dp),contentScale=ContentScale.Crop)
        else Text(session.account.displayName.take(1).uppercase(),style=MaterialTheme.typography.displayMedium,color=MaterialTheme.colorScheme.primary,fontWeight=FontWeight.Black)
        OutlinedButton(onClick={picker.launch(arrayOf("image/jpeg","image/png","image/webp"))},enabled=!busy){Text("Choisir une photo de profil")}
        if(photo!=null)OutlinedButton(onClick={confirmDelete=true},enabled=!busy){Text("Supprimer la photo")}
        if(confirmDelete)AlertDialog(onDismissRequest={confirmDelete=false},title={Text("Supprimer la photo ?")},text={Text("La photo sera retirée du profil sur tous vos appareils.")},confirmButton={TextButton(onClick={confirmDelete=false;launchChange{PrivateProfilePhotoApi.remove(latest);photo=null;message="Photo supprimée."}}){Text("Supprimer")}},dismissButton={TextButton(onClick={confirmDelete=false}){Text("Annuler")}})
        if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
        if(message.isNotBlank())Text(message,style=MaterialTheme.typography.bodySmall)
    }
}
