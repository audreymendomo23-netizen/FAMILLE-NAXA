package cm.naxa.bootik.domain
import org.junit.Test
import org.junit.Assert.*
class BootikPolicyTest {
 @Test fun offers(){assertEquals(40000L,BootikPolicy.quote("retailer","access",12));assertEquals(250000L,BootikPolicy.quote("distributor","premium",12));assertEquals(259200000L,BootikPolicy.trialEnd(0));assertTrue(runCatching{BootikPolicy.quote("retailer","access",3)}.isFailure)}
 @Test fun isolation(){assertFalse(BootikPolicy.validScope("ZIPPLE","a","b","c",100,0));assertFalse(BootikPolicy.validScope("BOOTIK","a","b","c",100,100));assertTrue(BootikPolicy.validScope("BOOTIK","a","b","c",100,0))}
}
