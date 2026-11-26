package cm.naxa.naxaservices

import android.graphics.BitmapFactory
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

internal fun commercialPhotoPaths(activity:String?,login:Boolean=false):List<String> = when {
    login -> listOf("media/office.jpg","media/workspace.jpg","media/printing.jpg","media/teamwork.jpg")
    activity=="impression" -> listOf("media/printing.jpg","media/stationery.jpg")
    activity=="menuiserie" -> listOf("media/wood-stock.jpg","media/furniture.jpg")
    activity=="domicile" -> listOf("media/painting.jpg","media/teamwork.jpg")
    else -> listOf("media/office.jpg","media/workspace.jpg")
}

@Composable
internal fun BusinessPhotoBackdrop(activity:String?=null,login:Boolean=false,modifier:Modifier=Modifier) {
    val context=LocalContext.current
    val paths=remember(activity,login){commercialPhotoPaths(activity,login)}
    val photos=remember(paths,context){
        paths.mapNotNull { path ->
            runCatching { context.assets.open(path).use { BitmapFactory.decodeStream(it) } }.getOrNull()?.asImageBitmap()
        }
    }
    var index by remember(paths){mutableIntStateOf(0)}
    LaunchedEffect(paths,photos.size) {
        if(photos.size>1)while(true){delay(4000);index=(index+1)%photos.size}
    }
    Box(modifier.background(Color(0xFF221E1E)).testTag("business-photo-backdrop")) {
        if(photos.isNotEmpty())Crossfade(targetState=index,animationSpec=tween(650),label="business-photo") { frame ->
            Image(photos[frame%photos.size],contentDescription=null,modifier=Modifier.fillMaxSize().blur(1.5.dp),contentScale=ContentScale.Crop)
        }
        Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color(0xD9141111),Color(0x96141111)))))
    }
}

@Composable
internal fun LoginBusinessBanner(locale:String){
    Box(Modifier.fillMaxWidth().heightIn(min=112.dp).clip(RoundedCornerShape(20.dp))) {
        BusinessPhotoBackdrop(login=true,modifier=Modifier.matchParentSize())
        Column(Modifier.fillMaxWidth().padding(18.dp),verticalArrangement=Arrangement.spacedBy(4.dp)) {
            Text(if(locale=="en")"Your business, in control." else "Votre activité, maîtrisée.",color=Color.White,style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
            Text(if(locale=="en")"Customers, services and teams in one place." else "Clients, prestations et équipes au même endroit.",color=Color(0xFFF4EEEE),style=MaterialTheme.typography.bodyMedium)
        }
    }
}
