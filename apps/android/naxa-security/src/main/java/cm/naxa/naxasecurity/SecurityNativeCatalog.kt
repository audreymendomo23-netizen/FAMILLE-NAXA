package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID
private val catalogKinds=mapOf("B5.02" to "customer","B5.03" to "customer","B5.04" to "contract","B5.05" to "team","B5.06" to "team","B5.14" to "asset","B5.15" to "asset","B5.19" to "asset","B5.20" to "part","B5.21" to "partner","B5.22" to "partner","B5.23" to "partner","B5.24" to "contract","B4.21" to "access_profile","B4.22" to "access_profile")
@Composable internal fun SecurityNativeCatalog(screen:String){
 val kind=catalogKinds[screen]?:return;val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope()
 var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var fields by remember(screen,g){mutableStateOf<Map<String,String>>(emptyMap())};var selected by remember(screen,g){mutableStateOf("")};var status by remember(screen,g){mutableStateOf("")};var busy by remember(screen,g){mutableStateOf(false)};var pending by remember(screen,g){mutableStateOf<Pair<String,String>?>(null)}
 val keys=listOf("label","reference")+when(kind){"contract"->listOf("parent_id","valid_from","valid_until","amount_fcfa");"team"->listOf("member_id");"asset"->listOf("device_id","valid_from","valid_until");"partner"->listOf("valid_from","valid_until");"part"->listOf("minimum");else->emptyList()}
 val labels=mapOf("label" to "Libellé","reference" to "Référence","parent_id" to "Identifiant client","member_id" to "Identifiant collaborateur","device_id" to "Identifiant appareil","valid_from" to "Début AAAA-MM-JJ","valid_until" to "Fin AAAA-MM-JJ","amount_fcfa" to "Montant FCFA","minimum" to "Seuil de stock","delta" to "Quantité signée","reason" to "Motif")
 fun act(op:String){if(busy)return;busy=true;scope.launch{try{val p=JSONObject();if(op=="create"){p.put("kind",kind);keys.forEach{k->val v=fields[k]?.trim().orEmpty();if(v.isNotEmpty())p.put(k,if(k in setOf("amount_fcfa","minimum"))v.toLong() else v)}}else if(op=="stock_move"){p.put("delta",fields.getValue("delta").toLong());p.put("reason",fields["reason"])};val target=if(op=="create")null else selected;val sig=op+target+p.toString();val id=pending?.takeIf{it.first==sig}?.second?:UUID.randomUUID().toString();pending=sig to id
 val v=SecurityNativeApi.catalogAction(s,site,id,op,target,p);check(v.optString("kind")==kind);if(n.generation==g){pending=null;rows=emptyList();selected="";status="Opération métier confirmée : "+v.optString("state")+" — actualisez."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Opération refusée ou non confirmée."}finally{if(n.generation==g)busy=false}}}
 Text("Registre métier : "+kind);Text("Gestion administrative, sans autorisation physique.")
 Button(enabled=!busy,onClick={busy=true;scope.launch{try{val a=SecurityNativeApi.records(s,site,"sec_business_catalog");if(n.generation==g){rows=a.filter{it.optString("kind")==kind};status="Registre métier chargé."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){rows=emptyList();status="Lecture refusée."}}finally{if(n.generation==g)busy=false}}}){Text("Actualiser le registre métier")}
 rows.forEach{r->Text(r.optString("label")+" · "+r.optString("reference")+" · "+r.optString("state")+(if(kind=="part")" · stock "+r.optLong("quantity") else ""));Text(r.optString("id"));Button(enabled=!busy,onClick={selected=r.optString("id")}){Text("Sélectionner "+r.optString("id").take(8))}}
 keys.forEach{k->OutlinedTextField(fields[k].orEmpty(),{fields=fields+(k to it)},enabled=!busy,label={Text(labels[k]?:k)})}
 Button(enabled=!busy&&!fields["label"].isNullOrBlank()&&!fields["reference"].isNullOrBlank(),onClick={act("create")}){Text("Créer la fiche métier")}
 if(rows.any{it.optString("id")==selected&&it.optString("state")=="active"}){if(kind=="part"){listOf("delta","reason").forEach{k->OutlinedTextField(fields[k].orEmpty(),{fields=fields+(k to it)},enabled=!busy,label={Text(labels[k]?:k)})};Button(enabled=!busy&&fields["delta"]?.toLongOrNull()!=null&&!fields["reason"].isNullOrBlank(),onClick={act("stock_move")}){Text("Enregistrer le mouvement")}};Button(enabled=!busy,onClick={act("archive")}){Text("Archiver la fiche")}}
 Text(status)
}
