package cm.naxa.naxaservices

import android.app.DatePickerDialog
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.findViewTreeLifecycleOwner
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import java.util.UUID

private data class BriefingWords(val title:String,val intro:String,val appointment:String,val completed:String,val revenue:String,val sales:String,val attendance:String,val missing:String,val play:String,val stop:String,val error:String)
private val briefingWords=mapOf(
 "fr" to BriefingWords("Mon bilan","Voici votre bilan partiel, établi à partir des données confirmées.","Rendez-vous","terminés","Chiffre d’affaires en francs CFA","ventes confirmées","Pointages personnels","Les autres indicateurs ne sont pas disponibles dans ce bilan.","Écouter mon bilan","Arrêter","Voix locale ou données indisponibles."),
 "en" to BriefingWords("My report","Here is your partial report based on confirmed records.","Appointments","completed","Revenue in CFA francs","confirmed sales","Personal clock events","Other indicators are not available in this report.","Listen to my report","Stop","Local voice or data unavailable."),
 "ff-CM" to BriefingWords("Jaŋtol am","Ɗoo ko jaŋtol maa ummoraade e humpito tabbitinaango.","Kawrital","timmuɗe","Ceede soodugol CFA","soodugol tabbitinaaɗo","Winndanɗe naatugol","Humpito goɗɗo heɓotaako e jaŋtol ngol.","Heɗo jaŋtol am","Dartin","Daande walla humpito heɓotaako."),
 "es" to BriefingWords("Mi informe","Este es tu informe parcial basado en datos confirmados.","Citas","completadas","Ingresos en francos CFA","ventas confirmadas","Registros personales de asistencia","Los demás indicadores no están disponibles en este informe.","Escuchar mi informe","Detener","Voz local o datos no disponibles."),
 "it" to BriefingWords("Il mio resoconto","Ecco il tuo resoconto parziale basato sui dati confermati.","Appuntamenti","completati","Ricavi in franchi CFA","vendite confermate","Registrazioni personali delle presenze","Gli altri indicatori non sono disponibili in questo resoconto.","Ascolta il mio resoconto","Interrompi","Voce locale o dati non disponibili."),
 "zh-CN" to BriefingWords("我的日报","这是根据已确认数据生成的部分报告。","预约","已完成","营业收入（非洲金融共同体法郎）","已确认销售","个人考勤记录","其他指标暂未包含在此报告中。","收听我的日报","停止","本地语音或数据不可用。"))
private val briefingLanguages=linkedMapOf("fr" to "Français","en" to "English","ff-CM" to "Fulfulde","es" to "Español","it" to "Italiano","zh-CN" to "中文")
internal fun briefingToday(now:Instant=Instant.now()):LocalDate=now.atZone(ZoneId.of("Africa/Douala")).toLocalDate()
internal fun briefingDateAllowed(date:LocalDate,today:LocalDate=briefingToday()):Boolean=!date.isAfter(today)&&!date.isBefore(today.minusDays(366))
private val briefingDateLabels=mapOf("fr" to "Date du bilan","en" to "Report date","ff-CM" to "Ñalnde jaŋtol","es" to "Fecha del informe","it" to "Data del resoconto","zh-CN" to "报告日期")
internal fun briefingCount(value:Any?):Long {
 require(value is Number)
 val n=value.toDouble()
 require(n.isFinite()&&n>=0&&n<=9007199254740991.0&&n%1.0==0.0)
 return n.toLong()
}
internal fun validateNativeBriefing(report:JSONObject,expectedDay:String) {
 require(report.opt("day")==expectedDay)
 require(report.opt("coverage")=="partial_confirmed_server_facts")
 require(report.opt("scope") in setOf("site","personal"))
 require(report.has("finance")&&report.has("personal_clock_events"))
 val generated=report.opt("generated_at") as? String ?: error("INVALID_BRIEFING")
 Instant.parse(generated)
 val a=report.getJSONObject("appointments")
 require(briefingCount(a.opt("completed_count"))<=briefingCount(a.opt("scheduled_count")))
 if(report.opt("scope")=="personal")require(report.isNull("finance"))
 if(!report.isNull("finance")){
  val f=report.getJSONObject("finance");briefingCount(f.opt("revenue_xaf"))
  require(briefingCount(f.opt("uncosted_sales_count"))<=briefingCount(f.opt("confirmed_sales_count")))
 }
 if(!report.isNull("personal_clock_events"))briefingCount(report.getJSONObject("personal_clock_events").opt("event_count"))
}
internal fun briefingText(report:JSONObject,language:String):String {
 val w=briefingWords.getValue(language)
 val appointments=report.getJSONObject("appointments")
 val finance=report.optJSONObject("finance")
 val attendance=report.optJSONObject("personal_clock_events")
 require(report.getString("coverage")=="partial_confirmed_server_facts")
 require(report.getString("scope") in setOf("site","personal"))
 require(report.getString("scope")!="personal"||finance==null)
 return buildString {
  append(w.intro).append(" ").append(report.getString("day")).append(". ")
  append(w.appointment).append(": ").append(briefingCount(appointments.opt("scheduled_count"))).append("; ").append(w.completed).append(": ").append(briefingCount(appointments.opt("completed_count"))).append(". ")
  if(finance!=null)append(w.revenue).append(": ").append(briefingCount(finance.opt("revenue_xaf"))).append("; ").append(w.sales).append(": ").append(briefingCount(finance.opt("confirmed_sales_count"))).append(". ")
  if(attendance!=null)append(w.attendance).append(": ").append(briefingCount(attendance.opt("event_count"))).append(". ")
  append(w.missing)
 }
}
internal fun nativeBriefingPeriod(rows:List<JSONObject>,end:LocalDate,days:Int):Map<String,Long?> {
 require(days in setOf(2,7,30)&&rows.size==days)
 rows.forEachIndexed{i,r->validateNativeBriefing(r,end.minusDays((days-1-i).toLong()).toString())}
 require(rows.all{it.getString("scope")==rows.first().getString("scope")})
 fun total(values:List<Long?>):Long? {
  if(values.any{it==null})return null
  return values.fold(0L){a,b->Math.addExact(a,b!!)}.also{require(it<=9007199254740991L)}
 }
 val site=rows.first().getString("scope")=="site"
 val metrics=linkedMapOf<String,Long?>("appointments" to total(rows.map{briefingCount(it.getJSONObject("appointments").opt("scheduled_count"))}),"completed" to total(rows.map{briefingCount(it.getJSONObject("appointments").opt("completed_count"))}))
 if(site)for((key,field) in listOf("revenue" to "revenue_xaf","sales" to "confirmed_sales_count","uncosted" to "uncosted_sales_count"))metrics[key]=total(rows.map{it.optJSONObject("finance")?.let{f->briefingCount(f.opt(field))}})
 metrics["clocks"]=total(rows.map{it.optJSONObject("personal_clock_events")?.let{p->briefingCount(p.opt("event_count"))}})
 return metrics
}
@Composable
internal fun DailyBriefingCard(session:AuthSession,siteId:String){
 if(!BuildConfig.BRIEFING_ENABLED||siteId.isBlank()||session.requirePasswordChange)return
 key(session.account.organizationId,session.account.memberId,session.deviceId,siteId){
  val context=LocalContext.current
  val latest by rememberUpdatedState(session)
  val scope=rememberCoroutineScope()
  val owner=LocalView.current.findViewTreeLifecycleOwner()
  var foreground by remember(owner){mutableStateOf(owner?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED)==true)}
  var loadJob by remember{mutableStateOf<Job?>(null)}
  var requestGeneration by remember{mutableStateOf(0)}
  var language by remember{mutableStateOf(session.account.defaultLocale.takeIf{it in briefingLanguages}?:"fr")}
  var date by remember{mutableStateOf(briefingToday())}
  var speed by remember{mutableStateOf(1f)}
  var engine by remember{mutableStateOf<TextToSpeech?>(null)}
  var ready by remember{mutableStateOf(false)}
  var playing by remember{mutableStateOf(false)}
  var activeUtterance by remember{mutableStateOf<String?>(null)}
  var paused by remember{mutableStateOf(false)}
  var spokenText by remember{mutableStateOf("")}
  var spokenOffset by remember{mutableStateOf(0)}
  var segmentBase by remember{mutableStateOf(0)}
  var busy by remember{mutableStateOf(false)}
  var error by remember{mutableStateOf(false)}
  var report by remember{mutableStateOf<JSONObject?>(null)}
  var periodDays by remember{mutableStateOf(7)}
  var period by remember{mutableStateOf<Map<String,Long?>?>(null)}
  var archiveIds by remember{mutableStateOf<List<Pair<String,String>>>(emptyList())}
  var reminderMode by remember{mutableStateOf("off")}
  var notice by remember{mutableStateOf(false)}
  val w=briefingWords.getValue(language)
  DisposableEffect(context){
   var disposed=false
   val handler=Handler(Looper.getMainLooper())
   val tts=TextToSpeech(context.applicationContext){status->handler.post{if(!disposed)ready=status==TextToSpeech.SUCCESS}}
   engine=tts
   tts.setOnUtteranceProgressListener(object:UtteranceProgressListener(){
    override fun onStart(utteranceId:String?){}
    override fun onRangeStart(utteranceId:String?,start:Int,end:Int,frame:Int){handler.post{if(!disposed&&activeUtterance==utteranceId)spokenOffset=(segmentBase+start).coerceIn(0,spokenText.length)}}
    override fun onDone(utteranceId:String?){handler.post{if(!disposed&&activeUtterance==utteranceId){activeUtterance=null;playing=false;paused=false;spokenOffset=0;spokenText=""}}}
    @Deprecated("Deprecated in Java") override fun onError(utteranceId:String?){handler.post{if(!disposed&&activeUtterance==utteranceId){activeUtterance=null;playing=false;error=true}}}
   })
   onDispose{disposed=true;tts.stop();tts.shutdown()}
  }
  fun stop(){activeUtterance=null;engine?.stop();playing=false;paused=false;spokenText="";spokenOffset=0;segmentBase=0}
  fun pause(){if(!playing)return;activeUtterance=null;engine?.stop();playing=false;paused=true}
  fun speakRemaining(){
   if(!foreground)return
   val tts=engine?:return
   segmentBase=spokenOffset.coerceIn(0,spokenText.length)
   if(segmentBase>=spokenText.length){stop();return}
   val id=UUID.randomUUID().toString();activeUtterance=id;paused=false
   playing=tts.speak(spokenText.substring(segmentBase),TextToSpeech.QUEUE_FLUSH,null,id)==TextToSpeech.SUCCESS
   if(!playing){activeUtterance=null;paused=true;error=true}else error=false
  }
  fun playText(text:String){
   val tts=engine
   if(!ready||tts==null){error=true;return}
   val wanted=Locale.forLanguageTag(language)
   val voice=tts.voices?.firstOrNull{!it.isNetworkConnectionRequired&&it.locale.language==wanted.language}
   if(voice==null){error=true;return}
   stop()
   if(tts.setVoice(voice)!=TextToSpeech.SUCCESS){error=true;return}
   tts.setSpeechRate(speed)
   spokenText=text;spokenOffset=0;speakRemaining()
  }
  fun load(andPlay:Boolean){
   if(!foreground||!briefingDateAllowed(date))return
   val requestedDay=date.toString()
   loadJob?.cancel();val generation=++requestGeneration
   stop();busy=true;error=false;report=null;period=null;archiveIds=emptyList();notice=false
   loadJob=scope.launch{
    try{
     val r=JSONObject(StaffRosterApi.call(latest,"rpc/ns_daily_briefing",JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId).put("p_day",requestedDay)))
     validateNativeBriefing(r,requestedDay)
     briefingText(r,language)
     if(!foreground||generation!=requestGeneration)return@launch
     report=r
     if(andPlay)playText(briefingText(r,language))
    }catch(c:CancellationException){throw c}catch(_:Exception){if(generation==requestGeneration&&foreground)error=true}finally{if(generation==requestGeneration)busy=false}
   }
  }
  fun label(fr:String,en:String,ff:String,es:String,it:String,zh:String)=when(language){"en"->en;"ff-CM"->ff;"es"->es;"it"->it;"zh-CN"->zh;else->fr}
  fun metricLabel(k:String)=when(k){"appointments"->w.appointment;"completed"->w.completed;"revenue"->w.revenue;"sales"->w.sales;"clocks"->w.attendance;else->label("Ventes sans coût","Uncosted sales","Jaaygol alaa njaru","Ventas sin coste","Vendite senza costo","未记录成本的销售")}
  fun periodAction(action:String,id:String?=null){
   if(!foreground||busy||!briefingDateAllowed(date))return
   val end=date;val days=periodDays;val generation=++requestGeneration
   loadJob?.cancel();stop();busy=true;error=false;notice=false
   loadJob=scope.launch{
    try{
     suspend fun rpc(name:String,body:JSONObject=JSONObject()):String=StaffRosterApi.call(latest,"rpc/"+name,body.put("p_org",latest.account.organizationId).put("p_site",siteId))
     fun current()=foreground&&generation==requestGeneration
     when(action){
      "load"->{val start=end.minusDays((days-1).toLong());require(briefingDateAllowed(start));val rows=(0 until days).map{i->JSONObject(rpc("ns_daily_briefing",JSONObject().put("p_day",start.plusDays(i.toLong()).toString())))};val result=nativeBriefingPeriod(rows,end,days);if(current())period=result}
      "save"->{require(period!=null&&end.isBefore(briefingToday()));val receipt=JSONObject(rpc("ns_archive_briefing",JSONObject().put("p_id",UUID.randomUUID().toString()).put("p_start",end.minusDays((days-1).toLong()).toString()).put("p_end",end.toString())));UUID.fromString(receipt.getString("id"));if(current())notice=true}
      "list"->{val rows=JSONArray(rpc("ns_list_briefing_archives"));require(rows.length()<=100);val result=(0 until rows.length()).map{i->val r=rows.getJSONObject(i);val rid=r.getString("id");UUID.fromString(rid);val a=LocalDate.parse(r.getString("period_start"));val b=LocalDate.parse(r.getString("period_end"));require(!a.isAfter(b));rid to "$a — $b"};if(current())archiveIds=result}
      "open"->{val r=JSONObject(rpc("ns_read_briefing_archive",JSONObject().put("p_id",id)));require(r.getString("id")==id);val rows=r.getJSONArray("snapshot");val ending=LocalDate.parse(r.getString("period_end"));val values=(0 until rows.length()).map{rows.getJSONObject(it)};require(values.all{it.getString("scope")==r.getString("scope")});val result=nativeBriefingPeriod(values,ending,rows.length());if(current()){period=null;report=null;playText(result.entries.joinToString(". "){(k,v)->metricLabel(k)+": "+(v?.toString()?:w.error)});notice=true}}
      "reminder"->{val result=JSONObject(rpc("ns_set_briefing_reminder",JSONObject().put("p_mode",reminderMode)));require(result.getString("mode")==reminderMode);if(current())notice=true}
     }
    }catch(c:CancellationException){throw c}catch(_:Exception){if(foreground&&generation==requestGeneration){period=null;archiveIds=emptyList();error=true}}finally{if(generation==requestGeneration)busy=false}
   }
  }
  DisposableEffect(owner){
   val observer=LifecycleEventObserver{_,event->
    when(event){
     Lifecycle.Event.ON_RESUME->foreground=true
     Lifecycle.Event.ON_PAUSE,Lifecycle.Event.ON_STOP->{foreground=false;requestGeneration++;loadJob?.cancel();loadJob=null;stop();report=null;period=null;archiveIds=emptyList();notice=false;busy=false;error=false}
     else->Unit
    }
   }
   owner?.lifecycle?.addObserver(observer)
   onDispose{owner?.lifecycle?.removeObserver(observer);loadJob?.cancel()}
  }
  Card(Modifier.fillMaxWidth()){
   Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
    Text(w.title,style=MaterialTheme.typography.titleLarge)
    OutlinedButton(onClick={
     val today=briefingToday()
     val selected=if(briefingDateAllowed(date,today))date else today
     val dialog=DatePickerDialog(context,{_,year,month,day->
      val chosen=LocalDate.of(year,month+1,day)
      if(foreground&&briefingDateAllowed(chosen)){
       requestGeneration++;loadJob?.cancel();loadJob=null;stop();report=null;period=null;archiveIds=emptyList();notice=false;busy=false;error=false;date=chosen
      }
     },selected.year,selected.monthValue-1,selected.dayOfMonth)
     val zone=ZoneId.systemDefault()
     dialog.datePicker.minDate=today.minusDays(366).atStartOfDay(zone).toInstant().toEpochMilli()
     dialog.datePicker.maxDate=today.atStartOfDay(zone).toInstant().toEpochMilli()
     dialog.show()
    },enabled=foreground){Text(briefingDateLabels.getValue(language)+": "+date.toString())}
    briefingLanguages.forEach{(code,label)->OutlinedButton(onClick={stop();language=code;error=false},enabled=!busy){Text((if(code==language)"✓ " else "")+label)}}
    Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){
     listOf(.8f,1f,1.2f,1.5f).forEach{s->TextButton(onClick={stop();speed=s},enabled=!busy){Text((if(s==speed)"✓ " else "")+s+"×")}}
    }
    Button(onClick={when{playing->pause();paused->speakRemaining();else->load(true)}},enabled=!busy&&briefingDateAllowed(date)){Text(if(playing)when(language){"en"->"Pause";"ff-CM"->"Fowtu";"es"->"Pausar";"it"->"Pausa";"zh-CN"->"暂停";else->"Pause"}else if(paused)when(language){"en"->"Resume";"ff-CM"->"Jokku";"es"->"Reanudar";"it"->"Riprendi";"zh-CN"->"继续";else->"Reprendre"}else w.play)}
    if(playing||paused)OutlinedButton(onClick={stop()},enabled=!busy){Text(w.stop)}
    OutlinedButton(onClick={load(false)},enabled=!busy&&briefingDateAllowed(date)){Text(when(language){"en"->"Refresh";"ff-CM"->"Hesɗitin";"es"->"Actualizar";"it"->"Aggiorna";"zh-CN"->"刷新";else->"Actualiser"})}
    if(error)Text(w.error,color=MaterialTheme.colorScheme.error)
    report?.let{Text(briefingText(it,language))}
    HorizontalDivider()
    Text(label("Bilan par période","Period report","Jaŋtol sahaa","Informe por período","Resoconto per periodo","期间报告"),style=MaterialTheme.typography.titleMedium)
    Row{listOf(2,7,30).forEach{d->TextButton(onClick={stop();periodDays=d;period=null},enabled=!busy&&foreground){Text((if(d==periodDays)"✓ " else "")+d.toString())}}}
    OutlinedButton(onClick={periodAction("load")},enabled=!busy&&foreground){Text(label("Calculer la période","Calculate period","Lim sahaa","Calcular período","Calcola periodo","计算期间"))}
    period?.forEach{(k,v)->TextButton(onClick={playText(metricLabel(k)+": "+v)},enabled=!busy&&foreground&&v!=null){Text(metricLabel(k)+": "+(v?.toString()?:w.error))}}
    OutlinedButton(onClick={periodAction("save")},enabled=!busy&&foreground&&period!=null&&date.isBefore(briefingToday())){Text(label("Archiver","Archive","Resnu","Archivar","Archivia","归档"))}
    OutlinedButton(onClick={periodAction("list")},enabled=!busy&&foreground){Text(label("Charger les archives","Load archives","Loow rese","Cargar archivos","Carica archivio","加载档案"))}
    archiveIds.forEach{(id,title)->TextButton(onClick={periodAction("open",id)},enabled=!busy&&foreground){Text(title)}}
    Text(label("Rappel du bilan","Report reminder","Tintinol jaŋtol","Recordatorio","Promemoria","报告提醒"))
    Row{listOf("off","daily","weekly").forEach{m->TextButton(onClick={reminderMode=m;notice=false},enabled=!busy&&foreground){Text((if(reminderMode==m)"✓ " else "")+when(m){"daily"->label("Jour","Day","Ñalnde","Día","Giorno","日");"weekly"->label("Semaine","Week","Yontere","Semana","Settimana","周");else->label("Arrêt","Off","Ñifti","No","No","关闭")})}}}
    OutlinedButton(onClick={periodAction("reminder")},enabled=!busy&&foreground){Text(label("Enregistrer le rappel","Save reminder","Resnu tintinol","Guardar recordatorio","Salva promemoria","保存提醒"))}
    if(notice)Text(label("Action confirmée","Action confirmed","Kuugal tabbitii","Acción confirmada","Azione confermata","操作已确认"))
   }
  }
 }
}
