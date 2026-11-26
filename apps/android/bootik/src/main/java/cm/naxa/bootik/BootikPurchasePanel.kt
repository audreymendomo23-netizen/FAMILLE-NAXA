package cm.naxa.bootik
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
@Composable fun BootikPurchasePanel(api:BootikApi,session:BootikSession,site:String,activity:String){
 val scope=rememberCoroutineScope()
 var suppliers by remember{mutableStateOf<List<JSONObject>>(emptyList())};var items by remember{mutableStateOf<List<JSONObject>>(emptyList())};var orders by remember{mutableStateOf<List<JSONObject>>(emptyList())}
 var supplier by remember{mutableStateOf("")};var balance by remember{mutableStateOf("")};var ref by remember{mutableStateOf("")};var qty by remember{mutableStateOf("1")};var cost by remember{mutableStateOf("")}
 var order by remember{mutableStateOf("")};var received by remember{mutableStateOf("")};var freight by remember{mutableStateOf("0")};var amount by remember{mutableStateOf("")};var method by remember{mutableStateOf("bank")};var payRef by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 val pending=remember{mutableMapOf<String,Pair<String,String>>()}
 fun rows(a:JSONArray)=(0 until a.length()).map{a.getJSONObject(it)}
 suspend fun call(action:String,p:JSONObject)=api.operation(session,site,action,p)
 suspend fun refresh(){orders=rows(call("purchases",JSONObject().put("activity_id",activity)).getJSONArray("orders"))}
 fun task(f:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{f()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message=e.message?.takeIf{it.startsWith("APPROVAL:")}?.removePrefix("APPROVAL:")?:"Opération non confirmée. Vérifiez les droits et la connexion."}finally{busy=false}}}
 suspend fun commit(action:String,key:String,field:String,p:JSONObject){val fp=p.toString();val old=pending[key];val id=if(old?.first==fp)old.second else UUID.randomUUID().toString().also{pending[key]=fp to it};p.put(field,id);val result=call(action,p);if(result.has("approval_state")){val refused=result.optString("approval_state")=="refused";if(refused)pending.remove(key);error("APPROVAL:"+if(refused)"Approbation refusée." else "Demande soumise. Réessayez avec les mêmes données après validation.")};check(result.getString(field)==id);pending.remove(key);message="Opération confirmée par le serveur.";try{refresh()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){orders=emptyList();order="";message="Opération confirmée ; rechargez la liste des achats."}}
 fun positive(s:String)=s.toDoubleOrNull()?.let{it.isFinite()&&it>0}==true
 fun money(s:String)=s.toLongOrNull()?.let{it>=0}==true
 val chosen=orders.find{it.getString("id")==order}
 Text("Achats et dettes fournisseurs",style=MaterialTheme.typography.titleMedium)
 Text("Commande par référence. Règlement externe enregistré uniquement.")
 Button(enabled=!busy,onClick={task{suppliers=rows(call("partners",JSONObject().put("activity_id",activity)).getJSONArray("suppliers"));items=rows(api.fetchCatalog(session,site)).filter{it.optString("activity_id")==activity&&!it.optBoolean("is_serialized")};refresh()}}){Text("Charger les achats")}
 suppliers.forEach{x->Row{RadioButton(supplier==x.getString("id"),{supplier=x.getString("id")},enabled=!busy);Text(x.getString("display_name"))}}
 var query by remember{mutableStateOf("")};var page by remember{mutableStateOf(0)}
 OutlinedTextField(query,{query=it;page=0},label={Text("Rechercher article à commander")},enabled=!busy)
 val matches=items.filter{BootikCatalogSearch.matches(it.optString("display_name")+" "+it.optString("sku"),query)}
 Row{TextButton(enabled=page>0&&!busy,onClick={page--}){Text("Précédent achats")};TextButton(enabled=(page+1)*50<matches.size&&!busy,onClick={page++}){Text("Suivant achats")}}
 matches.drop(page*50).take(50).forEach{x->Row{RadioButton(balance==x.getString("balance_id"),{balance=x.getString("balance_id")},enabled=!busy);Text(x.getString("display_name")+" "+x.optString("lot_code",""))}}
 OutlinedTextField(ref,{ref=it},label={Text("Référence d’achat")},enabled=!busy)
 OutlinedTextField(qty,{qty=it},label={Text("Quantité commandée")},enabled=!busy)
 OutlinedTextField(cost,{cost=it},label={Text("Coût unitaire fournisseur FCFA")},enabled=!busy)
 Button(enabled=!busy&&supplier.isNotBlank()&&balance.isNotBlank()&&ref.trim().length>=3&&positive(qty)&&money(cost),onClick={task{commit("purchase-create","create","order_id",JSONObject().put("supplier_id",supplier).put("balance_id",balance).put("reference",ref.trim()).put("quantity",qty.toDouble()).put("unit_cost_fcfa",cost.toLong()))}}){Text("Créer la commande fournisseur")}
 orders.forEach{x->Row{RadioButton(order==x.getString("id"),{order=x.getString("id")},enabled=!busy);Text(x.getString("reference")+" • "+x.getString("supplier_name")+" • "+x.getString("item_name"))}}
 chosen?.let{Text("Reçu "+it.getString("received_quantity")+"/"+it.getString("quantity")+" • Dette "+it.getString("payable_fcfa")+" FCFA")}
 OutlinedTextField(received,{received=it},label={Text("Quantité réception achat")},enabled=!busy)
 OutlinedTextField(freight,{freight=it},label={Text("Frais attribuables FCFA")},enabled=!busy)
 Button(enabled=!busy&&chosen!=null&&positive(received)&&money(freight)&&(received.toDoubleOrNull()?:0.0)<=chosen.getDouble("quantity")-chosen.getDouble("received_quantity"),onClick={task{commit("purchase-receive","receive","receipt_id",JSONObject().put("order_id",order).put("quantity",received.toDouble()).put("freight_fcfa",freight.toLong()));received=""}}){Text("Confirmer la réception fournisseur")}
 OutlinedTextField(amount,{amount=it},label={Text("Règlement fournisseur FCFA")},enabled=!busy)
 listOf("bank" to "Banque","cash" to "Espèces","mobile_money" to "Mobile Money externe").forEach{(k,l)->Row{RadioButton(method==k,{method=k},enabled=!busy);Text(l)}}
 OutlinedTextField(payRef,{payRef=it},label={Text("Référence règlement")},enabled=!busy)
 Button(enabled=!busy&&chosen!=null&&money(amount)&&(amount.toLongOrNull()?:0L)>0&&(amount.toDoubleOrNull()?:0.0)<=chosen.getDouble("payable_fcfa")&&payRef.trim().length>=3,onClick={task{commit("purchase-pay","pay","payment_id",JSONObject().put("order_id",order).put("amount_fcfa",amount.toLong()).put("method",method).put("reference",payRef.trim()));amount="";payRef=""}}){Text("Enregistrer le règlement effectué")}
 Text(message)
}
