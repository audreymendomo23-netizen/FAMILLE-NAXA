package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

@Composable fun BootikBusinessPanel(api:BootikApi,session:BootikSession,site:String,activity:String){
 val scope=rememberCoroutineScope()
 var days by remember{mutableStateOf(7)};var overview by remember{mutableStateOf<JSONObject?>(null)}
 var tasks by remember{mutableStateOf<JSONObject?>(null)};var partners by remember{mutableStateOf<List<Triple<String,String,String>>>(emptyList())}
 var partner by remember{mutableStateOf<Pair<String,String>?>(null)};var due by remember{mutableStateOf("")};var note by remember{mutableStateOf("")}
 var pending by remember{mutableStateOf<Pair<String,String>?>(null)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 suspend fun call(action:String,p:JSONObject=JSONObject())=api.operation(session,site,action,p.put("activity_id",activity))
 fun run(block:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération non confirmée. Vérifiez vos droits ou réessayez."}finally{busy=false}}}
 suspend fun send(data:JSONObject){val fp=data.toString();if(pending?.first!=fp)pending=fp to UUID.randomUUID().toString();val id=pending!!.second
  check(call("followup-action",data.put("request_id",id)).getString("event_id")==id);pending=null;message="Suivi CRM confirmé."
  try{tasks=call("followup-list")}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){tasks=null;message="Suivi CRM confirmé. Actualisez la liste."}
 }
 Text("Pilotage métier par activité",style=MaterialTheme.typography.titleMedium)
 Row{listOf(1,7,30).forEach{d->Row{RadioButton(days==d,{days=d;overview=null},enabled=!busy);Text("$d j")}}}
 Button(enabled=!busy,onClick={run{overview=call("business-overview",JSONObject().put("days",days))}}){Text("Actualiser le pilotage métier")}
 overview?.let{o->
  Text(if(o.getString("universe")=="retailer")"Détaillants" else "Distributeurs")
  Text("Ventes enregistrées : "+o.getString("revenue_fcfa")+" FCFA · "+o.getString("sales_lines")+" lignes")
  Text("Marge brute : "+(if(o.isNull("gross_margin_fcfa"))"Indéterminée (coûts manquants)" else o.getString("gross_margin_fcfa")+" FCFA")+" — hors charges et retours non raccordés")
  Text("Commandes ouvertes : "+o.getString("open_purchase_orders")+" · Dette fournisseurs : "+o.getString("supplier_payable_fcfa")+" FCFA")
  Text("Alertes stock : "+o.getString("low_stock_count")+" (200 premières au maximum)")
  val a=o.getJSONArray("replenishment");for(i in 0 until a.length()){val x=a.getJSONObject(i);Text(x.getString("name")+" · disponible "+x.getString("available")+" "+x.getString("unit")+" · commandes ouvertes "+x.getString("open_purchase_quantity")+" · suggestion "+x.getString("suggested_quantity"))}
  Text("Suggestion indicative. Aucun achat transmis automatiquement.")
 }
 Text("Agenda CRM — clients et fournisseurs",style=MaterialTheme.typography.titleMedium)
 Button(enabled=!busy,onClick={run{val a=call("partners");val t=call("followup-list");partners=listOf("customers" to "customer","suppliers" to "supplier").flatMap{(k,kind)->val rows=a.getJSONArray(k);(0 until rows.length()).map{val x=rows.getJSONObject(it);Triple(kind,x.getString("id"),x.getString("display_name"))}};tasks=t}}){Text("Charger le suivi CRM")}
 partners.forEach{(kind,id,label)->Row{RadioButton(partner==(kind to id),{partner=kind to id},enabled=!busy);Text((if(kind=="customer")"Client : " else "Fournisseur : ")+label)}}
 OutlinedTextField(due,{due=it},label={Text("Échéance du suivi AAAA-MM-JJ")},enabled=!busy,singleLine=true)
 OutlinedTextField(note,{if(it.length<=500)note=it},label={Text("Objet du suivi")},enabled=!busy)
 Button(enabled=!busy&&partner!=null&&due.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}"))&&note.trim().length>=3,onClick={run{val p=partner?:return@run;send(JSONObject().put("kind","create").put("partner_kind",p.first).put("partner_id",p.second).put("due_date",due).put("note",note.trim()));note=""}}){Text("Planifier le suivi CRM")}
 tasks?.let{t->Text(t.getString("total")+" suivi(s) — 200 premiers au maximum");val a=t.getJSONArray("items");for(i in 0 until a.length()){val x=a.getJSONObject(i);val id=x.getString("id");key(id){var outcome by remember{mutableStateOf("")};val state=x.getString("state");Text(x.optString("partner_name","Tiers")+" · "+x.getString("due_date")+" · "+(when(state){"completed"->"Terminé";"overdue"->"En retard";else->"À faire"})+" · "+x.getString("note"))
 if(state=="completed")Text("Résultat : "+x.optString("outcome")) else{OutlinedTextField(outcome,{if(it.length<=500)outcome=it},label={Text("Résultat du suivi")},enabled=!busy);Button(enabled=!busy&&outcome.trim().length>=3,onClick={run{send(JSONObject().put("kind","complete").put("task_id",id).put("note",outcome.trim()))}}){Text("Clôturer le suivi CRM")}}}}}
 Text(message);Text("Agenda interne : aucun SMS, WhatsApp ni encaissement déclenché.")
}
