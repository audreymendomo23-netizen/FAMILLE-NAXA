import {permitsSite} from './session.mjs';
const actions=new Set(['entitlement','trial','sale','support','support-cancel','catalog','payment-intent','payment-current','payment-status','payment-debit','team','activities','master-create','partners','dashboard','count-batch','transfer-ship','transfer-receive','transfers','stock-template','stock-import-preview','stock-import-apply','stock-setup','stock-health','purchases','purchase-create','purchase-receive','purchase-pay']);
export async function operation(base,session,site,action,payload,fetcher=fetch){
 if(!permitsSite(session,site)||session.app_id!=='BOOTIK'||!actions.has(action))throw Error('SCOPE_DENIED');
 const url=new URL(base.replace(/\/$/,'')+'/operation');
 if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash)throw Error('INVALID_API');
 const res=await fetcher(url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+session.access_token},body:JSON.stringify({app_id:'BOOTIK',site_id:site,action,payload}),cache:'no-store',redirect:'error'});
 if(!res.ok)throw Error('REQUEST_REJECTED');
 const j=await res.json();
 if(j.app_id!=='BOOTIK'||j.organization_id!==session.organization_id||j.member_id!==session.member_id||j.site_id!==site||j.action!==action||j.state!=='acknowledged'||!j.result||typeof j.result!=='object')throw Error('INVALID_RECEIPT');
 return j.result;
}

export async function syncEvent(base,session,site,event,fetcher=fetch){
 if(!permitsSite(session,site)||session.app_id!=='BOOTIK'||event.orgId!==session.organization_id||event.memberId!==session.member_id||event.siteId!==site||!['sale','stock','item-sale'].includes(event.aggregateType))throw Error('SCOPE_DENIED');
 const payload=JSON.parse(event.payload);if(payload.idempotency_key!==event.eventId)throw Error('EVENT_MISMATCH');
 const action=event.aggregateType==='stock'?'sync-stock':event.aggregateType==='item-sale'?'sync-item-sale':'sync-sale',resultKey=event.aggregateType==='stock'?'stock_event_id':event.aggregateType==='item-sale'?'sale_group_id':'sale_id';
 if(event.aggregateType==='stock'&&(!['receipt','loss','count'].includes(payload.stock_kind)||session.role==='staff'))throw Error('SCOPE_DENIED');
 if(event.aggregateType!=='stock'&&payload.stock_kind!==undefined)throw Error('EVENT_MISMATCH');
 const url=new URL(base.replace(/\/$/,'')+'/operation');if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash)throw Error('INVALID_API');
 const res=await fetcher(url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+session.access_token},body:JSON.stringify({app_id:'BOOTIK',site_id:site,action,payload}),cache:'no-store',redirect:'error'});
 if(!res.ok)throw Error('SYNC_RETRY_REQUIRED');
 const j=await res.json();if(j.app_id!=='BOOTIK'||j.organization_id!==event.orgId||j.member_id!==event.memberId||j.site_id!==site||j.event_id!==event.eventId||j.action!==action||!['acknowledged','conflict','rejected'].includes(j.state)||(j.state==='acknowledged'&&(typeof j.result?.[resultKey]!=='string'||!j.result[resultKey])))throw Error('INVALID_RECEIPT');
 return j;
}

export async function syncSale(base,session,site,event,fetcher=fetch){if(event.aggregateType!=='sale')throw Error('EVENT_MISMATCH');return syncEvent(base,session,site,event,fetcher)}

export async function fetchCatalog(base,session,site,fetcher=fetch){
 const items=[],seen=new Set();let cursor=null;
 for(let page=0;page<200;page++){
  const v=await operation(base,session,site,'catalog',cursor?{cursor}:{},fetcher);
  if(!Array.isArray(v.items)||v.items.length>500)throw Error('INVALID_CATALOG');
  for(const i of v.items){if(typeof i.balance_id!=='string'||seen.has(i.balance_id)||typeof i.display_name!=='string'||!Number.isFinite(Number(i.available))||!Number.isSafeInteger(Number(i.unit_price_fcfa)))throw Error('INVALID_CATALOG');seen.add(i.balance_id);items.push(i)}
  if(v.next_cursor===null)return items;
  if(typeof v.next_cursor!=='string'||!v.items.length||v.next_cursor!==v.items.at(-1).balance_id||v.next_cursor===cursor)throw Error('INVALID_CATALOG_CURSOR');cursor=v.next_cursor;
 }throw Error('CATALOG_TOO_LARGE');
}
export const searchCatalog=(items,query)=>{const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();const q=norm(query).trim();return q?items.filter(i=>[i.display_name,i.sku,i.barcode,i.lot_code,i.storage_label,i.location_code,i.activity_name].some(v=>norm(v).includes(q))):items};
