package cm.naxa.grillad
import org.junit.Test
import org.junit.Assert.*
class GrilladDomainTest{
 @Test fun tariffs(){assertEquals(2000L,planPrice("ACCESS",false));assertEquals(24000L,planPrice("ACCESS",true));assertEquals(6000L,planPrice("PREMIUM",false));assertEquals(60000L,planPrice("PREMIUM",true))}
 @Test fun saleAndReplay(){val l=Ledger();val s=l.sites.first();l.item(s,"Poulet","Poulet",1000,400);val id=l.items.first().id;l.prepare(s,id,5);l.open(s,100);l.sell(s,id,2,"r");l.sell(s,id,2,"r");assertEquals(1,l.sales.size);assertTrue(runCatching{l.sell(s,id,4,"r2")}.isFailure);l.expense(s,"Bois",200);assertEquals(1900L,l.expected(s));assertEquals(1000L,l.report(s).result);l.close(s,1900);assertEquals(0L,l.closings.first().second)}
 @Test fun noCrossSite(){val l=Ledger();val s=l.sites.first();l.item(s,"Porc","Porc",500,null);assertTrue(runCatching{l.site("Deux")}.isFailure);l.plan="PREMIUM";l.site("Deux");assertTrue(runCatching{l.prepare("Deux",l.items.first().id,1)}.isFailure)}
 @Test fun correctionAndCalendar(){val l=Ledger();val s=l.sites.first();l.item(s,"Poulet","Poulet",1000,400);val i=l.items.first().id;l.prepare(s,i,5);l.open(s,0);l.staff.add(s to "Vendeur");l.sell(s,i,2,"x","Vendeur");assertEquals("Vendeur",l.sales[0].actor);l.cancel(s,"x","Erreur de saisie");assertEquals(0L,l.report(s).ca);assertEquals(0L,l.items.first().sold);assertTrue(runCatching{l.close(s,100)}.isFailure);l.close(s,100,"Vérifié");assertTrue(periodMatch("2026-11-23","2026-11-27","semaine"));assertFalse(periodMatch("2026-11-22","2026-11-27","semaine"))}
}
