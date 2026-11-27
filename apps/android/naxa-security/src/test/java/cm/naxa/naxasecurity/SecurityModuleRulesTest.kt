package cm.naxa.naxasecurity
import org.junit.Assert.*
import org.junit.Test
class SecurityModuleRulesTest {
 @Test fun coversAllPreviouslyRedModules(){assertEquals(24,securityModules.size);assertEquals(24,securityModules.map{it.id}.toSet().size)}
 @Test fun samplesAndUnexpectedPrivileges(){securityModules.forEach{m->val valid=m.fields.zip(m.sample).toMap();assertTrue(SecurityModuleRules.evaluate(m,valid).isNotBlank());assertThrows(IllegalArgumentException::class.java){SecurityModuleRules.evaluate(m,valid+("approved" to "yes"))};if(m.fields.isNotEmpty())assertThrows(IllegalArgumentException::class.java){SecurityModuleRules.evaluate(m,valid-m.fields.first())}}}
 @Test fun deniesMediaWithoutConsent(){val m=securityModules.first{it.id=="NS-02"};assertThrows(IllegalArgumentException::class.java){SecurityModuleRules.evaluate(m,mapOf("device" to "cam-01","purpose" to "test","consent" to "no"))}}
 @Test fun deniesNegativePayment(){val m=securityModules.first{it.id=="NS-24"};assertThrows(IllegalArgumentException::class.java){SecurityModuleRules.evaluate(m,mapOf("reference" to "txn","amount" to "-1","channel" to "bank"))}}
}
