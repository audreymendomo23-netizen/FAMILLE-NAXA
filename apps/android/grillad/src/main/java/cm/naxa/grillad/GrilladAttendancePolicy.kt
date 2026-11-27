package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.foundation.layout.Row
import org.json.JSONObject
@Composable internal fun GrilladAttendancePolicy(settings:JSONObject?,enabled:Boolean,onSave:(JSONObject)->Unit){
 var expanded by remember{mutableStateOf(false)}
 TextButton({expanded=!expanded}){Text("Paramètres de pointage du site")}
 if(expanded){val fields=listOf("latitude" to "Latitude du point","longitude" to "Longitude du point","radius_m" to "Rayon autorisé (m)","max_accuracy_m" to "Précision maximale (m)","max_age_seconds" to "Âge maximal preuve (s)","photo_retention_days" to "Conservation photo (jours)");val values=remember(settings){mutableStateMapOf<String,String>().apply{fields.forEach{(k,_)->put(k,settings?.optString(k,"")?:"")}}};var active by remember(settings){mutableStateOf(settings?.optBoolean("enabled")?:false)};var informed by remember{mutableStateOf(false)};var reason by remember{mutableStateOf("")}
 Text("Coordonnées du lieu professionnel. Pas de suivi continu. Préserver la confidentialité et informer le personnel.")
 fields.forEach{(key,label)->OutlinedTextField(values[key]?:"",{values[key]=it},label={Text(label)})}
 Row{Checkbox(active,{active=it});Text("Activer le pointage")};Row{Checkbox(informed,{informed=it});Text("Information préalable du personnel effectuée")}
 OutlinedTextField(reason,{reason=it},label={Text("Motif politique de pointage")});val lat=values["latitude"]?.replace(',','.')?.toDoubleOrNull();val lon=values["longitude"]?.replace(',','.')?.toDoubleOrNull();val valid=lat!=null&&lon!=null&&lat in -90.0..90.0&&lon in -180.0..180.0&&fields.drop(2).all{values[it.first]?.toIntOrNull()!=null}
 Button({val p=obj("latitude" to lat,"longitude" to lon,"enabled" to active,"staff_informed" to informed,"reason" to reason);fields.drop(2).forEach{p.put(it.first,values[it.first]?.toIntOrNull())};onSave(p)},enabled=enabled&&valid&&reason.isNotBlank()&&(!active||informed)){Text("Enregistrer les paramètres du pointage")}}
}
