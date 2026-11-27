package cm.naxa.widemeet
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import org.json.JSONObject
import java.io.OutputStream
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

fun writeMinutesPdf(data:JSONObject,english:Boolean,output:OutputStream){
 require(!data.isNull("published_at")&&!data.isNull("approved_at")&&data.getString("verification_id")==data.getString("version_id"))
 fun tr(fr:String,en:String)=if(english)en else fr
 fun date(v:String)=DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm").withZone(ZoneId.of("Africa/Douala")).format(Instant.parse(v))
 val recipient=data.getString("recipient_name")
 val body=buildString{append(data.optJSONObject("snapshot")?.optString("title")?:tr("Réunion","Meeting"));append("\n\n"+tr("Version validée et publiée","Approved and published version")+" "+data.getInt("version"));append("\n"+tr("Validation","Approval")+" : "+date(data.getString("approved_at")));append("\n"+tr("Publication","Publication")+" : "+date(data.getString("published_at")));append("\n"+tr("Identifiant de vérification","Verification identifier")+" : "+data.getString("verification_id"));append("\n\n"+tr("Compte rendu rédigé et validé par un humain","Human-authored and approved minutes")+"\n\n");append(data.getString("body"));append("\n\n"+tr("Une révocation ultérieure ne rappelle pas une copie déjà exportée.","Later revocation cannot recall an exported copy."))}
 val paint=TextPaint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.rgb(24,34,43);textSize=12f}
 val layout=StaticLayout.Builder.obtain(body,0,body.length,paint,505).setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing(3f,1f).build()
 val label=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.rgb(49,92,49);textSize=12f;isFakeBoldText=true}
 val footer=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.DKGRAY;textSize=9f}
 val doc=PdfDocument()
 try{var line=0;var pageNo=1
  while(line<layout.lineCount){
   val top=layout.getLineTop(line);var next=line+1;while(next<layout.lineCount&&layout.getLineBottom(next)-top<=680)next++
   val page=doc.startPage(PdfDocument.PageInfo.Builder(595,842,pageNo).create());val canvas=page.canvas
   canvas.drawText("WideMeet | "+tr("Compte rendu","Meeting minutes"),45f,35f,label)
   canvas.save();canvas.clipRect(45f,60f,550f,740f);canvas.translate(45f,60f-top);layout.draw(canvas);canvas.restore()
   canvas.drawText((tr("Copie destinée à ","Copy intended for ")+recipient).take(90),45f,790f,footer);canvas.drawText(pageNo.toString(),530f,790f,footer)
   doc.finishPage(page);line=next;pageNo++
  };doc.writeTo(output)
 }finally{doc.close()}
}
