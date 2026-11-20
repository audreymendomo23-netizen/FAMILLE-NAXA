package cm.naxa.naxaservices
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.dp

@Composable
fun MiniTorchOverlay(target:Offset?,active:Boolean) {
 if(!active || target==null) return
 Canvas(Modifier.fillMaxSize()) {
  val center=Offset(target.x.coerceIn(0f,size.width),target.y.coerceIn(0f,size.height))
  val radius=178.dp.toPx()
  drawCircle(brush=Brush.radialGradient(0f to Color(0x33FFF0BD),0.42f to Color(0x18FFE9A8),1f to Color.Transparent,center=center,radius=radius),radius=radius,center=center)
  rotate(-24f,pivot=center+Offset(34.dp.toPx(),26.dp.toPx())) {
   drawRoundRect(Color(0xFFDD3A33),topLeft=center+Offset(18.dp.toPx(),22.dp.toPx()),size=Size(46.dp.toPx(),13.dp.toPx()),cornerRadius=CornerRadius(7.dp.toPx()))
   drawRoundRect(Color(0xFFB9BFC7),topLeft=center+Offset(4.dp.toPx(),17.dp.toPx()),size=Size(19.dp.toPx(),23.dp.toPx()),cornerRadius=CornerRadius(5.dp.toPx()))
   drawCircle(Color(0xFFFFF1C7),radius=5.dp.toPx(),center=center+Offset(8.dp.toPx(),28.dp.toPx()))
  }
 }
}
