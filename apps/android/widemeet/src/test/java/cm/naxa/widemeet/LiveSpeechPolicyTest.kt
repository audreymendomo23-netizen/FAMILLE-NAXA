package cm.naxa.widemeet
import org.junit.Test
import org.junit.Assert.*
class LiveSpeechPolicyTest {
 private val id="12345678-1234-1234-1234-123456789abc"
 private fun cue(status:String="ready",fallback:Boolean=false,uncertain:Boolean=false,target:String="en",source:String="fr",ttl:Long=9000)=liveSpeechWindow(status,fallback,uncertain,"en",source,target,"Translated sentence",id,0,8000,ttl)
 @Test fun acceptsOnlyCurrentTranslatedSpeech(){assertEquals(5000L,cue()!!.ttl);assertNull(cue(fallback=true));assertNull(cue(uncertain=true));assertNull(cue(status="waiting"));assertNull(cue(target="ff"));assertNull(cue(source="en"));assertNull(cue(ttl=0))}
 @Test fun rateIsBounded(){assertEquals(1.25f,liveListeningRate("1.25"),0f);assertEquals(1f,liveListeningRate("9"),0f)}
}
