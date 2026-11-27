package cm.naxa.zipple

import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.math.BigDecimal

internal data class NativePurchaseLine(val name:String,val unit:String,val qty:Long,val total:Long,val received:Long)
internal data class NativePurchaseOrder(val reference:String,val supplier:String,val phone:String,val lines:List<NativePurchaseLine>)
internal fun nativePurchaseOrder(snapshot:JSONObject,stock:JSONObject,id:String):NativePurchaseOrder? = runCatching {
 val purchases=snapshot.rows("purchases")
 val selected=purchases.single{it.getString("id")==id}
 val supplier=snapshot.rows("suppliers").single{it.getString("id")==selected.getString("supplier_id")}
 val batch=snapshot.rows("batches").firstOrNull{x->val ids=x.getJSONArray("purchase_ids");(0 until ids.length()).any{ids.getString(it)==id}}
 val list=if(batch==null)listOf(selected)else batch.getJSONArray("purchase_ids").let{ids->(0 until ids.length()).map{i->purchases.single{it.getString("id")==ids.getString(i)}}}
 val lines=list.map{x->
  require(x.getString("supplier_id")==supplier.getString("id"))
  val ingredient=stock.rows("ingredients").single{it.getString("id")==x.getString("ingredient_id")}
  NativePurchaseLine(ingredient.getString("name"),ingredient.getString("unit"),x.getLong("qty_milli"),x.getLong("total_xaf"),x.getLong("received_milli"))
 }
 NativePurchaseOrder(batch?.getString("reference")?:selected.getString("reference"),supplier.getString("name"),supplier.optString("whatsapp"),lines).also{nativePurchaseText(it,false)}
}.getOrNull()
internal fun nativePurchaseText(order:NativePurchaseOrder,en:Boolean):String{
 val t:(String,String)->String={fr,eng->if(en)eng else fr}
 fun clean(s:String)=s.map{if(it.isISOControl())' ' else it}.joinToString("").trim()
 fun qty(n:Long)=BigDecimal.valueOf(n,3).stripTrailingZeros().toPlainString()
 require(clean(order.reference).isNotBlank()&&clean(order.supplier).isNotBlank()&&order.lines.isNotEmpty()&&order.lines.size<=50)
 require(order.lines.all{clean(it.name).isNotBlank()&&clean(it.unit).isNotBlank()&&it.qty in 1L..1000000000L&&it.total in 1L..2147483647L&&it.received in 0L..it.qty})
 return (listOf("ZIPPLE - "+t("Bon de commande fournisseur","Supplier purchase order"),t("Référence : ","Reference: ")+clean(order.reference),t("Fournisseur : ","Supplier: ")+clean(order.supplier))+order.lines.map{clean(it.name)+" - "+qty(it.qty)+" "+clean(it.unit)+" - "+it.total+" FCFA - "+t("Reçu : ","Received: ")+qty(it.received)+" "+clean(it.unit)}+listOf(t("Total commande : ","Order total: ")+order.lines.sumOf{it.total}+" FCFA",t("Bon de commande, non une facture ni une preuve de paiement.","Purchase order, not an invoice or payment receipt."))).joinToString("\n")
}
internal fun nativePurchaseWhatsApp(order:NativePurchaseOrder,en:Boolean):Uri?=order.phone.takeIf{it.matches(Regex("[0-9]{9,15}"))}?.let{Uri.Builder().scheme("https").authority("wa.me").appendPath(it).appendQueryParameter("text",nativePurchaseText(order,en)).build()}
internal fun nativePurchasePdf(order:NativePurchaseOrder,en:Boolean):ByteArray{
 val text=nativePurchaseText(order,en);val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply{textSize=12f;color=android.graphics.Color.BLACK}
 val pdf=PdfDocument()
 try{
  var number=1;var page=pdf.startPage(PdfDocument.PageInfo.Builder(595,842,number).create());var y=42f
  for(line in text.split("\n")){
   var rest=line
   while(rest.isNotEmpty()){
    var n=paint.breakText(rest,true,511f,null).coerceAtLeast(1)
    if(n<rest.length&&rest[n-1].isHighSurrogate())n=if(n>1)n-1 else 2
    if(y>800f){pdf.finishPage(page);number++;page=pdf.startPage(PdfDocument.PageInfo.Builder(595,842,number).create());y=42f}
    page.canvas.drawText(rest.substring(0,n),42f,y,paint);rest=rest.substring(n);y+=18f
   }
  }
  pdf.finishPage(page)
  return ByteArrayOutputStream().use{pdf.writeTo(it);it.toByteArray()}
 }finally{pdf.close()}
}
@Composable internal fun NativePurchaseDocuments(data:ND,allowed:Boolean,en:Boolean){
 val t:(String,String)->String={fr,eng->if(en)eng else fr};val ctx=LocalContext.current;val scope=rememberCoroutineScope()
 var selected by remember{mutableStateOf("")};var message by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var pending by remember{mutableStateOf<ByteArray?>(null)}
 val snapshot=data.data["procurement_snapshot"]?:return;val stock=data.data["erp_snapshot"]?:return
 val order=remember(snapshot,stock,selected){nativePurchaseOrder(snapshot,stock,selected)}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")){uri->
  val bytes=pending;pending=null
  if(uri!=null&&bytes!=null&&allowed){busy=true;scope.launch{try{withContext(Dispatchers.IO){requireNotNull(ctx.contentResolver.openOutputStream(uri,"wt")).use{it.write(bytes)}};message=t("Bon enregistré","Purchase order saved")}catch(c:CancellationException){throw c}catch(_:Exception){message=t("Export non confirmé","Export unconfirmed")}finally{busy=false}}}
 }
 Text(t("Bons de commande fournisseur","Supplier purchase orders"))
 FloorChoice(t("Commande à exporter","Purchase to export"),snapshot.rows("purchases").map{it.optString("id") to it.optString("reference")},selected,allowed&&!busy&&pending==null){selected=it;message=""}
 if(selected.isNotBlank()&&order==null)Text(t("Document indisponible : données incomplètes. Actualisez.","Document unavailable: incomplete data. Refresh."))
 if(order!=null){
 Text(nativePurchaseText(order,en))
 OutlinedButton(enabled=allowed&&!busy&&pending==null,onClick={busy=true;scope.launch{try{pending=withContext(Dispatchers.IO){nativePurchasePdf(order,en)};save.launch("zipple-bon-"+order.reference.replace(Regex("[^a-zA-Z0-9_-]"),"_").take(80)+".pdf")}catch(c:CancellationException){throw c}catch(_:Exception){pending=null;message=t("Export non confirmé","Export unconfirmed")}finally{busy=false}}}){Text(t("Enregistrer le bon de commande PDF","Save purchase order PDF"))}
 val link=nativePurchaseWhatsApp(order,en)
 if(link!=null)OutlinedButton(enabled=allowed&&!busy,onClick={try{ctx.startActivity(Intent(Intent.ACTION_VIEW,link))}catch(_:Exception){message=t("WhatsApp indisponible","WhatsApp unavailable")}}){Text(t("Préparer le message WhatsApp fournisseur","Prepare supplier WhatsApp message"))}
 Text(t("Aucun envoi automatique. Vérifiez le destinataire dans WhatsApp.","No automatic delivery. Check recipient in WhatsApp."))
 }
 if(message.isNotBlank())Text(message)
}
