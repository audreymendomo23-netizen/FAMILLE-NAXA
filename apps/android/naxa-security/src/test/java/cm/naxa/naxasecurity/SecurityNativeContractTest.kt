package cm.naxa.naxasecurity
import org.junit.Assert.*
import org.junit.Test
class SecurityNativeContractTest {
 @Test fun persistentPayloads(){val ms=securityModules.filter{it.kind in SecurityNativeContract.persistent};assertEquals(17,ms.size);ms.forEach{m->assertTrue(SecurityNativeContract.payload(m,m.fields.zip(m.sample).toMap()).isNotEmpty())}}
 @Test fun paymentAndMedia(){val p=securityModules.first{it.id=="NS-24"};assertEquals(5000L,SecurityNativeContract.payload(p,p.fields.zip(p.sample).toMap())["amount_fcfa"]);assertEquals(5000L,SecurityNativeContract.payload(p,p.fields.zip(p.sample).toMap()+("amount" to "5000.0"))["amount_fcfa"]);val m=securityModules.first{it.id=="NS-03"};assertEquals("audio",SecurityNativeContract.payload(m,m.fields.zip(m.sample).toMap())["media"])}
 @Test fun scopeAndExpiry(){assertThrows(IllegalArgumentException::class.java){SecurityNativeContract.uuid("other")};assertFalse(SecurityNativeContract.usable(100,100));assertTrue(SecurityNativeContract.usable(101,100))}
}
