import {randomBytes,createHash,scrypt,timingSafeEqual} from 'node:crypto';
import {promisify} from 'node:util';
const derive=promisify(scrypt), digest=t=>createHash('sha256').update(t).digest('hex');
export async function verifier(password,salt){return (await derive(password,Buffer.from(salt,'hex'),64)).toString('hex')}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const validId=x=>typeof x==='string'&&uuid.test(x);
const allowed=new Set(['retailer','distributor']);
const plans=new Set(['access','premium']);
const kinds=new Set(['ticket','camera','alert','audio','video','screen']);
const reject=(status=400)=>({status,body:{error:status===401?'UNAUTHORIZED':'REQUEST_REJECTED'}});
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
   const raw=randomBytes(32).toString('hex');
   const s=await first('insert into bootik.bk_sessions(token_hash,organization_id,app_id,user_id,expires_at) values($1,$2,$3,$4,now()+interval \'15 minutes\') returning expires_at',[digest(raw),row.organization_id,row.app_id,row.user_id]);
   return {status:200,body:{app_id:'BOOTIK',access_token:raw,organization_id:row.organization_id,member_id:row.user_id,role:row.role,sites:permitted,expires_at:new Date(s.expires_at).getTime()}};
  }
  const s=await identity(token);if(!s)return reject(401);
  if(route==='logout'){await query('update bootik.bk_sessions set revoked_at=now() where token_hash=$1',[digest(token)]);return {status:204,body:{}}}
  if(route!=='operation'||!validId(body.site_id)||!body.payload||typeof body.payload!=='object'||Array.isArray(body.payload))return reject();
  const site=body.site_id,p=body.payload,action=body.action;
  const scope=[s.organization_id,s.app_id,s.user_id,site];
  await query('select bootik.bk_assert_scope($1,$2,$3,$4)',scope);
  let result;
  if(action==='entitlement'&&allowed.has(p.universe))result=await first('select bootik.bk_has_entitlement($1,$2,$3) as active',[s.organization_id,s.app_id,p.universe]);
  else if(action==='trial'&&allowed.has(p.universe)&&plans.has(p.plan))result=await first('select bootik.bk_start_trial($1,$2,$3,$4,$5,$6) as expires_at',[...scope,p.universe,p.plan]);
  else if(action==='support'&&kinds.has(p.kind)&&typeof p.consent==='boolean')result=await first('select bootik.bk_request_support($1,$2,$3,$4,$5,$6) as request_id',[...scope,p.kind,p.consent]);
  else if(action==='support-cancel'&&validId(p.request_id))result=await first('select bootik.bk_cancel_support($1,$2,$3,$4,$5) as cancelled',[...scope,p.request_id]);
  else if(action==='sale'&&validId(p.balance_id)&&typeof p.quantity==='number'&&Number.isFinite(p.quantity)&&p.quantity>0&&Number.isSafeInteger(p.unit_price_fcfa)&&p.unit_price_fcfa>=0&&validId(p.idempotency_key))result=await first('select bootik.bk_record_sale($1,$2,$3,$4,$5,$6,$7,$8) as sale_id',[...scope,p.balance_id,p.quantity,p.unit_price_fcfa,p.idempotency_key]);
  else if(action==='catalog')result={items:(await query('select b.id as balance_id,c.display_name,b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged as available,p.unit_price_fcfa from bootik.bk_inventory_balances b join bootik.bk_catalog_items c on c.id=b.item_id and c.organization_id=b.organization_id and c.activity_id=b.activity_id and c.app_id=b.app_id join bootik.bk_sale_prices p on p.item_id=b.item_id and p.organization_id=b.organization_id and p.activity_id=b.activity_id and p.app_id=b.app_id where b.organization_id=$1 and b.app_id=$2 and b.location_id=$3 and c.status=\'active\' order by c.display_name limit 500',[s.organization_id,s.app_id,site])).rows};
  else return reject();
  return {status:200,body:{app_id:'BOOTIK',organization_id:s.organization_id,site_id:site,action,state:'acknowledged',result}};
 }catch(e){return reject(e?.code==='42501'?403:400)}
 }
}
