package cm.naxa.naxasecurity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

class MainActivity:ComponentActivity(){
 override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{
  MaterialTheme(colorScheme=darkColorScheme(primary=Color(0xFF69D1DC),background=Color(0xFF0B1426),surface=Color(0xFF152238))){
   SecurityNativeWorkspace { SecurityNavigation() }
  }
 }}
}
@Composable private fun SecurityNavigation(){
 var tab by rememberSaveable { mutableStateOf("Accueil") }
 var selected by rememberSaveable { mutableStateOf("") }
 var search by rememberSaveable { mutableStateOf("") }
 val screen=securityScreens.firstOrNull{it.id==selected}
 BackHandler(screen!=null){selected=""}
 Scaffold(bottomBar={NavigationBar {securityTabs.forEach { item ->
  NavigationBarItem(selected=tab==item,onClick={tab=item;selected="";search=""},icon={Text(item.take(1))},label={Text(item)})
 } }}) { padding ->
  Column(Modifier.fillMaxSize().padding(padding).padding(16.dp)){
   Text("NAXA SECURITY",style=MaterialTheme.typography.headlineSmall)
   SecurityNativeSessionPanel()
   Spacer(Modifier.height(12.dp))
   if(screen!=null){
    TextButton(onClick={selected=""}){Text("Retour")}
    Text(screen.title,style=MaterialTheme.typography.headlineMedium)
    Text(screen.id+" · "+screen.bulk)
    
    Text("Écrans associés",Modifier.padding(top=16.dp),style=MaterialTheme.typography.titleMedium)
    LazyColumn{item { SecurityBusinessPanel(screen) };items(securityScreens.filter{it.bulk==screen.bulk&&it.id!=screen.id}){item->
     TextButton(onClick={selected=item.id;tab=item.tab}){Text(item.title)}
    }}
   }else{
    Text(tab,style=MaterialTheme.typography.headlineMedium)
    OutlinedTextField(value=search,onValueChange={search=it},label={Text("Rechercher un écran")},singleLine=true,modifier=Modifier.fillMaxWidth())
    val visible=securityScreens.filter{it.tab==tab&&(it.title.contains(search,true)||it.id.contains(search,true))}
    Text("${visible.size} écrans",Modifier.padding(vertical=8.dp))
    LazyColumn(verticalArrangement=Arrangement.spacedBy(8.dp)){items(visible,key={it.id}){item->
     OutlinedButton(onClick={selected=item.id},modifier=Modifier.fillMaxWidth()){Text(item.title+" · "+item.id)}
    }}
   }
  }
 }
}
