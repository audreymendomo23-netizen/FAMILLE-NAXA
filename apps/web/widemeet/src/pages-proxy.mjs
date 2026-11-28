// WideMeet only: fixed upstream, no service credentials, no arbitrary destinations.
const upstream="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/";
const actions={
 "widemeet-auth":new Set(["register","registration-policy","recovery-enroll","recover-key","request-recovery","login","refresh","change-password","push","chat-media","identity","switch-workspace","logout"]),
 "widemeet-room":new Set(["list","contacts","pass-list","read","create","command","media-grant","minutes","tasks","series-create","series-cancel","presence","recordings","recording-download","notices","external-invite","report-xlsx","transcription","connect"])
};
const fail=(status)=>new Response(JSON.stringify({error:"request_rejected"}),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}});
export async function proxyWideMeet(request,env,fetcher=fetch){
 const url=new URL(request.url),origin=env.WM_PUBLIC_ORIGIN;
 if(!origin||url.protocol!=="https:"||url.origin!==origin||request.headers.get("Origin")!==origin||url.search)return fail(403);
 if(request.method!=="POST")return fail(405);
 const m=/^\/api\/(widemeet-auth|widemeet-room)\/([a-z-]+)$/.exec(url.pathname);
 if(!m||!actions[m[1]].has(m[2]))return fail(404);
 if(request.headers.get("Content-Type")?.split(";")[0].trim()!=="application/json")return fail(415);
 const headers=new Headers({"Content-Type":"application/json","Origin":origin});
 const bearer=request.headers.get("Authorization");if(bearer)headers.set("Authorization",bearer);
 if(m[1]==="widemeet-auth"){
  const cookie=request.headers.get("Cookie")?.split(";").map(x=>x.trim()).find(x=>/^__Host-widemeet_refresh=[a-f0-9]{64}$/.test(x));
  if(cookie)headers.set("Cookie",cookie);
 }
 try{
  const r=await fetcher(upstream+m[1]+"/"+m[2],{method:"POST",headers,body:request.body,redirect:"manual",cache:"no-store"});
  if(r.status>=300&&r.status<400)return fail(502);
  const out=new Headers({"Cache-Control":"private, no-store","X-Content-Type-Options":"nosniff"});
  for(const k of ["Content-Type","Content-Disposition"])if(r.headers.has(k))out.set(k,r.headers.get(k));
  const cookie=r.headers.get("Set-Cookie");
  if(m[1]==="widemeet-auth"&&cookie){
   if(!/^__Host-widemeet_refresh=(?:[a-f0-9]{64})?; Path=\/; Secure; HttpOnly; SameSite=Strict(?:; Max-Age=\d+)?$/.test(cookie))return fail(502);
   out.set("Set-Cookie",cookie);
  }
  return new Response(r.body,{status:r.status,headers:out});
 }catch{return fail(502)}
}
