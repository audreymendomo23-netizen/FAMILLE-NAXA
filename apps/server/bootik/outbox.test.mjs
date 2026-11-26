import 'fake-indexeddb/auto';
import {test} from 'node:test';import assert from 'node:assert/strict';
import{enqueue,scoped,flush,verifyReceipt,discardConflict,loadCatalog,saveCatalog}from '../../web/bootik/src/outbox.ts';
test('persistent scoped catalog and sale queue',async()=>{
 const e={eventId:'event-one',orgId:'org',memberId:'member',siteId:'site',sequence:1,aggregateType:'sale',payload:'{}',state:'queued'};
 await enqueue(e);await enqueue(e);assert.equal((await scoped('org','member','site')).length,1);
 assert.equal((await scoped('other','member','site')).length,0);assert.equal((await scoped('org','other','site')).length,0);
 const receipt={app_id:'BOOTIK',event_id:e.eventId,organization_id:e.orgId,member_id:e.memberId,site_id:e.siteId,state:'conflict'};
 assert.throws(()=>verifyReceipt(e,{...receipt,member_id:'other'}));assert.throws(()=>verifyReceipt(e,{...receipt,app_id:'ZIPPLE'}));
 assert.equal(await flush({orgId:'org',memberId:'member',siteId:'site'},async()=>receipt,()=>true),1);
 assert.equal((await scoped('org','member','site'))[0].state,'conflict');
 assert.equal(await flush({orgId:'org',memberId:'member',siteId:'site'},async()=>{throw Error('must not send')},()=>true),0);
 await discardConflict(e);assert.equal((await scoped('org','member','site'))[0].state,'discarded');
 await saveCatalog('org','member','site',[{balance_id:'b'}]);assert.deepEqual((await loadCatalog('org','member','site')).items,[{balance_id:'b'}]);assert.deepEqual((await loadCatalog('org','other','site')).items,[]);
});
