import { createClient, type User } from "npm:@supabase/supabase-js@2";
const APPS = new Set(["kiosko","bootik","zipple","naxa_services","cotiz","loyable","naxa_hotel","campus237","naxa_security","grillad"]);
const cors = { "Access-Control-Allow-Origin":"*", "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods":"POST, OPTIONS", "Content-Type":"application/json" };
export function normalizePhone(value:string):string { const v=value.replace(/[\s().-]/g,""); if(!/^\+[1-9]\d{7,14}$/.test(v)) throw new Error("invalid_phone_e164"); return v; }
export function isAdult(iso:string,now=new Date()):boolean { if(!/^\d{4}-\d{2}-\d{2}$/.test(iso)) return false; const d=new Date(iso+"T00:00:00Z"); if(Number.isNaN(d.getTime())) return false; const cutoff=new Date(Date.UTC(now.getUTCFullYear()-18,now.getUTCMonth(),now.getUTCDate())); return d<=cutoff; }
export function safeAppCode(value:string):string { if(!APPS.has(value)) throw new Error("invalid_app_code"); return value; }
const hex=(b:Uint8Array)=>Array.from(b).map(x=>x.toString(16).padStart(2,"0")).join("");
async function digest(value:string):Promise<string>{return hex(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value))));}
function randomSecret():string { const b=crypto.getRandomValues(new Uint8Array(32)); return btoa(String.fromCharCode(...b)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,""); }
function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:cors});}
function jwtPayload(token:string):Record<string,unknown>{try{return JSON.parse(atob(token.split(".")[1].replace(/-/g,"+").replace(/_/g,"/")));}catch{return {};}}
type Body={action:string;[key:string]:unknown};
async function actorFrom(req:Request, url:string, anon:string, service:string):Promise<{user:User;admin:any;token:string}>{
 const auth=req.headers.get("Authorization")??""; const token=auth.replace(/^Bearer\s+/i,""); if(!token) throw new Error("unauthorized");
 const publicClient=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:"Bearer "+token}}});
 const {data,error}=await publicClient.auth.getUser(); if(error||!data.user) throw new Error("unauthorized");
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 return {user:data.user,admin,token};
}
async function authorizeEmployee(admin:any, actorId:string, appCode:string, orgId:string|null, locationId:string|null, roleCode:string):Promise<boolean>{
 if(locationId){
  const {data,error}=await admin.from("naxa_professional_assignments").select("id,role_code,statut").eq("profile_id",actorId).eq("pharmacie_id",locationId).eq("statut","active").in("role_code",["responsable","promoteur","gerant"]).limit(1);
  if(!error&&data?.length) {
   const role=await admin.from("naxa_roles").select("code").eq("code",roleCode).eq("assignable",true).eq("actif",true).maybeSingle();
   return !role.error&&!!role.data;
  }
  const owner=await admin.from("promoteur_pharmacies").select("pharmacie_id").eq("promoteur_id",actorId).eq("pharmacie_id",locationId).eq("actif",true).maybeSingle();
  if(!owner.error&&owner.data) return true;
 }
 if(orgId){
  const member=await admin.from("partner_members").select("member_role").eq("partner_id",orgId).eq("user_id",actorId).in("member_role",["owner","manager"]).maybeSingle();
  if(member.data){
   const universe=await admin.from("partner_universes").select("enabled").eq("partner_id",orgId).eq("universe_slug",appCode).eq("enabled",true).maybeSingle();
   return !universe.error&&!!universe.data;
  }
 }
 return false;
}
async function findUserByPhone(admin:any,phone:string):Promise<User|null>{
 for(let page=1;page<=10;page++){const {data,error}=await admin.auth.admin.listUsers({page,perPage:1000});if(error)throw error;const found=data.users.find((u:User)=>u.phone===phone);if(found)return found;if(data.users.length<1000)break;}
 return null;
}
async function handle(req:Request):Promise<Response>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 if(req.method!=="POST") return json({error:"method_not_allowed"},405);
 const url=Deno.env.get("SUPABASE_URL")!, anon=Deno.env.get("SUPABASE_ANON_KEY")!, service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 if(!url||!anon||!service) return json({error:"server_not_configured"},503);
 let body:Body; try{body=await req.json();}catch{return json({error:"invalid_json"},400);}
 try{
  if(body.action==="activate"){
   const token=String(body.token??"");const password=String(body.password??"");
   if(token.length<32||password.length<10) return json({error:"invalid_activation"},400);
   const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
   const {data:invite,error}=await admin.schema("famille_private").from("account_invites").select("*").eq("token_hash",await digest(token)).eq("status","pending").gt("expires_at",new Date().toISOString()).maybeSingle();
   if(error||!invite) return json({error:"activation_unavailable"},400);
   const {data:userData,error:userError}=await admin.auth.admin.updateUserById(invite.user_id,{password,app_metadata:{must_change_password:false}});
   if(userError||!userData.user) return json({error:"activation_unavailable"},400);
   const {error:grantError}=await admin.schema("famille_private").from("account_app_access").update({status:"active",updated_at:new Date().toISOString()}).eq("user_id",invite.user_id).eq("app_code",invite.app_code).eq("status","pending");
   if(grantError) return json({error:"activation_unavailable"},500);
   const {error:usedError}=await admin.schema("famille_private").from("account_invites").update({status:"accepted",accepted_at:new Date().toISOString(),accepted_by:invite.user_id}).eq("id",invite.id).eq("status","pending");
   if(usedError) return json({error:"activation_unavailable"},500);
   return json({ok:true,message:"account_activated"});
  }
  if(body.action==="login"){
   const app=safeAppCode(String(body.app_code??""));const phone=normalizePhone(String(body.phone??""));const loginHash=await digest(phone);
   const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
   const {data:locked}=await admin.schema("famille_private").rpc("login_is_locked",{p_login_hash:loginHash,p_app_code:app});
   if(locked) return json({error:"temporarily_locked"},423);
   const publicClient=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
   const {data,error}=await publicClient.auth.signInWithPassword({phone,password:String(body.password??"")});
   if(error||!data.session) {
    await admin.schema("famille_private").rpc("record_login_failure",{p_login_hash:loginHash,p_app_code:app});
    return json({error:"invalid_credentials"},401);
   }
   await admin.schema("famille_private").rpc("clear_login_failures",{p_login_hash:loginHash,p_app_code:app});
   const {data:grant}=await admin.schema("famille_private").from("account_app_access").select("id,status").eq("user_id",data.user.id).eq("app_code",app).eq("status","active").limit(1).maybeSingle();
   if(!grant) return json({error:"app_access_denied"},403);
   return json({session:data.session,user:{id:data.user.id,phone:data.user.phone,must_change_password:data.user.app_metadata?.must_change_password===true}});
  }
  if(body.action==="create_invite"||body.action==="create_employee"){
   const {user:actor,admin}=await actorFrom(req,url,anon,service);const platformAdmin=actor.app_metadata?.naxa_platform_admin===true||actor.app_metadata?.famille_platform_admin===true;
   const app=safeAppCode(String(body.app_code??""));const kind=body.action==="create_employee"?"employee":String(body.account_kind??"client");
   if(!["client","professional","employee"].includes(kind)) return json({error:"invalid_account_kind"},400);
   const phone=normalizePhone(String(body.phone??""));const first=String(body.first_name??"").trim();const last=String(body.last_name??"").trim();const dob=String(body.date_of_birth??"");
   if(!first||!last||!isAdult(dob)) return json({error:"valid_adult_identity_required"},400);
   const org=body.organization_id?String(body.organization_id):null;const loc=body.location_id?String(body.location_id):null;const role=body.role_code?String(body.role_code):null;
   if(!platformAdmin && (kind!=="employee"||!role||!await authorizeEmployee(admin,actor.id,app,org,loc,role))) return json({error:"scope_forbidden"},403);
   const requestId=String(body.request_id??crypto.randomUUID());const existing=await admin.schema("famille_private").from("account_invites").select("id,user_id,status,expires_at").eq("request_id",requestId).maybeSingle();
   if(existing.data) return json({ok:true,invite_id:existing.data.id,status:existing.data.status,expires_at:existing.data.expires_at,idempotent:true});
   let user=await findUserByPhone(admin,phone);let created=false;
   if(!user){
    const randomPassword=randomSecret()+"aA9!";
    const {data,error}=await admin.auth.admin.createUser({phone,phone_confirm:true,password:randomPassword,user_metadata:{username:phone,phone,phone_country:phone.startsWith("+237")?"CM":"",first_name:first,last_name:last,date_of_birth:dob,age_verified:true,consent_accepted_at:new Date().toISOString()}});
    if(error||!data.user) return json({error:"account_creation_failed"},400);user=data.user;created=true;
   }
   const expires=new Date(Date.now()+72*60*60*1000).toISOString();const token=randomSecret();const tokenHash=await digest(token);
   const access=await admin.schema("famille_private").from("account_app_access").upsert({user_id:user.id,app_code:app,account_kind:kind,organization_id:org,location_id:loc,role_code:role,plan_code:body.plan_code??null,duration_days:body.duration_days??null,discount_percent:body.discount_percent??0,trial_days:body.trial_days??0,status:"pending",granted_by:actor.id},{onConflict:"user_id,app_code,organization_id,location_id"});
   if(access.error){if(created) await admin.auth.admin.deleteUser(user.id);return json({error:"access_grant_failed"},500);}
   const invite=await admin.schema("famille_private").from("account_invites").insert({request_id:requestId,user_id:user.id,token_hash:tokenHash,app_code:app,account_kind:kind,organization_id:org,location_id:loc,created_by:actor.id,expires_at:expires,role_code:role});
   if(invite.error){if(created) await admin.auth.admin.deleteUser(user.id);return json({error:"invite_creation_failed"},500);}
   await admin.auth.admin.updateUserById(user.id,{app_metadata:{...(user.app_metadata??{}),must_change_password:true}});
   await admin.schema("famille_private").from("account_audit_log").insert({actor_id:actor.id,subject_user_id:user.id,app_code:app,event_code:"account.invited",outcome:"success",metadata:{kind,request_id:requestId}});
   const base=Deno.env.get("FAMILLE_ACTIVATION_URL")??"";
   return json({ok:true,user_id:user.id,invite_id:(invite.data as any)?.[0]?.id??null,activation_url:base?base.replace(/\/$/,"")+"/activate?token="+encodeURIComponent(token):null,activation_token:base?undefined:token,expires_at:expires,created_user:created});
  }
  if(body.action==="register_device"){
   const {user,admin,token}=await actorFrom(req,url,anon,service);const app=safeAppCode(String(body.app_code??""));
   const {data:grant,error}=await admin.schema("famille_private").from("account_app_access").select("id").eq("user_id",user.id).eq("app_code",app).eq("status","active").limit(1).maybeSingle();
   if(error||!grant) return json({error:"app_access_denied"},403);
   const payload=jwtPayload(token);const sessionId=typeof payload.session_id==="string"?payload.session_id:null;
   const {data,error:regError}=await admin.schema("famille_private").rpc("register_device",{p_user_id:user.id,p_app_code:app,p_organization_id:body.organization_id??null,p_location_id:body.location_id??null,p_installation_id:String(body.installation_id??""),p_auth_session_id:sessionId,p_platform:String(body.platform??"android"),p_device_label:String(body.device_label??"")});
   if(regError) return json({error:"device_registration_failed"},400);
   return json({ok:true,...data});
  }
  if(body.action==="revoke_device"){
   const {user,admin}=await actorFrom(req,url,anon,service);const deviceId=String(body.device_id??"");
   const {data:device,error}=await admin.schema("famille_private").from("account_devices").select("id,user_id").eq("id",deviceId).maybeSingle();
   if(error||!device) return json({error:"device_not_found"},404);
   const platformAdmin=user.app_metadata?.naxa_platform_admin===true||user.app_metadata?.famille_platform_admin===true;
   if(!platformAdmin&&device.user_id!==user.id) return json({error:"scope_forbidden"},403);
   const {data:revoked,error:revokeError}=await admin.schema("famille_private").rpc("revoke_device",{p_device_id:deviceId,p_actor_id:user.id});
   if(revokeError||!revoked) return json({error:"device_revoke_failed"},400);
   await admin.schema("famille_private").from("account_audit_log").insert({actor_id:user.id,subject_user_id:device.user_id,event_code:"device.revoked",outcome:"success",reason_code:"user_or_admin_request"});
   return json({ok:true,device_id:deviceId,revoked:true,session_invalidation:"requires_server_session_gate"});
  }
  if(body.action==="request_recovery"){
   const phone=normalizePhone(String(body.phone??""));const app=safeAppCode(String(body.app_code??""));const loginHash=await digest(phone);
   const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
   await admin.schema("famille_private").from("recovery_requests").insert({login_hash:loginHash,channel:"whatsapp"});
   const wa="https://wa.me/237681972237?text="+encodeURIComponent("Bonjour NAXA, je demande une assistance pour récupérer mon accès. Application : "+app+". Je suis prêt à vérifier mon identité par la procédure officielle.");
   return json({ok:true,message:"recovery_request_received",whatsapp_url:wa});
  }
  return json({error:"unknown_action"},400);
 }catch(error){return json({error:error instanceof Error?error.message:"request_failed"},400);}
}
if(import.meta.main) Deno.serve(handle);
