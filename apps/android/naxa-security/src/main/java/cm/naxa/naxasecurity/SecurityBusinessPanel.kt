package cm.naxa.naxasecurity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@Composable internal fun SecurityBusinessPanel(screen:SecurityScreen){
 var filter by remember(screen.id){mutableStateOf("")}
 var period by remember(screen.id){mutableStateOf("Aujourd’hui")}
 Card(Modifier.fillMaxWidth().padding(vertical=8.dp)){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text("Informations métier",style=MaterialTheme.typography.titleMedium)
 if(screen.id in listOf("B1.17","B1.18")){listOf("Essentiel — 5 000 F / mois · 60 000 F / an","Business — 20 000 F / mois · 200 000 F / an","Professional — 50 000 F / mois · 500 000 F / an").forEach{Text(it)}}else{
 OutlinedTextField(filter,{filter=it},label={Text("Filtrer les champs")},modifier=Modifier.fillMaxWidth())
 Row(horizontalArrangement=Arrangement.spacedBy(4.dp)){listOf("Aujourd’hui","7 jours","30 jours").forEach{p->FilterChip(selected=period==p,onClick={period=p},label={Text(p)})}}
 securityFields[screen.id].orEmpty().filter{it.contains(filter,true)}.forEach{field->Text(field,style=MaterialTheme.typography.labelLarge);Text("Non disponible — données non raccordées",style=MaterialTheme.typography.bodySmall)}
 }
 SecurityOperationalPanel(screen.id)
 SecurityModulePanel(screen.id)
 SecurityNativeCaseReport(screen.id)
 SecurityNativeField(screen.id)
 SecurityNativeVisitorPass(screen.id)
 SecurityNativeAudit(screen.id)
 SecurityActivityInbox(screen.id)
 SecurityNativeCatalog(screen.id)
 SecurityHelp(screen.id)
 SecurityNativeControl(screen.id)
 SecurityNativeMedia(screen.id)
 SecurityNativeAlarm(screen.id)
 SecurityNativeEvidenceShare(screen.id)
 SecurityNativeBilling(screen.id)
 SecurityNativeTracker(screen.id)
 if(screen.id in listOf("B4.08","B4.10"))SecurityAttendanceCapture(screen.id)
 Text("Les champs non raccordés restent préparatoires. Les opérations ci-dessus requièrent un reçu serveur ; aucune commande physique.",style=MaterialTheme.typography.bodySmall)
 }}
}
