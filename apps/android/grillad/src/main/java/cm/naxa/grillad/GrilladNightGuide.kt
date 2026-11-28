package cm.naxa.grillad
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
// Decorative only: no input listeners or text inspection.
@Composable internal fun GrilladNightGuide(modifier:Modifier=Modifier,animated:Boolean){
 val progress=if(animated){val transition=rememberInfiniteTransition(label="night guide");val p by transition.animateFloat(initialValue=0f,targetValue=1f,animationSpec=infiniteRepeatable(tween(2300,easing=LinearEasing),RepeatMode.Reverse),label="glow");p}else 0.5f
 Canvas(modifier.size(54.dp)){
  val c=Offset(size.width*(.42f+.16f*progress),size.height*.5f);val r=size.minDimension*.40f
  drawCircle(Brush.radialGradient(listOf(Color(0xFFFFCC75).copy(alpha=.35f),Color.Transparent),center=c,radius=r),r,c)
  drawOval(Color(0xFFFFE7B1).copy(alpha=.7f),Offset(c.x-r*.74f,c.y-r*.45f),Size(r*.70f,r*(.20f+.25f*progress)))
  drawOval(Color(0xFFFFE7B1).copy(alpha=.7f),Offset(c.x+r*.04f,c.y-r*.45f),Size(r*.70f,r*(.20f+.25f*progress)))
  drawOval(Color(0xFFFFB75F),Offset(c.x-r*.12f,c.y-r*.45f),Size(r*.24f,r*.85f))
 }
}
