package cm.naxa.naxaservices

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

@Composable
fun MiniTorchOverlay(target:Offset?,active:Boolean,activation:Boolean=false) {
    if(!active || (target==null && !activation))return
    val progress=remember { Animatable(0f) }
    LaunchedEffect(target,activation) {
        progress.snapTo(0f)
        progress.animateTo(1f,animationSpec=tween(if(activation)1650 else 1350))
    }
    Canvas(Modifier.fillMaxSize().testTag("night-torch-animation")) {
        val t=progress.value
        val alpha=(if(t<.2f)t/.2f else if(t>.72f)(1f-t)/.28f else 1f).coerceIn(0f,1f)
        val center=if(activation)Offset(size.width*(.20f+.60f*t),size.height*(.40f-.08f*t)) else Offset(target!!.x.coerceIn(0f,size.width),target.y.coerceIn(0f,size.height))
        val radius=178.dp.toPx()*(.7f+.3f*alpha)
        drawCircle(brush=Brush.radialGradient(0f to Color(0xFFFFF0BD).copy(alpha=.31f*alpha),.42f to Color(0xFFFFE9A8).copy(alpha=.15f*alpha),1f to Color.Transparent,center=center,radius=radius),radius=radius,center=center)
        rotate(-24f+if(activation)30f*t else 0f,pivot=center+Offset(34.dp.toPx(),26.dp.toPx())) {
            drawRoundRect(Color(0xFFDD3A33).copy(alpha=alpha),topLeft=center+Offset(18.dp.toPx(),22.dp.toPx()),size=Size(46.dp.toPx(),13.dp.toPx()),cornerRadius=CornerRadius(7.dp.toPx()))
            drawRoundRect(Color(0xFFB9BFC7).copy(alpha=alpha),topLeft=center+Offset(4.dp.toPx(),17.dp.toPx()),size=Size(19.dp.toPx(),23.dp.toPx()),cornerRadius=CornerRadius(5.dp.toPx()))
            drawCircle(Color(0xFFFFF1C7).copy(alpha=alpha),radius=5.dp.toPx(),center=center+Offset(8.dp.toPx(),28.dp.toPx()))
        }
    }
}
