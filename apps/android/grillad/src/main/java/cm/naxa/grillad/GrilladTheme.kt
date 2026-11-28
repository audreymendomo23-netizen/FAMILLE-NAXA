package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
// GRILLAD v2 provisional visual system. Semantic colors aligned with Web/PWA.
@Composable internal fun GrilladTheme(dark:Boolean,content:@Composable ()->Unit){
 val scheme=if(dark)darkColorScheme(primary=Color(0xFFFFBA8B),onPrimary=Color(0xFF2B170C),background=Color(0xFF151210),onBackground=Color(0xFFFFF1E7),surface=Color(0xFF241E1A),onSurface=Color(0xFFFFF1E7),surfaceVariant=Color(0xFF39291F),onSurfaceVariant=Color(0xFFF0D8C8),error=Color(0xFFFFB4AB),onError=Color(0xFF410002))else lightColorScheme(primary=Color(0xFF9C380D),onPrimary=Color.White,background=Color(0xFFF8F3ED),onBackground=Color(0xFF271C16),surface=Color.White,onSurface=Color(0xFF271C16),surfaceVariant=Color(0xFFF3E5D9),onSurfaceVariant=Color(0xFF4A3428),error=Color(0xFFC62828),onError=Color.White)
 MaterialTheme(colorScheme=scheme,shapes=Shapes(small=RoundedCornerShape(12.dp),medium=RoundedCornerShape(20.dp),large=RoundedCornerShape(26.dp)),content=content)
}
@Composable internal fun GrilladHero(ca:Long,target:Long){Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Color(0xFF302019),contentColor=Color(0xFFFFF6EE)),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Text("Chiffre d’affaires",style=MaterialTheme.typography.labelLarge);Text("${ca} F",style=MaterialTheme.typography.headlineLarge,fontWeight=FontWeight.Bold);if(target>0){Text("Objectif : $target F");LinearProgressIndicator(progress={ (ca.toDouble()/target).coerceIn(0.0,1.0).toFloat() },modifier=Modifier.fillMaxWidth(),color=Color(0xFFFFBA8B),trackColor=Color(0xFF624331))}else Text("Objectif non défini",style=MaterialTheme.typography.bodySmall)}}}
@Composable internal fun GrilladMetric(label:String,value:String,modifier:Modifier=Modifier){OutlinedCard(modifier){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){Text(label,style=MaterialTheme.typography.labelMedium);Text(value,style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.SemiBold)}}}

@Composable internal fun GrilladAuthHero(subtitle:String){
 Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Color(0xFF302019),contentColor=Color(0xFFFFF6EE)),shape=RoundedCornerShape(26.dp)){
  Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
   Text("GrillaD",style=MaterialTheme.typography.displaySmall,fontWeight=FontWeight.ExtraBold)
   Text(subtitle,style=MaterialTheme.typography.titleMedium)
  }
 }
}
