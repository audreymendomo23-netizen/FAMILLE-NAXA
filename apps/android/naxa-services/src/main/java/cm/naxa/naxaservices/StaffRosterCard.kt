package cm.naxa.naxaservices

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

internal fun rosterAvailable(mode:String)=mode=="single_site_multi_workstation"||mode=="multi_site_network"
internal object StaffRosterApi {
    suspend fun readAttendanceSelfie(session:AuthSession,siteId:String,eventId:String,path:String):ByteArray=withContext(Dispatchers.IO){
        val base=URI(BuildConfig.AUTH_FUNCTION_URL)
        require(base.scheme=="https"&&base.host!=null&&base.userInfo==null&&base.path.trimEnd('/')=="/functions/v1/naxa-services-auth")
        val parts=path.split("/");require(parts.size==4&&parts[0]==session.account.organizationId&&parts[1]==siteId&&parts[3]==eventId+".jpg")
        parts.take(3).forEach{require(UUID.fromString(it).toString()==it)};require(UUID.fromString(eventId).toString()==eventId)
        require(!session.requirePasswordChange&&session.accessToken.isNotBlank()&&BuildConfig.SUPABASE_ANON_KEY.isNotBlank())
        val c=URL("https://"+base.rawAuthority+"/storage/v1/object/authenticated/ns-attendance-selfies/"+path).openConnection() as HttpURLConnection
        try{c.instanceFollowRedirects=false;c.connectTimeout=10000;c.readTimeout=15000;c.useCaches=false;c.setRequestProperty("apikey",BuildConfig.SUPABASE_ANON_KEY);c.setRequestProperty("Authorization","Bearer "+session.accessToken)
            require(c.responseCode in 200..299&&c.contentType?.substringBefore(';')=="image/jpeg")
            c.inputStream.use{input->val out=java.io.ByteArrayOutputStream();val buf=ByteArray(8192);while(true){val n=input.read(buf);if(n<0)break;require(out.size()+n<=2097152);out.write(buf,0,n)};out.toByteArray().also{require(it.isNotEmpty())}}
        }finally{c.disconnect()}
    }
    suspend fun uploadAttendanceSelfie(session:AuthSession,siteId:String,eventId:String,bytes:ByteArray)=withContext(Dispatchers.IO){
        val base=URI(BuildConfig.AUTH_FUNCTION_URL)
        require(base.scheme=="https"&&base.host!=null&&base.userInfo==null&&base.path.trimEnd('/')=="/functions/v1/naxa-services-auth")
        require(!session.requirePasswordChange&&session.accessToken.isNotBlank()&&BuildConfig.SUPABASE_ANON_KEY.isNotBlank()&&bytes.isNotEmpty()&&bytes.size<=2097152)
        val path=listOf(session.account.organizationId,siteId,session.account.memberId,eventId).joinToString("/"){UUID.fromString(it).toString()}+".jpg"
        val c=URL("https://"+base.rawAuthority+"/storage/v1/object/ns-attendance-selfies/"+path).openConnection() as HttpURLConnection
        try{c.requestMethod="POST";c.instanceFollowRedirects=false;c.connectTimeout=10000;c.readTimeout=15000;c.useCaches=false;c.doOutput=true
            c.setRequestProperty("apikey",BuildConfig.SUPABASE_ANON_KEY);c.setRequestProperty("Authorization","Bearer "+session.accessToken);c.setRequestProperty("Content-Type","image/jpeg");c.setRequestProperty("x-upsert","false")
            c.outputStream.use{it.write(bytes)};require(c.responseCode in 200..299)
        }finally{c.disconnect()}
    }
    suspend fun call(session:AuthSession,path:String,body:JSONObject?=null):String=withContext(Dispatchers.IO){
        val base=URI(BuildConfig.AUTH_FUNCTION_URL)
        require(base.scheme=="https"&&base.host!=null&&base.userInfo==null&&base.path.trimEnd('/')=="/functions/v1/naxa-services-auth")
        require(!session.requirePasswordChange&&session.accessToken.isNotBlank()&&BuildConfig.SUPABASE_ANON_KEY.isNotBlank())
        val connection=URL("https://"+base.rawAuthority+"/rest/v1/"+path).openConnection() as HttpURLConnection
        try{
            connection.requestMethod=if(body==null)"GET" else "POST"
            connection.instanceFollowRedirects=false;connection.connectTimeout=10000;connection.readTimeout=15000;connection.useCaches=false
            connection.setRequestProperty("apikey",BuildConfig.SUPABASE_ANON_KEY)
            connection.setRequestProperty("Authorization","Bearer "+session.accessToken)
            connection.setRequestProperty("Content-Type","application/json")
            connection.setRequestProperty("Prefer","return=representation")
            if(body!=null){connection.doOutput=true;connection.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}}
            require(connection.responseCode in 200..299)
            connection.inputStream.bufferedReader().use{it.readText()}
        }finally{connection.disconnect()}
    }
}
private fun JSONArray.rows():List<JSONObject> = (0 until length()).mapNotNull{optJSONObject(it)}
private fun JSONObject.nullable(key:String):String?=if(isNull(key))null else optString(key).takeIf{it.isNotBlank()}
private val rosterOffset=ZoneOffset.ofHours(1)
private val rosterFormat=DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
private fun rosterDisplay(s:String?)=s?.let{runCatching{Instant.parse(it).atOffset(rosterOffset).format(rosterFormat)}.getOrDefault("—")} ?: "—"
private fun rosterInstant(s:String)=LocalDateTime.parse(s,rosterFormat).toInstant(rosterOffset).toString()

@Composable
internal fun StaffRosterCard(session:AuthSession,siteId:String){
    if(!BuildConfig.ROSTER_ENABLED||!rosterAvailable(session.account.businessMode)||siteId.isBlank()||session.requirePasswordChange)return
    key(session.account.organizationId,session.account.memberId,session.deviceId,siteId){
        val latest by rememberUpdatedState(session)
        val scope=rememberCoroutineScope()
        val locale=session.account.defaultLocale
        fun tr(fr:String,en:String,ff:String)=when(locale){"en"->en;"ff-CM"->ff;else->fr}
        var targets by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var shifts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var acks by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var justifications by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var pendingPublish by remember{mutableStateOf<Pair<String,String>?>(null)}
        var comparisons by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var busy by remember{mutableStateOf(false)}
        var loaded by remember{mutableStateOf(false)}
        var error by remember{mutableStateOf(false)}
        var reload by remember{mutableIntStateOf(0)}
        var selected by remember{mutableStateOf<JSONObject?>(null)}
        var edited by remember{mutableStateOf<JSONObject?>(null)}
        var start by remember{mutableStateOf("")};var end by remember{mutableStateOf("")}
        var pause by remember{mutableStateOf("0")};var tolerance by remember{mutableStateOf("10")};var reason by remember{mutableStateOf("")}
        var cancelShift by remember{mutableStateOf<JSONObject?>(null)}
        fun clear(){selected=null;edited=null;start="";end="";pause="0";tolerance="10";reason="";cancelShift=null}
        suspend fun refresh(){
            try{
                val current=latest
                val org=current.account.organizationId
                val filter="org_id=eq."+UUID.fromString(org)+"&site_id=eq."+UUID.fromString(siteId)
                val next=JSONArray(StaffRosterApi.call(current,"ns_roster_shifts?select=*&"+filter+"&order=starts_at.desc&limit=200")).rows()
                val people=JSONArray(StaffRosterApi.call(current,"rpc/ns_roster_targets",JSONObject().put("p_org",org).put("p_site",siteId))).rows()
                val seen=JSONArray(StaffRosterApi.call(current,"ns_roster_acknowledgements?select=shift_id,revision,acknowledged_at&"+filter+"&limit=1000")).rows()
                val report=JSONArray(StaffRosterApi.call(current,"ns_roster_service_comparison?select=*&"+filter+"&limit=200")).rows()
                val explanations=JSONArray(StaffRosterApi.call(current,"ns_roster_justifications?select=shift_id,baseline_revision,explanation,decision,decision_reason&"+filter+"&limit=200")).rows()
                shifts=next;targets=people;acks=seen;comparisons=report;justifications=explanations;loaded=true;error=false
            }catch(c:CancellationException){throw c}catch(_:Exception){loaded=false;error=true;targets=emptyList();shifts=emptyList();acks=emptyList();comparisons=emptyList();justifications=emptyList()}
        }
        LaunchedEffect(reload,session.accessToken){while(true){if(!busy)refresh();delay(30000)}}
        fun targetFor(row:JSONObject)=targets.firstOrNull{it.optString("member_id")==row.optString("member_id")&&it.nullable("workstation_id")==row.nullable("workstation_id")}
        fun perform(action:suspend()->Unit){
            if(busy||!loaded)return
            busy=true;error=false
            scope.launch{try{action();reload++}catch(c:CancellationException){throw c}catch(_:Exception){error=true}finally{busy=false}}
        }
        fun publish(cancel:JSONObject?=null){
            val person=if(cancel!=null)targetFor(cancel) else selected
            if(person==null||reason.isBlank())return
            perform{
                val row=cancel?:edited
                val body=JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId)
                    .put("p_post",person.nullable("workstation_id")?:JSONObject.NULL).put("p_member",person.optString("member_id"))
                    .put("p_starts",cancel?.optString("starts_at")?:rosterInstant(start))
                    .put("p_ends",cancel?.optString("ends_at")?:rosterInstant(end))
                    .put("p_break",cancel?.optInt("planned_break_minutes")?:pause.toInt())
                    .put("p_tolerance",cancel?.optInt("tolerance_minutes")?:tolerance.toInt())
                    .put("p_status",if(cancel!=null)"cancelled" else "published")
                    .put("p_expected_revision",row?.optLong("revision")?:0L).put("p_reason",reason.trim())
                val fingerprint=body.toString()
                val id=row?.optString("id")?:pendingPublish?.takeIf{it.first==fingerprint}?.second?:UUID.randomUUID().toString()
                if(row==null)pendingPublish=fingerprint to id
                body.put("p_id",id)
                val receipt=JSONObject(StaffRosterApi.call(latest,"rpc/ns_publish_roster_shift",body))
                require(receipt.getString("id")==id&&receipt.getLong("revision")==body.getLong("p_expected_revision")+1L&&receipt.getString("status")==body.getString("p_status"))
                pendingPublish=null;clear()
            }
        }
        Card(Modifier.fillMaxWidth()){
            Column(Modifier.fillMaxWidth().padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
                Text(tr("Planning de service","Work schedule","Feere golle"),style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
                Text(tr("Heure de Douala (UTC+1)","Douala time (UTC+1)","Sahaa Duwaala (UTC+1)"))
                OutlinedButton(onClick={reload++},enabled=!busy){Text(tr("Actualiser","Refresh","Hesɗitin"))}
                if(error)Text(tr("Planning ou modification non confirmé. Actualisez et réessayez.","Schedule or change not confirmed. Refresh and retry.","Feere golle walla baylugol tabbitinaaka. Hesɗitin, eto."),color=MaterialTheme.colorScheme.error)
                if(loaded&&targets.isNotEmpty()){
                    Text(tr("Publier ou modifier un service","Publish or edit a shift","Bayyin walla waylu golle"),fontWeight=FontWeight.Bold)
                    if(edited==null&&cancelShift==null)targets.forEach{p->
                        OutlinedButton(onClick={selected=p},enabled=!busy,modifier=Modifier.fillMaxWidth()){
                            Text((if(selected===p)"✓ " else "")+p.optString("display_name")+" · "+(p.nullable("workstation_name")?:tr("Site","Site","Nokkuure")))
                        }
                    }
                    if(cancelShift==null){
                        OutlinedTextField(start,{start=it},label={Text(tr("Début (AAAA-MM-JJ HH:mm)","Start (YYYY-MM-DD HH:mm)","Fuɗɗagol (YYYY-MM-DD HH:mm)"))},modifier=Modifier.fillMaxWidth(),singleLine=true)
                        OutlinedTextField(end,{end=it},label={Text(tr("Fin (AAAA-MM-JJ HH:mm)","End (YYYY-MM-DD HH:mm)","Timmugol (YYYY-MM-DD HH:mm)"))},modifier=Modifier.fillMaxWidth(),singleLine=true)
                        OutlinedTextField(pause,{pause=it},label={Text(tr("Pause (min)","Break (min)","Fooftugol (min)"))},modifier=Modifier.fillMaxWidth(),singleLine=true)
                        OutlinedTextField(tolerance,{tolerance=it},label={Text(tr("Tolérance (min)","Tolerance (min)","Yaafuyya (min)"))},modifier=Modifier.fillMaxWidth(),singleLine=true)
                    }
                    OutlinedTextField(reason,{reason=it},label={Text(tr("Motif","Reason","Sabu"))},modifier=Modifier.fillMaxWidth())
                    Button(onClick={publish(cancelShift)},enabled=!busy&&reason.isNotBlank()&&(selected!=null||cancelShift!=null)){Text(if(cancelShift!=null)tr("Confirmer l'annulation","Confirm cancellation","Tabbitin haaytugol") else tr("Publier et notifier","Publish and notify","Bayyin e tintin"))}
                    if(edited!=null||cancelShift!=null)TextButton(onClick={clear()}){Text(tr("Abandonner","Discard","Accu"))}
                }
                if(loaded&&shifts.isEmpty())Text(tr("Aucun service planifié.","No scheduled shifts.","Alaa golle e feere."))
                shifts.forEach{row->
                    HorizontalDivider()
                    val own=row.optString("member_id")==session.account.memberId
                    val ack=acks.any{it.optString("shift_id")==row.optString("id")&&it.optLong("revision")==row.optLong("revision")}
                    val p=targetFor(row)
                    Text(if(own)tr("Mon service","My shift","Golle am") else p?.optString("display_name")?:tr("Collaborateur","Employee","Gollotooɗo"),fontWeight=FontWeight.SemiBold)
                    Text(rosterDisplay(row.nullable("starts_at"))+" — "+rosterDisplay(row.nullable("ends_at")))
                    Text(if(row.optString("status")=="cancelled")tr("Annulé","Cancelled","Haaytaama") else tr("Publié","Published","Bayyinaama"))
                    Text(if(ack)tr("Pris en compte","Acknowledged","Jaɓaama") else tr("À confirmer","Awaiting acknowledgement","Foti jaɓeede"))
                    if(own&&!ack)Button(onClick={perform{StaffRosterApi.call(latest,"rpc/ns_ack_roster_shift",JSONObject().put("p_id",row.optString("id")).put("p_revision",row.optLong("revision")))}},enabled=!busy){Text(tr("J'ai pris connaissance","Acknowledge","Mi heɓii humpito"))}
                    if(p!=null&&row.optString("status")=="published"){
                        OutlinedButton(onClick={clear();edited=row;selected=p;start=rosterDisplay(row.nullable("starts_at"));end=rosterDisplay(row.nullable("ends_at"));pause=row.optInt("planned_break_minutes").toString();tolerance=row.optInt("tolerance_minutes").toString()},enabled=!busy){Text(tr("Modifier","Edit","Waylu"))}
                        TextButton(onClick={clear();cancelShift=row},enabled=!busy){Text(tr("Annuler le service","Cancel shift","Haaytu golle"))}
                    }
                    comparisons.filter{it.optString("shift_id")==row.optString("id")}.forEach{c->
                        Text(tr("Arrivée","Arrival","Naatugol")+": "+rosterDisplay(c.nullable("actual_start"))+" · "+tr("Départ","Departure","Yaltugol")+": "+rosterDisplay(c.nullable("actual_end")))
                        Text(tr("Retard","Late","Leeltugol")+": "+(c.nullable("late_minutes")?:"—")+" min · "+tr("Départ anticipé","Early departure","Yaltugol adii")+": "+(c.nullable("early_departure_minutes")?:"—")+" min")
                        Text(tr("Temps supplémentaire","Extra time","Sahaa ɓeydiiɗo")+": "+(c.nullable("extra_minutes")?:"—")+" min · "+tr("Pause réelle","Actual break","Fooftugol goonga")+": "+(c.nullable("actual_break_minutes")?:"—")+" min")
                        val baseline=c.optLong("baseline_revision")
                        val shiftId=row.optString("id")
                        val justification=justifications.firstOrNull{it.optString("shift_id")==shiftId&&it.optLong("baseline_revision")==baseline}
                        key(shiftId,baseline){
                            var explanation by remember{mutableStateOf("")}
                            if(justification!=null){
                                Text(justification.optString("explanation"))
                                Text(when(justification.nullable("decision")){"accepted"->tr("Justification acceptée","Explanation accepted","Jaɓaama");"rejected"->tr("Justification refusée","Explanation rejected","Jaɓaaka");else->tr("Justification à examiner","Explanation awaiting review","Ƴeewto")})
                                justification.nullable("decision_reason")?.let{Text(it)}
                                if(p!=null&&justification.nullable("decision")==null){
                                    OutlinedTextField(explanation,{explanation=it.take(1000)},label={Text(tr("Motif de la décision","Decision reason","Sabu ñaawol"))},enabled=!busy)
                                    listOf("accepted" to tr("Accepter","Accept","Jaɓ"),"rejected" to tr("Refuser","Reject","Sal")).forEach{(decision,label)->
                                        OutlinedButton(enabled=!busy&&explanation.isNotBlank(),onClick={perform{
                                            val result=JSONObject(StaffRosterApi.call(latest,"rpc/ns_decide_roster_justification",JSONObject().put("p_shift",shiftId).put("p_revision",baseline).put("p_decision",decision).put("p_reason",explanation.trim())))
                                            require(result.getString("decision")==decision);explanation=""
                                        }}){Text(label)}
                                    }
                                }
                            }else if(own&&c.optString("comparison_status") in listOf("variance_review","unmatched_review","multiple_sessions_review")){
                                OutlinedTextField(explanation,{explanation=it.take(1000)},label={Text(tr("Expliquez l'écart","Explain the variance","Humpit ceertugol"))},enabled=!busy)
                                Button(enabled=!busy&&explanation.isNotBlank(),onClick={perform{
                                    val result=JSONObject(StaffRosterApi.call(latest,"rpc/ns_submit_roster_justification",JSONObject().put("p_shift",shiftId).put("p_revision",baseline).put("p_explanation",explanation.trim())))
                                    require(result.optBoolean("submitted"));explanation=""
                                }}){Text(tr("Justifier l'écart","Explain variance","Humpit ceertugol"))}
                            }
                        }
                    }
                }
            }
        }
    }
}
