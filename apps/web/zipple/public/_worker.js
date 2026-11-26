const EDGE="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-n1";
const COOKIE="__Host-zipple-refresh";
const HOST="https://naxa-zipple.pages.dev";
const headers={"Content-Type":"application/json","Cache-Control":"private, no-store","X-Content-Type-Options":"nosniff","X-Zipple-Session-Revision":"3"};
const cookie=(value,age)=>COOKIE+"="+value+"; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age="+age;
const clear=cookie("",0);
// POST requests are never cached; do not use the version-dependent Workers Request.cache option.
const upstreamHeaders=authorization=>({"Content-Type":"application/json","Cache-Control":"no-store","Origin":HOST,...(authorization?{Authorization:authorization}:{})});
const tokenOK=t=>typeof t==="string"&&/^[A-Za-z0-9_-]{20,512}$/.test(t);
const answer=(status,body,setCookie)=>new Response(JSON.stringify(body),{status,headers:{...headers,...(setCookie?{"Set-Cookie":setCookie}:{})}});
// Reuse NAXA's server-side cookie boundary and NAXA Services' isolated session contract.
// Worker-specific adaptation: do not follow a redirect carrying credentials.
async function upstreamCall(action,payload,authorization,fetcher){
 const response=await fetcher(EDGE+"/"+action,{method:"POST",headers:upstreamHeaders(authorization),body:JSON.stringify(payload),redirect:"manual"});
 if(response.status>=300&&response.status<400)throw new Error("UPSTREAM_REDIRECT");
 return response;
}
export async function sessionRoute(req,fetcher=(input,init)=>globalThis.fetch(input,init)){
 const url=new URL(req.url),action=url.pathname.split("/").pop();
 if(url.origin!==HOST||req.headers.get("origin")!==url.origin||req.method!=="POST"||!["login","refresh","logout","forget"].includes(action)||!req.headers.get("content-type")?.startsWith("application/json"))return answer(403,{error:"DENIED"});
 let body;try{const raw=await req.text();if(raw.length>8192)return answer(413,{error:"INVALID"});body=JSON.parse(raw);if(!body||typeof body!=="object")return answer(400,{error:"INVALID"})}catch{return answer(400,{error:"INVALID"})}
 const old=(req.headers.get("cookie")||"").split(";").map(s=>s.trim()).find(s=>s.startsWith(COOKIE+"="))?.slice(COOKIE.length+1);
 if(action==="forget"){
  if(tokenOK(old))try{const rotated=await upstreamCall("refresh",{app_id:"ZIPPLE",refresh_token:old},undefined,fetcher);if(rotated.ok){const s=await rotated.json();if(s.app_id==="ZIPPLE"&&tokenOK(s.access_token))await upstreamCall("logout",{app_id:"ZIPPLE"},"Bearer "+s.access_token,fetcher)}}catch{}
  return answer(200,{accepted:true},clear);
 }
 let payload={app_id:"ZIPPLE"},authorization;
 if(action==="login"){
  if(typeof body.identifier!=="string"||!body.identifier.trim()||body.identifier.length>180||typeof body.password!=="string"||!body.password||body.password.length>1024)return answer(400,{error:"INVALID"});
  payload={...payload,identifier:body.identifier.trim(),password:body.password,remember_device:true};
 }else if(action==="refresh"){
  if(!tokenOK(old))return answer(401,{error:"DENIED"},clear);
  payload={...payload,refresh_token:old};
 }else{
  if(!tokenOK(body.access_token))return answer(401,{error:"DENIED"},clear);
  authorization="Bearer "+body.access_token;
 }
 try{
  const upstream=await upstreamCall(action,payload,authorization,fetcher);
  if(!upstream.ok){const denied=upstream.status===401||upstream.status===403;return answer(denied?401:upstream.status===429?429:503,{error:denied?"DENIED":upstream.status===429?"RATE_LIMITED":"UPSTREAM_UNAVAILABLE"},action==="logout"||(action==="refresh"&&denied)?clear:undefined)}
  if(action==="logout")return answer(200,{accepted:true},clear);
  const data=await upstream.json();
  if(data.app_id!=="ZIPPLE"||!tokenOK(data.refresh_token)||!tokenOK(data.access_token))return answer(502,{error:"INVALID_SESSION"},clear);
  const {refresh_token,...session}=data;
  return answer(200,session,cookie(refresh_token,604800));
 }catch(error){return answer(503,{error:error?.message==="UPSTREAM_REDIRECT"?"UPSTREAM_REDIRECT":"TRANSPORT_UNAVAILABLE"},action==="logout"?clear:undefined)}
}
export default {fetch(req,env){const u=new URL(req.url);return u.pathname.startsWith("/session/")?sessionRoute(req):env.ASSETS.fetch(req)}};
