// Dedicated GRILLAD gateway, adapted from the family accounting bearer/RPC pattern.
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const date=/^\d{4}-\d{2}-\d{2}$/;
const actions=new Set(['add_item','prepare','sell','cancel_sale','open_cash','close_cash','expense','target','change_price','attendance','ack_notice']);
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
   const phone=String(body.phone||'').replace(/[\s().-]/g,'');
   if(!/^\+[1-9]\d{7,14}$/.test(phone))return reply(400,{error:'INVALID_PHONE'});
   if(body.action==='recovery'){const x=await post('/functions/v1/famille-account-lifecycle',{action:'request_recovery',app_code:'grillad',phone});return x.ok?reply(200,{result:{requested:true}}):upstream(x)}
   if(typeof body.password!=='string'||body.password.length<1||body.password.length>256||!uuid.test(body.installation)||!['web','android'].includes(body.platform))return reply(400,{error:'INVALID_LOGIN'});
   const x=await post('/functions/v1/famille-account-lifecycle',{action:'login',app_code:'grillad',phone,password:body.password,installation_id:body.installation,platform:body.platform,device_label:'GRILLAD '+body.platform});
   if(!x.ok)return upstream(x);
   const s=x.result?.session;if(!s?.access_token||!s?.refresh_token||x.result?.user?.must_change_password)return reply(403,{error:'ACCOUNT_SETUP_REQUIRED'});
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
  if(!/^Bearer \S+$/.test(bearer))return reply(401,{error:'SESSION'});
  const token=bearer.slice(7);
  if(body.action==='logout'){const r=await fetcher(base+'/auth/v1/logout?scope=local',{method:'POST',headers:{apikey:env.key,Authorization:bearer},redirect:'error',signal:AbortSignal.timeout(15000)});return r.ok?reply(200,{result:true}):reply(401,{error:'SESSION'});}
  // RPCs run under the caller token, never under service_role.
  if(body.action==='workspace')return upstream(await post('/rest/v1/rpc/grillad_workspace',{},token));
  if(!uuid.test(body.org)||!uuid.test(body.site))return reply(400,{error:'SCOPE'});
  const scope={p_org:body.org,p_site:body.site};
  if(body.action==='snapshot'){
   if(!date.test(body.from)||!date.test(body.to))return reply(400,{error:'PERIOD'});
   return upstream(await post('/rest/v1/rpc/grillad_snapshot',{...scope,p_from:body.from,p_to:body.to},token));
  }
  if(body.action==='mutate'&&uuid.test(body.event)&&actions.has(body.operation)&&body.payload&&typeof body.payload==='object'&&!Array.isArray(body.payload))return upstream(await post('/rest/v1/rpc/grillad_action',{...scope,p_event:body.event,p_action:body.operation,p_payload:body.payload},token));
  return reply(400,{error:'ACTION'});
 }catch{return reply(503,{error:'SERVICE_UNAVAILABLE'});}
}
