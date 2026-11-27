package cm.naxa.naxaservices

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.util.zip.ZipInputStream

class NativeReportExportTest {
    @Test fun xlsxContainsRealWorksheetWithNumbersAndNoFormulaInjection(){
        val out=ByteArrayOutputStream()
        NativeReportExport.writeXlsx(out,listOf(listOf("Site","CA","Marge"),listOf("=A1<&",1000L,null)))
        val files=mutableMapOf<String,String>()
        ZipInputStream(out.toByteArray().inputStream()).use { z ->
            while(true){val e=z.nextEntry?:break;files[e.name]=z.readBytes().toString(Charsets.UTF_8)}
        }
        assertTrue(files.containsKey("[Content_Types].xml"))
        assertTrue(files.containsKey("xl/workbook.xml"))
        val sheet=files.getValue("xl/worksheets/sheet1.xml")
        assertTrue(sheet.contains("=A1&lt;&amp;"))
        assertTrue(sheet.contains("<c r=\"B2\"><v>1000</v></c>"))
        assertFalse(sheet.contains("<f>"))
        assertFalse(sheet.contains("r=\"C2\""))
    }
}
