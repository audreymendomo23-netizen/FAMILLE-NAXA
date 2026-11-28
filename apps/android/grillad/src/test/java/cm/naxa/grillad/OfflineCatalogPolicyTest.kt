package cm.naxa.grillad
import org.junit.Assert.*
import org.junit.Test
class OfflineCatalogPolicyTest{
 @Test fun onlySameUserAndDayWithinEightHours(){val t=100000L;assertTrue(OfflineCatalogPolicy.valid("a","a","2026-11-28","2026-11-28",t,t+OfflineCatalogPolicy.MAX_AGE_MS));assertFalse(OfflineCatalogPolicy.valid("a","b","2026-11-28","2026-11-28",t,t));assertFalse(OfflineCatalogPolicy.valid("a","a","2026-11-28","2026-11-29",t,t));assertFalse(OfflineCatalogPolicy.valid("a","a","2026-11-28","2026-11-28",t,t+OfflineCatalogPolicy.MAX_AGE_MS+1));assertFalse(OfflineCatalogPolicy.valid("a","a","2026-11-28","2026-11-28",t,t-1))}
}
