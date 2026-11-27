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
        var availability by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var ownPosts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var templates by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var alerts by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var leavePost by remember{mutableStateOf("")};var leaveKind by remember{mutableStateOf("leave")}
        var leaveStart by remember{mutableStateOf("")};var leaveEnd by remember{mutableStateOf("")};var leaveReason by remember{mutableStateOf("")}
        var templateDate by remember{mutableStateOf("")};var templateName by remember{mutableStateOf("")}
        val pendingExtensions=remember{mutableMapOf<String,Pair<String,String>>()}
        fun extensionId(kind:String,body:JSONObject):String{
            val fingerprint=body.toString();val previous=pendingExtensions[kind]
            if(previous?.first==fingerprint)return previous.second
            return UUID.randomUUID().toString().also{pendingExtensions[kind]=fingerprint to it}
        }
        var justifications by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var pendingPublish by remember{mutableStateOf<Pair<String,List<String>>?>(null)}
        var comparisons by remember{mutableStateOf<List<JSONObject>>(emptyList())}
        var busy by remember{mutableStateOf(false)}
        var loaded by remember{mutableStateOf(false)}
        var error by remember{mutableStateOf(false)}
        var reload by remember{mutableIntStateOf(0)}
        var selected by remember{mutableStateOf<JSONObject?>(null)}
        var edited by remember{mutableStateOf<JSONObject?>(null)}
        var start by remember{mutableStateOf("")};var end by remember{mutableStateOf("")}
        var pause by remember{mutableStateOf("0")};var tolerance by remember{mutableStateOf("10")};var reason by remember{mutableStateOf("")}
        var repeat by remember{mutableStateOf("once")};var repeatCount by remember{mutableStateOf("1")}
        var cancelShift by remember{mutableStateOf<JSONObject?>(null)}
        fun clear(){selected=null;edited=null;start="";end="";pause="0";tolerance="10";reason="";cancelShift=null;repeat="once";repeatCount="1"}
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
                val absences=JSONArray(StaffRosterApi.call(current,"ns_roster_availability?select=*&"+filter+"&order=starts_at.desc&limit=200")).rows()
                val posts=JSONArray(StaffRosterApi.call(current,"rpc/ns_roster_own_posts",JSONObject().put("p_org",org).put("p_site",siteId))).rows()
                val models=JSONArray(StaffRosterApi.call(current,"ns_roster_templates?select=*&"+filter+"&archived_at=is.null&limit=100")).rows()
                val issues=JSONArray(StaffRosterApi.call(current,"rpc/ns_roster_alerts",JSONObject().put("p_org",org).put("p_site",siteId))).rows()
                shifts=next;targets=people;acks=seen;comparisons=report;justifications=explanations;availability=absences;ownPosts=posts;templates=models;alerts=issues;loaded=true;error=false
            }catch(c:CancellationException){throw c}catch(_:Exception){loaded=false;error=true;targets=emptyList();shifts=emptyList();acks=emptyList();comparisons=emptyList();justifications=emptyList();availability=emptyList();ownPosts=emptyList();templates=emptyList();alerts=emptyList()}
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
                val count=if(row==null&&repeat!="once")repeatCount.toInt() else 1
                require(count in 1..31&&(row!=null||repeat=="once"||count>=2))
                val seconds=(if(repeat=="weekly")7L else 1L)*86400L
                val commands=(0 until count).map{i->if(i==0)body else JSONObject(body.toString())
                    .put("p_starts",Instant.parse(body.getString("p_starts")).plusSeconds(i*seconds).toString())
                    .put("p_ends",Instant.parse(body.getString("p_ends")).plusSeconds(i*seconds).toString())}
                val fingerprint=JSONArray(commands).toString()
                val ids=if(row!=null)listOf(row.getString("id")) else pendingPublish?.takeIf{it.first==fingerprint}?.second?:List(count){UUID.randomUUID().toString()}
                if(row==null)pendingPublish=fingerprint to ids
                val payloads=commands.mapIndexed{i,command->JSONObject(command.toString()).put("p_id",ids[i])}
                val receipts=if(count==1)listOf(JSONObject(StaffRosterApi.call(latest,"rpc/ns_publish_roster_shift",payloads.first())))
                    else JSONObject(StaffRosterApi.call(latest,"rpc/ns_publish_roster_batch",JSONObject().put("p_commands",JSONArray(payloads)))).getJSONArray("receipts").rows()
                require(receipts.size==count&&ids.all{id->receipts.count{it.getString("id")==id&&it.getLong("revision")==body.getLong("p_expected_revision")+1L&&it.getString("status")==body.getString("p_status")}==1})
                pendingPublish=null;clear()
            }
        }
        Card(Modifier.fillMaxWidth()){
            Column(Modifier.fillMaxWidth().padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
                Text(tr("Planning de service","Work schedule","Feere golle"),style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
                Text(tr("Heure de Douala (UTC+1)","Douala time (UTC+1)","Sahaa Duwaala (UTC+1)"))
                OutlinedButton(onClick={reload++},enabled=!busy){Text(tr("Actualiser","Refresh","Hesɗitin"))}
                if(error)Text(tr("Planning ou modification non confirmé. Actualisez et réessayez.","Schedule or change not confirmed. Refresh and retry.","Feere golle walla baylugol tabbitinaaka. Hesɗitin, eto."),color=MaterialTheme.colorScheme.error)
                if(loaded&&ownPosts.isNotEmpty()){
                    Text(tr("Congés et indisponibilités","Leave and availability","Heddaade e alaa"),fontWeight=FontWeight.Bold)
                    ownPosts.forEach{p->val id=p.nullable("workstation_id")?:"";OutlinedButton(enabled=!busy,onClick={leavePost=id}){Text((if(leavePost==id)"✓ " else "")+(p.nullable("workstation_name")?:tr("Site","Site","Nokkuure")))}}
                    listOf("leave" to tr("Congé","Leave","Heddaade"),"unavailable" to tr("Indisponibilité","Unavailable","Alaa")).forEach{(id,label)->OutlinedButton(enabled=!busy,onClick={leaveKind=id}){Text((if(leaveKind==id)"✓ " else "")+label)}}
                    OutlinedTextField(leaveStart,{leaveStart=it},label={Text(tr("Début de la demande (AAAA-MM-JJ HH:mm)","Request start (YYYY-MM-DD HH:mm)","Fuɗɗagol ɗaɓɓitannde"))},modifier=Modifier.fillMaxWidth(),enabled=!busy,singleLine=true)
                    OutlinedTextField(leaveEnd,{leaveEnd=it},label={Text(tr("Fin de la demande (AAAA-MM-JJ HH:mm)","Request end (YYYY-MM-DD HH:mm)","Timmugol ɗaɓɓitannde"))},modifier=Modifier.fillMaxWidth(),enabled=!busy,singleLine=true)
                    OutlinedTextField(leaveReason,{leaveReason=it.take(500)},label={Text(tr("Motif de la demande","Request reason","Sabu ɗaɓɓitannde"))},modifier=Modifier.fillMaxWidth(),enabled=!busy)
                    Button(enabled=!busy&&leaveReason.isNotBlank()&&leaveStart.isNotBlank()&&leaveEnd.isNotBlank()&&ownPosts.any{(it.nullable("workstation_id")?:"")==leavePost},onClick={perform{
                        val body=JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId).put("p_post",leavePost.takeIf{it.isNotBlank()}?:JSONObject.NULL).put("p_start",rosterInstant(leaveStart)).put("p_end",rosterInstant(leaveEnd)).put("p_kind",leaveKind).put("p_reason",leaveReason.trim())
                        val id=extensionId("availability",body);body.put("p_id",id)
                        val receipt=JSONObject(StaffRosterApi.call(latest,"rpc/ns_request_roster_availability",body))
                        require(receipt.getString("id")==id&&receipt.getString("status") in listOf("pending","approved","rejected"));pendingExtensions.remove("availability");leaveStart="";leaveEnd="";leaveReason=""
                    }}){Text(tr("Envoyer la demande","Submit request","Neldu ɗaɓɓitannde"))}
                }
                availability.forEach{a->key(a.getString("id")){
                    var decisionReason by remember{mutableStateOf("")}
                    val editable=targetFor(a)!=null
                    HorizontalDivider()
                    Text((if(a.optString("kind")=="leave")tr("Congé","Leave","Heddaade")else tr("Indisponibilité","Unavailable","Alaa"))+" · "+(if(a.optString("member_id")==session.account.memberId)tr("Ma demande","My request","Ɗaɓɓitannde am")else targetFor(a)?.optString("display_name")?:tr("Collaborateur","Employee","Gollotooɗo")))
                    Text(rosterDisplay(a.nullable("starts_at"))+" — "+rosterDisplay(a.nullable("ends_at")));Text(a.optString("reason"))
                    Text(when(a.optString("status")){"approved"->tr("Approuvée","Approved","Jaɓaama");"rejected"->tr("Refusée","Rejected","Jaɓaaka");else->tr("À examiner","Awaiting review","Ƴeewto")})
                    a.nullable("decision_reason")?.let{Text(it)}
                    if(editable&&a.optString("status")=="pending"){
                        OutlinedTextField(decisionReason,{decisionReason=it.take(500)},label={Text(tr("Motif de la décision","Decision reason","Sabu ñaawol"))},enabled=!busy)
                        listOf("approved" to tr("Approuver la demande","Approve request","Jaɓ ɗaɓɓitannde"),"rejected" to tr("Refuser la demande","Reject request","Sal ɗaɓɓitannde")).forEach{(status,label)->OutlinedButton(enabled=!busy&&decisionReason.isNotBlank(),onClick={perform{
                            val r=JSONObject(StaffRosterApi.call(latest,"rpc/ns_decide_roster_availability",JSONObject().put("p_id",a.getString("id")).put("p_status",status).put("p_reason",decisionReason.trim())))
                            require(r.getString("id")==a.getString("id")&&r.getString("status")==status);decisionReason=""
                        }}){Text(label)}}
                    }
                }}
                if(loaded&&targets.isNotEmpty()&&templates.isNotEmpty()){
                    Text(tr("Modèles de service","Shift templates","Leɗɗe golle"),fontWeight=FontWeight.Bold)
                    OutlinedTextField(templateDate,{templateDate=it},label={Text(tr("Date du premier service (AAAA-MM-JJ)","First shift date (YYYY-MM-DD)","Ñalngu golle aranere"))},enabled=!busy,singleLine=true)
                    templates.forEach{t->
                        Text(t.optString("name")+" · "+t.optInt("repeat_count"))
                        OutlinedButton(enabled=!busy&&templateDate.isNotBlank()&&targetFor(t)!=null,onClick={
                            try{
                                val p=targetFor(t);val date=java.time.LocalDate.parse(templateDate).atStartOfDay().toInstant(rosterOffset)
                                val first=date.plusSeconds(t.getLong("start_minute")*60);val last=first.plusSeconds(t.getLong("duration_minutes")*60)
                                clear();selected=p;start=rosterDisplay(first.toString());end=rosterDisplay(last.toString());pause=t.getInt("break_minutes").toString();tolerance=t.getInt("tolerance_minutes").toString();repeat=if(t.getInt("repeat_count")==1)"once" else if(t.getInt("repeat_days")==7)"weekly" else "daily";repeatCount=t.getInt("repeat_count").toString();reason=t.getString("name")
                            }catch(_:Exception){error=true}
                        }){Text(tr("Utiliser le modèle","Use template","Huutoro leydi"))}
                        var archiveConfirm by remember(t.getString("id")){mutableStateOf(false)}
                        TextButton(enabled=!busy,onClick={archiveConfirm=true}){Text(tr("Archiver","Archive","Resnu"))}
                        if(archiveConfirm)AlertDialog(onDismissRequest={archiveConfirm=false},title={Text(tr("Archiver ce modèle ?","Archive this template?","Resnude ndee leydi?"))},confirmButton={TextButton(onClick={archiveConfirm=false;perform{
                            val r=JSONObject(StaffRosterApi.call(latest,"rpc/ns_archive_roster_template",JSONObject().put("p_id",t.getString("id"))));require(r.getString("id")==t.getString("id")&&r.getBoolean("archived"))
                        }}){Text(tr("Archiver","Archive","Resnu"))}},dismissButton={TextButton(onClick={archiveConfirm=false}){Text(tr("Annuler","Cancel","Haaytu"))}})
                    }
                }
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
                    if(edited==null&&cancelShift==null){
                        Text(tr("Répétition du service","Shift repetition","Ɓeydude golle"))
                        listOf("once" to tr("Une fois","Once","Laawol gootol"),"daily" to tr("Chaque jour","Daily","Ñalawma kala"),"weekly" to tr("Chaque semaine","Weekly","Yontere kala")).forEach{(value,label)->
                            OutlinedButton(enabled=!busy,onClick={repeat=value;repeatCount=if(value=="once")"1" else "2"}){Text((if(repeat==value)"✓ " else "")+label)}
                        }
                        if(repeat!="once")OutlinedTextField(repeatCount,{repeatCount=it},label={Text(tr("Nombre de services (2–31)","Number of shifts (2–31)","Limoore golle (2–31)"))},enabled=!busy,singleLine=true)
                    }
                    OutlinedTextField(reason,{reason=it},label={Text(tr("Motif","Reason","Sabu"))},modifier=Modifier.fillMaxWidth())
                    Button(onClick={publish(cancelShift)},enabled=!busy&&reason.isNotBlank()&&(selected!=null||cancelShift!=null)){Text(if(cancelShift!=null)tr("Confirmer l'annulation","Confirm cancellation","Tabbitin haaytugol") else tr("Publier et notifier","Publish and notify","Bayyin e tintin"))}
                    if(edited==null&&cancelShift==null&&selected!=null){
                        OutlinedTextField(templateName,{templateName=it.take(80)},label={Text(tr("Nom du modèle","Template name","Innde leydi"))},enabled=!busy,singleLine=true)
                        OutlinedButton(enabled=!busy&&templateName.isNotBlank()&&start.isNotBlank()&&end.isNotBlank(),onClick={perform{
                            val p=requireNotNull(selected);val first=Instant.parse(rosterInstant(start));val last=Instant.parse(rosterInstant(end));val local=first.atOffset(rosterOffset)
                            val body=JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId).put("p_post",p.nullable("workstation_id")?:JSONObject.NULL).put("p_member",p.getString("member_id")).put("p_name",templateName.trim()).put("p_start",local.hour*60+local.minute).put("p_duration",java.time.Duration.between(first,last).toMinutes()).put("p_break",pause.toInt()).put("p_tolerance",tolerance.toInt()).put("p_step",if(repeat=="weekly")7 else 1).put("p_count",if(repeat=="once")1 else repeatCount.toInt())
                            val id=extensionId("template",body);body.put("p_id",id)
                            val r=JSONObject(StaffRosterApi.call(latest,"rpc/ns_save_roster_template",body));require(r.getString("id")==id&&r.getBoolean("saved"));pendingExtensions.remove("template");templateName=""
                        }}){Text(tr("Enregistrer comme modèle","Save as template","Resnu leydi"))}
                    }
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
                    if(p!=null){
                        alerts.filter{it.optString("shift_id")==row.optString("id")&&it.optLong("revision")==row.optLong("revision")}.forEach{a->
                            if(a.optBoolean("unacknowledged_due"))Text(tr("Accusé en retard","Acknowledgement overdue","Jaɓgol leelii"),color=MaterialTheme.colorScheme.error)
                            if(a.optLong("appointment_conflicts")>0)Text(tr("Rendez-vous à réaffecter ou vérifier","Appointments to reassign or review","Ɗe njiillooje ƴeewtetee")+": "+a.optLong("appointment_conflicts"),color=MaterialTheme.colorScheme.error)
                        }
                        val substitutes=targets.filter{it.optString("member_id")!=row.optString("member_id")&&it.nullable("workstation_id")==row.nullable("workstation_id")}
                        if(row.optString("status")=="published"&&runCatching{Instant.parse(row.getString("starts_at")).isAfter(Instant.now())}.getOrDefault(false)&&substitutes.isNotEmpty())key(row.getString("id")){
                            var substitute by remember{mutableStateOf("")};var replacementReason by remember{mutableStateOf("")}
                            Text(tr("Remplaçant","Substitute","Lomtinɗo"))
                            substitutes.forEach{t->val id=t.getString("member_id");OutlinedButton(enabled=!busy,onClick={substitute=id}){Text((if(substitute==id)"✓ " else "")+t.getString("display_name"))}}
                            OutlinedTextField(replacementReason,{replacementReason=it.take(500)},label={Text(tr("Motif du remplacement","Replacement reason","Sabu lomtingol"))},enabled=!busy)
                            Button(enabled=!busy&&substitute.isNotBlank()&&replacementReason.isNotBlank(),onClick={perform{
                                val shift=row.getString("id");val body=JSONObject().put("p_shift",shift).put("p_revision",row.getLong("revision")).put("p_member",substitute).put("p_reason",replacementReason.trim());val id=extensionId("replacement:"+shift,body);body.put("p_new_shift",id)
                                val r=JSONObject(StaffRosterApi.call(latest,"rpc/ns_replace_roster_shift",body));require(r.getString("original_shift_id")==shift&&r.getString("replacement_shift_id")==id&&r.getBoolean("replaced"));pendingExtensions.remove("replacement:"+shift);replacementReason=""
                            }}){Text(tr("Remplacer le collaborateur","Replace employee","Lomtin gollotooɗo"))}
                        }
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
