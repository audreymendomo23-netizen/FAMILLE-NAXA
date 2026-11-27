package cm.naxa.zipple

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneOffset

private val doualaOffset=ZoneOffset.ofHours(1)
internal fun zippleBookingTime(value:String):String? = try {
    if(!value.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}"))) null
    else LocalDateTime.parse(value.replace(' ','T')).atOffset(doualaOffset).toInstant().toString()
} catch (_:java.time.DateTimeException){null}

@Composable private fun FloorChoice(label:String, options:List<Pair<String,String>>, selected:String, enabled:Boolean, onSelect:(String)->Unit) {
    var open by remember{mutableStateOf(false)}
    Box {
        OutlinedButton(enabled=enabled&&options.isNotEmpty(),onClick={open=true}) {
            Text(label+" : "+(options.find{it.first==selected}?.second?:"—"))
        }
        DropdownMenu(expanded=open,onDismissRequest={open=false}) {
            options.forEach{(id,name)->DropdownMenuItem(text={Text(name)},onClick={onSelect(id);open=false})}
        }
    }
}
@Composable internal fun ZippleNativeFloor(api:ZippleBusiness, session:Session, site:String, en:Boolean, restaurant:Boolean) {
    val t:(String,String)->String={fr,english->if(en)english else fr}
    val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
    var data by remember{mutableStateOf<JSONObject?>(null)}
    var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
    var zoneName by remember{mutableStateOf("")};var tableId by remember{mutableStateOf("")}
    var zoneId by remember{mutableStateOf("")};var seats by remember{mutableStateOf("4")}
    var guest by remember{mutableStateOf("")};var party by remember{mutableStateOf("2")}
    var start by remember{mutableStateOf("")};var end by remember{mutableStateOf("")}
    var waiting by remember{mutableStateOf("")};var waitingParty by remember{mutableStateOf("2")}
    val permitted=session.role in setOf("promoteur","manager")&&session.permits(site)
    suspend fun load(){data=api.call(session,site,"floor_snapshot") as? JSONObject?:error("DATA")}
    fun run(block:suspend()->Unit){
        if(busy||!permitted)return
        busy=true;message=""
        scope.launch{try{block()}catch(c:CancellationException){throw c}catch(_:Exception){message=t("Opération non confirmée","Operation unconfirmed")}finally{busy=false}}
    }
    suspend fun write(action:String,payload:JSONObject,idempotent:Boolean=false){
        val body=if(idempotent)keys.apply(action,payload)else payload
        val result=api.call(session,site,action,body)
        require(result!=null&&result!=false)
        if(idempotent)keys.confirmed(action)
        load();message=t("Configuration enregistrée","Configuration saved")
    }
    LaunchedEffect(session.member,site){try{load()}catch(c:CancellationException){throw c}catch(_:Exception){message=t("Données indisponibles","Data unavailable")}}
    val allowed=permitted&&!busy
    Text(t("Gestion des salles","Room management"),style=MaterialTheme.typography.titleLarge)
    OutlinedButton(enabled=allowed,onClick={run{load()}}){Text(t("Actualiser les salles","Refresh rooms"))}
    val d=data
    OutlinedTextField(zoneName,{zoneName=it.take(80)},label={Text(t("Nom de la zone","Zone name"))},enabled=allowed&&d!=null,modifier=Modifier.fillMaxWidth())
    Button(enabled=allowed&&d!=null&&zoneName.trim().isNotEmpty(),onClick={run{
        write("zone_add",JSONObject().put("name",zoneName.trim()));zoneName=""
    }}){Text(t("Créer la zone","Create zone"))}
    val tables=d?.rows("tables").orEmpty().filter{it.optString("kind")!="pickup"}
    val zones=d?.rows("zones").orEmpty()
    val selected=tables.find{it.optString("id")==tableId}
    FloorChoice(t("Table à configurer","Table to configure"),tables.map{it.optString("id") to it.optString("label")},tableId,allowed){id->
        val x=tables.first{it.optString("id")==id};tableId=id;zoneId=if(x.isNull("zone_id"))"" else x.optString("zone_id");seats=x.optInt("seats",4).toString()
    }
    FloorChoice(t("Zone de la table","Table zone"),listOf("" to "—")+zones.map{it.optString("id") to it.optString("name")},zoneId,allowed&&selected!=null){zoneId=it}
    OutlinedTextField(seats,{seats=it.filter(Char::isDigit).take(3)},label={Text(t("Nombre de places","Seats"))},enabled=allowed&&selected!=null)
    Button(enabled=allowed&&selected!=null&&(seats.toIntOrNull()?:0) in 1..100,onClick={run{
        write("table_config",JSONObject().put("table_id",tableId).put("zone_id",if(zoneId.isBlank())JSONObject.NULL else zoneId).put("seats",seats.toInt()))
    }}){Text(t("Enregistrer la table","Save table"))}
    selected?.let{x->Text(x.optString("label")+" · "+x.optInt("seats")+" "+t("places","seats"))}
    if(restaurant&&d!=null){
        Text(t("Réservations Restaurant","Restaurant reservations"),style=MaterialTheme.typography.titleMedium)
        OutlinedTextField(guest,{guest=it.take(160)},label={Text(t("Nom de réservation","Booking name"))},enabled=allowed)
        OutlinedTextField(party,{party=it.filter(Char::isDigit).take(3)},label={Text(t("Nombre de personnes","Party size"))},enabled=allowed)
        OutlinedTextField(start,{start=it.take(16)},label={Text(t("Début AAAA-MM-JJ HH:mm","Start YYYY-MM-DD HH:mm"))},enabled=allowed)
        OutlinedTextField(end,{end=it.take(16)},label={Text(t("Fin AAAA-MM-JJ HH:mm","End YYYY-MM-DD HH:mm"))},enabled=allowed)
        Text(t("Heure de Douala (UTC+1)","Douala time (UTC+1)"))
        val from=zippleBookingTime(start);val until=zippleBookingTime(end)
        Button(enabled=allowed&&selected!=null&&guest.trim().isNotEmpty()&&(party.toIntOrNull()?:0) in 1..(selected?.optInt("seats")?:0)&&from!=null&&until!=null&&java.time.Instant.parse(from).isBefore(java.time.Instant.parse(until)),onClick={run{
            write("reserve_table",JSONObject().put("table_id",tableId).put("guest_name",guest.trim()).put("party_size",party.toInt()).put("starts_at",from).put("ends_at",until),true);guest=""
        }}){Text(t("Réserver la table","Book table"))}
        d.rows("reservations").forEach{x->
            val state=x.optString("state");val label=x.optString("guest_name")
            Text(label+" · "+when(state){"booked"->t("Réservée","Booked");"seated"->t("Installée","Seated");"cancelled"->t("Annulée","Cancelled");else->state})
            Text(x.optString("starts_at")+" / "+x.optString("ends_at"))
            if(state=="booked")for((next,fr,english) in listOf(Triple("seated","Accueillir","Seat"),Triple("cancelled","Annuler","Cancel"),Triple("expired","Expirer","Expire"))){
                OutlinedButton(enabled=allowed,onClick={run{write("reservation_transition",JSONObject().put("reservation_id",x.getString("id")).put("next",next))}}){Text(t(fr,english)+" : "+label)}
            }
        }
        Text(t("Liste d’attente","Waiting list"),style=MaterialTheme.typography.titleMedium)
        OutlinedTextField(waiting,{waiting=it.take(160)},label={Text(t("Nom en attente","Waiting guest name"))},enabled=allowed)
        OutlinedTextField(waitingParty,{waitingParty=it.filter(Char::isDigit).take(3)},label={Text(t("Taille du groupe","Group size"))},enabled=allowed)
        Button(enabled=allowed&&waiting.trim().isNotEmpty()&&(waitingParty.toIntOrNull()?:0) in 1..100,onClick={run{
            write("waitlist_add",JSONObject().put("guest_name",waiting.trim()).put("party_size",waitingParty.toInt()),true);waiting=""
        }}){Text(t("Ajouter à l’attente","Add to waiting list"))}
        d.rows("waitlist").forEach{x->val label=x.optString("guest_name")
            Text(label+" · "+x.optInt("party_size"))
            OutlinedButton(enabled=allowed&&selected!=null,onClick={run{write("waitlist_transition",JSONObject().put("waitlist_id",x.getString("id")).put("next","seated").put("table_id",tableId))}}){Text(t("Installer","Seat")+" : "+label)}
            OutlinedButton(enabled=allowed,onClick={run{write("waitlist_transition",JSONObject().put("waitlist_id",x.getString("id")).put("next","cancelled").put("table_id",JSONObject.NULL))}}){Text(t("Retirer de l’attente","Remove from waiting list")+" : "+label)}
        }
    }
    if(message.isNotBlank())Text(message)
}
