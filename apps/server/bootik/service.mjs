import {randomBytes,createHash,scrypt,timingSafeEqual} from 'node:crypto';
import {promisify} from 'node:util';
import {template,previewCsv} from './stock-import.mjs';
const derive=promisify(scrypt), digest=t=>createHash('sha256').update(t).digest('hex');
export async function verifier(password,salt){return (await derive(password,Buffer.from(salt,'hex'),64)).toString('hex')}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const validId=x=>typeof x==='string'&&uuid.test(x);
const allowed=new Set(['retailer','distributor']);
const plans=new Set(['access','premium']);
const kinds=new Set(['ticket','camera','alert','audio','video','screen']);
const reject=(status=400)=>({status,body:{error:status===401?'UNAUTHORIZED':'REQUEST_REJECTED'}});
// Adapted from NAXA Services inventory.ts / supplier form: explicit normalization, no implicit stock change.
const clean=(x,n,required=false)=>{if(typeof x!=='string')throw Error('INVALID_TEXT');const v=x.trim();if(v.length>n||(required&&!v))throw Error('INVALID_TEXT');return v};
function normalizeMaster(kind,p){
 const name=clean(p.name,160,true);
 if(kind==='item'){
  if(!Number.isSafeInteger(p.price_fcfa)||p.price_fcfa<0)throw Error('INVALID_PRICE');
  const lot=clean(p.lot_code??'',80),expiry=clean(p.expiry??'',10),location=clean(p.location??'',160);
  if(expiry&&(!lot||!/^\d{4}-\d{2}-\d{2}$/.test(expiry)))throw Error('INVALID_LOT');
  const minimum=p.minimum_quantity??0,target=p.target_quantity??0;
  if(![minimum,target].every(x=>typeof x==='number'&&Number.isFinite(x)&&x>=0&&x<=1000000000&&Math.abs(x*1000000-Math.round(x*1000000))<0.001)||target<minimum||(minimum>0&&target===0))throw Error('INVALID_THRESHOLDS');
  return {name,sku:clean(p.sku,80,true).toUpperCase(),unit:clean(p.unit,40,true),barcode:clean(p.barcode??'',80),price_fcfa:p.price_fcfa,lot_code:lot,expiry,location,minimum_quantity:minimum,target_quantity:target};
 }
 const phone=clean(p.phone??'',32),email=clean(p.email??'',160);
 if(email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw Error('INVALID_EMAIL');
 if(kind==='customer')return {name,phone,email};
 const whatsapp=clean(p.whatsapp??'',32).replace(/\D/g,'');
 if(whatsapp&&!/^\d{9,15}$/.test(whatsapp))throw Error('INVALID_WHATSAPP');
 if(!Number.isInteger(p.terms_days)||p.terms_days<0||p.terms_days>365)throw Error('INVALID_TERMS');
 return {name,phone,email,whatsapp,terms_days:p.terms_days};
}
export function createBootikService(db,{now=Date.now}={}){
 const attempts=new Map();
 const query=(q,p=[])=>db.query(q,p);
 const first=async(q,p)=> (await query(q,p)).rows[0];
 async function sites(s){return (await query('select l.id,l.display_name as name from bootik.bk_member_sites ms join bootik.bk_locations l on l.id=ms.location_id and l.organization_id=ms.organization_id and l.app_id=ms.app_id where ms.organization_id=$1 and ms.app_id=$2 and ms.user_id=$3 order by l.id',[s.organization_id,s.app_id,s.user_id])).rows}
 async function identity(token){
  if(typeof token!=='string'||!/^[0-9a-f]{64}$/.test(token))return null;
  return first('select s.organization_id,s.app_id,s.user_id,m.role,s.expires_at from bootik.bk_sessions s join bootik.bk_members m using(organization_id,app_id,user_id) where s.token_hash=$1 and s.revoked_at is null and s.expires_at>now() and m.active',[digest(token)]);
 }
 return async function handle(route,body,token,rateKey='local'){
 try{
  if(!body||body.app_id!=='BOOTIK')return reject();
  if(route==='login'||route==='recovery'){
   if(typeof body.identifier!=='string'||body.identifier.trim().length<1||body.identifier.length>160)return reject();
   const t=now();for(const [k,v] of attempts)if(v.until<=t)attempts.delete(k);
   if(attempts.size>=10000&&!attempts.has(rateKey))return reject(429);
   const bucket=attempts.get(rateKey)||{count:0,until:t+60000};bucket.count++;attempts.set(rateKey,bucket);if(bucket.count>10)return reject(429);
   const identifier=body.identifier.trim().toLowerCase();
   if(route==='recovery'){await query('insert into bootik.bk_recovery_requests(identifier) values($1)',[identifier]);return {status:204,body:{}}}
   if(typeof body.password!=='string'||body.password.length<1||body.password.length>256)return reject();
   const row=await first('select c.*,m.role from bootik.bk_credentials c join bootik.bk_members m using(organization_id,app_id,user_id) where c.identifier=$1 and m.active',[identifier]);
   const actual=await verifier(body.password,row?.salt_hex||'00000000000000000000000000000000');
   if(!row||!timingSafeEqual(Buffer.from(actual,'hex'),Buffer.from(row.verifier_hex,'hex')))return reject(401);
   const permitted=await sites(row);if(!permitted.length)return reject(401);
   const raw=randomBytes(32).toString('hex'), refresh=body.remember_device===true?randomBytes(32).toString('hex'):null;
   const s=await first("insert into bootik.bk_sessions(token_hash,organization_id,app_id,user_id,expires_at,refresh_hash,refresh_expires_at) values($1,$2,$3,$4,now()+interval '15 minutes',$5,case when $5::text is null then null else now()+interval '30 days' end) returning expires_at",[digest(raw),row.organization_id,row.app_id,row.user_id,refresh?digest(refresh):null]);
   return {status:200,body:{app_id:'BOOTIK',access_token:raw,organization_id:row.organization_id,member_id:row.user_id,role:row.role,sites:permitted,expires_at:new Date(s.expires_at).getTime(),...(refresh?{refresh_token:refresh}:{})}};
  }
  if(route==='refresh'){
   if(typeof body.refresh_token!=='string'||!/^[0-9a-f]{64}$/.test(body.refresh_token))return reject(401);
   const raw=randomBytes(32).toString('hex'),refresh=randomBytes(32).toString('hex');
   const s=await first("update bootik.bk_sessions s set token_hash=$1,expires_at=now()+interval '15 minutes',refresh_hash=$2 from bootik.bk_members m where s.refresh_hash=$3 and s.revoked_at is null and s.refresh_expires_at>now() and m.organization_id=s.organization_id and m.app_id=s.app_id and m.user_id=s.user_id and m.active returning s.organization_id,s.app_id,s.user_id,s.expires_at,m.role",[digest(raw),digest(refresh),digest(body.refresh_token)]);
   if(!s)return reject(401);const permitted=await sites(s);if(!permitted.length)return reject(401);
   return {status:200,body:{app_id:'BOOTIK',access_token:raw,refresh_token:refresh,organization_id:s.organization_id,member_id:s.user_id,role:s.role,sites:permitted,expires_at:new Date(s.expires_at).getTime()}};
  }
  if(route==='logout'){
   const raw=typeof token==='string'&&/^[0-9a-f]{64}$/.test(token)?digest(token):null;
   const refresh=typeof body.refresh_token==='string'&&/^[0-9a-f]{64}$/.test(body.refresh_token)?digest(body.refresh_token):null;
   if(!raw&&!refresh)return reject(401);
   await query('update bootik.bk_sessions set revoked_at=now() where revoked_at is null and (token_hash=$1 or refresh_hash=$2)',[raw,refresh]);return {status:204,body:{}};
  }
  const s=await identity(token);if(!s)return reject(401);
  if(route!=='operation'||!validId(body.site_id)||!body.payload||typeof body.payload!=='object'||Array.isArray(body.payload))return reject();
  const site=body.site_id,p=body.payload,action=body.action;
  const scope=[s.organization_id,s.app_id,s.user_id,site];
  await query('select bootik.bk_assert_scope($1,$2,$3,$4)',scope);
  let result;
  if(action==='entitlement'&&allowed.has(p.universe))result=await first('select bootik.bk_has_entitlement($1,$2,$3) as active',[s.organization_id,s.app_id,p.universe]);
  else if(action==='trial'&&allowed.has(p.universe)&&plans.has(p.plan))result=await first('select bootik.bk_start_trial($1,$2,$3,$4,$5,$6) as expires_at',[...scope,p.universe,p.plan]);
  else if(action==='payment-intent'&&allowed.has(p.universe)&&plans.has(p.plan)&&[1,12].includes(p.months)&&['mtn_momo','orange_money'].includes(p.channel)&&validId(p.request_key)){
   const i=await first('select bootik.bk_prepare_subscription($1,$2,$3,$4,$5,$6,$7,$8,$9) as id',[...scope,p.universe,p.plan,p.months,p.channel,p.request_key]);
   result=await first('select id,amount_fcfa,channel,destination,beneficiary,instructions,expires_at,state from bootik.bk_payment_intents where id=$1',[i.id]);
  }
  else if(action==='payment-current'&&allowed.has(p.universe)){
   result={intent:await first("select id,amount_fcfa,channel,destination,beneficiary,instructions,expires_at,state,paid_period_id from bootik.bk_payment_intents where organization_id=$1 and app_id=$2 and user_id=$3 and location_id=$4 and universe=$5 order by created_at desc limit 1",[...scope,p.universe])||null};
  }
  else if(action==='payment-status'&&validId(p.intent_id)){
   result=await first('select id,amount_fcfa,channel,destination,beneficiary,instructions,expires_at,state,paid_period_id from bootik.bk_payment_intents where id=$1 and organization_id=$2 and app_id=$3 and user_id=$4 and location_id=$5',[p.intent_id,...scope]);
   if(!result)return reject(403);
  }
  else if(action==='payment-debit'&&validId(p.intent_id)&&p.direction==='payer_debit'&&p.success===true&&typeof p.reference==='string'&&Number.isSafeInteger(p.amount_fcfa)&&typeof p.destination==='string'&&typeof p.provider_at==='string'&&typeof p.evidence_sha==='string'){
   result=await first('select bootik.bk_submit_debit($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as accepted',[...scope,p.intent_id,p.reference,p.amount_fcfa,p.destination,p.provider_at,p.evidence_sha]);
  }
  else if(action==='support'&&kinds.has(p.kind)&&typeof p.consent==='boolean')result=await first('select bootik.bk_request_support($1,$2,$3,$4,$5,$6) as request_id',[...scope,p.kind,p.consent]);
  else if(action==='support-cancel'&&validId(p.request_id))result=await first('select bootik.bk_cancel_support($1,$2,$3,$4,$5) as cancelled',[...scope,p.request_id]);
  else if(action==='sync-stock'&&validId(p.balance_id)&&validId(p.idempotency_key)&&['receipt','loss','count'].includes(p.stock_kind)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>=0&&typeof p.expected_version==='string'&&typeof p.reason==='string'){
   const receipt={app_id:'BOOTIK',organization_id:s.organization_id,member_id:s.user_id,site_id:site,action,event_id:p.idempotency_key};
   try{if(p.landed_cost_fcfa!=null&&(!Number.isSafeInteger(p.landed_cost_fcfa)||p.landed_cost_fcfa<0||p.stock_kind!=='receipt'))return reject();const v=await first('select bootik.bk_record_stock_event($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) as stock_event_id',[...scope,p.balance_id,p.idempotency_key,p.stock_kind,p.quantity,p.expected_version,p.reason,p.landed_cost_fcfa??null]);return {status:200,body:{...receipt,state:'acknowledged',result:v}}}
   catch(e){if(e?.code==='42501')return {status:200,body:{...receipt,state:'rejected',result:{reason:'BOOTIK_SCOPE_DENIED'}}};
    if(['BOOTIK_IDEMPOTENCY_CONFLICT','BOOTIK_STOCK_INSUFFICIENT','BOOTIK_STOCK_VERSION_CONFLICT','BOOTIK_LOT_UNAVAILABLE','BOOTIK_ENTITLEMENT_REQUIRED','BOOTIK_BALANCE_DENIED','BOOTIK_ACTIVITY_INACTIVE','BOOTIK_ITEM_UNAVAILABLE','BOOTIK_STOCK_EVENT_INVALID'].includes(e?.message))return {status:200,body:{...receipt,state:'conflict',result:{reason:e.message}}};throw e}
  }
  else if(action==='sync-item-sale'&&validId(p.item_id)&&validId(p.idempotency_key)&&typeof p.unit_code==='string'&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>0&&Number.isSafeInteger(p.unit_price_fcfa)&&p.unit_price_fcfa>=0){
   const scopedReceipt={app_id:'BOOTIK',organization_id:s.organization_id,member_id:s.user_id,site_id:site,action,event_id:p.idempotency_key};
   try{const v=await first('select bootik.bk_sell_item($1,$2,$3,$4,$5,$6,$7,$8,$9) as sale_group_id',[...scope,p.item_id,p.idempotency_key,p.unit_code,p.quantity,p.unit_price_fcfa]);return {status:200,body:{...scopedReceipt,state:'acknowledged',result:v}}}
   catch(e){if(e?.code==='42501')return {status:200,body:{...scopedReceipt,state:'rejected',result:{reason:'BOOTIK_SCOPE_DENIED'}}};if(['BOOTIK_IDEMPOTENCY_CONFLICT','BOOTIK_STOCK_INSUFFICIENT','BOOTIK_PRICE_MISMATCH','BOOTIK_LOT_UNAVAILABLE','BOOTIK_ENTITLEMENT_REQUIRED','BOOTIK_ACTIVITY_INACTIVE','BOOTIK_ITEM_UNAVAILABLE','BOOTIK_FRACTIONAL_XAF','BOOTIK_INVALID_SALE','BOOTIK_INVALID_UNIT','BOOTIK_FEFO_REQUIRED'].includes(e?.message))return {status:200,body:{...scopedReceipt,state:'conflict',result:{reason:e.message}}};throw e}
  }
  else if(action==='stock-setup'&&validId(p.item_id)&&validId(p.request_id)&&['lot','unit'].includes(p.kind)){
   let data;
   if(p.kind==='lot'){data={lot_code:clean(p.lot_code,80,true),expiry:clean(p.expiry??'',10),origin:clean(p.origin??'',160)};if(data.expiry&&!/^\d{4}-\d{2}-\d{2}$/.test(data.expiry))return reject()}
   else{if(typeof p.factor!=='number'||!Number.isFinite(p.factor)||p.factor<=0)return reject();data={unit_code:clean(p.unit_code,40,true),factor:p.factor}}
   result=await first('select bootik.bk_setup_stock($1,$2,$3,$4,$5,$6,$7,$8::jsonb) as setup_id',[...scope,p.item_id,p.request_id,p.kind,JSON.stringify(data)]);
  }
  else if(action==='sync-sale'&&validId(p.balance_id)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>0&&Number.isSafeInteger(p.unit_price_fcfa)&&p.unit_price_fcfa>=0&&validId(p.idempotency_key)){
   const scopedReceipt={app_id:'BOOTIK',organization_id:s.organization_id,member_id:s.user_id,site_id:site,action,event_id:p.idempotency_key};
   try{const v=await first('select bootik.bk_record_sale($1,$2,$3,$4,$5,$6,$7,$8) as sale_id',[...scope,p.balance_id,p.quantity,p.unit_price_fcfa,p.idempotency_key]);return {status:200,body:{...scopedReceipt,state:'acknowledged',result:v}}}
   catch(e){if(e?.code==='42501')return {status:200,body:{...scopedReceipt,state:'rejected',result:{reason:'BOOTIK_SCOPE_DENIED'}}};const conflict=['BOOTIK_IDEMPOTENCY_CONFLICT','BOOTIK_STOCK_INSUFFICIENT','BOOTIK_PRICE_MISMATCH','BOOTIK_LOT_UNAVAILABLE','BOOTIK_ENTITLEMENT_REQUIRED','BOOTIK_BALANCE_DENIED','BOOTIK_ACTIVITY_INACTIVE','BOOTIK_ITEM_UNAVAILABLE','BOOTIK_FRACTIONAL_XAF','BOOTIK_INVALID_SALE','BOOTIK_FEFO_REQUIRED'];
    if(conflict.includes(e?.message))return {status:200,body:{...scopedReceipt,state:'conflict',result:{reason:e.message}}};throw e}
  }
  else if(action==='sale'&&validId(p.balance_id)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>0&&Number.isSafeInteger(p.unit_price_fcfa)&&p.unit_price_fcfa>=0&&validId(p.idempotency_key))result=await first('select bootik.bk_record_sale($1,$2,$3,$4,$5,$6,$7,$8) as sale_id',[...scope,p.balance_id,p.quantity,p.unit_price_fcfa,p.idempotency_key]);
  else if(action==='team'&&s.role!=='staff')result={members:(await query("select m.user_id,m.role,m.active from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) where m.organization_id=$1 and m.app_id=$2 and ms.location_id=$3 order by m.role,m.user_id",[s.organization_id,s.app_id,site])).rows};
  else if(action==='activities')result={activities:(await query("select a.id,a.display_name,a.profile_code,a.universe_code from bootik.bk_activities a join bootik.bk_activity_locations al on (al.activity_id,al.organization_id,al.app_id)=(a.id,a.organization_id,a.app_id) where a.organization_id=$1 and a.app_id=$2 and al.location_id=$4 and a.status='active' and bootik.bk_can_access_activity($1,$2,$3,$4,a.id) order by a.display_name",scope)).rows};
  else if(action==='master-create'&&validId(p.activity_id)&&validId(p.request_id)&&['item','customer','supplier'].includes(p.kind)){
   const data=normalizeMaster(p.kind,p);
   result=await first('select bootik.bk_create_master($1,$2,$3,$4,$5,$6,$7,$8) as entity_id',[...scope,p.activity_id,p.request_id,p.kind,data]);
  }
  else if(action==='partners'&&s.role!=='staff'&&validId(p.activity_id)){
   const permitted=await first('select bootik.bk_can_access_activity($1,$2,$3,$4,$5) and exists(select 1 from bootik.bk_activity_locations where organization_id=$1 and app_id=$2 and location_id=$4 and activity_id=$5) as permitted',[...scope,p.activity_id]);if(!permitted?.permitted)return reject(403);
   result={customers:(await query('select id,display_name,phone,email from bootik.bk_customers where organization_id=$1 and app_id=$2 and activity_id=$3 and status=\'active\' order by display_name,id limit 500',[s.organization_id,s.app_id,p.activity_id])).rows,suppliers:(await query('select id,display_name,phone,whatsapp_phone,email,payment_terms from bootik.bk_suppliers where organization_id=$1 and app_id=$2 and activity_id=$3 and status=\'active\' order by display_name,id limit 500',[s.organization_id,s.app_id,p.activity_id])).rows};
  }
  else if(action==='dashboard'&&s.role!=='staff')result=await first("select count(*)::text as sales_count,coalesce(sum(total_fcfa),0)::text as revenue_fcfa from bootik.bk_sales where organization_id=$1 and app_id=$2 and location_id=$4 and bootik.bk_can_access_activity($1,$2,$3,$4,activity_id) and created_at>=date_trunc('day',now() at time zone 'Africa/Douala') at time zone 'Africa/Douala' and created_at<=now()",scope);
  else if(['stock-template','stock-import-preview','stock-import-apply'].includes(action)&&validId(p.activity_id)&&s.role!=='staff'){
   const activity=await first("select a.profile_code,a.universe_code from bootik.bk_activities a join bootik.bk_activity_locations al on (al.activity_id,al.organization_id,al.app_id)=(a.id,a.organization_id,a.app_id) where a.organization_id=$1 and a.app_id=$2 and al.location_id=$4 and a.id=$5 and a.status='active' and bootik.bk_can_access_activity($1,$2,$3,$4,a.id)",[...scope,p.activity_id]);
   if(!activity)return reject(403);
   if(action==='stock-template')result={csv:template(activity.profile_code),profile:activity.profile_code};
   else {
    if(typeof p.csv!=='string'||p.csv.length>10000)return reject();
    const rows=previewCsv(activity.profile_code,p.csv,normalizeMaster);
    if(action==='stock-import-preview'){
     const valid=rows.filter(x=>x.status==='create'),existing=(await query("select sku,barcode from bootik.bk_catalog_items where organization_id=$1 and app_id=$2 and activity_id=$3 and (sku=any($4::text[]) or barcode=any($5::text[]))",[s.organization_id,s.app_id,p.activity_id,valid.map(x=>x.data.sku),valid.map(x=>x.data.barcode).filter(Boolean)])).rows;
     result={rows:rows.map(x=>x.status==='create'&&existing.some(v=>v.sku===x.data.sku||(x.data.barcode&&v.barcode===x.data.barcode))?{row:x.row,status:'reject',reason:'REFERENCE_EXISTANTE'}:x)};
    }else{
     if(!validId(p.batch_id)||rows.some(x=>x.status!=='create'))return reject();
     result=await first('select bootik.bk_apply_stock_import($1,$2,$3,$4,$5,$6,$7::jsonb) as report',[...scope,p.activity_id,p.batch_id,JSON.stringify(rows)]);
     result={...result,batch_id:p.batch_id};
    }
   }
  }
  else if(action==='count-batch'&&validId(p.batch_id)&&validId(p.activity_id)&&typeof p.reason==='string'&&Array.isArray(p.lines)&&p.lines.length>=1&&p.lines.length<=30&&p.lines.every(x=>x&&validId(x.balance_id)&&validId(x.event_id)&&typeof x.quantity==='number'&&Number.isFinite(x.quantity)&&x.quantity>=0&&typeof x.expected_version==='string')){
   result=await first('select bootik.bk_count_batch($1,$2,$3,$4,$5,$6,$7,$8::jsonb) as batch_id',[...scope,p.batch_id,p.activity_id,p.reason,JSON.stringify(p.lines.map(x=>({balance_id:x.balance_id,event_id:x.event_id,quantity:x.quantity,expected_version:x.expected_version})))]);
  }
  else if(action==='transfer-ship'&&validId(p.destination_site)&&validId(p.balance_id)&&validId(p.transfer_id)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>0&&typeof p.expected_version==='string'&&typeof p.reason==='string')result=await first('select bootik.bk_ship_transfer($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as transfer_id',[...scope,p.destination_site,p.balance_id,p.transfer_id,p.quantity,p.expected_version,p.reason]);
  else if(action==='transfer-receive'&&validId(p.transfer_id)&&validId(p.receipt_id)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>0&&typeof p.reason==='string')result=await first('select bootik.bk_receive_transfer($1,$2,$3,$4,$5,$6,$7,$8) as receipt_id',[...scope,p.transfer_id,p.receipt_id,p.quantity,p.reason]);
  else if(action==='transfers'&&s.role!=='staff')result={transfers:(await query("select t.id,t.source_site,t.destination_site,t.quantity,t.received,t.shipped_at,c.display_name,l1.display_name as source_name,l2.display_name as destination_name from bootik.bk_stock_transfers t join bootik.bk_catalog_items c on c.id=t.item_id join bootik.bk_locations l1 on l1.id=t.source_site join bootik.bk_locations l2 on l2.id=t.destination_site where t.organization_id=$1 and t.app_id=$2 and $4 in (t.source_site,t.destination_site) and bootik.bk_can_access_activity($1,$2,$3,$4,t.activity_id) order by t.shipped_at desc limit 200",scope)).rows};
  else if(action==='purchase-create'&&validId(p.order_id)&&validId(p.supplier_id)&&validId(p.balance_id)&&typeof p.reference==='string'&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&Number.isSafeInteger(p.unit_cost_fcfa)){
   result=await first('select bootik.bk_purchase_create($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as order_id',[...scope,p.order_id,p.supplier_id,p.balance_id,p.reference,p.quantity,p.unit_cost_fcfa]);
  }
  else if(action==='purchase-receive'&&validId(p.order_id)&&validId(p.receipt_id)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&Number.isSafeInteger(p.freight_fcfa)){
   result=await first('select bootik.bk_purchase_receive($1,$2,$3,$4,$5,$6,$7,$8) as receipt_id',[...scope,p.order_id,p.receipt_id,p.quantity,p.freight_fcfa]);
  }
  else if(action==='purchase-pay'&&validId(p.order_id)&&validId(p.payment_id)&&Number.isSafeInteger(p.amount_fcfa)&&['cash','bank','mobile_money'].includes(p.method)&&typeof p.reference==='string'){
   result=await first('select bootik.bk_purchase_pay($1,$2,$3,$4,$5,$6,$7,$8,$9) as payment_id',[...scope,p.order_id,p.payment_id,p.amount_fcfa,p.method,p.reference]);
  }
  else if(action==='purchases'&&validId(p.activity_id)&&s.role!=='staff'){
   const allowed=await first('select bootik.bk_can_access_activity($1,$2,$3,$4,$5) and exists(select 1 from bootik.bk_activity_locations where organization_id=$1 and app_id=$2 and location_id=$4 and activity_id=$5) as allowed',[...scope,p.activity_id]);if(!allowed?.allowed)return reject(403);
   result={orders:(await query("select o.id,o.reference,o.quantity,o.received_quantity,o.unit_cost_fcfa,o.received_amount_fcfa,o.paid_amount_fcfa,(o.received_amount_fcfa-o.paid_amount_fcfa) as payable_fcfa,case when o.quantity=o.received_quantity then 'received' when o.received_quantity>0 then 'partial' else 'ordered' end as state,c.display_name as item_name,s.display_name as supplier_name from bootik.bk_purchase_orders o join bootik.bk_inventory_balances b on b.id=o.balance_id join bootik.bk_catalog_items c on c.id=b.item_id join bootik.bk_suppliers s on s.id=o.supplier_id where o.organization_id=$1 and o.app_id=$2 and o.location_id=$4 and o.activity_id=$5 and bootik.bk_can_access_activity($1,$2,$3,$4,o.activity_id) order by o.created_at desc limit 201",[...scope,p.activity_id])).rows};if(result.orders.length>200)return reject(413);
  }
  else if(action==='stock-health'&&s.role!=='staff'){
   const rows=(await query("select c.id as item_id,c.sku,c.display_name,a.display_name as activity_name,coalesce(sum(b.quantity_on_hand),0)::text as quantity_on_hand,coalesce(sum(case when c.is_serialized or (b.lot_id is not null and (l.quality_state<>'available' or l.expires_at<current_date)) then 0 else greatest(0,b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged) end),0)::text as available,r.minimum_quantity,r.target_quantity,count(*) filter(where b.quantity_on_hand>0 and b.unit_cost_fcfa is null)::int as uncosted_balances,case when count(*) filter(where b.quantity_on_hand>0 and b.unit_cost_fcfa is null)>0 then null else round(coalesce(sum(b.quantity_on_hand*b.unit_cost_fcfa),0))::text end as valuation_fcfa,count(*) filter(where b.quantity_on_hand>0 and l.expires_at between current_date and current_date+30 and l.quality_state='available')::int as expiring_balances,count(*) filter(where b.quantity_on_hand>0 and (l.expires_at<current_date or l.quality_state<>'available'))::int as blocked_balances from bootik.bk_inventory_balances b join bootik.bk_catalog_items c on c.id=b.item_id and c.organization_id=b.organization_id and c.app_id=b.app_id and c.activity_id=b.activity_id join bootik.bk_activities a on a.id=b.activity_id and a.organization_id=b.organization_id and a.app_id=b.app_id left join bootik.bk_product_lots l on l.id=b.lot_id left join bootik.bk_reorder_policies r on (r.organization_id,r.app_id,r.activity_id,r.location_id,r.item_id)=(b.organization_id,b.app_id,b.activity_id,b.location_id,b.item_id) where b.organization_id=$1 and b.app_id=$2 and b.location_id=$4 and bootik.bk_can_access_activity($1,$2,$3,$4,b.activity_id) and a.status='active' and c.status='active' group by c.id,c.sku,c.display_name,a.display_name,r.minimum_quantity,r.target_quantity order by c.display_name,c.id limit 10001",scope)).rows;
   if(rows.length>10000)return reject(413);
   result={items:rows.map(x=>({...x,low_stock:x.minimum_quantity!=null&&Number(x.available)<=Number(x.minimum_quantity),suggested_quantity:x.target_quantity==null?null:Math.max(0,Number(x.target_quantity)-Number(x.available))}))};
  }
  else if(action==='catalog'){
   if(p.cursor!=null&&!validId(p.cursor))return reject();
   const rows=(await query("select b.id as balance_id,c.id as item_id,c.sku,c.barcode,c.display_name,c.base_unit_code,c.is_serialized,a.profile_code,a.id as activity_id,a.display_name as activity_name,l.lot_code,l.expires_at::text,l.quality_state,sl.label as storage_label,sl.location_code,b.quantity_on_hand,b.quantity_reserved,b.quantity_damaged,b.updated_at::text as stock_version,p.unit_price_fcfa,case when $6::boolean then b.unit_cost_fcfa else null end as unit_cost_fcfa,case when c.is_serialized or (b.lot_id is not null and (l.quality_state<>'available' or l.expires_at<current_date)) then 0 else greatest(0,b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged) end as available,r.minimum_quantity,r.target_quantity,(select coalesce(jsonb_agg(jsonb_build_object('unit_code',iu.unit_code,'factor',iu.to_base_factor) order by iu.unit_role,iu.unit_code),'[]'::jsonb) from bootik.bk_item_units iu where iu.item_id=c.id and iu.organization_id=c.organization_id and iu.app_id=c.app_id and iu.activity_id=c.activity_id and iu.unit_role in ('base','sale')) as sale_units from bootik.bk_inventory_balances b join bootik.bk_catalog_items c on (c.id,c.organization_id,c.activity_id,c.app_id)=(b.item_id,b.organization_id,b.activity_id,b.app_id) join bootik.bk_sale_prices p on (p.item_id,p.organization_id,p.activity_id,p.app_id)=(b.item_id,b.organization_id,b.activity_id,b.app_id) join bootik.bk_activities a on (a.id,a.organization_id,a.app_id)=(b.activity_id,b.organization_id,b.app_id) left join bootik.bk_product_lots l on (l.id,l.item_id,l.activity_id,l.organization_id,l.app_id)=(b.lot_id,b.item_id,b.activity_id,b.organization_id,b.app_id) left join bootik.bk_storage_locations sl on (sl.id,sl.organization_id,sl.activity_id,sl.location_id,sl.app_id)=(b.storage_location_id,b.organization_id,b.activity_id,b.location_id,b.app_id) left join bootik.bk_reorder_policies r on (r.organization_id,r.app_id,r.activity_id,r.location_id,r.item_id)=(b.organization_id,b.app_id,b.activity_id,b.location_id,b.item_id) where b.organization_id=$1 and b.app_id=$2 and b.location_id=$4 and bootik.bk_can_access_activity($1,$2,$3,$4,b.activity_id) and a.status='active' and c.status='active' and ($5::uuid is null or b.id>$5::uuid) order by b.id limit 501",[...scope,p.cursor??null,s.role!=='staff'])).rows;
   result={items:rows.slice(0,500),next_cursor:rows.length>500?rows[499].balance_id:null};
  }
  else return reject();
  return {status:200,body:{app_id:'BOOTIK',organization_id:s.organization_id,member_id:s.user_id,site_id:site,action,state:'acknowledged',result}};
 }catch(e){return reject(e?.code==='42501'?403:400)}
 }
}
