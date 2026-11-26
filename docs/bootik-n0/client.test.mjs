import {test} from 'node:test';import assert from 'node:assert/strict';import {operation,syncEvent} from '../../apps/web/bootik/src/operations.mjs';
const s={app_id:'BOOTIK',organization_id:'o',member_id:'m',access_token:'test-token',expires_at:Date.now()+600000,sites:[{id:'s'}]};
const receipt={app_id:'BOOTIK',organization_id:'o',member_id:'m',site_id:'s',action:'trial',state:'acknowledged',result:{expires_at:'test'}};
test('accepts scoped receipt',async()=>{const v=await operation('https://example.test',s,'s','trial',{universe:'retailer'},async(url,opts)=>{assert.equal(opts.headers.Authorization,'Bearer test-token');assert.equal(JSON.parse(opts.body).site_id,'s');return {ok:true,json:async()=>receipt}});assert.equal(v.expires_at,'test')});
test('rejects cross-site, wrong receipt and non-HTTPS',async()=>{const fetcher=async()=>({ok:true,json:async()=>({...receipt,organization_id:'other'})});await assert.rejects(operation('https://example.test',s,'other','trial',{},fetcher));await assert.rejects(operation('https://example.test',s,'s','trial',{},fetcher));await assert.rejects(operation('http://example.test',s,'s','trial',{},fetcher))});

test('stock receipts are bound to event type, member and site',async()=>{
 const session={...s,role:'manager'},e={eventId:'stock-event',orgId:'o',memberId:'m',siteId:'s',aggregateType:'stock',payload:JSON.stringify({idempotency_key:'stock-event',stock_kind:'receipt'})};
 const result={app_id:'BOOTIK',organization_id:'o',member_id:'m',site_id:'s',event_id:'stock-event',action:'sync-stock',state:'acknowledged',result:{stock_event_id:'stock-receipt'}};
 const sender=body=>async(url,opts)=>{assert.equal(JSON.parse(opts.body).action,'sync-stock');return {ok:true,json:async()=>body}};
 assert.equal((await syncEvent('https://example.test',session,'s',e,sender(result))).result.stock_event_id,'stock-receipt');
 await assert.rejects(syncEvent('https://example.test',session,'s',e,sender({...result,action:'sync-sale'})));
 await assert.rejects(syncEvent('https://example.test',session,'s',e,sender({...result,result:{sale_id:'different'}})));
 await assert.rejects(syncEvent('https://example.test',session,'s',e,sender({...result,member_id:'other'})));
 await assert.rejects(syncEvent('https://example.test',{...session,role:'staff'},'s',e,sender(result)));
});
