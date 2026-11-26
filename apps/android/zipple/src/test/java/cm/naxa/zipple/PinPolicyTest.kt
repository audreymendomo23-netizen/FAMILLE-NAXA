package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class PinPolicyTest {
 @Test fun fourDigits(){assertTrue(LocalAccessPinPolicy.isValid("1234"));assertFalse(LocalAccessPinPolicy.isValid("12"));assertFalse(LocalAccessPinPolicy.isValid("１２３４"))}
 @Test fun backoff(){assertEquals(0L,LocalAccessPinPolicy.lockoutDurationMillis(4));assertEquals(30000L,LocalAccessPinPolicy.lockoutDurationMillis(5));assertEquals(60000L,LocalAccessPinPolicy.lockoutDurationMillis(10))}
 @Test fun memberIsolation(){assertTrue(LocalAccessPinGatePolicy.requiresUnlock("b","a"));assertFalse(LocalAccessPinGatePolicy.requiresUnlock("a","a"))}
}
