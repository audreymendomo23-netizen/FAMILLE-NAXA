package cm.naxa.grillad
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.animation.core.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
@Composable internal fun GrilladBrandMark(light:Boolean=false,compact:Boolean=false){
 val context=LocalContext.current
 val enabled=android.provider.Settings.Global.getFloat(context.contentResolver,android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,1f)>0f&&LocalWindowInfo.current.isWindowFocused
 val phase=if(enabled){val animation=rememberInfiniteTransition(label="brand-ember");val value by animation.animateFloat(0f,1f,infiniteRepeatable(tween(2400,easing=LinearEasing)),label="ember");value}else 0f
 val ink=if(light)Color(0xFFF7F5EF) else MaterialTheme.colorScheme.onBackground
 val paths=remember{listOf("M7 36 L18 49 M0 57 L14 64 M83 47 L92 34 M86 65 L99 57","M42 5 C49 24 33 31 23 43 C13 55 18 70 33 76 C27 64 31 55 39 47 C38 57 45 59 47 65 C54 56 58 48 53 35 C66 44 71 57 66 69 C78 60 83 48 73 35 C75 44 70 46 69 47 C71 29 58 15 42 5 Z","M8 79 Q21 73 31 79 Q35 86 25 89 L13 89 Q4 86 8 79 Z M35 82 Q47 73 59 80 Q66 87 59 92 L38 92 Q29 90 35 82 Z M64 79 Q77 73 87 81 Q91 88 81 89 L69 89 Q61 87 64 79 Z","M130 30 C111 30 99 42 99 60 C99 78 111 90 130 90 C141 90 150 86 156 79 L156 57 L130 57 L130 68 L143 68 L143 74 C140 77 135 79 130 79 C119 79 112 71 112 60 C112 49 119 41 130 41 C136 41 142 43 146 48 L155 40 C149 33 140 30 130 30 Z M161 47 H173 V53 Q179 45 191 47 V59 Q174 56 174 70 V89 H161 Z M195 49 H208 V89 H195 Z M214 29 H226 V89 H214 Z M232 29 H244 V89 H232 Z M269 46 C255 46 248 56 248 68 C248 82 257 90 269 90 Q278 90 284 83 V89 H296 V47 H284 V53 Q278 46 269 46 Z M272 57 C280 57 284 62 284 68 C284 75 280 80 272 80 C264 80 260 75 260 68 C260 62 264 57 272 57 Z","M302 30 H324 C344 30 357 42 357 60 C357 78 344 89 324 89 H302 Z M315 42 V77 H324 C336 77 344 71 344 60 C344 49 336 42 324 42 Z","M202 25 C205 32 195 35 195 41 C195 47 207 47 209 41 C212 35 206 29 202 25 Z").map{PathParser().parsePathString(it).toPath()}}
 Canvas(Modifier.width(if(compact)132.dp else 230.dp).aspectRatio(360f/96f).semantics{contentDescription="GrillaD"}){
  scale(size.width/363f,size.height/96f,pivot=Offset.Zero){
   drawPath(paths[0],Color(0xFFF2A93B),style=Stroke(5f,cap=StrokeCap.Round))
   drawPath(paths[1],Color(0xFFD64A1F));drawPath(paths[2],ink)
   paths[3].fillType=androidx.compose.ui.graphics.PathFillType.EvenOdd;paths[4].fillType=androidx.compose.ui.graphics.PathFillType.EvenOdd
   drawPath(paths[3],ink);drawPath(paths[4],Color(0xFFD64A1F))
   rotate(4f*kotlin.math.sin(phase*6.283185f),pivot=Offset(202f,45f)){scale(1f,1f+0.07f*kotlin.math.sin(phase*6.283185f),pivot=Offset(202f,45f)){drawPath(paths[5],Color(0xFFE9691D))}}
  }
 }
}
internal fun grilladCommercialError(e:Exception):String=if(e is GrilladApiError)when(e.status){0->"Connexion indisponible — vérifiez avant de réessayer.";401->"Connexion refusée ou session expirée. Reconnectez-vous.";403->"Vous n’avez pas accès à cette opération.";400->"Vérifiez les informations saisies.";409->"Opération à vérifier avant de réessayer.";else->"Service momentanément indisponible. Réessayez."}else "Opération non confirmée. Vérifiez avant de réessayer."
