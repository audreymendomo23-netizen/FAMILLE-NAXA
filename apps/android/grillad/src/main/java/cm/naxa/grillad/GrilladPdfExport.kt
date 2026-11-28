package cm.naxa.grillad
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.content.Context
import android.net.Uri
import org.json.JSONObject
internal fun receiptLines(r:JSONObject):List<String> = buildList {
 add(r.optString("organization"));add(r.optString("site"));add("Référence : "+r.optString("id"));add("Date : "+r.optString("at"))
 add(if(r.optBoolean("cancelled"))"ANNULÉ — ne vaut pas paiement" else "Vente confirmée par GRILLAD")
 rows(r.optJSONArray("lines")).forEach{l->add(l.optString("name")+" × "+l.optString("qty")+" @ "+l.optString("price")+" = "+l.optString("total")+" FCFA")}
 add("Total initial : "+r.optString("total")+" FCFA");add("Total net : "+r.optString("net_total")+" FCFA");r.optJSONObject("cash_declaration")?.let{d->add("Mode déclaré : "+when(d.optString("method")){"cash"->"Espèces";"mtn_momo"->"MTN Mobile Money";"orange_money"->"Orange Money";else->"Inconnu"});if(d.optString("method")!="cash")add("Rapprochement financier distinct de la vente")}
}
internal fun reportPdfLines(r:JSONObject):List<String> = buildList {
 fun amount(k:String)=if(r.isNull(k))"Non attribué / inconnu" else r.optString(k)+" FCFA"
 add("Période : "+r.optString("from")+" / "+r.optString("to"))
 listOf("ca" to "CA","direct_ca" to "Direct","connect_ca" to "Connect","cost" to "Coût","expenses" to "Dépenses","encaissements" to "Encaissements espèces","mtn_declared" to "MTN déclaré","orange_declared" to "Orange déclaré","purchase_amount" to "Achats documentaires (non imputés)").forEach{(k,v)->add("$v : "+amount(k))}
 rows(r.optJSONArray("purchases_by_supplier")).forEach{x->add(x.optString("supplier")+" : "+x.optString("amount")+" FCFA")}
 add("Ventes : "+r.optString("sales_count")+" / Unités : "+r.optString("quantity"))
 rows(r.optJSONArray("sites")).forEach{x->add(x.optString("name")+" : CA "+x.optString("ca")+" FCFA")}
 add("Données confirmées serveur uniquement")
}
internal fun writeGrilladPdf(context:Context,uri:Uri,title:String,lines:List<String>){
 val pdf=PdfDocument()
 try {
  val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply{textSize=12f}
  val wrapped=(listOf(title)+lines).flatMap{line->line.replace(Regex("[\\r\\n\\t]")," ").chunked(70).ifEmpty{listOf("")}}
  wrapped.chunked(44).forEachIndexed{i,part->val page=pdf.startPage(PdfDocument.PageInfo.Builder(595,842,i+1).create());part.forEachIndexed{j,s->page.canvas.drawText(s,40f,50f+j*17f,paint)};pdf.finishPage(page)}
  context.contentResolver.openOutputStream(uri)?.use{pdf.writeTo(it)}?:error("Fichier indisponible")
 }finally{pdf.close()}
}
