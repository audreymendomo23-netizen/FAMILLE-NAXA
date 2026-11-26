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

import {fetchCatalog,searchCatalog} from '../../apps/web/bootik/src/operations.mjs';
test('catalogue local 5100 fiches: pagination et recherche SKU/code/lot/emplacement',async()=>{
 const rows=Array.from({length:5100},(_,i)=>({balance_id:String(i+1),display_name:'Référence '+(i+1),sku:'SKU-'+(i+1),barcode:i===5099?'0012345678901':'',storage_label:i===5099?'Étagère Z':'',available:1,unit_price_fcfa:100}));
 const fake=async(url,opts)=>{const req=JSON.parse(opts.body);const offset=Number(req.payload.cursor??0);const items=rows.slice(offset,offset+500);return {ok:true,json:async()=>({...receipt,action:'catalog',result:{items,next_cursor:offset+500<rows.length?items.at(-1).balance_id:null}})}};
 const result=await fetchCatalog('https://example.test',s,'s',fake);assert.equal(result.length,5100);assert.equal(searchCatalog(result,'0012345678901')[0].sku,'SKU-5100');assert.equal(searchCatalog(result,'etagere z').length,1);
 await assert.rejects(fetchCatalog('https://example.test',s,'s',async()=>({ok:true,json:async()=>({...receipt,action:'catalog',result:{items:[rows[0]],next_cursor:'invalid'}})})));
});

import {profileColumns,template,parseCsv} from '../../apps/server/bootik/stock-import.mjs';
test('22 profils CSV et parser strict sans perte des zéros',()=>{assert.equal(Object.keys(profileColumns).length,22);for(const key of Object.keys(profileColumns)){assert.ok(template(key).includes('quantite_initiale'));assert.ok(profileColumns[key].every(x=>template(key).includes(x)))}assert.deepEqual(parseCsv('nom;code\n"Produit; A";00001'),[['nom','code'],['Produit; A','00001']]);assert.throws(()=>parseCsv('nom;code\n"non ferme'));});

test('grouped FEFO receipt cannot acknowledge a regular sale',async()=>{
 const e={eventId:'group',orgId:'o',memberId:'m',siteId:'s',aggregateType:'item-sale',payload:JSON.stringify({idempotency_key:'group',item_id:'i',unit_code:'pack',quantity:1})};const result={...receipt,action:'sync-item-sale',event_id:'group',result:{sale_group_id:'g'}};
 const sender=body=>async(url,opts)=>{assert.equal(JSON.parse(opts.body).action,'sync-item-sale');return {ok:true,json:async()=>body}};
 assert.equal((await syncEvent('https://example.test',s,'s',e,sender(result))).result.sale_group_id,'g');await assert.rejects(syncEvent('https://example.test',s,'s',e,sender({...result,action:'sync-sale'})));
});

import {permitsSite,permitsOffline} from '../../apps/web/bootik/src/session.mjs';
test('offline lease expires monotonically and rejects abnormal clock rollback',()=>{const x={sites:[{id:'s'}],server_now:100000,offline_until:160000,expires_at:200000,observed_wall:300000,observed_mono:1000};assert.equal(permitsOffline(x,'s',350000,51000),true);assert.equal(permitsOffline(x,'s',360000,61000),false);assert.equal(permitsSite(x,'s',360000,61000),true);assert.equal(permitsSite(x,'s',300000,61000),false);assert.equal(permitsSite(x,'other',350000,51000),false)});
