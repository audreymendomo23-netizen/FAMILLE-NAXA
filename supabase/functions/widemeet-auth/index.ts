// WideMeet internal login candidate. Adapted from NS internal aliases and ZIPPLE opaque sessions.
// No deployment until disposable Replay and rate-limit qualification; default disabled.
import {chatMedia} from "./chat-media.ts";
import {encryptToken,validPushToken,serviceAccount,accessToken,dispatchPush} from "../../../packages/widemeet-domain/push-delivery.mjs";
const url=(Deno.env.get("SUPABASE_URL")??"").replace(/\/$/,"");
const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
const anon=Deno.env.get("SUPABASE_ANON_KEY")??"";
const origins=new Set((Deno.env.get("WM_ALLOWED_ORIGINS")??"").split(",").map(s=>s.trim()).filter(Boolean));
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const cookieName="__Host-widemeet_refresh";
const groupWatches=new Set<string>();
const refreshCookie=(value:string,remember:boolean,until:number)=>cookieName+"="+value+"; Path=/; Secure; HttpOnly; SameSite=Strict"+(remember?"; Max-Age="+Math.max(0,Math.floor((until-Date.now())/1000)):"");
const clearCookie=cookieName+"=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0";
function cookieRefresh(req:Request){const parts=(req.headers.get("cookie")??"").split(";").map(x=>x.trim()).filter(x=>x.startsWith(cookieName+"="));return parts.length===1?parts[0].slice(cookieName.length+1):"";}
const headers={apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"};
async function rest(path:string,init:RequestInit={}){
 const response=await fetch(url+"/rest/v1/"+path,{...init,headers:{...headers,...(init.headers??{})},redirect:"error",cache:"no-store"});
 if(!response.ok)throw new Error("backend_rejected");
 return response.status===204?null:await response.json();
}
function eq(v:string){return encodeURIComponent(v)}
// Separate support endpoint/key; never issue ordinary meeting grants for assistance.
async function supportGrant(admission:any,p_hash:string){
 const key=Deno.env.get("WM_SUPPORT_LIVEKIT_API_KEY")??"",secret=Deno.env.get("WM_SUPPORT_LIVEKIT_API_SECRET")??"";
 const endpoint=new URL(Deno.env.get("WM_SUPPORT_LIVEKIT_URL")??"");
 if(endpoint.protocol!=="wss:"||endpoint.username||endpoint.password||endpoint.pathname!=="/"||endpoint.search||endpoint.hash||!/^[A-Za-z0-9_-]{8,128}$/.test(key)||secret.length<32)throw Error("support_media_unavailable");
 const now=Date.now(),exp=Math.floor(Math.min(admission.endMs,now+60000)/1000);
 if(exp<=Math.floor(now/1000))throw Error("support_media_unavailable");
 const sources=admission.sources;
 if(!Array.isArray(sources)||!sources.includes("microphone")||sources.some((s:unknown)=>s!=="microphone"&&s!=="screen_share"))throw Error("support_media_unavailable");
 const enc=(v:Uint8Array)=>btoa(String.fromCharCode(...v)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
 const json=(v:unknown)=>enc(new TextEncoder().encode(JSON.stringify(v)));
 const claims={iss:key,sub:admission.identity,nbf:Math.floor(now/1000)-5,exp,wm_session_hash:p_hash,video:{room:admission.room,roomJoin:true,canPublish:true,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:sources,roomAdmin:false,roomCreate:false,roomRecord:false,roomList:false}};
 const k=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
 const data=json({alg:"HS256",typ:"JWT"})+"."+json(claims);
 const sig=await crypto.subtle.sign("HMAC",k,new TextEncoder().encode(data));
 return {url:endpoint.origin,token:data+"."+enc(new Uint8Array(sig)),expires_at:exp*1000};
}
async function digest(v:string){return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(v)))).map(n=>n.toString(16).padStart(2,"0")).join("")}
function token(){return Array.from(crypto.getRandomValues(new Uint8Array(32))).map(n=>n.toString(16).padStart(2,"0")).join("")}
async function workspaces(accountId:string){
 const rows=await rest("wm_memberships?select=workspace_id,role,enabled,wm_workspaces!inner(id,kind,name,enabled)&account_id=eq."+eq(accountId)+"&enabled=eq.true&wm_workspaces.enabled=eq.true");
 return rows.flatMap((r:any)=>{const w=r.wm_workspaces;return w&&((w.kind==="individual"&&r.role==="owner")||(w.kind==="enterprise"&&["promoteur","manager","staff"].includes(r.role)))?[{id:w.id,kind:w.kind,name:w.name,role:r.role,enabled:true}]:[]});
}
// Accept only a bounded JPEG thumbnail with a valid frame header. The private
// binary is never served as HTML/SVG or exposed through a public URL.
function thumbnail(v:unknown){
 if(typeof v!=="string"||v.length>87384||v.length%4!==0||!/^[A-Za-z0-9+/]+={0,2}$/.test(v))return false;
 try{
 const b=Uint8Array.from(atob(v),c=>c.charCodeAt(0));
 if(b.length<16||b.length>65536||b[0]!==255||b[1]!==216||b.at(-2)!==255||b.at(-1)!==217)return false;
 let pos=2,frame=false;
 while(pos<b.length-2){
  if(b[pos++]!==255)return false;
  while(b[pos]===255)pos++;
  const marker=b[pos++];
  if(pos+2>b.length)return false;
  const size=b[pos]*256+b[pos+1];
  if(size<2||pos+size>b.length-2)return false;
  if([192,193,194].includes(marker)){
   if(frame||size<11||b[pos+2]!==8)return false;
   const h=b[pos+3]*256+b[pos+4],w=b[pos+5]*256+b[pos+6],n=b[pos+7];
   if(!w||!h||w>512||h>512||![1,3].includes(n)||size!==8+3*n)return false;
   frame=true;
  }
  if(marker===218)return frame;
  pos+=size;
 }
 return false;
 }catch{return false}
}
Deno.serve(async request=>{
 const origin=request.headers.get("origin");
 const cors:Record<string,string>=origin&&origins.has(origin)?{"Access-Control-Allow-Origin":origin,"Vary":"Origin","Access-Control-Allow-Headers":"content-type,authorization,apikey","Access-Control-Allow-Methods":"POST,OPTIONS","Access-Control-Allow-Credentials":"true"}:{};
 const send=(status:number,body:unknown,extra:Record<string,string>={})=>new Response(status===204?null:JSON.stringify(body),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store",...cors,...extra}});
 if(origin&&!origins.has(origin))return send(403,{error:"forbidden"});
 if(request.method==="OPTIONS")return send(204,null);
 if(Deno.env.get("WM_AUTH_QUALIFIED")!=="true"||!url||!service||!anon)return send(503,{error:"unavailable"});
 if(request.method!=="POST")return send(405,{error:"method"});
 try{
 const action=new URL(request.url).pathname.split("/").filter(Boolean).at(-1);
 const limit=action==="chat-media"?1405000:action==="identity"?90000:16384;
 // Bound the streamed body before allocating/decode; normal identity limits are unchanged.
 const reader=request.body?.getReader();if(!reader)return send(400,{error:"invalid_request"});
 const decoder=new TextDecoder();let raw="",size=0;for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>limit){await reader.cancel().catch(()=>{});return send(413,{error:"request_too_large"})}raw+=decoder.decode(value,{stream:true})}raw+=decoder.decode();
 const body=JSON.parse(raw);
 if(!body||body.app_id!=="WIDEMEET")return send(403,{error:"forbidden"});
 if(action==="central"){
 if(Deno.env.get("WM_CENTRAL_QUALIFIED")!=="true"||!origin||origin!==Deno.env.get("WM_CENTRAL_ORIGIN"))return send(503,{error:"unavailable"});
 const jwt=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(jwt.length>8192||!/^[-_A-Za-z0-9]+\.[-_A-Za-z0-9]+\.[-_A-Za-z0-9]+$/.test(jwt))return send(401,{error:"credentials"});
 const verified=await fetch(url+"/auth/v1/user",{headers:{apikey:anon,Authorization:"Bearer "+jwt},redirect:"error",cache:"no-store"});
 if(!verified.ok)return send(401,{error:"credentials"});
 const user=await verified.json();
 const rawClaim=jwt.split(".")[1].replace(/-/g,"+").replace(/_/g,"/");
 const claims=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(rawClaim.padEnd(Math.ceil(rawClaim.length/4)*4,"=")),c=>c.charCodeAt(0))));
 if(claims.sub!==user.id||claims.iss!==url+"/auth/v1"||claims.role!=="authenticated"||claims.aal!=="aal2"||!uuid.test(claims.sub??"")||!uuid.test(claims.session_id??"")||!Number.isSafeInteger(claims.exp)||claims.exp*1000<=Date.now())return send(403,{error:"scope"});
 const name=body.action,data=body.data;
 if(typeof name!=="string"||!data||typeof data!=="object"||Array.isArray(data))return send(400,{error:"invalid_request"});
 const support=name.startsWith("support-"),mediaReady=Deno.env.get("WM_SUPPORT_MEDIA_QUALIFIED")==="true";
 if(support&&Deno.env.get("WM_SUPPORT_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 if(name==="support-call-grant"&&!mediaReady)return send(503,{error:"unavailable"});
 const handle=token();
 const v=await rest("rpc/wm_central_dispatch",{method:"POST",body:JSON.stringify({p_user:claims.sub,p_session:claims.session_id,p_exp:new Date(claims.exp*1000).toISOString(),p_new_hash:token(),p_action:name,p_data:name==="support-call-grant"?{...data,handle}:data})});
 if(!v)return send(403,{error:"scope"});
 if(name==="support-call-grant"){
 if(!uuid.test(data.call_id??"")||v.room!=="wm-support-"+data.call_id.toLowerCase()||!uuid.test(v.identity??"")||v.sources?.includes("screen_share"))return send(403,{error:"scope"});
 return send(200,await supportGrant(v,handle));
 }
 if(name==="capabilities")v.agent=v.agent===true&&Deno.env.get("WM_SUPPORT_QUALIFIED")==="true";
 if(support)v.transport_ready=mediaReady;
 return send(200,v);
 }
 if(action==="register"){
 if(Deno.env.get("WM_SIGNUP_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const domain=(Deno.env.get("WM_AUTH_ALIAS_DOMAIN")??"").trim().toLowerCase();
 if(!/^[a-z0-9.-]{3,100}$/.test(domain)||!domain.includes(".")||domain.startsWith(".")||domain.endsWith("."))return send(503,{error:"unavailable"});
 const display=typeof body.display_name==="string"?body.display_name.trim():"",kind=body.kind;
 const workspace=typeof body.workspace_name==="string"?body.workspace_name.trim():"";
 const password=body.password,version="wm-replay-draft-20261126";
 if(!uuid.test(body.installation_id??"")||!uuid.test(body.request_id??"")||!["individual","enterprise"].includes(kind)||!display||display.length>120||!workspace||workspace.length>120||typeof password!=="string"||password.length<12||password.length>256||body.accepted_terms!==true||body.terms_version!==version||body.privacy_version!==version)return send(400,{error:"invalid_registration"});
 const installation=body.installation_id.toLowerCase(),requestId=body.request_id.toLowerCase();
 const key=await digest("wm-registration:"+installation+":"+requestId);
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-signup-device:"+installation),p_installation_hash:await digest("wm-signup-global")})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 // Deterministic technical alias lets a retry recover a successful GoTrue create after a lost response.
 // No public email delivery, password/alias never persisted in browser or returned.
 const email="wm-"+key.slice(0,40)+"@"+domain;
 try{
 await fetch(url+"/auth/v1/admin/users",{method:"POST",headers:{apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"},body:JSON.stringify({email,password,email_confirm:true,app_metadata:{app_code:"widemeet",wm_registration_key:key}}),redirect:"error",cache:"no-store"});
 }catch{/* A lost response must be verified through GoTrue, never assumed successful. */}
 const verified=await fetch(url+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:anon,"Content-Type":"application/json"},body:JSON.stringify({email,password}),redirect:"error",cache:"no-store"});
 if(!verified.ok)return send(409,{error:"registration_unconfirmed"});
 const identity=(await verified.json()).user;
 if(!identity||!uuid.test(identity.id??"")||identity.app_metadata?.app_code!=="widemeet"||identity.app_metadata?.wm_registration_key!==key)return send(409,{error:"registration_unconfirmed"});
 const generated="WM-"+token().slice(0,20).toUpperCase();
 const loginId=await rest("rpc/wm_register_account",{method:"POST",body:JSON.stringify({p_installation:installation,p_request:requestId,p_auth_user:identity.id,p_login:generated,p_alias:email,p_display:display,p_kind:kind,p_workspace:workspace,p_terms:version,p_privacy:version})});
 if(typeof loginId!=="string"||!/^WM-[A-Z0-9]{8,24}$/.test(loginId))return send(503,{error:"registration_unconfirmed"});
 return send(200,{login_id:loginId,kind});
 }
 if(action==="recovery-enroll"){
 const supervised=body.supervised===true;
 if(supervised&&Deno.env.get("WM_SUPPORT_RECOVERY_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 if(Deno.env.get("WM_RECOVERY_KEY_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,""),password=body.current_password;
 if(!/^[a-f0-9]{64}$/.test(access)||typeof password!=="string"||!password||password.length>256)return send(400,{error:"invalid_request"});
 const p_hash=await digest(access),context=(await rest("rpc/wm_session_context",{method:"POST",body:JSON.stringify({p_hash})}))?.[0];
 if(!context||context.password_change_required)return send(403,{error:"scope"});
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-recovery-enroll:"+context.account_id),p_installation_hash:await digest("wm-recovery-enroll-device:"+context.installation_id)})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 const account=(await rest("wm_accounts?select=id,auth_user_id,auth_alias,credential_epoch&id=eq."+eq(context.account_id)+"&enabled=eq.true&limit=1"))?.[0];
 if(!account)return send(403,{error:"scope"});
 const proof=await fetch(url+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:anon,"Content-Type":"application/json"},body:JSON.stringify({email:account.auth_alias,password}),redirect:"error",cache:"no-store"});
 if(!proof.ok||(await proof.json()).user?.id!==account.auth_user_id)return send(401,{error:"credentials"});
 const recoveryKey=token();
 const enrolled=await rest(supervised?"rpc/wm_support_enroll_fallback":"rpc/wm_enroll_recovery_key",{method:"POST",body:JSON.stringify({p_hash,p_key_hash:await digest((supervised?"wm-supervised-recovery:":"wm-offline-recovery:")+recoveryKey),p_epoch:account.credential_epoch})});
 if(enrolled!==true)return send(409,{error:"unconfirmed"});
 return send(200,{recovery_key:recoveryKey});
 }
 if(action==="recover-key"){
 const supervised=body.supervised===true;
 if(supervised&&Deno.env.get("WM_SUPPORT_RECOVERY_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 if(Deno.env.get("WM_RECOVERY_KEY_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const identifier=typeof body.identifier==="string"?body.identifier.trim().toUpperCase():"";
 const recoveryKey=typeof body.recovery_key==="string"?body.recovery_key.trim().toLowerCase():"",next=body.new_password,requestId=body.request_id;
 if(!/^WM-[A-Z0-9]{8,24}$/.test(identifier)||! /^[a-f0-9]{64}$/.test(recoveryKey)||!uuid.test(requestId??"")||!uuid.test(body.installation_id??"")||!["web","android"].includes(body.platform)||typeof next!=="string"||next.length<12||next.length>256)return send(400,{error:"invalid_request"});
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-key-recovery:"+identifier),p_installation_hash:await digest("wm-key-recovery-device:"+body.installation_id.toLowerCase())})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 const p_key_hash=await digest((supervised?"wm-supervised-recovery:":"wm-offline-recovery:")+recoveryKey),p_commitment=await digest("wm-recovery-commit:"+recoveryKey+":"+requestId.toLowerCase()+":"+next);
 const p_request=requestId.toLowerCase();
 const op=await rest(supervised?"rpc/wm_support_begin_fallback":"rpc/wm_begin_key_recovery",{method:"POST",body:JSON.stringify({p_identifier:identifier,p_key_hash,p_request,p_commitment})});
 if(!op||!["start","verify"].includes(op.mode)||!uuid.test(op.auth_user_id??"")||!uuid.test(op.account_id??""))return send(401,{error:"credentials"});
 async function verify(){
  const proof=await fetch(url+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:anon,"Content-Type":"application/json"},body:JSON.stringify({email:op.auth_alias,password:next}),redirect:"error",cache:"no-store"});
  if(proof.status===400||proof.status===401)return false;
  if(!proof.ok)throw Error("provider_unavailable");
  return (await proof.json()).user?.id===op.auth_user_id;
 }
 const params={p_account:op.account_id,p_key_hash,p_request,p_commitment};
 if(op.mode==="start"){
  if(!(await verify())){
   if(await rest("rpc/wm_prepare_key_recovery_write",{method:"POST",body:JSON.stringify(params)})!==true)return send(409,{error:"recovery_unconfirmed"});
   // Only the single fenced worker may change the GoTrue credential.
   const changed=await fetch(url+"/auth/v1/admin/users/"+eq(op.auth_user_id),{method:"PUT",headers,body:JSON.stringify({password:next}),redirect:"error",cache:"no-store"});
   if(!changed.ok)return send(409,{error:"recovery_unconfirmed"});
  }
 }
 // An interrupted operation can only finish with proof of the exact new password.
 if(!(await verify()))return send(409,{error:"recovery_unconfirmed"});
 if(await rest("rpc/wm_finish_key_recovery",{method:"POST",body:JSON.stringify(params)})!==true)return send(409,{error:"recovery_unconfirmed"});
 return send(200,{recovered:true,reconnect:true},{"Set-Cookie":clearCookie});
 }
 if(action==="request-recovery"){
 if(body.supervised===true){
  if(Deno.env.get("WM_SUPPORT_RECOVERY_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
  const identifier=typeof body.identifier==="string"?body.identifier.trim().toUpperCase():"",key=typeof body.recovery_key==="string"?body.recovery_key.trim().toLowerCase():"";
  if(!/^WM-[A-Z0-9]{8,24}$/.test(identifier)||!/^[a-f0-9]{64}$/.test(key)||!uuid.test(body.installation_id??"")||!["web","android"].includes(body.platform))return send(400,{error:"invalid_request"});
  const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-support-request:"+identifier),p_installation_hash:await digest("wm-support-request-device:"+body.installation_id.toLowerCase())})});
  if(allowed!==true)return send(429,{error:"too_many_attempts"});
  const result=await rest("rpc/wm_support_request_fallback",{method:"POST",body:JSON.stringify({p_identifier:identifier,p_key_hash:await digest("wm-supervised-recovery:"+key)})});
  return result?.case_id?send(200,result):send(401,{error:"credentials"});
 }
 const identifier=typeof body.identifier==="string"?body.identifier.trim().toUpperCase():"";
 if(!/^WM-[A-Z0-9]{8,24}$/.test(identifier)||!uuid.test(body.installation_id??"")||!["web","android"].includes(body.platform))return send(400,{error:"invalid_request"});
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-recovery:"+identifier),p_installation_hash:await digest("wm-recovery-installation:"+body.installation_id.toLowerCase())})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 await rest("rpc/wm_request_recovery",{method:"POST",body:JSON.stringify({p_identifier:identifier})});
 return send(200,{accepted:true});
 }
 if(action==="login"){
 const identifier=typeof body.identifier==="string"?body.identifier.trim().toUpperCase():"";
 const password=body.password;
 if(!/^WM-[A-Z0-9]{8,24}$/.test(identifier)||typeof password!=="string"||password.length<1||password.length>256||!uuid.test(body.installation_id??"")||!["web","android"].includes(body.platform))return send(401,{error:"credentials"});
 // Reserve before looking up account; fail closed if the shared limiter is unavailable.
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-login:"+identifier),p_installation_hash:await digest("wm-installation:"+body.installation_id.toLowerCase())})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 const rows=await rest("wm_accounts?select=id,auth_user_id,auth_alias,password_change_required,credential_epoch,password_change_id,enabled&login_id=eq."+eq(identifier)+"&enabled=eq.true&limit=1");
 const a=rows[0];if(!a||a.password_change_id!==null)return send(401,{error:"credentials"});
 const auth=await fetch(url+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:anon,"Content-Type":"application/json"},body:JSON.stringify({email:a.auth_alias,password}),redirect:"error",cache:"no-store"});
 if(!auth.ok)return send(401,{error:"credentials"});
 const authData=await auth.json();if(authData.user?.id!==a.auth_user_id)return send(401,{error:"credentials"});
 // Do not return the GoTrue token, use a dedicated WideMeet opaque session instead.
 const ws=await workspaces(a.id);if(!ws.length)return send(403,{error:"scope"});
 const active=ws.find((w:any)=>w.kind==="individual")??ws[0];
 const access=token(),accessHash=await digest(access);
 const sessionId=await rest("rpc/wm_issue_verified_session",{method:"POST",body:JSON.stringify({p_account:a.id,p_installation:body.installation_id,p_workspace:active.id,p_hash:accessHash,p_epoch:a.credential_epoch})});
 let refresh="";
 if(typeof body.remember_me==="boolean"&&!a.password_change_required){
 refresh=token();
 if(await rest("rpc/wm_attach_refresh",{method:"POST",body:JSON.stringify({p_hash:accessHash,p_refresh_hash:await digest(refresh),p_remember:body.remember_me})})!==true)return send(503,{error:"unavailable"});
 }
 const saved=(await rest("wm_device_sessions?select=expires_at,refresh_until,remember_me&id=eq."+eq(sessionId)+"&revoked_at=is.null&limit=1"))[0];
 if(!saved)return send(403,{error:"scope"});
 const response={app_id:"WIDEMEET",access_token:access,member_id:a.id,device_id:sessionId,expires_at:Date.parse(saved.expires_at),server_now:Date.now(),require_password_change:a.password_change_required,active_workspace_id:active.id,workspaces:ws,refresh_available:!!refresh,...(refresh&&body.platform==="android"&&!origin?{refresh_token:refresh}:{})};
 return send(200,response,body.platform==="web"?{"Set-Cookie":refresh?refreshCookie(refresh,saved.remember_me,Date.parse(saved.refresh_until)):clearCookie}:{});

 }
 if(action==="refresh"){
 if(!uuid.test(body.installation_id??"")||!["web","android"].includes(body.platform)||body.platform==="android"&&origin)return send(401,{error:"credentials"});
 const previous=body.platform==="web"?cookieRefresh(request):body.refresh_token;
 if(typeof previous!=="string"||!/^[a-f0-9]{64}$/.test(previous))return send(401,{error:"credentials"},body.platform==="web"?{"Set-Cookie":clearCookie}:{});
 const access=token(),refresh=token();
 const sessionId=await rest("rpc/wm_rotate_refresh",{method:"POST",body:JSON.stringify({p_old:await digest(previous),p_installation:body.installation_id,p_access:await digest(access),p_refresh:await digest(refresh)})});
 if(!uuid.test(sessionId??""))return send(401,{error:"credentials"},body.platform==="web"?{"Set-Cookie":clearCookie}:{});
 const saved=(await rest("wm_device_sessions?select=account_id,workspace_id,expires_at,refresh_until,remember_me&id=eq."+eq(sessionId)+"&revoked_at=is.null&limit=1"))[0];
 if(!saved)return send(403,{error:"scope"});
 const ws=await workspaces(saved.account_id);
 if(!ws.some((w:any)=>w.id===saved.workspace_id))return send(403,{error:"scope"});
 return send(200,{app_id:"WIDEMEET",access_token:access,member_id:saved.account_id,device_id:sessionId,expires_at:Date.parse(saved.expires_at),server_now:Date.now(),require_password_change:false,active_workspace_id:saved.workspace_id,workspaces:ws,refresh_available:true,...(body.platform==="android"?{refresh_token:refresh}:{})},body.platform==="web"?{"Set-Cookie":refreshCookie(refresh,saved.remember_me,Date.parse(saved.refresh_until))}:{});
 }
 if(action==="change-password"){
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 const old=body.current_password,next=body.new_password,requestId=body.request_id;
 if(!/^[a-f0-9]{64}$/.test(access)||!uuid.test(requestId??"")||typeof old!=="string"||!old||old.length>256||typeof next!=="string"||next.length<12||next.length>256||old===next)return send(400,{error:"invalid_request"});
 const p_hash=await digest(access);
 const context=(await rest("rpc/wm_session_context",{method:"POST",body:JSON.stringify({p_hash})}))[0];
 if(!context)return send(401,{error:"credentials"});
 const account=(await rest("wm_accounts?select=id,auth_user_id,auth_alias,credential_epoch,password_change_id,password_change_session&id=eq."+eq(context.account_id)+"&enabled=eq.true&limit=1"))[0];
 if(!account)return send(403,{error:"scope"});
 const pending=account.password_change_id!==null;
 if(pending&&(account.password_change_id!==requestId||account.password_change_session!==context.session_id))return send(409,{error:"change_pending"});
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-change:"+account.id),p_installation_hash:await digest("wm-change-session:"+context.session_id)})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 async function verify(password:string){
 const response=await fetch(url+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:anon,"Content-Type":"application/json"},body:JSON.stringify({email:account.auth_alias,password}),redirect:"error",cache:"no-store"});
 if(!response.ok)return null;
 const data=await response.json();
 return data.user?.id===account.auth_user_id&&typeof data.access_token==="string"?data:null;
 }
 // If a password update response was lost, only the same change owner can
 // complete the pending operation, after independently proving the new password.
 let verifiedNew=pending?await verify(next):null;
 if(pending&&!verifiedNew)return send(409,{error:"change_pending"});
 if(!verifiedNew){
 const verified=await verify(old);if(!verified)return send(401,{error:"credentials"});
 const begun=await rest("rpc/wm_begin_password_change",{method:"POST",body:JSON.stringify({p_hash,p_request:requestId,p_epoch:account.credential_epoch})});
 if(begun!==true)return send(409,{error:"change_pending"});
 const updated=await fetch(url+"/auth/v1/user",{method:"PUT",headers:{apikey:anon,Authorization:"Bearer "+verified.access_token,"Content-Type":"application/json"},body:JSON.stringify({password:next}),redirect:"error",cache:"no-store"});
 if(!updated.ok)return send(409,{error:"change_unconfirmed"});
 verifiedNew=await verify(next);if(!verifiedNew)return send(409,{error:"change_unconfirmed"});
 }
 const finished=await rest("rpc/wm_finish_password_change",{method:"POST",body:JSON.stringify({p_hash,p_request:requestId})});
 if(finished!==true)return send(409,{error:"change_unconfirmed"});
 return send(200,{changed:true,reconnect:true},{"Set-Cookie":clearCookie});
 }
 if(action==="push"||action==="push-worker"){
 if(Deno.env.get("WM_PUSH_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const encryptionKey=Deno.env.get("WM_PUSH_ENCRYPTION_KEY")??"";
 if(!/^[a-f0-9]{64}$/.test(encryptionKey))return send(503,{error:"unavailable"});
 const rpc=(name:string,args:Record<string,unknown>)=>rest("rpc/"+name,{method:"POST",body:JSON.stringify(args)});
 if(action==="push-worker"){
  const secret=Deno.env.get("WM_PUSH_WORKER_SECRET")??"";
  const presented=request.headers.get("authorization")??"";
  if(origin||secret.length<64||presented.length!==secret.length+7||await digest(presented)!==await digest("Bearer "+secret))return send(403,{error:"scope"});
  const project=Deno.env.get("WM_FIREBASE_PROJECT_ID")??"";
  const account=serviceAccount(Deno.env.get("WM_FCM_SERVICE_ACCOUNT_JSON")??"",project);
  const access=await accessToken(account);
  return send(200,await dispatchPush({rpc,encryptionKey,project,access,limit:25}));
 }
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(!/^[a-f0-9]{64}$/.test(access)||!["register","status","revoke"].includes(body.action))return send(400,{error:"invalid_request"});
 let data:Record<string,unknown>={};
 if(body.action==="register"){
  if(!validPushToken(body.token)||!["android","web"].includes(body.platform))return send(400,{error:"invalid_request"});
  data={...await encryptToken(body.token,encryptionKey),platform:body.platform};
 }
 const v=await rpc("wm_push_device_action",{p_hash:await digest(access),p_action:body.action,p_data:data});
 return v?send(200,v):send(403,{error:"scope"});
 }
 if(action==="chat-media"){
 if(Deno.env.get("WM_CHAT_MEDIA_QUALIFIED")!=="true"||Deno.env.get("WM_WORKSPACE_CENTERS_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(access.length!==64||[...access].some(c=>!"0123456789abcdef".includes(c)))return send(401,{error:"credentials"});
 if(!["list","upload","download","revoke"].includes(body.action)||!body.data||typeof body.data!=="object"||Array.isArray(body.data))return send(400,{error:"invalid_request"});
 const p_hash=await digest(access);
 const result=await chatMedia({base:url,service,p_hash,action:body.action,data:body.data,rpc:(a:string,d:Record<string,unknown>)=>rest("rpc/wm_chat_media_action",{method:"POST",body:JSON.stringify({p_hash,p_action:a,p_data:d})})});
 return send(result.status,result.body);
 }
 if(action==="identity"){
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(!/^[a-f0-9]{64}$/.test(access))return send(401,{error:"credentials"});
 const name=body.action,data=body.data??{};
 if(name!=="photo-save"&&raw.length>16384)return send(413,{error:"request_too_large"});
 if(!["profile","profile-update","language-preferences","language-save","language-reset","photo-read","photo-save","photo-delete","onboarding-step","contacts","favorite","groups","group-save","group-delete","invite","invitations","respond-invite","member-role","manager-assign","revoke-member","billing","billing-list","billing-create","billing-cancel","devices","revoke-device","dashboard","support-capabilities","support-list","support-queue","support-create","support-read","support-claim","support-reply","support-close","center-contacts","center-thread","center-send","center-seen","center-statistics","center-periodic-list","center-periodic-save","group-chat-list","group-chat-create","group-chat-members","group-chat-remove","group-chat-add","group-chat-rename","group-chat-thread","group-chat-watch","group-chat-send","group-chat-seen","group-chat-report","group-chat-reports","group-chat-resolve-report","support-feedback","support-privacy-review","support-release","support-call-read","support-call-request","support-call-accept","support-call-decline","support-call-end","support-call-heartbeat","support-call-grant","support-screen-consent","support-screen-start","support-screen-stop","support-recovery-queue","support-recovery-review"].includes(name)||typeof data!=="object"||Array.isArray(data))return send(400,{error:"invalid_request"});
 const p_hash=await digest(access);
 const context=(await rest("rpc/wm_session_context",{method:"POST",body:JSON.stringify({p_hash})}))?.[0];
 if(!context||context.password_change_required)return send(403,{error:"scope"});
 if(typeof name==="string"&&name.startsWith("group-chat-")){
 if(Deno.env.get("WM_WORKSPACE_CENTERS_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 if(name==="group-chat-watch"){
  // Bounded authenticated change delivery, existing service-only RPC, no open
  // transaction while waiting, no new public credential or database grant.
  if(!uuid.test(data.group_id??"")||(data.after!=null&&!/^[a-f0-9]{64}$/.test(data.after)))return send(400,{error:"invalid_request"});
  if(groupWatches.has(p_hash)||groupWatches.size>=100)return send(429,{error:"watch_busy"});
  groupWatches.add(p_hash);
  try{
   const deadline=Date.now()+8000;
   const query={group_id:data.group_id,query:data.query??"",before_id:data.before_id??null,limit:data.limit??50};
   for(;;){
    const snapshot=await rest("rpc/wm_group_chat",{method:"POST",body:JSON.stringify({p_hash,p_action:"group-chat-snapshot",p_data:query}),signal:AbortSignal.timeout(3000)});
    if(!snapshot||!Array.isArray(snapshot.members)||!Array.isArray(snapshot.thread?.items))return send(403,{error:"scope"});
    const version=await digest(JSON.stringify(snapshot));
    if(version!==data.after)return send(200,{changed:true,version,...snapshot});
    if(Date.now()>=deadline||request.signal.aborted)return send(200,{changed:false,version});
    await new Promise(resolve=>setTimeout(resolve,750));
   }
  }finally{groupWatches.delete(p_hash)}
 }
 const result=await rest("rpc/wm_group_chat",{method:"POST",body:JSON.stringify({p_hash,p_action:name,p_data:data})});
 return result?send(200,result):send(403,{error:"scope"});
 }
 if(typeof name==="string"&&name.startsWith("center-")){
 if(Deno.env.get("WM_WORKSPACE_CENTERS_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const rpc=name==="center-periodic-list"||name==="center-periodic-save"?"rpc/wm_periodic_action":"rpc/wm_workspace_center";
 const result=await rest(rpc,{method:"POST",body:JSON.stringify({p_hash,p_action:name,p_data:data})});
 return result?send(200,result):send(403,{error:"scope"});
 }
 if(typeof name==="string"&&name.startsWith("support-")){
 if(Deno.env.get("WM_SUPPORT_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 const mediaReady=Deno.env.get("WM_SUPPORT_MEDIA_QUALIFIED")==="true";
 if(name==="support-call-grant"){
  if(!mediaReady||!uuid.test(data.call_id??""))return send(503,{error:"unavailable"});
  const handle=token();
  const admission=await rest("rpc/wm_support_issue_media",{method:"POST",body:JSON.stringify({p_hash,p_call:data.call_id,p_handle:handle})});
  if(!admission||admission.identity!==context.account_id||admission.room!=="wm-support-"+data.call_id.toLowerCase())return send(403,{error:"scope"});
  return send(200,await supportGrant(admission,handle));
 }
 const result=await rest("rpc/wm_support_action",{method:"POST",body:JSON.stringify({p_hash,p_action:name,p_data:data})});
 if(result&&(name==="support-capabilities"||name.startsWith("support-call-")||name.startsWith("support-screen-")))result.transport_ready=mediaReady;
 return result?send(200,result):send(403,{error:"scope"});
 }
 if(["photo-read","photo-save","photo-delete"].includes(name)){
 if(name==="photo-save"){
 if(!thumbnail(data.jpeg))return send(400,{error:"invalid_photo"});
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-photo:"+context.account_id),p_installation_hash:await digest("wm-photo-device:"+context.installation_id)})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 }
 const result=await rest("rpc/wm_profile_photo",{method:"POST",body:JSON.stringify({p_hash,p_action:name,p_data:data})});
 return result?send(200,result):send(403,{error:"scope"});
 }
 if(["billing-list","billing-create","billing-cancel"].includes(name)){
 if(Deno.env.get("WM_BILLING_TEST")!=="true")return send(503,{error:"unavailable"});
 const result=await rest("rpc/wm_billing_action",{method:"POST",body:JSON.stringify({p_hash,p_action:name,p_data:data})});
 return result?send(200,result):send(403,{error:"scope"});
 }
 if(["billing","dashboard"].includes(name)){
 const profile=await rest("rpc/wm_identity_action",{method:"POST",body:JSON.stringify({p_hash,p_action:"profile",p_data:{}})});
 if(!profile)return send(403,{error:"scope"});
 if(name==="billing"&&!["owner","promoteur"].includes(profile.role))return send(403,{error:"scope"});
 const ent=(await rest("wm_room_entitlements?select=plan,enabled,valid_until&workspace_id=eq."+eq(context.workspace_id)+"&limit=1"))?.[0];
 const valid=ent?.enabled===true&&Date.parse(ent.valid_until)>Date.now();
 if(name==="billing")return send(200,{plan:valid?ent.plan:null,valid_until:valid?ent.valid_until:null,kind:profile.workspace_kind,payment_available:false,intent_available:Deno.env.get("WM_BILLING_TEST")==="true"});
 const metrics=await rest("rpc/wm_identity_action",{method:"POST",body:JSON.stringify({p_hash,p_action:"dashboard-identity",p_data:{}})});
 if(!metrics)return send(403,{error:"scope"});
 const rows=valid||profile.workspace_kind==="individual"?await rest("rpc/wm_room_list",{method:"POST",body:JSON.stringify({p_hash})}):[];
 const upcoming=Array.isArray(rows)?rows.filter((r:any)=>r.status==="scheduled"&&r.scheduled_ms>=Date.now()).sort((a:any,b:any)=>a.scheduled_ms-b.scheduled_ms):[];
 return send(200,{display_name:profile.display_name,role:profile.role,next_meeting:upcoming[0]??null,upcoming_count:upcoming.length,active_count:Array.isArray(rows)?rows.filter((r:any)=>r.status==="open"||r.status==="paused").length:0,subscription_active:valid,team_count:metrics.team_count,pending_invitation_count:metrics.pending_invitation_count,favorite_count:metrics.favorite_count,group_count:metrics.group_count});
 }
 if(name==="invite"){
 const allowed=await rest("rpc/wm_reserve_auth_attempt",{method:"POST",body:JSON.stringify({p_identifier_hash:await digest("wm-invite:"+context.account_id),p_installation_hash:await digest("wm-invite-device:"+context.installation_id)})});
 if(allowed!==true)return send(429,{error:"too_many_attempts"});
 }
 const result=await rest("rpc/wm_identity_action",{method:"POST",body:JSON.stringify({p_hash,p_action:name,p_data:data})});
 if(!result)return send(403,{error:"scope"});
 return send(200,result);
 }
 if(action==="switch-workspace"){
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(!/^[a-f0-9]{64}$/.test(access)||!uuid.test(body.workspace_id??""))return send(401,{error:"credentials"});
 const oldHash=await digest(access);
 const context=(await rest("rpc/wm_session_context",{method:"POST",body:JSON.stringify({p_hash:oldHash})}))[0];
 if(!context||context.password_change_required)return send(403,{error:"scope"});
 const ws=await workspaces(context.account_id);
 if(!ws.some((w:any)=>w.id===body.workspace_id))return send(403,{error:"scope"});
 const newAccess=token();
 const sessionId=await rest("rpc/wm_switch_workspace",{method:"POST",body:JSON.stringify({p_old_hash:oldHash,p_workspace:body.workspace_id,p_new_hash:await digest(newAccess)})});
 const saved=(await rest("wm_device_sessions?select=expires_at&id=eq."+eq(sessionId)+"&revoked_at=is.null&limit=1"))[0];
 if(!saved)return send(403,{error:"scope"});
 return send(200,{app_id:"WIDEMEET",access_token:newAccess,member_id:context.account_id,device_id:sessionId,expires_at:Date.parse(saved.expires_at),server_now:Date.now(),require_password_change:false,active_workspace_id:body.workspace_id,workspaces:ws});
 }
 if(action==="logout"){
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(!/^[a-f0-9]{64}$/.test(access))return send(401,{error:"credentials"});
 await rest("wm_device_sessions?token_hash=eq."+await digest(access)+"&revoked_at=is.null",{method:"PATCH",body:JSON.stringify({revoked_at:new Date().toISOString(),refresh_hash:null,refresh_until:null})});
 return send(204,null,{"Set-Cookie":clearCookie});
 }
 return send(404,{error:"unavailable"});
 }catch{return send(503,{error:"unavailable"})}
});
