package cm.naxa.bootik
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import cm.naxa.bootik.data.BootikLocalDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
@RunWith(AndroidJUnit4::class)
class BootikOutboxInstrumentedTest{
 @Test fun automaticScopeCannotCrossSession()=runBlocking{
  val db=Room.inMemoryDatabaseBuilder(InstrumentationRegistry.getInstrumentation().targetContext,BootikLocalDatabase::class.java).build()
  val now=System.currentTimeMillis()
  val session=BootikSession("test-token","member","org","manager",listOf(BootikSite("site","Site")),now+60000)
  val a=BootikSyncScope(BootikApi("https://example.invalid"),db.scoped(),session,"site")
  val b=a.copy(workId="second-binding")
  try{
   BootikSync.activate(a);assertFalse(BootikSync.automaticAllowed(a))
   BootikSync.setAutomatic(a,true);assertTrue(BootikSync.automaticAllowed(a))
   BootikSync.setAutomatic(a,false);assertFalse(BootikSync.automaticAllowed(a))
   BootikSync.setAutomatic(a,true);BootikSync.activate(b)
   assertFalse(BootikSync.automaticAllowed(a));assertFalse(BootikSync.automaticAllowed(b))
   assertTrue(BootikSync.runActive(a.workId));assertEquals(0,BootikSync.flush(a))
  }finally{BootikSync.deactivate(a);BootikSync.deactivate(b);db.close()}
 }
 @Test fun stockReceiptCannotAcknowledgeSale(){
  val stock=BootikScopedEvent("stock-event","org","member","site",2,"{}")
  assertTrue(BootikReceiptPolicy.valid("BOOTIK","org","member","site","stock-event","sync-stock","acknowledged",stock,"sync-stock"))
  assertFalse(BootikReceiptPolicy.valid("BOOTIK","org","member","site","stock-event","sync-sale","acknowledged",stock,"sync-stock"))
  assertFalse(BootikReceiptPolicy.valid("BOOTIK","org","other","site","stock-event","sync-stock","acknowledged",stock,"sync-stock"))
 }
 @Test fun largeCatalogCacheAndGroupedReceipt()=runBlocking{
  val db=Room.inMemoryDatabaseBuilder(InstrumentationRegistry.getInstrumentation().targetContext,BootikLocalDatabase::class.java).build()
  try{
   val a=org.json.JSONArray();for(i in 1..5100)a.put(org.json.JSONObject().put("sku","SKU-"+i).put("name","Référence "+i).put("barcode",if(i==5100)"0012345678901" else ""))
   val d=db.scoped();d.cache(BootikCatalogCache("org","member","site",a.toString(),1));val loaded=org.json.JSONArray(d.catalog("org","member","site")!!.itemsJson);assertEquals(5100,loaded.length())
   val matches=(0 until loaded.length()).map{loaded.getJSONObject(it)}.filter{BootikCatalogSearch.matches(it.getString("barcode"),"0012345678901")};assertEquals(1,matches.size);assertEquals("SKU-5100",matches.first().getString("sku"))
   assertTrue(BootikCatalogSearch.matches("Étagère Z","etagere z"));assertNull(d.catalog("org","other","site"));d.cache(BootikCatalogCache("org","member@new","site","[]",2));assertEquals(1,d.purgeCatalogVersions("org","member","member@new"));assertNull(d.catalog("org","member","site"));assertNotNull(d.catalog("org","member@new","site"))
   val e=BootikScopedEvent("group","org","member","site",1,"{}")
   assertTrue(BootikReceiptPolicy.valid("BOOTIK","org","member","site","group","sync-item-sale","acknowledged",e,"sync-item-sale"))
   assertFalse(BootikReceiptPolicy.valid("BOOTIK","org","member","site","group","sync-sale","acknowledged",e,"sync-item-sale"))
  }finally{db.close()}
 }
 @Test fun scopedQueueAndCache()=runBlocking{
  val db=Room.inMemoryDatabaseBuilder(InstrumentationRegistry.getInstrumentation().targetContext,BootikLocalDatabase::class.java).build()
  try{
   val d=db.scoped();val e=BootikScopedEvent("event","org","member","site",1,"{}");d.enqueue(e)
   assertEquals(0,d.events("other","member","site").size);assertEquals(0,d.acknowledge("event","other","member","site","acknowledged"))
   assertFalse(BootikReceiptPolicy.valid("BOOTIK","org","other","site","event","sync-sale","acknowledged",e))
   assertTrue(BootikReceiptPolicy.valid("BOOTIK","org","member","site","event","sync-sale","acknowledged",e))
   assertEquals(1,d.acknowledge("event","org","member","site","conflict"));assertEquals(0,d.acknowledge("event","org","member","site","acknowledged"));assertEquals(1,d.discard("event","org","member","site"))
   d.cache(BootikCatalogCache("org","member","site","[]",1));assertNull(d.catalog("org","other","site"));assertEquals("[]",d.catalog("org","member","site")?.itemsJson)
  }finally{db.close()}
 }
}
