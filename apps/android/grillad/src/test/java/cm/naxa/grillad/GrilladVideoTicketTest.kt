package cm.naxa.grillad
import org.junit.Test
import org.junit.Assert.*
class GrilladVideoTicketTest{@Test fun resourceRejectsCrossOrigin(){val t=GrilladVideoTicket("12345678-1234-1234-1234-123456789abc",java.net.URI("https://media.example.test/a/whep"),"Bearer "+"a".repeat(43),1000);assertEquals("https://media.example.test/a/resource",t.resource("resource").toString());try{t.resource("https://other.example.test/token");fail("cross origin")}catch(_:IllegalArgumentException){}}}
