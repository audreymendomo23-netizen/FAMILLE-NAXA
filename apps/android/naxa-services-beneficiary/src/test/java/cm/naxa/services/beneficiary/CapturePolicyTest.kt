package cm.naxa.services.beneficiary
import org.junit.Assert.*
import org.junit.Test
class CapturePolicyTest {
    @Test fun failedCaptureSurvivesLaterSuccessfulCapture() {
        val failed=CapturePolicy.nextOutstanding(0,false)!!
        val second=CapturePolicy.nextOutstanding(failed,false)!!
        assertEquals(1,CapturePolicy.nextOutstanding(second,true))
        assertNull(CapturePolicy.nextOutstanding(0,true))
        assertNull(CapturePolicy.nextOutstanding(Int.MAX_VALUE,false))
    }
    @Test fun onlyRecognizedCandidateStatesAcknowledgeTransmission() {
        for(status in listOf("pending","matched","review","rejected")) assertTrue(CapturePolicy.acknowledged(status))
        for(status in listOf(null,"","confirmed","error","unknown")) assertFalse(CapturePolicy.acknowledged(status))
    }

    @Test fun exactOriginAndEnrolledChannelRequired() {
        assertTrue(CapturePolicy.allowed("mtn_momo",true,true,"MobileMoney"))
        assertTrue(CapturePolicy.allowed("orange_money",true,true,"OrangeMoney"))
        assertFalse(CapturePolicy.allowed("orange_money",true,true,"MobileMoney"))
        assertFalse(CapturePolicy.allowed("mtn_momo",true,true,"mobilemoney"))
        assertFalse(CapturePolicy.allowed(null,true,true,"MobileMoney"))
        assertFalse(CapturePolicy.allowed("mtn_momo",false,true,"MobileMoney"))
        assertFalse(CapturePolicy.allowed("mtn_momo",true,false,"MobileMoney"))
    }
    @Test fun onlyCreditCandidatesAreForwarded() {
        assertTrue(CapturePolicy.creditCandidate("mtn_momo","Vous avez reçu 5000 FCFA de TEST. Financial Transaction ID: TEST123"))
        assertTrue(CapturePolicy.creditCandidate("orange_money","Payment de 699000111 par 699000222. ID transaction: ABC123, montant transaction: 5000 FCFA"))
        assertFalse(CapturePolicy.creditCandidate("mtn_momo","Votre code de confirmation est 1234"))
        assertFalse(CapturePolicy.creditCandidate("orange_money","Vous avez envoyé 5000 FCFA"))
        assertFalse(CapturePolicy.creditCandidate("mtn_momo","Vous avez reçu 5000 FCFA. Financial Transaction ID: TEST123. Votre code PIN est 1234"))
    }
}
