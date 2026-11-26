package cm.naxa.bootik
import org.junit.Test
import org.junit.Assert.*
class BootikAccessTest {
 @Test fun scope(){assertTrue(BootikAccess.valid("BOOTIK","m","o","manager",listOf("s"),100,0));assertFalse(BootikAccess.valid("NAXA","m","o","manager",listOf("s"),100,0));assertFalse(BootikAccess.valid("BOOTIK","m","o","manager",listOf("s","s"),100,0));assertFalse(BootikAccess.valid("BOOTIK","m","o","staff",listOf("s"),100,100))}
}
