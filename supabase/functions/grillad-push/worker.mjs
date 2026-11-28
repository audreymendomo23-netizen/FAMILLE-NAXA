// Dedicated GRILLAD FCM data-only transport. No token, credential or notice content in logs.
const oauth='https://oauth2.googleapis.com/token',fcm='https://fcm.googleapis.com/v1/projects/grillad/messages:send';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const enc=new TextEncoder();
const b64=x=>btoa(String.fromCharCode(...new Uint8Array(x))).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const part=x=>b64(enc.encode(JSON.stringify(x)));
export function account(raw){
 const a=JSON.parse(raw||'{}');
 if(a.type!=='service_account'||a.project_id!=='grillad'||!/^[-a-z0-9.]+@grillad\.iam\.gserviceaccount\.com$/.test(a.client_email||'')||!/^-----BEGIN PRIVATE KEY-----[\s\S]+-----END PRIVATE KEY-----\s*$/.test(a.private_key||''))throw Error('FCM_CONFIG');
 return a;
}
export async function accessToken(a,fetcher=fetch){
 const pem=a.private_key.replace(/-----[^-]+-----|\s/g,'');
 const key=await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
 const now=Math.floor(Date.now()/1000);
 const unsigned=part({alg:'RS256',typ:'JWT'})+'.'+part({iss:a.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:oauth,iat:now,exp:now+3300});
 const assertion=unsigned+'.'+b64(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,enc.encode(unsigned)));
 const r=await fetcher(oauth,{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),redirect:'error',signal:AbortSignal.timeout(10000)});
 if(!r.ok)throw Error('FCM_OAUTH');const v=await r.json();if(typeof v.access_token!=='string'||!v.access_token)throw Error('FCM_OAUTH');return v.access_token;
}
export async function send(token,bearer,fetcher=fetch){
 if(typeof token!=='string'||token.length<30||token.length>4096||/\s/.test(token))return 'refused';
 try{
 const r=await fetcher(fcm,{method:'POST',headers:{Authorization:'Bearer '+bearer,'Content-Type':'application/json'},body:JSON.stringify({message:{token,data:{app:'grillad',kind:'inbox'},android:{priority:'normal',ttl:'3600s',collapse_key:'grillad_inbox'}}}),redirect:'error',signal:AbortSignal.timeout(10000)});
 const j=await r.json().catch(()=>null);
 if(r.ok)return typeof j?.name==='string'&&j.name.startsWith('projects/grillad/messages/')?'accepted':'uncertain';
 if(r.status===404&&j?.error?.details?.some(x=>x.errorCode==='UNREGISTERED'))return 'invalid';
 return r.status===429||r.status>=500?'uncertain':'refused';
 }catch{return 'uncertain'}
}
export async function run(req,env,fetcher=fetch,authorize=accessToken){
 const reply=(s,v)=>new Response(JSON.stringify(v),{status:s,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
 if(req.method!=='POST'||!env.jobSecret||env.jobSecret.length<32||req.headers.get('x-grillad-job-secret')!==env.jobSecret)return reply(403,{error:'DENIED'});
 if(!/^https:\/\/idupfjbkwjcavyisxteo\.supabase\.co$/.test(env.url||'')||!env.service)return reply(503,{error:'NOT_CONFIGURED'});
 let bearer;try{bearer=await authorize(account(env.account),fetcher)}catch{return reply(503,{error:'FCM_AUTH_UNAVAILABLE'})}
 async function rpc(name,p){const r=await fetcher(env.url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:env.service,Authorization:'Bearer '+env.service,'Content-Type':'application/json'},body:JSON.stringify(p),redirect:'error',signal:AbortSignal.timeout(10000)});if(!r.ok)throw Error('RPC');return r.json()}
 const totals={accepted:0,invalid:0,refused:0,uncertain:0,skipped:0};
 try{
 const ids=await rpc('grillad_push_claim',{p_limit:10});if(!Array.isArray(ids)||ids.length>10||ids.some(x=>!uuid.test(x.id)))throw Error('CLAIMS');
 for(const {id} of ids){const d=await rpc('grillad_push_start',{p_id:id});if(d===null){totals.skipped++;continue}const result=await send(d.token,bearer,fetcher);if(await rpc('grillad_push_finish',{p_id:id,p_status:result})!==true)throw Error('FINISH');totals[result]++}
 return reply(totals.uncertain||totals.refused?503:200,totals);
 }catch{return reply(503,{error:'JOB_INCOMPLETE',...totals})}
}
