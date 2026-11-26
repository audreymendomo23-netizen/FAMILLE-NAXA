package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class ReceiptPolicyTest {
 @Test fun acceptsScopedReceipt(){assertEquals("acknowledged",ReceiptPolicy.verify("e","o","s","e","o","s","ZIPPLE","acknowledged"))}
 @Test(expected=IllegalArgumentException::class) fun rejectsWrongOrg(){ReceiptPolicy.verify("e","o","s","e","other","s","ZIPPLE","acknowledged")}
 @Test(expected=IllegalArgumentException::class) fun rejectsInventedStatus(){ReceiptPolicy.verify("e","o","s","e","o","s","ZIPPLE","paid")}
}
