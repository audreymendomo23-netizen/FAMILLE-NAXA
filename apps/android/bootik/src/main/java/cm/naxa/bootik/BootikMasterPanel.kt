package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
@Composable fun BootikMasterPanel(api:BootikApi,session:BootikSession,site:String){
 val scope=rememberCoroutineScope()
 var activities by remember{mutableStateOf<List<Pair<String,String>>>(emptyList())};var activity by remember{mutableStateOf("")}
 var kind by remember{mutableStateOf("item")};var name by remember{mutableStateOf("")};var sku by remember{mutableStateOf("")};var unit by remember{mutableStateOf("unit")};var price by remember{mutableStateOf("")};var barcode by remember{mutableStateOf("")}
 var phone by remember{mutableStateOf("")};var email by remember{mutableStateOf("")};var whatsapp by remember{mutableStateOf("")};var terms by remember{mutableStateOf("0")}
 var partners by remember{mutableStateOf<List<String>>(emptyList())};var dashboard by remember{mutableStateOf("")};var message by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)}
 var lot by remember{mutableStateOf("")};var expiry by remember{mutableStateOf("")};var location by remember{mutableStateOf("")};var minimum by remember{mutableStateOf("0")};var target by remember{mutableStateOf("0")}
 var pending by remember{mutableStateOf<Pair<String,String>?>(null)}
 fun task(block:suspend()->Unit){if(busy)return;busy=true;message="";scope.launch{try{block()}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération non confirmée. Vérifiez les droits et la connexion."}finally{busy=false}}}
 Text("Catalogue et tiers",style=MaterialTheme.typography.titleMedium)
 Button(enabled=!busy,onClick={task{val rows=api.operation(session,site,"activities",JSONObject()).getJSONArray("activities");activities=(0 until rows.length()).map{val j=rows.getJSONObject(it);j.getString("id") to (j.getString("display_name")+" • "+j.getString("profile_code"))};activity="";partners=emptyList()}}){Text("Charger les activités autorisées")}
 activities.forEach{(id,label)->Row{RadioButton(activity==id,{activity=id;partners=emptyList()},enabled=!busy);Text(label)}}
 listOf("item" to "Article standard","customer" to "Client","supplier" to "Fournisseur").forEach{(id,label)->Row{RadioButton(kind==id,{kind=id},enabled=!busy);Text(label)}}
 OutlinedTextField(name,{name=it},label={Text("Nom")},enabled=!busy,singleLine=true)
 if(kind=="item"){
  OutlinedTextField(sku,{sku=it},label={Text("SKU")},enabled=!busy,singleLine=true)
  OutlinedTextField(unit,{unit=it},label={Text("Unité")},enabled=!busy,singleLine=true)
  OutlinedTextField(price,{price=it},label={Text("Prix FCFA")},enabled=!busy,singleLine=true)
  OutlinedTextField(barcode,{barcode=it},label={Text("Code-barres")},enabled=!busy,singleLine=true)
  OutlinedTextField(lot,{lot=it},label={Text("Lot initial")},enabled=!busy,singleLine=true)
  OutlinedTextField(expiry,{expiry=it},label={Text("Péremption AAAA-MM-JJ")},enabled=!busy,singleLine=true)
  OutlinedTextField(location,{location=it},label={Text("Emplacement initial")},enabled=!busy,singleLine=true)
  OutlinedTextField(minimum,{minimum=it},label={Text("Seuil minimum")},enabled=!busy,singleLine=true)
  OutlinedTextField(target,{target=it},label={Text("Stock cible")},enabled=!busy,singleLine=true)
  Text("Stock initial nul. Articles sérialisés : parcours dédié requis.")
 }else{
  OutlinedTextField(phone,{phone=it},label={Text("Téléphone")},enabled=!busy,singleLine=true)
  OutlinedTextField(email,{email=it},label={Text("E-mail")},enabled=!busy,singleLine=true)
  if(kind=="supplier"){OutlinedTextField(whatsapp,{whatsapp=it},label={Text("WhatsApp")},enabled=!busy,singleLine=true);OutlinedTextField(terms,{terms=it},label={Text("Délai de paiement (jours)")},enabled=!busy,singleLine=true)}
 }
 Button(enabled=!busy&&activity.isNotBlank()&&name.isNotBlank()&&(kind!="item"||(sku.isNotBlank()&&unit.isNotBlank()&&(price.toLongOrNull()?:-1L)>=0)),onClick={task{
  val p=JSONObject().put("activity_id",activity).put("kind",kind).put("name",name).put("sku",sku).put("unit",unit).put("price_fcfa",price.toLongOrNull()?:-1L).put("barcode",barcode).put("phone",phone).put("email",email).put("whatsapp",whatsapp).put("terms_days",terms.toIntOrNull()?:-1).put("lot_code",lot).put("expiry",expiry).put("location",location).put("minimum_quantity",minimum.toDoubleOrNull()?:-1.0).put("target_quantity",target.toDoubleOrNull()?:-1.0)
  val fp=p.toString();if(pending?.first!=fp)pending=fp to UUID.randomUUID().toString();p.put("request_id",pending!!.second)
  check(api.operation(session,site,"master-create",p).getString("entity_id").isNotBlank());pending=null;name="";sku="";price="";barcode="";phone="";email="";whatsapp="";lot="";expiry="";location="";minimum="0";target="0";partners=emptyList();message="Fiche confirmée par le serveur. Actualisez le catalogue ou les tiers."
 }}){Text("Enregistrer la fiche")}
 Button(enabled=!busy&&activity.isNotBlank(),onClick={task{val v=api.operation(session,site,"partners",JSONObject().put("activity_id",activity));partners=listOf("customers" to "Client","suppliers" to "Fournisseur").flatMap{(k,label)->val a=v.getJSONArray(k);(0 until a.length()).map{val j=a.getJSONObject(it);label+" • "+j.getString("display_name")+" • "+j.optString("phone","—")}}}}){Text("Afficher clients et fournisseurs")}
 partners.forEach{Text(it)}
 if(activity.isNotBlank())key(activity){BootikStockImportPanel(api,session,site,activity)}
 Text("Ventes du jour (Douala)",style=MaterialTheme.typography.titleMedium)
 Button(enabled=!busy,onClick={task{val d=api.operation(session,site,"dashboard",JSONObject());dashboard=d.getString("sales_count")+" ventes unitaires • "+d.getString("revenue_fcfa")+" FCFA de ventes confirmées (pas un total de caisse)"}}){Text("Actualiser les indicateurs")}
 Text(dashboard);Text(message)
}
