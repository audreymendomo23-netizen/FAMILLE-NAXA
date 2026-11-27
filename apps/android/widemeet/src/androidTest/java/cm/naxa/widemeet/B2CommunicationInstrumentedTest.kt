package cm.naxa.widemeet
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.SystemClock
import android.util.Base64
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

@RunWith(AndroidJUnit4::class)
class B2CommunicationInstrumentedTest {
 @get:Rule val compose=createComposeRule()
 private val member=UUID.randomUUID().toString()
 private val peer=UUID.randomUUID().toString()
 private val room=UUID.randomUUID().toString()
 private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
 private fun session():Session{val w=UUID.randomUUID().toString();val now=System.currentTimeMillis();return Session("WIDEMEET","a".repeat(64),member,UUID.randomUUID().toString(),now+300000,now,now,SystemClock.elapsedRealtime(),false,w,listOf(Workspace(w,"enterprise","Fixture","promoteur",true)))}
 private fun rows(vararg x:JSONObject)=JSONObject().put("items",JSONArray(x.toList()))
 private fun awaitText(t:String)=compose.waitUntil(10000){compose.onAllNodesWithText(t,substring=false).fetchSemanticsNodes().isNotEmpty()}
 @Test fun connectSourceRequiresPreviewAndCanStop(){
  val s=session();val gateway=RoomGateway("https://127.0.0.1/widemeet-auth");var receiver=false;val confirmed=AtomicBoolean(false);val stopped=AtomicBoolean(false)
  val code="b".repeat(64)
  val transport:suspend(String,JSONObject)->JSONObject={action,d->
   assertEquals(room,d.getString("room_id"))
   when(action){
    "source-status"->JSONObject().put("enabled",true).put("receiver_name",if(receiver)"Fixture display" else "")
    "preview"->{assertEquals(code,d.getString("code"));JSONObject().put("receiver_name","Fixture display")}
    "confirm"->{assertEquals(code,d.getString("code"));assertEquals("Fixture display",d.getString("receiver_name"));receiver=true;confirmed.set(true);JSONObject().put("confirmed",true)}
    "source-stop"->{receiver=false;stopped.set(true);JSONObject()}
    else->throw IllegalArgumentException(action)
   }
  }
  compose.setContent{MaterialTheme{ConnectSource(false,gateway,s,room,true,transport)}}
  awaitText("Code de l’écran")
  compose.onNodeWithText("Confirmer l’appairage").assertDoesNotExist()
  compose.onNodeWithText("Code de l’écran").performTextInput(code)
  compose.onNodeWithText("Vérifier l’écran").performClick()
  awaitText("Confirmer cet écran : Fixture display")
  compose.onNodeWithText("Confirmer l’appairage").performClick()
  awaitText("Récepteur autorisé : Fixture display");assertTrue(confirmed.get())
  compose.onNodeWithText("Arrêter l’affichage").performClick();awaitText("Code de l’écran");assertTrue(stopped.get())
 }
 @Test fun chatMediaRejectsChangedBytesAndRemovesRevokedFile(){
  val s=session();val gateway=AuthGateway(context,"https://127.0.0.1/widemeet-auth");val id=UUID.randomUUID().toString()
  val revoked=AtomicBoolean(false);val downloaded=AtomicBoolean(false);val pdf="%PDF-1.4 fixture".toByteArray()
  val item=JSONObject().put("id",id).put("sender_id",member).put("kind","file").put("mime","application/pdf").put("name","fixture.pdf").put("bytes",pdf.size).put("sha256",chatMediaDigest(pdf))
  val transport:suspend(String,JSONObject)->JSONObject={action,d->
   assertEquals(peer,d.getString("peer_id"))
   when(action){
    "list"->if(revoked.get())rows()else rows(item)
    "download"->{assertEquals(id,d.getString("id"));downloaded.set(true);JSONObject(item.toString()).put("content",Base64.encodeToString(pdf.map{(it.toInt() xor 1).toByte()}.toByteArray(),Base64.NO_WRAP))}
    "revoke"->{assertEquals(id,d.getString("id"));revoked.set(true);JSONObject().put("state","revoked")}
    else->throw IllegalArgumentException(action)
   }
  }
  compose.setContent{MaterialTheme{Column(Modifier.verticalScroll(rememberScrollState())){ChatMediaPanel(false,gateway,s,peerId=peer,transport=transport)}}}
  awaitText("fixture.pdf · "+pdf.size+" o");compose.onNodeWithText("Télécharger").performScrollTo().performClick()
  awaitText("Accès, format ou transfert non confirmé.");assertTrue(downloaded.get())
  compose.onNodeWithText("Révoquer le fichier").performScrollTo().performClick()
  compose.waitUntil(10000){revoked.get()&&compose.onAllNodesWithText("fixture.pdf · "+pdf.size+" o").fetchSemanticsNodes().isEmpty()}
 }
 @Test fun groupNativeReplyReportAndResolution(){
  val s=session();val gateway=AuthGateway(context,"https://127.0.0.1/widemeet-auth");val gid=UUID.randomUUID().toString();val mid=UUID.randomUUID().toString()
  val sent=AtomicBoolean(false);val reported=AtomicBoolean(false);val resolved=AtomicBoolean(false)
  val group=JSONObject().put("id",gid).put("name","Fixture group").put("creator_id",member).put("member_count",3)
  val message=JSONObject().put("id",mid).put("sender_id",peer).put("display_name","Fixture peer").put("body","Fixture message").put("created_at","2026-11-27").put("read_at",JSONObject.NULL).put("mention_ids",JSONArray(listOf(member)))
  val person=JSONObject().put("member_id",peer).put("display_name","Fixture peer")
  val thread=rows(message).put("next_before_id",JSONObject.NULL)
  val transport:suspend(String,JSONObject)->JSONObject={action,d->
   when(action){
    "group-chat-list"->rows(group)
    "center-contacts"->rows(person)
    "group-chat-thread"->thread
    "group-chat-members"->rows(person)
    "group-chat-watch"->{delay(300);JSONObject().put("changed",true).put("version","a".repeat(64)).put("thread",thread).put("members",JSONArray(listOf(person)))}
    "group-chat-send"->{assertEquals(mid,d.getString("reply_to"));assertEquals("Fixture reply",d.getString("body"));sent.set(true);JSONObject().put("sent",true)}
    "group-chat-report"->{assertEquals(mid,d.getString("message_id"));reported.set(true);JSONObject().put("reported",true)}
    "group-chat-reports"->if(reported.get()&&!resolved.get())rows(JSONObject().put("message_id",mid).put("reporter_id",member).put("preview","Fixture report"))else rows()
    "group-chat-resolve-report"->{assertEquals(mid,d.getString("message_id"));resolved.set(true);JSONObject().put("resolved",true)}
    else->throw IllegalArgumentException(action)
   }
  }
  compose.setContent{MaterialTheme{Column(Modifier.verticalScroll(rememberScrollState())){GroupChat(false,gateway,s,transport=transport){}}}}
  awaitText("Fixture group · 3");compose.onNodeWithText("Fixture group · 3").performScrollTo().performClick()
  awaitText("Vous êtes mentionné")
  compose.onNodeWithText("Répondre").performScrollTo().performClick();awaitText("Réponse à : Fixture message")
  compose.onNodeWithText("Message de groupe").performScrollTo().performTextInput("Fixture reply")
  compose.onNodeWithText("Envoyer au groupe").performScrollTo().performClick()
  compose.waitUntil(10000){sent.get()}
  compose.onNodeWithText("Signaler",substring=false).performScrollTo().performClick();compose.onNodeWithText("Confirmer",substring=false).performClick()
  compose.waitUntil(10000){reported.get()}
  compose.onNodeWithText("Signalements du groupe").performScrollTo().performClick()
  awaitText("Clôturer le signalement");compose.onNodeWithText("Clôturer le signalement").performScrollTo().performClick()
  compose.waitUntil(10000){resolved.get()}
 }
 @Test fun actualAacDecoderProducesPcm(){
  val asset=InstrumentationRegistry.getInstrumentation().context.assets.open("b2-synthetic-silence.m4a").use{it.readBytes()};assertEquals(847,asset.size)
  val file=File.createTempFile("wm-b2-codec-",".m4a",context.cacheDir);file.writeBytes(asset)
  val extractor=MediaExtractor();var codec:MediaCodec?=null
  try{
   extractor.setDataSource(file.absolutePath);assertTrue(extractor.trackCount>0);val format=extractor.getTrackFormat(0);val mime=format.getString(MediaFormat.KEY_MIME)!!;assertEquals("audio/mp4a-latm",mime)
   extractor.selectTrack(0);val decoder=MediaCodec.createDecoderByType(mime);codec=decoder;decoder.configure(format,null,null,0);decoder.start()
   var inputDone=false;var outputDone=false;var pcm=0;val info=MediaCodec.BufferInfo();val end=SystemClock.elapsedRealtime()+10000
   while(!outputDone&&SystemClock.elapsedRealtime()<end){
    if(!inputDone){val index=decoder.dequeueInputBuffer(10000);if(index>=0){val buf=decoder.getInputBuffer(index)!!;buf.clear();val n=extractor.readSampleData(buf,0);if(n<0){decoder.queueInputBuffer(index,0,0,0,MediaCodec.BUFFER_FLAG_END_OF_STREAM);inputDone=true}else{decoder.queueInputBuffer(index,0,n,extractor.sampleTime,0);extractor.advance()}}}
    val out=decoder.dequeueOutputBuffer(info,10000);if(out>=0){pcm+=info.size;outputDone=info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM!=0;decoder.releaseOutputBuffer(out,false)}
   }
   assertTrue("PCM not decoded",outputDone&&pcm>0)
  }finally{runCatching{codec?.stop()};runCatching{codec?.release()};extractor.release();file.delete()}
 }
}
