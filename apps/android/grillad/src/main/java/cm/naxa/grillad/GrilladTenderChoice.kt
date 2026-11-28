package cm.naxa.grillad
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.Column
@Composable internal fun GrilladTenderChoice(value:String,onChange:(String)->Unit){Column{Text("Moyen de règlement déclaré");listOf("cash" to "Espèces","mtn_momo" to "MTN Mobile Money","orange_money" to "Orange Money").forEach{(k,label)->TextButton({onChange(k)}){Text((if(value==k)"✓ " else "")+label)}}}}
