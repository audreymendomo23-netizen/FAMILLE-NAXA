package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
private fun asrRows(x:JSONObject,k:String):List<JSONObject>{val a=x.getJSONArray(k);return (0 until a.length()).map{a.getJSONObject(it)}}
private fun stamp(ms:Long)= "%02d:%02d".format(java.util.Locale.ROOT,ms/60000,ms/1000%60)
@Composable fun TranscriptionPanel(english:Boolean,gateway:RoomGateway,session:Session,roomId:String?=null,onDraft:((String)->Unit)?=null,onArchives:(()->Unit)?=null){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope()
 var rooms by remember{mutableStateOf<List<JSONObject>>(emptyList())};var room by remember{mutableStateOf(roomId)};var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var selected by remember{mutableStateOf<JSONObject?>(null)}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)}
 var uncertainOnly by remember(room,selected?.optString("recording_id")){mutableStateOf(false)};var localQuery by remember(room,selected?.optString("recording_id")){mutableStateOf("")}
 var query by remember(room,selected?.optString("recording_id")){mutableStateOf("")};var hits by remember(room,selected?.optString("recording_id")){mutableStateOf<JSONObject?>(null)};var chosen by remember(room,selected?.optString("recording_id"),session.accessToken){mutableStateOf<Set<Int>>(emptySet())};var speakerIndex by remember(room,selected?.optString("recording_id")){mutableStateOf<Int?>(null)};var speakerNumber by remember(room,selected?.optString("recording_id")){mutableIntStateOf(0)}
 suspend fun req(action:String,data:JSONObject)=gateway.request("transcription",JSONObject().put("action",action).put("data",data),session) as JSONObject
 suspend fun list(id:String){try{items=asrRows(req("list",JSONObject().put("room_id",id)),"items");selected?.let{v->if(items.none{it.optString("recording_id")==v.optString("recording_id")&&it.optString("status")==v.optString("status")})selected=null}}catch(e:CancellationException){throw e}catch(e:Exception){items=emptyList();selected=null;throw e}}
 suspend fun open(id:String){room=id;selected=null;items=emptyList();list(id)}
 suspend fun load(){if(roomId!=null)open(roomId)else rooms=asrRows(gateway.request("minutes",JSONObject().put("action","list").put("data",JSONObject()),session) as JSONObject,"items").filter{it.optBoolean("can_manage")&&it.optBoolean("premium")}}
 suspend fun action(kind:String,id:String){val rid=room?:return;try{selected=req(kind,JSONObject().put("room_id",rid).put("recording_id",id));list(rid)}catch(e:CancellationException){throw e}catch(e:Exception){selected=null;items=emptyList();throw e}}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;hits=null;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){selected=null;items=emptyList();rooms=emptyList();error=true}finally{busy=false}}}
 LaunchedEffect(roomId,session.deviceId){work{load()}}
 LaunchedEffect(room,selected?.optString("recording_id"),selected?.optString("status"),busy){val rid=room?:return@LaunchedEffect;val id=selected?.optString("recording_id")?:return@LaunchedEffect;if(busy||selected?.optString("status") !in setOf("queued","running"))return@LaunchedEffect;while(true){delay(5000);if(busy||room!=rid||selected?.optString("recording_id")!=id)return@LaunchedEffect;try{val v=req("read",JSONObject().put("room_id",rid).put("recording_id",id));if(!busy&&room==rid){selected=v;items=items.map{if(it.optString("recording_id")==id)JSONObject(it.toString()).put("status",v.optString("status")).put("attempts",v.optInt("attempts"))else it}};if(v.optString("status") !in setOf("queued","running"))return@LaunchedEffect}catch(e:CancellationException){throw e}catch(e:Exception){selected=null;items=emptyList();error=true;return@LaunchedEffect}}}
 fun status(s:String)=when(s){"not_requested"->tr("Non demandé","Not requested");"queued"->tr("En attente","Queued");"running"->tr("En cours","Processing");"complete"->tr("À relire","Review needed");"failed"->tr("Échec","Failed");else->tr("État indisponible","Status unavailable")}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Transcription des enregistrements","Recording transcription"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Traitement local et horodatage. Relisez les résultats ; locuteurs non identifiés. Aucune publication automatique.","Local processing and timestamps. Review results; speakers unidentified. No automatic publication."))
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error)Text(tr("Service indisponible ou accès non autorisé.","Service unavailable or access denied."),color=MaterialTheme.colorScheme.error)
 val rid=room
 if(rid==null){TextButton(enabled=!busy,onClick={work{load()}}){Text(tr("Actualiser","Refresh"))};for(x in rooms)TextButton(enabled=!busy,onClick={work{open(x.getString("room_id"))}}){Text(x.getString("title"))};if(!busy&&rooms.isEmpty())Text(tr("Aucun enregistrement de réunion Premium accessible.","No accessible Premium meeting recording."))}
 else{if(roomId==null)TextButton(enabled=!busy,onClick={room=null;selected=null;items=emptyList()}){Text(tr("Retour aux réunions","Back to meetings"))};TextButton(enabled=!busy,onClick={work{list(rid)}}){Text(tr("Actualiser","Refresh"))}
 for(x in items){Text(x.getString("finished_at")+" · "+status(x.getString("status")));TextButton(enabled=!busy,onClick={work{action(if(x.optString("status")=="not_requested")"request" else "read",x.getString("recording_id"))}}){Text(if(x.optString("status")=="not_requested")tr("Demander la transcription","Request transcription")else tr("Consulter","View"))}}
 if(!busy&&items.isEmpty())Text(tr("Aucun segment audio conservé.","No retained audio segments."))
 selected?.let{v->Text(status(v.optString("status")));if(v.optString("status")=="failed"&&v.optInt("attempts")<3)Button(enabled=!busy,onClick={work{action("retry",v.getString("recording_id"))}}){Text(tr("Relancer","Retry"))}
 v.optJSONObject("result")?.let{result->Text(tr("Langue détectée","Detected language")+": "+(when(result.optString("language").lowercase()){"fr"->tr("Français","French");"en"->tr("Anglais","English");"ff"->tr("Fulfulde","Fulfulde");"es"->tr("Espagnol","Spanish");"it"->tr("Italien","Italian");"zh"->tr("Mandarin","Mandarin");"wes"->tr("Pidgin camerounais","Cameroonian Pidgin");"ewo"->tr("Ewondo","Ewondo");"dua"->tr("Duala","Duala");"bas"->tr("Basaa","Basaa");"bbj"->tr("Ghomala’","Ghomala’");"bum"->tr("Bulu","Bulu");"bax"->tr("Bamoun","Bamoun");"ybb"->tr("Yemba","Yemba");"mhk"->tr("Mungaka","Mungaka");"ar"->tr("Arabe","Arabic");"pt"->tr("Portugais","Portuguese");"de"->tr("Allemand","German");else->tr("Langue indéterminée","Unknown language")}));val captions=result.optJSONObject("captions")?.takeIf{it.optString("recording_id")==v.optString("recording_id")};val segments=if(captions!=null)asrRows(captions,"cues")else asrRows(result,"segments");Text(tr("Transcription originale (hors direct)","Original transcript (not live)"));val lines=segments.map{s->"["+stamp(s.getLong("start_ms"))+"–"+stamp(s.getLong("end_ms"))+"] "+s.getString("text")+(if(s.optBoolean("uncertain"))" "+tr("[incertain]","[uncertain]")else "")};fun annotationFor(index:Int,events:List<JSONObject>)=events.filter{it.optInt("segment_index",-1)==index}.maxByOrNull{it.optInt("revision")}
 fun speakerLabel(n:Int)=if(n>0)tr("Locuteur anonyme ","Anonymous speaker ")+n else tr("Locuteur inconnu","Unknown speaker")
 val annotations=asrRows(result,"speaker_annotations")
 val sourceSelection=chosen.intersect(segments.mapIndexed{i,s->s.optInt("segment_index",i)}.toSet())
 Text(tr("Attribution manuelle anonyme : aucun nom ni identité déduite par l’IA.","Anonymous manual assignment: no names or AI-inferred identity."))
 OutlinedTextField(localQuery,{localQuery=it.take(100)},label={Text(tr("Filtrer les segments affichés","Filter visible segments"))});Row{Checkbox(uncertainOnly,{uncertainOnly=it});Text(tr("Segments à vérifier uniquement","Only segments to check"))}
 for(i in lines.indices){if((uncertainOnly&&!segments[i].optBoolean("uncertain"))||!segments[i].optString("text").contains(localQuery.trim(),ignoreCase=true))continue;val index=segments[i].optInt("segment_index",i);val annotation=annotationFor(index,annotations);Text(speakerLabel(annotation?.optInt("speaker_number")?:0)+(if(annotation!=null)" · "+tr("Corrigé manuellement","Manually reviewed") else ""));Text(lines[i]);if(onDraft!=null)Row{Checkbox(checked=index in sourceSelection,enabled=!busy&&(index in sourceSelection||sourceSelection.size<10),onCheckedChange={checked->chosen=if(checked)chosen+index else chosen-index});Text(tr("Inclure dans le brouillon","Include in draft"))};TextButton(enabled=!busy,onClick={speakerIndex=index;speakerNumber=annotation?.optInt("speaker_number")?:0}){Text(tr("Annoter le locuteur","Annotate speaker"))};if(speakerIndex==index){for(n in 0..10)Row{RadioButton(selected=speakerNumber==n,enabled=!busy,onClick={speakerNumber=n});Text(speakerLabel(n))};Button(enabled=!busy,onClick={work{val value=speakerNumber;val ack=req("speaker-review",JSONObject().put("room_id",rid).put("recording_id",v.getString("recording_id")).put("segment_index",index).put("speaker_number",value).put("expected_revision",annotation?.optInt("revision")?:0).put("event_id",java.util.UUID.randomUUID().toString()));check(ack.getBoolean("saved")&&ack.getJSONObject("event").getInt("speaker_number")==value);action("read",v.getString("recording_id"));speakerIndex=null}}){Text(tr("Enregistrer l’annotation","Save annotation"))};TextButton(enabled=!busy,onClick={speakerIndex=null}){Text(tr("Annuler","Cancel"))}}}

 OutlinedTextField(value=query,onValueChange={if(it.length<=120){query=it;hits=null}},enabled=!busy,label={Text(tr("Rechercher dans cette transcription","Search this transcript"))})
 Button(enabled=!busy&&query.trim().length>=2,onClick={work{val response=req("search",JSONObject().put("room_id",rid).put("recording_id",v.getString("recording_id")).put("query",query.trim()));check(response.getString("recording_id")==v.getString("recording_id"));hits=response}}){Text(tr("Rechercher","Search"))}
 hits?.takeIf{it.optString("recording_id")==v.optString("recording_id")}?.let{h->val matches=asrRows(h,"matches");Text(matches.size.toString()+" "+tr("extraits correspondants","matching excerpts"));for(x in matches)Text("["+stamp(x.getLong("start_ms"))+"–"+stamp(x.getLong("end_ms"))+"] "+x.getString("text")+(if(x.optBoolean("uncertain"))" "+tr("[incertain]","[uncertain]")else ""))}

 val review=result.optJSONObject("review")?.takeIf{it.optString("recording_id")==v.optString("recording_id")};if(review!=null){
 fun sourceLine(x:JSONObject)="["+stamp(x.getLong("start_ms"))+"–"+stamp(x.getLong("end_ms"))+"] "+x.getString("text")+(if(x.optBoolean("uncertain"))" "+tr("[incertain]","[uncertain]")else "")
 val excerpts=asrRows(review,"excerpts").map(::sourceLine);val candidates=asrRows(review,"decision_candidates").map(::sourceLine)
 Text(tr("Extraits sourcés à vérifier","Source excerpts to review"),style=MaterialTheme.typography.titleSmall)
 Text(tr("Extraits de la transcription. Vérifiez les décisions avant validation.","Transcript excerpts. Review decisions before approval."))
 for(line in excerpts)Text(line)
 Text(tr("Suggestions de décisions et d’actions","Suggested decisions and actions"),style=MaterialTheme.typography.titleSmall)
 val none=tr("Aucune suggestion disponible.","No suggestions available.")
 for(line in candidates)Text(line);if(candidates.isEmpty())Text(none)
 val reviewDraft=tr("Extraits sourcés à vérifier — ","Source excerpts to review — ")+v.optString("recording_id")+"\n"+excerpts.joinToString("\n")+"\n\n"+tr("Suggestions de décisions et d’actions (à valider)","Suggested decisions and actions (pending approval)")+"\n"+(if(candidates.isEmpty())none else candidates.joinToString("\n"))
 if(onDraft!=null){
 val reviewChoices=(asrRows(review,"excerpts")+asrRows(review,"decision_candidates")).distinctBy{it.getInt("segment_index")}.sortedBy{it.getInt("segment_index")}
 val selection=sourceSelection
 Text(tr("Sélectionner les extraits pour le brouillon","Select excerpts for draft"));Text(selection.size.toString()+"/10 · "+tr("Sélectionnez aussi tout segment original ci-dessus.","You can also select any original segment above."))
 for(x in reviewChoices){val index=x.getInt("segment_index");Row{Checkbox(checked=index in selection,enabled=!busy&&(index in selection||selection.size<10),onCheckedChange={checked->chosen=if(checked)chosen+index else chosen-index});Text(sourceLine(x))}}
 Button(enabled=!busy&&selection.isNotEmpty(),onClick={work{val rec=v.getString("recording_id");val response=req("draft-review",JSONObject().put("room_id",rid).put("recording_id",rec).put("indices",org.json.JSONArray(selection.sorted())));check(response.getString("recording_id")==rec&&response.optString("method")=="selected-source-review-v1"&&!response.getBoolean("approved"));val rows=asrRows(response,"items");check(rows.map{it.getInt("segment_index")}==selection.sorted());val body=tr("Extraits sélectionnés à vérifier — ","Selected excerpts to verify — ")+rec+"\n"+rows.joinToString("\n"){x->val a=annotationFor(x.getInt("segment_index"),asrRows(response,"speaker_annotations"));(if(a!=null)speakerLabel(a.getInt("speaker_number"))+" ("+tr("corrigé manuellement","manually reviewed")+") : " else "")+sourceLine(x)};check(body.length<=8000);onDraft(body)}}){Text(tr("Insérer la sélection vérifiée","Insert verified selection"))}
 }
 if(onDraft!=null&&excerpts.isNotEmpty())Button(enabled=!busy&&reviewDraft.length<=8000,onClick={onDraft(reviewDraft)}){Text(tr("Insérer la revue sourcée dans le brouillon","Insert source review into draft"))}
 };if(lines.isEmpty())Text(tr("Aucune parole détectée.","No speech detected."));val draft=tr("Extraits de transcription à vérifier — segment ","Transcript excerpts to verify — segment ")+v.optString("recording_id")+"\n"+lines.joinToString("\n");if(onDraft!=null&&lines.isNotEmpty())Button(enabled=!busy&&draft.length<=8000,onClick={onDraft(draft)}){Text(tr("Insérer les extraits dans le brouillon","Insert excerpts into draft"))}}
 }}
 if(onArchives!=null)TextButton(onClick=onArchives){Text(tr("Ouvrir les comptes rendus","Open minutes"))}
 }}
}
