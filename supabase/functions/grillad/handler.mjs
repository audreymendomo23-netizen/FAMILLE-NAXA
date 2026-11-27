// Dedicated GRILLAD gateway, adapted from the family accounting bearer/RPC pattern.
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const date=/^\d{4}-\d{2}-\d{2}$/;
const actions=new Set(['add_item','prepare','sell','cancel_sale','open_cash','close_cash','expense','target','change_price']);
export async function handle(request,env,fetcher=fetch){
 const origin=request.headers.get('origin');const allowed=env.origins||[];
 const headers={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin','Access-Control-Allow-Methods':'POST, OPTIONS','Access-Control-Allow-Headers':'authorization, apikey, content-type'};
 if(origin&&allowed.includes(origin))headers['Access-Control-Allow-Origin']=origin;
 const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers});
 if(origin&&!allowed.includes(origin))return reply(403,{error:'ORIGIN_DENIED'});
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method!=='POST')return reply(405,{error:'METHOD'});
 const base=(env.url||'').replace(/\/$/,'');if(!/^https?:\/\/[^/]+$/.test(base)||!env.key)return reply(503,{error:'NOT_CONFIGURED'});
 let body;try{const raw=await request.text();if(raw.length>700000)return reply(413,{error:'TOO_LARGE'});body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))throw Error()}catch{return reply(400,{error:'INVALID_BODY'})}
 const bearer=request.headers.get('authorization')||'';
 async function post(path,data,token=env.key){
  const r=await fetcher(base+path,{method:'POST',headers:{apikey:env.key,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(data),redirect:'error',signal:AbortSignal.timeout(15000)});
  const result=await r.json().catch(()=>null);
  return {status:r.status,ok:r.ok,result};
 }
 function upstream(x){return x.ok?reply(200,{result:x.result}):reply(x.status===401?401:x.status===403||x.result?.code==='42501'?403:x.status===429?429:x.status>=500?503:400,{error:x.result?.code==='42501'?'ACCESS_DENIED':'OPERATION_REFUSED'});}
 try{
  if(body.action==='login'||body.action==='recovery'){
   if(!env.service)return reply(503,{error:'AUTH_NOT_CONFIGURED'});
   const phone=String(body.phone||'').replace(/[\s().-]/g,'');
   if(!/^\+[1-9]\d{7,14}$/.test(phone))return reply(400,{error:'INVALID_PHONE'});
   const recovery=body.action==='recovery';
   if(!recovery&&(typeof body.password!=='string'||body.password.length<1||body.password.length>256||!uuid.test(body.installation)||!['web','android'].includes(body.platform)))return reply(400,{error:'INVALID_LOGIN'});
   const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('grillad:'+phone));const hash=Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('');
   async function control(path,data){const r=await fetcher(base+'/rest/v1/rpc/'+path,{method:'POST',headers:{apikey:env.service,Authorization:'Bearer '+env.service,'Content-Type':'application/json'},body:JSON.stringify(data),redirect:'error',signal:AbortSignal.timeout(15000)});return r.ok&&await r.json()===true}
   const allowed=await control('grillad_auth_begin',{p_hash:hash,p_recovery:recovery});
   if(recovery)return reply(200,{result:{requested:true}});
   if(!allowed)return reply(429,{error:'TEMPORARILY_LOCKED'});
   const x=await post('/auth/v1/token?grant_type=password',{phone,password:body.password});
   if(!x.ok)return reply(401,{error:'INVALID_CREDENTIALS'});
   const s=x.result;if(!s?.access_token||!s?.refresh_token||!uuid.test(s.user?.id)||s.user?.app_metadata?.must_change_password)return reply(403,{error:'ACCOUNT_SETUP_REQUIRED'});
   let sid;try{sid=JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).session_id}catch{return reply(403,{error:'SESSION'})}
   if(!uuid.test(sid)||!await control('grillad_auth_finish',{p_hash:hash,p_user:s.user.id,p_session:sid,p_installation:body.installation,p_platform:body.platform}))return reply(403,{error:'DEVICE_OR_GRANT_DENIED'});
   const w=await post('/rest/v1/rpc/grillad_workspace',{},s.access_token);
   if(!w.ok||!Array.isArray(w.result)||!w.result.length)return reply(403,{error:'NO_WORKSPACE'});
   return reply(200,{result:{access:s.access_token,refresh:s.refresh_token,sites:w.result}});
  }
  if(body.action==='refresh'){
   if(typeof body.refresh!=='string'||body.refresh.length<10||body.refresh.length>8192)return reply(400,{error:'INVALID_REFRESH'});
   const x=await post('/auth/v1/token?grant_type=refresh_token',{refresh_token:body.refresh});
   if(!x.ok)return upstream(x);const s=x.result;
   if(!s?.access_token||!s?.refresh_token)return reply(401,{error:'SESSION'});
   const w=await post('/rest/v1/rpc/grillad_workspace',{},s.access_token);
   if(!w.ok||!Array.isArray(w.result)||!w.result.length)return reply(403,{error:'NO_WORKSPACE'});
   return reply(200,{result:{access:s.access_token,refresh:s.refresh_token,sites:w.result}});
  }
  if(['connect_catalog','connect_submit','connect_status'].includes(body.action)){
   if(!env.service||typeof body.qr!=='string'||!/^[A-Za-z0-9_-]{32,128}$/.test(body.qr))return reply(403,{error:'PARTNER_UNAVAILABLE'});
   const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.qr));const hash=Array.from(new Uint8Array(bytes),x=>x.toString(16).padStart(2,'0')).join('');
   let rpc='grillad_connect_catalog',params={p_hash:hash};
   if(body.action==='connect_submit'){if(!uuid.test(body.order)||!Array.isArray(body.lines))return reply(400,{error:'ORDER'});rpc='grillad_connect_submit';params={...params,p_order:body.order,p_lines:body.lines}}
   if(body.action==='connect_status'){if(!uuid.test(body.order))return reply(400,{error:'ORDER'});rpc='grillad_connect_status';params={...params,p_order:body.order}}
   const r=await fetcher(base+'/rest/v1/rpc/'+rpc,{method:'POST',headers:{apikey:env.service,Authorization:'Bearer '+env.service,'Content-Type':'application/json'},body:JSON.stringify(params),redirect:'error',signal:AbortSignal.timeout(15000)});
   return upstream({ok:r.ok,status:r.status,result:await r.json().catch(()=>null)});
  }
  if(!/^Bearer \S+$/.test(bearer))return reply(401,{error:'SESSION'});
  const token=bearer.slice(7);
  if(body.action==='logout'){const r=await fetcher(base+'/auth/v1/logout?scope=local',{method:'POST',headers:{apikey:env.key,Authorization:bearer},redirect:'error',signal:AbortSignal.timeout(15000)});return r.ok?reply(200,{result:true}):reply(401,{error:'SESSION'});}
  // RPCs run under the caller token, never under service_role.
  if(body.action==='workspace')return upstream(await post('/rest/v1/rpc/grillad_workspace',{},token));
  if(!uuid.test(body.org)||!uuid.test(body.site))return reply(400,{error:'SCOPE'});
  const scope={p_org:body.org,p_site:body.site};
  if(body.action==='security_list')return upstream(await post('/rest/v1/rpc/grillad_security_list',scope,token));
  if(body.action==='pilotage_status')return upstream(await post('/rest/v1/rpc/grillad_pilotage_status',scope,token));
  if(body.action==='report'&&date.test(body.from)&&date.test(body.to)&&typeof body.network==='boolean'&&(body.family==null||['Porc','Poulet','Poisson','Brochettes','Omelettes'].includes(body.family))&&(body.actor==null||uuid.test(body.actor))&&(body.item==null||uuid.test(body.item)))return upstream(await post('/rest/v1/rpc/grillad_report',{...scope,p_from:body.from,p_to:body.to,p_network:body.network,p_family:body.family??null,p_actor:body.actor??null,p_item:body.item??null},token));
  if(body.action==='connect_list')return upstream(await post('/rest/v1/rpc/grillad_connect_list',scope,token));
  if(body.action==='connect_transition'&&uuid.test(body.order)&&uuid.test(body.event)&&['accepted','preparing','ready','handed','refused','cancelled'].includes(body.next))return upstream(await post('/rest/v1/rpc/grillad_connect_transition',{...scope,p_order:body.order,p_event:body.event,p_next:body.next,p_received:body.received??null,p_reason:body.reason??null},token));
  if(body.action==='daily_list')return upstream(await post('/rest/v1/rpc/grillad_daily_list',scope,token));
  if(body.action==='notice_feed')return upstream(await post('/rest/v1/rpc/grillad_notice_feed',scope,token));
  if(body.action==='notice_ack'&&typeof body.id==='string'&&body.id.length<=100)return upstream(await post('/rest/v1/rpc/grillad_notice_ack',{...scope,p_id:body.id},token));
  if(body.action==='notice_set'&&['sales','stock','cash','daily','attendance','connect','security'].includes(body.category)&&typeof body.enabled==='boolean')return upstream(await post('/rest/v1/rpc/grillad_notice_set',{...scope,p_category:body.category,p_enabled:body.enabled},token));
  if(body.action==='attendance_status')return upstream(await post('/rest/v1/rpc/grillad_attendance_status',scope,token));
  if(body.action==='attendance_capture'&&uuid.test(body.event)&&['arrival','departure'].includes(body.kind)&&typeof body.at==='string'&&typeof body.lat==='number'&&typeof body.lon==='number'&&typeof body.accuracy==='number'&&typeof body.photo==='string')return upstream(await post('/rest/v1/rpc/grillad_attendance_capture',{...scope,p_event:body.event,p_kind:body.kind,p_at:body.at,p_lat:body.lat,p_lon:body.lon,p_accuracy:body.accuracy,p_photo:body.photo},token));
  if(body.action==='snapshot'){
   if(!date.test(body.from)||!date.test(body.to))return reply(400,{error:'PERIOD'});
   return upstream(await post('/rest/v1/rpc/grillad_snapshot',{...scope,p_from:body.from,p_to:body.to},token));
  }
  if(body.action==='mutate'&&uuid.test(body.event)&&actions.has(body.operation)&&body.payload&&typeof body.payload==='object'&&!Array.isArray(body.payload))return upstream(await post('/rest/v1/rpc/grillad_action',{...scope,p_event:body.event,p_action:body.operation,p_payload:body.payload},token));
  return reply(400,{error:'ACTION'});
 }catch{return reply(503,{error:'SERVICE_UNAVAILABLE'});}
}
