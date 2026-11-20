package cm.naxa.zipple
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.*
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{MaterialTheme{Column(Modifier.fillMaxSize().padding(24.dp)){Text("Zipple",style=MaterialTheme.typography.headlineMedium);Text("Socle natif Famille NAXA — parcours métier à intégrer.")}}}}}