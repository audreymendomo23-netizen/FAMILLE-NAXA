// ZIPPLE N1 candidate server boundary. No live adapter or credentials included.
// Provider must verify credentials/tokens, bind them to ZIPPLE, enforce rate limits,
// rotate refresh tokens and return trusted server membership, never caller metadata.
const response=(status,body)=>new Response(JSON.stringify(body),{status,headers:{"content-type":"application/json","cache-control":"no-store"}});
export function siteIdsFromScopes(scopes,active){
 if(!Array.isArray(scopes)||!Array.isArray(active))return [];
 const ids=new Set(active.filter(s=>s&&typeof s.id==="string"&&s.id&&s.active===true).map(s=>s.id));
 if(scopes.some(s=>s?.scope_type==="organization"))return [...ids];
 return [...new Set(scopes.filter(s=>s?.scope_type==="site"&&ids.has(s.site_id)).map(s=>s.site_id))];
}
export function scopedSession(identity,now=Date.now()){
 if(!identity||identity.app_id!=="ZIPPLE"||identity.active!==true||identity.session_active!==true||!["promoteur","manager","staff"].includes(identity.role)||typeof identity.member_id!=="string"||!identity.member_id||typeof identity.organization_id!=="string"||!identity.organization_id||typeof identity.access_token!=="string"||identity.access_token.length<20||!Number.isSafeInteger(identity.expires_at)||identity.expires_at<=now)throw Error("DENIED");
 const ids=siteIdsFromScopes(identity.scopes,identity.active_sites);
 const sites=identity.active_sites.filter(s=>ids.includes(s.id)).map(s=>({id:s.id,name:String(s.name??"")}));
 if(!sites.length||new Set(sites.map(s=>s.id)).size!==sites.length)throw Error("DENIED");
 return {app_id:"ZIPPLE",member_id:identity.member_id,organization_id:identity.organization_id,organization_name:String(identity.organization_name??""),role:identity.role,access_token:identity.access_token,expires_at:identity.expires_at,sites,...(typeof identity.refresh_token==="string"&&identity.refresh_token.length>=20?{refresh_token:identity.refresh_token}:{})};
}
export function createAuthHandler(provider){
 return async function handler(request){
  try{
   if(request.method!=="POST")return response(405,{error:"METHOD"});
   const action=new URL(request.url).pathname.split("/").pop();
   if(!["login","refresh","recovery","logout"].includes(action))return response(404,{error:"NOT_FOUND"});
   const raw=await request.text();if(raw.length>8192)return response(413,{error:"REQUEST_TOO_LARGE"});
   const body=JSON.parse(raw);
   if(!body||body.app_id!=="ZIPPLE")return response(403,{error:"DENIED"});
   if(action==="login"){
    if(typeof body.identifier!=="string"||!body.identifier.trim()||body.identifier.length>180||typeof body.password!=="string"||!body.password||body.password.length>1024)return response(400,{error:"INVALID"});
    await provider.rateLimit({action,identifier:body.identifier.trim()});
    const trusted=await provider.authenticate({app_id:"ZIPPLE",identifier:body.identifier.trim(),password:body.password,remember_device:body.remember_device===true});
    const session=scopedSession(trusted);
    if(body.remember_device!==true)delete session.refresh_token;
    return response(200,session);
   }
   if(action==="refresh"){
    if(typeof body.refresh_token!=="string"||body.refresh_token.length<20||body.refresh_token.length>4096)return response(400,{error:"INVALID"});
    await provider.rateLimit({action});
    return response(200,scopedSession(await provider.rotate({app_id:"ZIPPLE",refresh_token:body.refresh_token})));
   }
   if(action==="recovery"){
    if(typeof body.identifier!=="string"||!body.identifier.trim()||body.identifier.length>180)return response(400,{error:"INVALID"});
    await provider.rateLimit({action,identifier:body.identifier.trim()});
    await provider.recover({app_id:"ZIPPLE",identifier:body.identifier.trim()});
    return response(202,{accepted:true});
   }
   const bearer=request.headers.get("authorization")??"";
   if(!bearer.startsWith("Bearer ")||bearer.length<27)return response(401,{error:"DENIED"});
   await provider.revoke({app_id:"ZIPPLE",access_token:bearer.slice(7)});
   return response(200,{accepted:true});
  }catch{return response(401,{error:"DENIED"});}
 };
}
