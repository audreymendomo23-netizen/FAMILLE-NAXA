package cm.naxa.widemeet

import android.graphics.BitmapFactory
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// Same original JPEG bytes as Web/PWA, full decode and Fit (no crop, blur or opacity effect).
internal val wideMeetPhotoNames=setOf("home","meeting","schedule","join","signin","report","archive","presentation","analysis")
@Composable internal fun WideMeetPhoto(name:String,animate:Boolean,height:Dp){
 if(name !in wideMeetPhotoNames)return
 val context=LocalContext.current
 val bitmap=remember(context,name){runCatching{context.assets.open("wm-photos/"+name+".jpg").use{BitmapFactory.decodeStream(it)?.asImageBitmap()}}.getOrNull()}
 val offset=remember(name){Animatable(0f)}
 LaunchedEffect(name,animate){if(animate){offset.snapTo(10f);offset.animateTo(0f,tween(420))}else offset.snapTo(0f)}
 if(bitmap!=null)Image(bitmap=bitmap,contentDescription=null,contentScale=ContentScale.Fit,modifier=Modifier.fillMaxWidth().height(height).offset(y=offset.value.dp).testTag("wm-photo-"+name))
}

// Decorative sign-in backdrop only. Same original bytes; cover may crop to the viewport, no filter or blur.
@Composable internal fun WideMeetSignInBackground(modifier:Modifier=Modifier){
 val context=LocalContext.current
 val bitmap=remember(context){runCatching{context.assets.open("wm-photos/signin.jpg").use{BitmapFactory.decodeStream(it)?.asImageBitmap()}}.getOrNull()}
 Box(modifier.background(Color(0xFF07552C)).testTag("wm-signin-background")){
 if(bitmap!=null)Image(bitmap=bitmap,contentDescription=null,contentScale=ContentScale.Crop,modifier=Modifier.matchParentSize().testTag("wm-signin-background-image"))
 Box(Modifier.matchParentSize().background(Brush.verticalGradient(listOf(Color(0xFF07552C).copy(alpha=.12f),Color(0xFF07552C).copy(alpha=.38f)))))
 }
}
