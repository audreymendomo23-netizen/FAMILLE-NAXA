package cm.naxa.grillad
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import org.json.JSONObject

internal fun grilladActivitySeries(daily:List<JSONObject>):List<Pair<String,Double>> =
 daily.filter{it.optString("service_day").matches(Regex("\\d{4}-\\d{2}-\\d{2}"))&&it.optInt("version",0)>0}
  .groupBy{it.optString("service_day")}.values.mapNotNull{versions->versions.maxByOrNull{it.optInt("version")}}
  .mapNotNull{row->val d=row.optJSONObject("data");val ca=d?.opt("ca") as? Number;if(d!=null&&d.opt("provisional")==false&&ca!=null&&ca.toDouble().isFinite())row.optString("service_day") to ca.toDouble() else null}
  .sortedBy{it.first}.takeLast(7)

@Composable internal fun GrilladActivityTrend(daily:List<JSONObject>,tr:(String)->String){
 val points=grilladActivitySeries(daily)
 OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
  Text(tr("Évolution du chiffre d’affaires"),style=MaterialTheme.typography.titleMedium)
  Text(tr("Services clôturés"),style=MaterialTheme.typography.bodySmall)
  if(points.isEmpty()){Text(tr("Aucune synthèse de service disponible."));return@Column}
  val context=LocalContext.current
  val motion=android.provider.Settings.Global.getFloat(context.contentResolver,android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,1f)>0f
  val progress=remember{Animatable(1f)}
  LaunchedEffect(points,motion){if(motion){progress.snapTo(0f);progress.animateTo(1f,tween(650))}else progress.snapTo(1f)}
  val line=MaterialTheme.colorScheme.primary
  val grid=MaterialTheme.colorScheme.outlineVariant
  Canvas(Modifier.fillMaxWidth().height(112.dp)){
   val low=minOf(0.0,points.minOf{it.second});val high=maxOf(0.0,points.maxOf{it.second});val span=(high-low).takeIf{it>0}?:1.0
   val inset=8.dp.toPx();val width=(size.width-2*inset).coerceAtLeast(0f);val height=(size.height-2*inset).coerceAtLeast(0f)
   fun y(v:Double)=inset+height*(1-((v-low)/span).toFloat())
   val coords=points.mapIndexed{i,p->Offset(inset+width*(if(points.size==1)0.5f else i.toFloat()/(points.size-1)),y(p.second))}
   drawLine(grid,Offset(inset,y(0.0)),Offset(inset+width,y(0.0)),1.dp.toPx())
   for(i in 0 until coords.lastIndex){val a=coords[i];val b=coords[i+1];val fraction=(progress.value*coords.lastIndex-i).coerceIn(0f,1f);if(fraction>0f)drawLine(line,a,Offset(a.x+(b.x-a.x)*fraction,a.y+(b.y-a.y)*fraction),2.5.dp.toPx(),StrokeCap.Round)}
   coords.forEach{drawCircle(line,3.dp.toPx(),it)}
  }
  points.forEach{(day,ca)->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(day,style=MaterialTheme.typography.bodySmall);Text("${ca.toLong()} F",style=MaterialTheme.typography.labelLarge)}}
 }}
}
