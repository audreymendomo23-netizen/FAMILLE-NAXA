package cm.naxa.bootik
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
@Composable fun BootikCashPanel(api:BootikApi,session:BootikSession,site:String){
 val scope=rememberCoroutineScope();val manager=session.role!="staff"
 var acts by remember{mutableStateOf<List<JSONObject>>(emptyList())};var act by remember{mutableStateOf("")};var registers by remember{mutableStateOf<List<JSONObject>>(emptyList())};var sessions by remember{mutableStateOf<List<JSONObject>>(emptyList())};var items by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var reg by remember{mutableStateOf("")};var sid by remember{mutableStateOf("")};var code by remember{mutableStateOf("")};var name by remember{mutableStateOf("")};var opening by remember{mutableStateOf("0")};var query by remember{mutableStateOf("")};var item by remember{mutableStateOf("")};var qty by remember{mutableStateOf("1")};var basket by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var tender by remember{mutableStateOf("")};var movement by remember{mutableStateOf("expense")};var amount by remember{mutableStateOf("")};var reason by remember{mutableStateOf("")};var counted by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 val pending=remember{mutableMapOf<String,Pair<String,String>>()}
 fun rows(a:JSONArray)=(0 until a.length()).map{a.getJSONObject(it)}
 suspend fun call(a:String,p:JSONObject)=api.operation(session,site,a,p)
 fun task(f:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{f()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération non confirmée. Vérifiez les droits et la connexion."}finally{busy=false}}}
 suspend fun refresh(){val v=call("cash-state",JSONObject().put("activity_id",act));registers=rows(v.getJSONArray("registers"));sessions=rows(v.getJSONArray("sessions"))}
 suspend fun mutate(kind:String,p:JSONObject):JSONObject{p.put("activity_id",act).put("kind",kind);val fp=p.toString();val old=pending[kind];val id=if(old?.first==fp)old.second else UUID.randomUUID().toString().also{pending[kind]=fp to it};p.put("request_id",id);val result=call("cash-action",p);val field=when(kind){"register"->"register_id";"open","close"->"session_id";"checkout"->"checkout_id";else->"movement_id"};check(result.getString(field)==if(kind=="close")p.getString("session_id") else id);pending.remove(kind);message="Opération caisse confirmée.";try{refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){registers=emptyList();sessions=emptyList();sid="";message="Opération confirmée ; rechargez les caisses."};return result}
 fun money(x:String)=x.toLongOrNull()?.let{it>=0}==true
 val chosen=sessions.find{it.getString("id")==sid&&it.isNull("closed_at")};val selected=items.find{it.getString("item_id")==item};val total=basket.sumOf{it.getDouble("quantity")*it.getDouble("unit_price_fcfa")}
 Text("Caisse connectée et panier",style=MaterialTheme.typography.titleMedium);Text("Espèces uniquement. Les ventes stock non rattachées ne sont pas des encaissements de caisse.")
 Button(enabled=!busy,onClick={task{acts=rows(call("activities",JSONObject()).getJSONArray("activities"))}}){Text("Charger les activités caisse")}
 acts.forEach{x->Row{RadioButton(act==x.getString("id"),{act=x.getString("id");registers=emptyList();sessions=emptyList();items=emptyList();reg="";sid="";item="";basket=emptyList()},enabled=!busy);Text(x.getString("display_name"))}}
 Button(enabled=!busy&&act.isNotBlank(),onClick={task{refresh();items=rows(api.fetchCatalog(session,site)).filter{it.optString("activity_id")==act&&!it.optBoolean("is_serialized")}.distinctBy{it.getString("item_id")}}}){Text("Charger les caisses et articles")}
 if(manager){OutlinedTextField(code,{code=it},label={Text("Code caisse")},enabled=!busy);OutlinedTextField(name,{name=it},label={Text("Nom caisse")},enabled=!busy);Button(enabled=!busy&&act.isNotBlank()&&code.isNotBlank()&&name.isNotBlank(),onClick={task{mutate("register",JSONObject().put("code",code).put("name",name));code="";name=""}}){Text("Créer la caisse")}}
 registers.forEach{x->Row{RadioButton(reg==x.getString("id"),{reg=x.getString("id")},enabled=!busy&&!x.getBoolean("occupied"));Text(x.getString("name")+if(x.getBoolean("occupied"))" — ouverte" else "")}}
 OutlinedTextField(opening,{opening=it},label={Text("Fonds initial FCFA")},enabled=!busy);Button(enabled=!busy&&reg.isNotBlank()&&money(opening),onClick={task{sid=mutate("open",JSONObject().put("register_id",reg).put("opening_float_fcfa",opening.toLong())).getString("session_id")}}){Text("Ouvrir la caisse")}
 sessions.filter{it.isNull("closed_at")}.forEach{x->Row{RadioButton(sid==x.getString("id"),{sid=x.getString("id");basket=emptyList()},enabled=!busy);Text(x.getString("register_name")+if(x.getBoolean("own"))" — Ma session" else " — Autre opérateur")}}
 chosen?.let{Text("Solde théorique espèces : "+it.getString("theoretical_fcfa")+" FCFA")}
 OutlinedTextField(query,{query=it},label={Text("Recherche article panier")},enabled=!busy)
 items.filter{BootikCatalogSearch.matches(it.getString("display_name")+" "+it.optString("sku")+" "+it.optString("barcode"),query)}.take(100).forEach{x->Row{RadioButton(item==x.getString("item_id"),{item=x.getString("item_id")},enabled=!busy);Text(x.getString("display_name")+" — "+x.getString("unit_price_fcfa")+" FCFA")}}
 OutlinedTextField(qty,{qty=it},label={Text("Quantité panier (unité de base)")},enabled=!busy)
 Button(enabled=!busy&&chosen?.optBoolean("own")==true&&selected!=null&&qty.toDoubleOrNull()?.let{it.isFinite()&&it>0}==true&&basket.size<20&&basket.none{it.getString("item_id")==item},onClick={selected?.let{basket=basket+JSONObject().put("item_id",item).put("unit_code",it.getString("base_unit_code")).put("quantity",qty.toDouble()).put("unit_price_fcfa",it.getLong("unit_price_fcfa")).put("name",it.getString("display_name"))}}){Text("Ajouter au panier caisse")}
 basket.forEach{x->Row{Text(x.getString("name")+" × "+x.getString("quantity"));TextButton(enabled=!busy,onClick={basket=basket.filterNot{it.getString("item_id")==x.getString("item_id")}}){Text("Retirer du panier")}}}
 Text("Montant panier : $total FCFA")
 OutlinedTextField(tender,{tender=it},label={Text("Espèces remises FCFA")},enabled=!busy)
 Button(enabled=!busy&&chosen?.optBoolean("own")==true&&basket.isNotEmpty()&&money(tender)&&(tender.toDoubleOrNull()?:0.0)>=total,onClick={task{val lines=JSONArray();basket.forEach{x->lines.put(JSONObject(x.toString()).apply{remove("name")})};val x=mutate("checkout",JSONObject().put("session_id",sid).put("lines",lines).put("tender_fcfa",tender.toLong()));basket=emptyList();tender="";message="Vente caisse confirmée. Monnaie à rendre : "+x.getString("change_fcfa")+" FCFA • reçu "+x.getString("checkout_id")}}){Text("Valider le panier espèces")}
 if(manager){
 listOf("expense" to "Dépense","in" to "Entrée","out" to "Sortie").forEach{(k,l)->Row{RadioButton(movement==k,{movement=k},enabled=!busy);Text(l)}}
 OutlinedTextField(amount,{amount=it},label={Text("Montant mouvement caisse FCFA")},enabled=!busy);OutlinedTextField(reason,{reason=it},label={Text("Motif mouvement ou écart caisse")},enabled=!busy)
 Button(enabled=!busy&&chosen!=null&&money(amount)&&(amount.toLongOrNull()?:0)>0&&reason.trim().length>=3,onClick={task{mutate("movement",JSONObject().put("session_id",sid).put("movement_kind",movement).put("amount_fcfa",amount.toLong()).put("reason",reason));amount="";reason=""}}){Text("Enregistrer le mouvement caisse")}
 OutlinedTextField(counted,{counted=it},label={Text("Espèces comptées à la clôture FCFA")},enabled=!busy)
 Button(enabled=!busy&&chosen!=null&&money(counted),onClick={task{val x=mutate("close",JSONObject().put("session_id",sid).put("counted_close_fcfa",counted.toLong()).put("reason",reason));sid="";basket=emptyList();reason="";message="Caisse clôturée. Écart : "+x.getString("variance_fcfa")+" FCFA"}}){Text("Clôturer la caisse")}
 };Text(message)
}
