package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.Canvas
import androidx.compose.animation.core.*
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.runtime.getValue
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
// GRILLAD v2 provisional visual system. Semantic colors aligned with Web/PWA.
@Composable internal fun GrilladTheme(dark:Boolean,content:@Composable ()->Unit){
 val scheme=if(dark)darkColorScheme(primary=Color(0xFFFFBA8B),onPrimary=Color(0xFF2B170C),background=Color(0xFF151210),onBackground=Color(0xFFFFF1E7),surface=Color(0xFF241E1A),onSurface=Color(0xFFFFF1E7),surfaceVariant=Color(0xFF39291F),onSurfaceVariant=Color(0xFFF0D8C8),error=Color(0xFFFFB4AB),onError=Color(0xFF410002))else lightColorScheme(primary=Color(0xFFB83E18),onPrimary=Color.White,background=Color(0xFFF7F5EF),onBackground=Color(0xFF1F1F1F),surface=Color.White,onSurface=Color(0xFF1F1F1F),surfaceVariant=Color(0xFFF3E5D9),onSurfaceVariant=Color(0xFF4A3428),error=Color(0xFFC62828),onError=Color.White)
 MaterialTheme(colorScheme=scheme,shapes=Shapes(small=RoundedCornerShape(12.dp),medium=RoundedCornerShape(20.dp),large=RoundedCornerShape(26.dp)),content=content)
}
@Composable internal fun GrilladHero(ca:Long,target:Long,tr:(String)->String={it}){Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Color(0xFF1F1F1F),contentColor=Color(0xFFF7F5EF)),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Text(tr("Chiffre d’affaires"),style=MaterialTheme.typography.labelLarge);Text("${ca} F",style=MaterialTheme.typography.headlineLarge,fontWeight=FontWeight.Bold);if(target>0){Text(tr("Objectif")+" : $target F");LinearProgressIndicator(progress={ (ca.toDouble()/target).coerceIn(0.0,1.0).toFloat() },modifier=Modifier.fillMaxWidth(),color=Color(0xFFFFBA8B),trackColor=Color(0xFF624331))}else Text(tr("Objectif non défini"),style=MaterialTheme.typography.bodySmall)}}}
@Composable internal fun GrilladMetric(label:String,value:String,modifier:Modifier=Modifier){OutlinedCard(modifier){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){Text(label,style=MaterialTheme.typography.labelMedium);Text(value,style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.SemiBold)}}}

@Composable internal fun GrilladAuthHero(subtitle:String){
 Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Color(0xFF1F1F1F),contentColor=Color(0xFFF7F5EF)),shape=RoundedCornerShape(26.dp)){
  Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
   GrilladBrandMark(light=true)
   Text(subtitle,style=MaterialTheme.typography.titleMedium)
   Box(Modifier.fillMaxWidth().aspectRatio(4f/3f).clip(RoundedCornerShape(14.dp))){
    Image(painter=painterResource(R.drawable.grillad_auth_braise),contentDescription=null,modifier=Modifier.matchParentSize(),contentScale=ContentScale.Fit)
    val context=LocalContext.current
    val motion=android.provider.Settings.Global.getFloat(context.contentResolver,android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,1f)>0f
    if(motion&&LocalWindowInfo.current.isWindowFocused)GrilladAuthSteam(Modifier.matchParentSize())
   }
  }
 }
}

// Three low-opacity wisps drawn independently of the original bitmap.
@Composable private fun GrilladAuthSteam(modifier:Modifier){
 val transition=rememberInfiniteTransition(label="atelier-steam")
 val phase by transition.animateFloat(initialValue=0f,targetValue=1f,animationSpec=infiniteRepeatable(animation=tween(5800,easing=LinearEasing)),label="steam-phase")
 Canvas(modifier){
  val sx=size.width/516f;val sy=size.height/387f
  for(i in 0..2){
   val t=(phase+i/3f)%1f
   val opacity=(kotlin.math.sin(t*Math.PI).toFloat().coerceAtLeast(0f))*0.14f
   val x=(239f+i*17f+8f*kotlin.math.sin(t*6.28318f))*sx
   val y=(171f-39f*t-i*4f)*sy
   val path=Path().apply{moveTo(x,y);cubicTo(x-15*sx,y-22*sy,x+17*sx,y-33*sy,x+5*sx,y-53*sy);cubicTo(x-9*sx,y-73*sy,x-15*sx,y-88*sy,x+6*sx,y-109*sy)}
   drawPath(path,Color(0xFFFFF8ED).copy(alpha=opacity*.22f),style=Stroke(width=15*sx,cap=StrokeCap.Round))
   drawPath(path,Color(0xFFFFF8ED).copy(alpha=opacity*.45f),style=Stroke(width=9*sx,cap=StrokeCap.Round))
   drawPath(path,Color(0xFFFFF8ED).copy(alpha=opacity*.55f),style=Stroke(width=4*sx,cap=StrokeCap.Round))
  }
 }
}
