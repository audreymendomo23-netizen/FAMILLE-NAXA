const EDGE="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-n1";
const COOKIE="__Host-zipple-refresh";
const HOST="https://naxa-zipple.pages.dev";
const headers={"Content-Type":"application/json","Cache-Control":"no-store","X-Content-Type-Options":"nosniff"};
const cookie=(value,age)=>COOKIE+"="+value+"; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age="+age;
const clear=cookie("",0);
const tokenOK=t=>typeof t==="string"&&/^[A-Za-z0-9_-]{20,512}$/.test(t);
const answer=(status,body,setCookie)=>new Response(JSON.stringify(body),{status,headers:{...headers,...(setCookie?{"Set-Cookie":setCookie}:{})}});
export async function sessionRoute(req,fetcher=fetch){
 const url=new URL(req.url),action=url.pathname.split("/").pop();
 if(url.origin!==HOST||req.headers.get("origin")!==url.origin||req.method!=="POST"||!["login","refresh","logout","forget"].includes(action)||!req.headers.get("content-type")?.startsWith("application/json"))return answer(403,{error:"DENIED"});
 let body;try{const raw=await req.text();if(raw.length>8192)return answer(413,{error:"INVALID"});body=JSON.parse(raw);if(!body||typeof body!=="object")return answer(400,{error:"INVALID"})}catch{return answer(400,{error:"INVALID"})}
 const old=(req.headers.get("cookie")||"").split(";").map(s=>s.trim()).find(s=>s.startsWith(COOKIE+"="))?.slice(COOKIE.length+1);
 if(action==="forget"){
  if(tokenOK(old))try{const rotated=await fetcher(EDGE+"/refresh",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"ZIPPLE",refresh_token:old}),redirect:"error"});if(rotated.ok){const s=await rotated.json();if(s.app_id==="ZIPPLE"&&tokenOK(s.access_token))await fetcher(EDGE+"/logout",{method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+s.access_token},body:JSON.stringify({app_id:"ZIPPLE"}),redirect:"error"})}}catch{}
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
  const upstream=await fetcher(EDGE+"/"+action,{method:"POST",headers:{"Content-Type":"application/json",...(authorization?{Authorization:authorization}:{})},body:JSON.stringify(payload),redirect:"error",cache:"no-store"});
  if(!upstream.ok)return answer(upstream.status>=500?503:401,{error:"DENIED"},action==="login"?undefined:clear);
  if(action==="logout")return answer(200,{accepted:true},clear);
  const data=await upstream.json();
  if(data.app_id!=="ZIPPLE"||!tokenOK(data.refresh_token)||!tokenOK(data.access_token))return answer(502,{error:"INVALID_SESSION"},clear);
  const {refresh_token,...session}=data;
  return answer(200,session,cookie(refresh_token,604800));
 }catch{return answer(503,{error:"UNAVAILABLE"},action==="logout"?clear:undefined)}
}
export default {fetch(req,env){const u=new URL(req.url);return u.pathname.startsWith("/session/")?sessionRoute(req):env.ASSETS.fetch(req)}};
