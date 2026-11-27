package cm.naxa.grillad
import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
private fun xmlText(v:Any?):String=(v?.toString()?:"").filter{it=='\t'||it=='\n'||it=='\r'||(it.code>=32&&it!='\ufffe'&&it!='\uffff')}.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;")
internal fun grilladReportRows(r:JSONObject):List<List<Any?>> = buildList {
 fun value(k:String)=if(r.isNull(k))"Non attribué / inconnu" else r.opt(k)
 fun item(x:JSONObject,k:String)=if(x.isNull(k))"Non attribué / inconnu" else x.opt(k)
 add(listOf("GRILLAD — Rapport financier"));add(listOf("Du",r.optString("from"),"Au",r.optString("to")));add(listOf("Indicateur","FCFA / quantité"))
 listOf("ca" to "CA","direct_ca" to "Direct","connect_ca" to "Connect","cost" to "Coût","expenses" to "Dépenses","sales_count" to "Ventes","quantity" to "Unités").forEach{(k,v)->add(listOf(v,value(k)))}
 add(emptyList());add(listOf("Point","CA FCFA","Dépenses FCFA"));rows(r.optJSONArray("sites")).forEach{x->add(listOf(x.optString("name"),item(x,"ca"),item(x,"expenses")))}
 add(emptyList());add(listOf("Famille","CA FCFA","Quantité"));rows(r.optJSONArray("by_family")).forEach{x->add(listOf(x.optString("family"),item(x,"ca"),item(x,"quantity")))}
 add(emptyList());add(listOf("Vendeur (référence)","CA FCFA","Quantité"));rows(r.optJSONArray("by_seller")).forEach{x->add(listOf(x.optString("actor"),item(x,"ca"),item(x,"quantity")))}
 add(listOf("Données confirmées serveur uniquement"))
}
internal fun writeGrilladXlsx(context:Context,uri:Uri,table:List<List<Any?>>){
 require(table.size<=10000&&table.all{it.size<=26})
 val ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main";val rel="http://schemas.openxmlformats.org/package/2006/relationships";val off="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 val p="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
 val sheet=buildString{append("$p<worksheet xmlns=\"$ns\"><sheetData>");table.forEachIndexed{i,row->append("<row r=\""+(i+1)+"\">");row.forEachIndexed{j,v->val ref=('A'.code+j).toChar().toString()+(i+1);if(v is Int||v is Long)append("<c r=\"$ref\"><v>$v</v></c>")else append("<c r=\"$ref\" t=\"inlineStr\"><is><t xml:space=\"preserve\">"+xmlText(v)+"</t></is></c>")};append("</row>")};append("</sheetData></worksheet>")}
 val files=linkedMapOf(
 "[Content_Types].xml" to "$p<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
 "_rels/.rels" to "$p<Relationships xmlns=\"$rel\"><Relationship Id=\"rId1\" Type=\"$off/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
 "xl/workbook.xml" to "$p<workbook xmlns=\"$ns\" xmlns:r=\"$off\"><sheets><sheet name=\"Rapport\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
 "xl/_rels/workbook.xml.rels" to "$p<Relationships xmlns=\"$rel\"><Relationship Id=\"rId1\" Type=\"$off/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
 "xl/worksheets/sheet1.xml" to sheet)
 val output=context.contentResolver.openOutputStream(uri)?:error("Fichier indisponible")
 ZipOutputStream(output).use{z->files.forEach{(name,text)->z.putNextEntry(ZipEntry(name));z.write(text.toByteArray(Charsets.UTF_8));z.closeEntry()}}
}
