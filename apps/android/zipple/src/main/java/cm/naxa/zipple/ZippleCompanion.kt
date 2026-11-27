package cm.naxa.zipple
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import org.json.JSONObject
import java.time.LocalDate
import java.text.Normalizer

private fun localTopic(q:String):String?{
 val s=Normalizer.normalize(q,Normalizer.Form.NFD).replace(Regex("\\p{M}+"),"").lowercase()
 if(s.length>300||Regex("\\b(modifier|supprimer|payer|effacer|annuler|delete|change|pay|cancel|ignore|password|secret|token|mot de passe)\\b").containsMatchIn(s))return null
 return listOf("group" to "multisite|multi.site|groupe|group|consolidation|consolide","cash" to "caisse|cash|encaissements?|collections?","feedback" to "avis|satisfaction|feedback|reviews?","stock" to "stocks?|ruptures?|inventory","credit" to "creances?|ardoises?|debt|receivables?","margin" to "marges?|margin|profit|couts?|costs?","sales" to "ventes?|sales|revenu|revenue|chiffre d.affaires|ca").filter{Regex("\\b("+it.second+")\\b").containsMatchIn(s)}.singleOrNull()?.first
}
@Composable internal fun ZippleCompanion(api:ZippleBusiness,session:Session,site:String,en:Boolean,data:Map<String,JSONObject>,today:LocalDate,mode:String){
 val t:(String,String)->String={fr,eng->if(en)eng else fr};val scope=rememberCoroutineScope();val context=LocalContext.current
 var question by remember{mutableStateOf("")};var from by remember{mutableStateOf(today.toString())};var to by remember{mutableStateOf(today.toString())};var result by remember{mutableStateOf<List<String>>(emptyList())};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 var speech by remember{mutableStateOf<SpeechRecognizer?>(null)};var listening by remember{mutableStateOf(false)}
 DisposableEffect(Unit){onDispose{speech?.destroy()}}
 fun startSpeech(){if(Build.VERSION.SDK_INT<31||!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)){message=t("Dictée locale indisponible.","Local dictation unavailable.");return}
 try{speech?.destroy();val r=SpeechRecognizer.createOnDeviceSpeechRecognizer(context);speech=r;r.setRecognitionListener(object:RecognitionListener{
 override fun onReadyForSpeech(p:Bundle?){};override fun onBeginningOfSpeech(){};override fun onRmsChanged(v:Float){};override fun onBufferReceived(v:ByteArray?){};override fun onEndOfSpeech(){}
 override fun onError(e:Int){listening=false;message=t("Dictée locale indisponible.","Local dictation unavailable.")}
 override fun onResults(v:Bundle?){listening=false;question=v?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.take(300).orEmpty();result=emptyList()}
 override fun onPartialResults(v:Bundle?){};override fun onEvent(e:Int,b:Bundle?){}
 });listening=true;r.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM).putExtra(RecognizerIntent.EXTRA_LANGUAGE,if(en)"en-US" else "fr-FR").putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE,true).putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,1))
 }catch(_:Exception){listening=false;message=t("Dictée locale indisponible.","Local dictation unavailable.")}}
 val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){if(it)startSpeech()else message=t("Microphone refusé.","Microphone denied.")}
 val m=data[mode];Text(t("Feedback Intelligence — motifs des avis","Feedback Intelligence — review reasons"),style=MaterialTheme.typography.titleMedium)
 Text((m?.optString("feedback_count")?:"—")+" "+t("avis sur la période","reviews in period")+" · "+(m?.optString("feedback_average")?:"—")+"/5")
 val reasons=mapOf("wait" to t("Attente","Wait"),"accuracy" to t("Exactitude","Accuracy"),"quality" to t("Qualité","Quality"),"temperature" to t("Température","Temperature"),"presentation" to t("Présentation","Presentation"),"welcome" to t("Accueil","Welcome"),"other" to t("Autre","Other"))
 if(m?.optJSONArray("feedback_reasons")==null)Text(t("Motifs indisponibles.","Reasons unavailable."))else if(m.rows("feedback_reasons").isEmpty())Text(t("Aucun motif enregistré.","No recorded reasons."))else m.rows("feedback_reasons").sortedByDescending{it.optInt("count")}.forEach{r->reasons[r.optString("reason")]?.let{Text(it+" : "+r.optInt("count"))}}
 Text(t("Pas de classement si moins de 10 avis, ni analyse des commentaires personnels.","No ranking below 10 reviews, no analysis of personal comments."))
 Text(t("Business Companion — assistant de pilotage","Business Companion — business assistant"),style=MaterialTheme.typography.titleMedium)
 Text(t("Assistant local à règles : ventes, caisse, marge, stock, créances, avis ou groupe. Lecture seule.","Local rule-based assistant: sales, cash, margin, stock, receivables, reviews or group. Read only."))
 OutlinedTextField(question,{question=it.take(300);result=emptyList()},enabled=!busy,label={Text(t("Question métier","Business question"))},modifier=Modifier.fillMaxWidth())
 OutlinedButton(enabled=!listening&&!busy,onClick={if(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)startSpeech()else permission.launch(Manifest.permission.RECORD_AUDIO)}){Text(t("Dicter localement","Dictate locally"))}
 OutlinedTextField(from,{from=it.take(10);result=emptyList()},enabled=!busy,label={Text(t("Période assistant — début","Assistant period — start"))});OutlinedTextField(to,{to=it.take(10);result=emptyList()},enabled=!busy,label={Text(t("Période assistant — fin","Assistant period — end"))})
 val valid=runCatching{val f=LocalDate.parse(from);val e=LocalDate.parse(to);f<=e&&e<=today&&e.toEpochDay()-f.toEpochDay()<=365}.getOrDefault(false)
 Button(enabled=valid&&!busy&&question.isNotBlank()&&session.permits(site),onClick={val topic=localTopic(question);if(topic==null){result=emptyList();message=t("Question non reconnue ou ambiguë.","Unknown or ambiguous question.")}else{busy=true;message="";result=emptyList();scope.launch{try{
 val action=when(topic){"group"->"ledger_group_statement";"credit"->"credit_snapshot";else->"pilotage"};val body=when(topic){"group"->JSONObject().put("from",from).put("to",to);"credit"->JSONObject();else->JSONObject().put("start",from).put("end",to)}
 val x=api.call(session,site,action,body) as? JSONObject?:error("DATA")
 val fields=when(topic){"sales"->listOf("recorded_xaf","refunds_xaf","credit_notes_xaf","receipts");"cash"->listOf("collected_xaf","absolute_cash_variance_xaf");"margin"->listOf("known_cost_xaf","gross_margin_xaf","uncosted_receipts","expenses_xaf");"stock"->listOf("current_low_stock");"feedback"->listOf("feedback_count","feedback_average");"group"->listOf("sites_included","sites_total","revenue_xaf","expenses_xaf","result_xaf","unclassified","pending_sources","unknown_cost_receipts");else->emptyList()}
 val names=mapOf("recorded_xaf" to t("Ventes brutes","Gross sales"),"refunds_xaf" to t("Remboursements","Refunds"),"credit_notes_xaf" to t("Avoirs","Credit notes"),"receipts" to t("Reçus","Receipts"),"collected_xaf" to t("Encaissements","Collections"),"absolute_cash_variance_xaf" to t("Écarts de caisse","Cash variances"),"known_cost_xaf" to t("Coût connu","Known cost"),"gross_margin_xaf" to t("Marge brute connue","Known gross margin"),"uncosted_receipts" to t("Reçus sans coût","Uncosted receipts"),"expenses_xaf" to t("Charges","Expenses"),"current_low_stock" to t("Matières au seuil","Ingredients at threshold"),"feedback_count" to t("Avis","Reviews"),"feedback_average" to t("Note moyenne","Average rating"),"sites_included" to t("Sites inclus","Included sites"),"sites_total" to t("Sites totaux","Total sites"),"revenue_xaf" to t("Produits comptables","Accounting revenue"),"result_xaf" to t("Résultat comptable","Accounting result"),"unclassified" to t("Non classés","Unclassified"),"pending_sources" to t("Sources en attente","Pending sources"),"unknown_cost_receipts" to t("Reçus sans coût","Unknown cost receipts"))
 val period=if(topic in listOf("stock","credit"))today.toString() else "$from — $to"
 result=listOf((if(topic=="group")t("Périmètre comptable autorisé ; consolidation potentiellement incomplète","Authorized accounting scope; consolidation may be incomplete")else t("Établissement courant","Current site"))+" · "+period,t("Source","Source")+" : "+action)+(if(topic=="credit"){val rows=x.rows("sales").filter{it.optLong("balance_xaf")>0&&runCatching{LocalDate.parse(it.optString("due_on"))}.isSuccess};listOf(t("Créances dues aujourd’hui","Receivables due today")+" : "+rows.filter{it.optString("due_on")==today.toString()}.sumOf{it.optLong("balance_xaf")}+" FCFA",t("Créances en retard","Overdue receivables")+" : "+rows.filter{it.optString("due_on")<today.toString()}.sumOf{it.optLong("balance_xaf")}+" FCFA")}else fields.map{k->(names[k]?:k)+" : "+if(x.isNull(k))"—" else x.optString(k)+(if(k.endsWith("_xaf"))" FCFA" else "")})
 }catch(c:CancellationException){throw c}catch(_:Exception){message=t("Source indisponible ou non autorisée.","Source unavailable or unauthorized.")}finally{busy=false}}}}){Text(t("Interroger ZIPPLE","Ask ZIPPLE"))}
 if(message.isNotBlank())Text(message);result.forEach{Text(it)}
 ZippleDocumentIntake(api,session,site,en,today)
}
@Composable private fun ZippleDocumentIntake(api:ZippleBusiness,session:Session,site:String,en:Boolean,today:LocalDate){
 val t:(String,String)->String={fr,eng->if(en)eng else fr};val context=LocalContext.current;val scope=rememberCoroutineScope();val keys=remember{RequestKeys()}
 var raw by remember{mutableStateOf("")};var label by remember{mutableStateOf("")};var amount by remember{mutableStateOf("")};var reference by remember{mutableStateOf("")};var date by remember{mutableStateOf(today.toString())};var category by remember{mutableStateOf("other")};var method by remember{mutableStateOf("")};var confirmed by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var msg by remember{mutableStateOf("")}
 fun extract(value:String){raw=value.take(12000);confirmed=false;val lines=raw.lines().map{it.trim()}
 val totals=lines.mapNotNull{Regex("^(?:TOTAL\\s*(?:TTC|A PAYER|À PAYER)?|NET\\s*(?:A|À)\\s*PAYER|AMOUNT\\s*DUE|GRAND\\s*TOTAL)\\s*[:=]?\\s*([\\d][\\d .\\u00a0\\u202f]*)(?:\\s*(?:FCFA|XAF|F CFA))?\\s*$",RegexOption.IGNORE_CASE).matchEntire(it)?.groupValues?.get(1)?.trim()?.takeUnless{v->Regex("\\.\\d{1,2}$").containsMatchIn(v)}?.replace(Regex("[ .\\u00a0\\u202f]"),"")?.toLongOrNull()?.takeIf{n->n in 1..2147483647L}}.distinct()
 amount=totals.singleOrNull()?.toString().orEmpty();reference=lines.mapNotNull{Regex("^(?:FACTURE|INVOICE|BON|REFERENCE|RÉFÉRENCE|REF)\\s*(?:N[°ºo.]?\\s*)?[:#]?\\s*([A-Z0-9][A-Z0-9/_-]{3,79})$",RegexOption.IGNORE_CASE).matchEntire(it)?.groupValues?.get(1)}.distinct().singleOrNull().orEmpty()
 date=lines.mapNotNull{Regex("^DATE\\s*[:]?\\s*(\\d{4}-\\d{2}-\\d{2})$",RegexOption.IGNORE_CASE).matchEntire(it)?.groupValues?.get(1)?.takeIf{v->runCatching{LocalDate.parse(v)}.isSuccess}}.distinct().singleOrNull().orEmpty();msg=if(totals.size>1)t("Plusieurs totaux détectés : contrôle manuel requis.","Several totals found: manual review required.")else ""}
 val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null&&!busy){busy=true;msg="";scope.launch{try{
 val bitmap=withContext(Dispatchers.IO){val bytes=context.contentResolver.openInputStream(uri)?.use{it.readNBytes(5000001)}?:error("FILE");require(bytes.size<=5000000);val opts=BitmapFactory.Options().apply{inJustDecodeBounds=true};BitmapFactory.decodeByteArray(bytes,0,bytes.size,opts);require(opts.outWidth>0&&opts.outHeight>0&&opts.outWidth.toLong()*opts.outHeight<=16000000);BitmapFactory.decodeByteArray(bytes,0,bytes.size)?:error("IMAGE")}
 val recognizer=TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);try{val value=suspendCancellableCoroutine<String>{c->recognizer.process(InputImage.fromBitmap(bitmap,0)).addOnSuccessListener{if(c.isActive)c.resume(it.text)}.addOnFailureListener{if(c.isActive)c.resumeWithException(it)}};extract(value)}finally{recognizer.close();bitmap.recycle()}
 }catch(c:CancellationException){throw c}catch(_:Exception){msg=t("OCR indisponible ou image illisible. Saisie manuelle possible.","OCR unavailable or unreadable image. Manual entry available.")}finally{busy=false}}}}
 Text(t("OCR — préparer une dépense","OCR — prepare an expense"),style=MaterialTheme.typography.titleMedium);Text(t("JPG/PNG local ; PDF à convertir en image. Aucun envoi de l’image ou du texte brut.","Local JPG/PNG; convert PDF to image. No image or raw text upload."))
 OutlinedButton(enabled=!busy,onClick={picker.launch(arrayOf("image/jpeg","image/png"))}){Text(t("Image de facture","Invoice image"))}
 OutlinedTextField(raw,{raw=it.take(12000);confirmed=false},enabled=!busy,label={Text(t("Texte extrait à contrôler","Extracted text to review"))},modifier=Modifier.fillMaxWidth());OutlinedButton(enabled=!busy,onClick={extract(raw)}){Text(t("Extraire les champs","Extract fields"))}
 OutlinedTextField(label,{label=it.take(160);confirmed=false},enabled=!busy,label={Text(t("Libellé de dépense","Expense label"))});OutlinedTextField(amount,{amount=it.take(10);confirmed=false},enabled=!busy,label={Text(t("Montant extrait FCFA","Extracted amount XAF"))});OutlinedTextField(reference,{reference=it.take(160);confirmed=false},enabled=!busy,label={Text(t("Référence extraite","Extracted reference"))});OutlinedTextField(date,{date=it.take(10);confirmed=false},enabled=!busy,label={Text(t("Date extraite","Extracted date"))})
 var catOpen by remember{mutableStateOf(false)};var methodOpen by remember{mutableStateOf(false)}
 Box{OutlinedButton(enabled=!busy,onClick={catOpen=true}){Text(t("Catégorie de dépense","Expense category")+" : "+category)};DropdownMenu(catOpen,{catOpen=false}){listOf("rent","utilities","transport","staff","maintenance","other").forEach{x->DropdownMenuItem(text={Text(x)},onClick={category=x;confirmed=false;catOpen=false})}}}
 Box{OutlinedButton(enabled=!busy,onClick={methodOpen=true}){Text(t("Moyen de règlement constaté","Observed payment method")+" : "+method.ifBlank{"—"})};DropdownMenu(methodOpen,{methodOpen=false}){listOf("cash","mtn_momo","orange_money","bank","card").forEach{x->DropdownMenuItem(text={Text(x)},onClick={method=x;confirmed=false;methodOpen=false})}}}
 Row{Checkbox(confirmed,{confirmed=it},enabled=!busy);Text(t("J’ai vérifié la pièce et tous les champs.","I verified the document and all fields."))}
 val valid=confirmed&&label.isNotBlank()&&reference.trim().length>=4&&amount.toLongOrNull()?.let{it in 1..2147483647L}==true&&method.isNotBlank()&&runCatching{LocalDate.parse(date)<=today}.getOrDefault(false)
 Button(enabled=valid&&!busy&&session.permits(site),onClick={busy=true;msg="";scope.launch{try{val body=JSONObject().put("label",label.trim()).put("amount_xaf",amount.toLong()).put("reference",reference.trim()).put("expense_date",date).put("category",category).put("method",method);api.call(session,site,"expense_submit",keys.apply("ocr_expense",body));keys.confirmed("ocr_expense");raw="";label="";amount="";reference="";date=today.toString();method="";confirmed=false;msg=t("Dépense soumise à validation. Aucun paiement effectué.","Expense submitted for approval. No payment made.")}catch(c:CancellationException){throw c}catch(_:Exception){msg=t("Soumission non confirmée. Réessayer sans modifier les champs.","Submission unconfirmed. Retry without changing fields.")}finally{busy=false}}}){Text(t("Soumettre la dépense extraite","Submit extracted expense"))}
 if(msg.isNotBlank())Text(msg)
}
