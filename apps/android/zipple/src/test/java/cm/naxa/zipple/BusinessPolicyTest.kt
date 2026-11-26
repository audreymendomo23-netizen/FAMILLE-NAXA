package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class BusinessPolicyTest {
 @Test fun exactEndpointAndDebugIsolation(){
  val hosted="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-business"
  assertEquals(hosted,ZippleBusinessPolicy.endpoint(hosted,false))
  assertNull(ZippleBusinessPolicy.endpoint("https://evil.example/functions/v1/zipple-business",false))
  assertNull(ZippleBusinessPolicy.endpoint("https://127.0.0.1:4443/zipple-business",false))
  assertEquals("https://127.0.0.1:4443/zipple-business",ZippleBusinessPolicy.endpoint("https://127.0.0.1:4443/zipple-business",true))
  assertNull(ZippleBusinessPolicy.endpoint("https://127.0.0.1:4443/zipple-business?redirect=x",true))
  assertNull(ZippleBusinessPolicy.endpoint("http://127.0.0.1:4443/zipple-business",true))
 }
 @Test fun neverExposePaymentConfirmationOrAdmin(){
  assertTrue(ZippleBusinessPolicy.allowed("order_create"))
  assertTrue(ZippleBusinessPolicy.allowed("erp_snapshot"))
  assertFalse(ZippleBusinessPolicy.allowed("confirm_subscription"))
  assertFalse(ZippleBusinessPolicy.allowed("guest_open"))
  assertFalse(ZippleBusinessPolicy.allowed("../admin"))
 }
}
