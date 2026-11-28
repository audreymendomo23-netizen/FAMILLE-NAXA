package cm.naxa.widemeet.auth
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import org.json.JSONObject
const val COMMERCIAL_LEGAL_VERSION="wm-commercial-20261128-v1"
@Composable fun CommercialLegal(english:Boolean,kind:String,approved:Boolean,onBack:()->Unit){
 val context=LocalContext.current
 val doc=remember(english,kind){JSONObject(context.assets.open("legal-commercial.json").bufferedReader().use{it.readText()}).getJSONObject(if(english)"en" else "fr").getJSONObject(kind)}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
 Text(doc.getString("title"),style=MaterialTheme.typography.headlineMedium)
 if(!approved)Text(if(english)"Provisional document. Registration is not currently open." else "Document provisoire. Les inscriptions ne sont pas actuellement ouvertes.")
 val sections=doc.getJSONArray("sections")
 for(i in 0 until sections.length()){val row=sections.getJSONArray(i);Text(row.getString(0),style=MaterialTheme.typography.titleMedium);Text(row.getString(1))}
 TextButton(onClick=onBack){Text(if(english)"Back" else "Retour")}
 }}
}
