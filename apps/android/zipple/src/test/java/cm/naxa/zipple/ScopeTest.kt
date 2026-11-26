package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class ScopeTest{
 @Test fun scope(){assertTrue(Scope.valid("ZIPPLE","m","o","promoteur",listOf("s"),100,1));assertFalse(Scope.valid("NAXA_SERVICES","m","o","promoteur",listOf("s"),100,1));assertFalse(Scope.valid("ZIPPLE","m","o","admin",listOf("s"),100,1));assertFalse(Scope.valid("ZIPPLE","m","o","staff",listOf("s","s"),100,1));assertFalse(Scope.valid("ZIPPLE","m","o","staff",listOf("s"),1,1))}
}
