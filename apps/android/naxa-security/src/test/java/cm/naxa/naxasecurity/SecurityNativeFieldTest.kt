package cm.naxa.naxasecurity
import org.junit.Assert.*
import org.junit.Test
class SecurityNativeFieldTest {
 @Test fun patrolRequiresAssignedActor(){assertEquals(listOf("patrol_check","patrol_submit"),nativeFieldChoices("patrol","running",true).map{it.op});assertTrue(nativeFieldChoices("patrol","running",false).isEmpty());assertTrue(nativeFieldChoices("patrol","submitted",true).isEmpty())}
 @Test fun maintenanceReviewDistinct(){assertEquals("maintenance_complete",nativeFieldChoices("maintenance","in_progress",true,false).single().op);assertEquals("maintenance_review",nativeFieldChoices("maintenance","in_progress",false,true).single().op);assertTrue(nativeFieldChoices("maintenance","in_progress",true,true).isEmpty())}
 @Test fun attendanceAndSafetyNeverSelfReviewed(){assertTrue(nativeFieldChoices("attendance","pending_review",true).isEmpty());assertTrue(nativeFieldChoices("safety","reported",true).isEmpty());assertEquals("safety_ack",nativeFieldChoices("safety","reported",false).single().op)}
}
