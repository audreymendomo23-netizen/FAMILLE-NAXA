// Candidate Supabase adapter. Based on NAXA Services internal identifier -> GoTrue alias.
import {createAuthHandler} from "../auth-boundary.mjs";
const enc=x=>encodeURIComponent(x);
const hash=async x=>Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(x)))).map(x=>x.toString(16).padStart(2,"0")).join("");
const token=()=>Array.from(crypto.getRandomValues(new Uint8Array(32))).map(x=>x.toString(16).padStart(2,"0")).join("");
const deny=()=>{throw Error("DENIED")};
const normalize=x=>x.trim().toLowerCase();
const loginId=x=>/^[a-z0-9][a-z0-9._+@-]{0,179}$/.test(x);
export function createSupabaseZipple({url,anonKey,serviceKey,origins=[],fetcher=fetch}){
 if(!url||!anonKey||!serviceKey)throw Error("MISSING_SERVER_CONFIG");
 const base=url.replace(/\/$/,"");
 async function call(path,{key=serviceKey,bearer=key,method="GET",body}={}){
  const r=await fetcher(base+path,{method,headers:{apikey:key,Authorization:"Bearer "+bearer,"Content-Type":"application/json"},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:"error"});
  if(!r.ok)deny();const t=await r.text();return t?JSON.parse(t):null;
 }
 const rpc=(name,body)=>call("/rest/v1/rpc/"+name,{method:"POST",body});
 async function issue(name,parameters,remember=true){
  const a=token(),f=remember?token():null;
  const identity=await rpc(name,{...parameters,p_access:await hash(a),p_refresh:f?await hash(f):null});
  if(!identity)deny();return {...identity,access_token:a,refresh_token:f};
 }
 const provider={
  rateLimit:async({action,identifier})=>{if(!await rpc("zp_rate_limit",{p_bucket:await hash(action+":"+normalize(identifier??"global"))}))deny()},
  authenticate:async({identifier,password,remember_device})=>{
   if(!loginId(normalize(identifier)))deny();
   const rows=await call("/rest/v1/zp_members?select=id,auth_user_id,auth_alias,credential_epoch&active=eq.true&reset_pending=eq.false&login_id=eq."+enc(normalize(identifier))+"&limit=2");
   if(!Array.isArray(rows)||rows.length!==1)deny();const m=rows[0];
   const auth=await call("/auth/v1/token?grant_type=password",{key:anonKey,method:"POST",body:{email:m.auth_alias,password}});
   if(!auth?.access_token||!auth?.user?.id)deny();
   // GoTrue authenticates credentials; its tokens must not leave this gateway.
   await call("/auth/v1/logout?scope=local",{key:anonKey,bearer:auth.access_token,method:"POST"});
   if(auth.user.id!==m.auth_user_id)deny();
   return issue("zp_issue",{p_member:m.id,p_auth_user:auth.user.id,p_epoch:m.credential_epoch},remember_device);
  },
  rotate:async({refresh_token})=>issue("zp_rotate",{p_previous:await hash(refresh_token)}),
  recover:async({identifier})=>{if(loginId(normalize(identifier)))await rpc("zp_recovery",{p_login:normalize(identifier)})},
  revoke:async({access_token})=>{if(!await rpc("zp_revoke",{p_access:await hash(access_token)}))deny()}
 };
 const auth=createAuthHandler(provider);
 return async req=>{
  const origin=req.headers.get("origin");const allowed=origin&&origins.includes(origin);
  const headers={"Cache-Control":"no-store","Vary":"Origin",...(allowed?{"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"authorization,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"}:{})};
  if(origin&&!allowed)return Response.json({error:"DENIED"},{status:403,headers});
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
  let res;
  if(new URL(req.url).pathname.includes("/admin/recovery/")){
   let claimed=false,operator,requestId,attempt;
   try{
    const raw=await req.text(),bearer=req.headers.get("authorization")??"";
    if(req.method!=="POST"||raw.length>8192||!bearer.startsWith("Bearer "))deny();
    const body=JSON.parse(raw);if(body.app_id!=="ZIPPLE")deny();
    const identity=await call("/auth/v1/user",{key:anonKey,bearer:bearer.slice(7)});
    operator=identity?.id;if(!operator)deny();
    const action=new URL(req.url).pathname.split("/").pop();
    if(action==="list"){res=Response.json({requests:await rpc("zp_admin_recovery_list",{p_operator:operator})})}
    else if(action==="complete"){
     if(typeof body.request_id!=="string"||typeof body.reason!=="string"||body.reason.trim().length<10||body.reason.length>500||typeof body.new_password!=="string"||body.new_password.length<12||body.new_password.length>128)deny();
     requestId=body.request_id;attempt=crypto.randomUUID();
     const target=await rpc("zp_admin_recovery_begin",{p_operator:operator,p_request:requestId,p_reason:body.reason.trim(),p_attempt:attempt});
     if(!target)deny();claimed=true;
     // Auth admin update is server-side only; no credential returned or logged.
     await call("/auth/v1/admin/users/"+enc(target),{method:"PUT",body:{password:body.new_password}});
     if(!await rpc("zp_admin_recovery_finish",{p_operator:operator,p_request:requestId,p_attempt:attempt,p_success:true}))deny();
     res=Response.json({resolved:true});
    }else deny();
   }catch{
    if(claimed){try{await rpc("zp_admin_recovery_finish",{p_operator:operator,p_request:requestId,p_attempt:attempt,p_success:false})}catch{/* account stays locked pending operator review */}}
    res=Response.json({error:"DENIED"},{status:403});
   }
  }else if(new URL(req.url).pathname.endsWith("/sync")){
   try{
    const raw=await req.text();if(req.method!=="POST"||raw.length>8192)deny();
    const b=JSON.parse(raw),bearer=req.headers.get("authorization")??"";
    if(!bearer.startsWith("Bearer ")||b.app_id!=="ZIPPLE"||b.aggregate_type!=="n1_probe"||typeof b.event_id!=="string"||b.event_id.length<1||b.event_id.length>128||!Number.isSafeInteger(b.sequence)||b.sequence<0||!b.payload||typeof b.payload!=="object")deny();
    const state=await rpc("zp_probe_receipt",{p_access:await hash(bearer.slice(7)),p_org:b.organization_id,p_member:b.member_id,p_site:b.site_id,p_event:b.event_id,p_digest:await hash(JSON.stringify([b.sequence,b.payload]))});
    if(!["acknowledged","conflict"].includes(state))deny();
    res=Response.json({app_id:"ZIPPLE",event_id:b.event_id,organization_id:b.organization_id,site_id:b.site_id,state});
   }catch{res=Response.json({error:"DENIED"},{status:403})}
  }else res=await auth(req);
  return new Response(res.body,{status:res.status,headers:{...Object.fromEntries(res.headers),...headers}});
 };
}
