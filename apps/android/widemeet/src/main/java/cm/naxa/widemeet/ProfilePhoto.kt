package cm.naxa.widemeet
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.AuthGateway
import cm.naxa.widemeet.auth.Session
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

private suspend fun photoJpeg(context:Context,uri:Uri):String=withContext(Dispatchers.IO){
 val resolver=context.contentResolver
 val opts=BitmapFactory.Options().apply{inJustDecodeBounds=true}
 resolver.openInputStream(uri)?.use{BitmapFactory.decodeStream(it,null,opts)}
 require(opts.outWidth in 1..16000&&opts.outHeight in 1..16000)
 var sample=1
 while(max(opts.outWidth,opts.outHeight)/sample>512)sample*=2
 val original=resolver.openInputStream(uri)?.use{BitmapFactory.decodeStream(it,null,BitmapFactory.Options().apply{inSampleSize=sample})}?:error("invalid photo")
 try{
 val scale=minOf(1f,256f/max(original.width,original.height))
 val w=max(1,(original.width*scale).roundToInt());val h=max(1,(original.height*scale).roundToInt())
 val normalized=Bitmap.createBitmap(w,h,Bitmap.Config.ARGB_8888)
 try{
 val canvas=Canvas(normalized);canvas.drawColor(Color.WHITE)
 canvas.drawBitmap(original,null,android.graphics.Rect(0,0,w,h),android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG))
 for(quality in listOf(82,65,45,25)){
 val bytes=ByteArrayOutputStream();require(normalized.compress(Bitmap.CompressFormat.JPEG,quality,bytes))
 if(bytes.size()<=65536)return@withContext Base64.encodeToString(bytes.toByteArray(),Base64.NO_WRAP)
 }
 error("photo too large")
 }finally{normalized.recycle()}
 }finally{original.recycle()}
}

@Composable fun ProfilePhoto(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var jpeg by remember{mutableStateOf<String?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var notice by remember{mutableStateOf("")}
 suspend fun load(){val response=gateway.identity(session,"photo-read");jpeg=if(response.isNull("jpeg"))null else response.optString("jpeg").takeIf{it.length<=87384&&Regex("^[A-Za-z0-9+/]+={0,2}$").matches(it)}}
 LaunchedEffect(session.deviceId){busy=true;try{load()}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}
 val picker=rememberLauncherForActivityResult(ActivityResultContracts.GetContent()){uri->
 if(uri!=null&&!busy){busy=true;error=false;notice="";scope.launch{try{val next=photoJpeg(context,uri);gateway.identity(session,"photo-save",JSONObject().put("jpeg",next));load();notice=tr("Photo enregistrée","Photo saved")}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 }
 val bitmap=remember(jpeg){jpeg?.let{runCatching{val data=Base64.decode(it,Base64.DEFAULT);val opts=BitmapFactory.Options().apply{inJustDecodeBounds=true};BitmapFactory.decodeByteArray(data,0,data.size,opts);require(opts.outWidth in 1..512&&opts.outHeight in 1..512);BitmapFactory.decodeByteArray(data,0,data.size)}.getOrNull()}}
 DisposableEffect(bitmap){onDispose{bitmap?.recycle()}}
 Text(tr("Ma photo de profil","My profile photo"),style=MaterialTheme.typography.titleMedium)
 if(bitmap!=null)Image(bitmap.asImageBitmap(),contentDescription=tr("Votre photo de profil","Your profile photo"),modifier=Modifier.size(96.dp))
 Button(enabled=!busy,onClick={picker.launch("image/*")}){Text(tr("Choisir une photo","Choose a photo"))}
 if(jpeg!=null)TextButton(enabled=!busy,onClick={busy=true;error=false;notice="";scope.launch{try{gateway.identity(session,"photo-delete");load();notice=tr("Photo supprimée","Photo removed")}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}){Text(tr("Supprimer la photo","Remove photo"))}
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Photo non confirmée. Réessayez.","Photo not confirmed. Try again."),color=MaterialTheme.colorScheme.error)
 if(notice.isNotEmpty())Text(notice)
}
