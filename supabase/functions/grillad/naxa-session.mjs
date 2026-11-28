import {verifyNaxaIdentity} from './naxa-identity.mjs';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const digest=async value=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),x=>x.toString(16).padStart(2,'0')).join('');
// Distinct reserved alias namespace. Never match a user by their declared phone or email.
export async function federatedAlias(identity){return 'grillad-naxa-'+(await digest(identity.issuer+'|'+identity.subject)).slice(0,48)+'@accounts.grillad.invalid'}
export async function establishNaxaSession({body,env,base,post,validProfile,workspaceFor,fetcher=fetch}){
 const fail=(status,error)=>({status,body:{error}});
 if(!env.service||!env.naxaPublishableKey)return fail(503,'AUTH_NOT_CONFIGURED');
 if(!uuid.test(body.installation)||!['web','android'].includes(body.platform))return fail(400,'SIGNUP_INPUT');
 const identity=await verifyNaxaIdentity(body.naxa_access,{publishableKey:env.naxaPublishableKey},fetcher);
 if(!identity)return fail(401,'INVALID_CREDENTIALS');
 const email=await federatedAlias(identity),hash=await digest('grillad:naxa:'+identity.subject);
 const guard=await post('/rest/v1/rpc/grillad_auth_begin',{p_hash:hash,p_recovery:false},env.service);
 if(!guard.ok||guard.result!==true)return fail(429,'TEMPORARILY_LOCKED');
 const lookup=()=>post('/rest/v1/rpc/grillad_federated_identity',{p_email:email,p_subject:identity.subject},env.service);
 let account=await lookup();
 if(!account.ok)return fail(503,'AUTH_NOT_CONFIGURED');
 const profile=validProfile(body);
 if(!account.result&&!profile)return {status:200,body:{result:{onboarding_required:true}}};
 async function admin(path,payload){const r=await fetcher(base+path,{method:'POST',headers:{apikey:env.service,Authorization:'Bearer '+env.service,'Content-Type':'application/json'},body:JSON.stringify(payload),redirect:'error',signal:AbortSignal.timeout(15000)});return {ok:r.ok,status:r.status,result:await r.json().catch(()=>null)}}
 if(!account.result){
  const random=Array.from(crypto.getRandomValues(new Uint8Array(32)),x=>x.toString(16).padStart(2,'0')).join('')+'Aa9!';
  const created=await admin('/auth/v1/admin/users',{email,password:random,email_confirm:true,app_metadata:{grillad_federated:true,naxa_subject:identity.subject}});
  if(!created.ok&&![400,409,422].includes(created.status))return fail(503,'SIGNUP_REFUSED');
  account=await lookup();
 }
 if(!account.ok||!uuid.test(account.result?.user_id))return fail(403,'ACCOUNT_SETUP_REQUIRED');
 // Generate and consume an internal one-time token server-side; no email is sent.
 const link=await admin('/auth/v1/admin/generate_link',{type:'magiclink',email});
 const hashToken=link.result?.hashed_token;
 if(!link.ok||typeof hashToken!=='string'||hashToken.length<20||hashToken.length>256)return fail(503,'AUTH_NOT_CONFIGURED');
 const issued=await post('/auth/v1/verify',{type:'magiclink',token_hash:hashToken});const s=issued.result;
 if(!issued.ok||!s?.access_token||!s?.refresh_token||s.user?.id!==account.result.user_id||s.user?.email!==email||s.user?.app_metadata?.grillad_federated!==true||s.user?.app_metadata?.naxa_subject!==identity.subject)return fail(403,'SESSION');
 let sid;try{sid=JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).session_id}catch{}
 if(!uuid.test(sid))return fail(403,'SESSION');
 let trial;
 if(!account.result.has_access){
  if(!profile)return {status:200,body:{result:{onboarding_required:true}}};
  const p=await post('/rest/v1/rpc/grillad_self_trial',{p_user:s.user.id,p_session:sid,p_email:email,p_name:body.name,p_phone:body.phone,p_org:body.organization,p_site:body.site_name,p_terms:body.terms},env.service);
  if(!p.ok)return fail(p.result?.code==='42501'?403:400,'SIGNUP_REFUSED');
  trial=p.result?.trial_ends_at;
 }
 const bound=await post('/rest/v1/rpc/grillad_auth_finish',{p_hash:hash,p_user:s.user.id,p_session:sid,p_installation:body.installation,p_platform:body.platform},env.service);
 if(!bound.ok||bound.result!==true)return fail(403,'DEVICE_OR_GRANT_DENIED');
 const w=await workspaceFor(s.access_token);if(!w)return fail(403,'NO_WORKSPACE');
 return {status:200,body:{result:{user_id:s.user.id,access:s.access_token,refresh:s.refresh_token,...(trial?{trial_ends_at:trial}:{}),...w}}};
}
