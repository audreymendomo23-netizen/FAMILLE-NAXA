package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import org.json.JSONObject
import java.time.LocalDate
@Composable internal fun GrilladFutureHours(enabled:Boolean,onSave:(JSONObject)->Unit){
 var hour by remember{mutableStateOf("")};var date by remember{mutableStateOf("")};var reason by remember{mutableStateOf("")}
 OutlinedTextField(hour,{hour=it},label={Text("Nouvel horaire HH:mm")});OutlinedTextField(date,{date=it},label={Text("Date future AAAA-MM-JJ")});OutlinedTextField(reason,{reason=it},label={Text("Motif du nouvel horaire")})
 val parts=hour.split(":");val h=parts.getOrNull(0)?.toIntOrNull();val m=parts.getOrNull(1)?.toIntOrNull();val validDate=runCatching{LocalDate.parse(date)>LocalDate.parse(dayKey())}.getOrDefault(false)
 Button({if(h!=null&&m!=null)onSave(obj("start_minute" to h*60+m,"effective_from" to date,"reason" to reason))},enabled=enabled&&parts.size==2&&h!=null&&h in 0..23&&m!=null&&m in 0..59&&validDate&&reason.isNotBlank()){Text("Programmer l’horaire futur")}
}
