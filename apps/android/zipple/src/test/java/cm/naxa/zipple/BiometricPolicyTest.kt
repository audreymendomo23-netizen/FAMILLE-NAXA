package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class BiometricPolicyTest {
 @Test fun consentAndScope(){
  assertTrue(ZippleBiometricPolicy.allowed(true,true,true,true,100,1))
  assertFalse(ZippleBiometricPolicy.allowed(false,true,true,true,100,1))
  assertFalse(ZippleBiometricPolicy.allowed(true,false,true,true,100,1))
  assertFalse(ZippleBiometricPolicy.allowed(true,true,false,true,100,1))
  assertFalse(ZippleBiometricPolicy.allowed(true,true,true,false,100,1))
  assertFalse(ZippleBiometricPolicy.allowed(true,true,true,true,100,100))
 }
}
