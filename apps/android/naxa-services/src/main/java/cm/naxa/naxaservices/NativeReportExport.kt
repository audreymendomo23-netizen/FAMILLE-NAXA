package cm.naxa.naxaservices

import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import java.io.OutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Export local indicatif. Cellules numériques et texte inline, jamais de formules injectées. */
internal object NativeReportExport {
    private fun xml(s:String)=s.filter { it=='\t'||it=='\n'||it=='\r'||it>=' ' }.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&apos;")
    fun writeXlsx(out:OutputStream,rows:List<List<Any?>>) {
        require(rows.isNotEmpty()&&rows.size<=10000&&rows.all { it.size<=26 })
        val ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        ZipOutputStream(out).use { zip ->
            fun entry(name:String,value:String){zip.putNextEntry(ZipEntry(name));zip.write(value.toByteArray(Charsets.UTF_8));zip.closeEntry()}
            entry("[Content_Types].xml","""<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>""")
            entry("_rels/.rels","""<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>""")
            entry("xl/workbook.xml","""<workbook xmlns="$ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Rapport" sheetId="1" r:id="rId1"/></sheets></workbook>""")
            entry("xl/_rels/workbook.xml.rels","""<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>""")
            val body=buildString {
                append("<worksheet xmlns=\"").append(ns).append("\"><sheetData>")
                rows.forEachIndexed { i,row ->
                    append("<row r=\"").append(i+1).append("\">")
                    row.forEachIndexed { j,value ->
                        if(value!=null){
                            val cell=('A'+j).toString()+(i+1)
                            if(value is Number)append("<c r=\"").append(cell).append("\"><v>").append(value).append("</v></c>")
                            else append("<c r=\"").append(cell).append("\" t=\"inlineStr\"><is><t xml:space=\"preserve\">").append(xml(value.toString())).append("</t></is></c>")
                        }
                    };append("</row>")
                };append("</sheetData></worksheet>")
            }
            entry("xl/worksheets/sheet1.xml",body)
        }
    }
    fun writePdf(out:OutputStream,rows:List<List<Any?>>){
        require(rows.size>=2&&rows.size<=10000)
        val document=PdfDocument()
        try {
            val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply{textSize=11f}
            var pageNumber=0
            val headers=rows[1]
            // Each site is a separate labelled block; no ambiguous wide table or clipped financial values.
            rows.drop(2).forEach { row ->
                val page=document.startPage(PdfDocument.PageInfo.Builder(595,842,++pageNumber).create())
                val canvas=page.canvas
                canvas.drawText("NAXA SERVICES — rapport local indicatif",32f,42f,paint)
                canvas.drawText(rows.first().drop(1).joinToString(" · ").take(80),32f,62f,paint)
                headers.forEachIndexed { index,header ->
                    canvas.drawText(header.toString().take(44),32f,100f+index*24f,paint)
                    canvas.drawText((row.getOrNull(index)?.toString()?:"Non déterminable").take(32),315f,100f+index*24f,paint)
                }
                canvas.drawText("Non certifié — données locales, hors clôture comptable.",32f,790f,paint)
                document.finishPage(page)
            }
            document.writeTo(out)
        } finally {document.close()}
    }
}
