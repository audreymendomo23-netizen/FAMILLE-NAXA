package cm.naxa.widemeet

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** UI adapter: authoritative server/SFU callbacks and actual stream state required. */
@Composable fun PresentationDisplayCard(
 english:Boolean, preferred:String, effective:String?, canPresent:Boolean, canDisplay:Boolean,
 online:Boolean, pending:Boolean, receiverId:String?, receiverName:String?,
 onQuality:(String)->Unit, onPair:()->Unit, onDisconnect:(String)->Unit
){
 fun tr(fr:String,en:String)=if(english)en else fr
 val levels=mapOf("low" to 360,"medium" to 720,"high" to 1080)
 Card(Modifier.fillMaxWidth()){
  Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
   Text(tr("Qualité de présentation","Presentation quality"),style=MaterialTheme.typography.titleMedium)
   levels.forEach{(key,height)->Row{
    RadioButton(selected=preferred==key,onClick={onQuality(key)},enabled=online&&!pending&&canPresent)
    Text(key.replaceFirstChar{it.uppercase()}+" Quality · "+height+"p",modifier=Modifier.padding(top=12.dp))
   }}
   Text(tr("Qualité effective : ","Effective quality: ")+(levels[effective]?.let{"${it}p"}?:tr("Non confirmée","Unconfirmed")))
   Text("WideMeet Connect",style=MaterialTheme.typography.titleMedium)
   if(receiverId!=null){Text(tr("Affichage sur : ","Displaying on: ")+(receiverName?:tr("Écran connecté","Connected display")))
    OutlinedButton(enabled=online&&!pending,onClick={onDisconnect(receiverId)}){Text(tr("Arrêter l’affichage","Stop display"))}
   }else{Button(enabled=online&&!pending&&canDisplay,onClick=onPair){Text(tr("Connecter un écran","Connect a display"))}
    if(!canDisplay)Text(tr("Affichage externe non autorisé pour cette réunion.","External display is not allowed for this meeting."))
   }
  }
 }
}
