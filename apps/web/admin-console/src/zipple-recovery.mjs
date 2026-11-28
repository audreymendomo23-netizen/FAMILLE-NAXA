// The central console uses ordinary Supabase Auth with a PUBLIC key and pre-enrolled operator TOTP.
const project="https://idupfjbkwjcavyisxteo.supabase.co";
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function publicKeyAllowed(key){
 if(typeof key!=="string")return false;
 if(/^sb_publishable_[A-Za-z0-9_-]+$/.test(key))return true;
 try{const p=key.split(".");if(p.length!==3)return false;const s=p[1].replace(/-/g,"+").replace(/_/g,"/");const c=JSON.parse(atob(s.padEnd(Math.ceil(s.length/4)*4,"=")));return c.role==="anon"&&c.ref==="idupfjbkwjcavyisxteo"}catch{return false}
}
export function createRecoveryClient({url,key,fetcher=fetch}){
 if(url!==project||!publicKeyAllowed(key))throw Error("CONFIGURATION");
 async function request(path,method,body,token){
  const r=await fetcher(project+path,{method,headers:{...(path.startsWith("/auth/v1/")?{apikey:key}:{}),"content-type":"application/json",...(token?{authorization:"Bearer "+token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(20000)});
  if(!r.ok)throw Error("ACCESS_DENIED");const raw=await r.text();return raw?JSON.parse(raw):null;
 }
 const auth=(path,method,body,token)=>request("/auth/v1/"+path,method,body,token);
 const edge=(action,body,token)=>request("/functions/v1/zipple-n1/admin/recovery/"+action,"POST",{app_id:"ZIPPLE",...body},token);
 return {
  async login(email,password){
   const s=await auth("token?grant_type=password","POST",{email,password});
   if(typeof s?.access_token!=="string")throw Error("ACCESS_DENIED");
   try{
    const u=await auth("user","GET",undefined,s.access_token);
    const factors=(u?.factors??[]).filter(f=>f.factor_type==="totp"&&f.status==="verified"&&uuid.test(f.id)).map(f=>({id:f.id,name:f.friendly_name||"Authentificateur"}));
    if(!factors.length)throw Error("MFA_ENROLLMENT_REQUIRED");
    return {token:s.access_token,factors};
   }catch(e){try{await auth("logout?scope=local","POST",undefined,s.access_token)}catch{}throw e}
  },
  async verify(token,factor,code){
   if(!uuid.test(factor)||!/^\d{6}$/.test(code))throw Error("INVALID_CODE");
   const c=await auth("factors/"+factor+"/challenge","POST",{},token);
   if(!uuid.test(c?.id??""))throw Error("ACCESS_DENIED");
   const s=await auth("factors/"+factor+"/verify","POST",{challenge_id:c.id,code},token);
   if(typeof s?.access_token!=="string")throw Error("ACCESS_DENIED");return s.access_token;
  },
  async widemeet(token,action,data={}){if(!token||typeof action!=="string")throw Error("ACCESS_DENIED");const result=await request("/functions/v1/widemeet-auth/central","POST",{app_id:"WIDEMEET",action,data},token);if(!result||typeof result!=="object")throw Error("ACCESS_DENIED");return result},
  async list(token){const data=await edge("list",{},token);if(!Array.isArray(data?.requests))throw Error("ACCESS_DENIED");return data.requests},
  async complete(token,id,reason,password){
   if(!uuid.test(id)||typeof reason!=="string"||reason.trim().length<10||reason.length>500||typeof password!=="string"||password.length<12||password.length>128)throw Error("INVALID_INPUT");
   const data=await edge("complete",{request_id:id,reason:reason.trim(),new_password:password},token);
   if(data?.resolved!==true)throw Error("ACCESS_DENIED");return true;
  },
  logout(token){return auth("logout?scope=local","POST",undefined,token)}
 };
}
