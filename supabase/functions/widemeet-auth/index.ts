// WideMeet internal login candidate. Adapted from NS internal aliases and ZIPPLE opaque sessions.
// No deployment until disposable Replay and rate-limit qualification; default disabled.
const url=(Deno.env.get("SUPABASE_URL")??"").replace(/\/$/,"");
const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
const anon=Deno.env.get("SUPABASE_ANON_KEY")??"";
const origins=new Set((Deno.env.get("WM_ALLOWED_ORIGINS")??"").split(",").map(s=>s.trim()).filter(Boolean));
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const headers={apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"};
async function rest(path:string,init:RequestInit={}){
 const response=await fetch(url+"/rest/v1/"+path,{...init,headers:{...headers,...(init.headers??{})},redirect:"error",cache:"no-store"});
 if(!response.ok)throw new Error("backend_rejected");
 return response.status===204?null:await response.json();
}
function eq(v:string){return encodeURIComponent(v)}
async function digest(v:string){return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(v)))).map(n=>n.toString(16).padStart(2,"0")).join("")}
function token(){return Array.from(crypto.getRandomValues(new Uint8Array(32))).map(n=>n.toString(16).padStart(2,"0")).join("")}
async function workspaces(accountId:string){
 const rows=await rest("wm_memberships?select=workspace_id,role,enabled,wm_workspaces!inner(id,kind,name,enabled)&account_id=eq."+eq(accountId)+"&enabled=eq.true&wm_workspaces.enabled=eq.true");
 return rows.flatMap((r:any)=>{const w=r.wm_workspaces;return w&&((w.kind==="individual"&&r.role==="owner")||(w.kind==="enterprise"&&["promoteur","manager","staff"].includes(r.role)))?[{id:w.id,kind:w.kind,name:w.name,role:r.role,enabled:true}]:[]});
}
Deno.serve(async request=>{
 const origin=request.headers.get("origin");
 const cors=origin&&origins.has(origin)?{"Access-Control-Allow-Origin":origin,"Vary":"Origin","Access-Control-Allow-Headers":"content-type,authorization,apikey","Access-Control-Allow-Methods":"POST,OPTIONS"}:{};
 const send=(status:number,body:unknown)=>new Response(status===204?null:JSON.stringify(body),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store",...cors}});
 if(origin&&!origins.has(origin))return send(403,{error:"forbidden"});
 if(request.method==="OPTIONS")return send(204,null);
 if(Deno.env.get("WM_AUTH_QUALIFIED")!=="true"||!url||!service||!anon)return send(503,{error:"unavailable"});
 if(request.method!=="POST")return send(405,{error:"method"});
 try{
 const action=new URL(request.url).pathname.split("/").filter(Boolean).at(-1);
 const body=await request.json();
 if(!body||body.app_id!=="WIDEMEET")return send(403,{error:"forbidden"});
 if(action==="login"){
 const identifier=typeof body.identifier==="string"?body.identifier.trim().toUpperCase():"";
 const password=body.password;
 if(!/^WM-[A-Z0-9]{8,24}$/.test(identifier)||typeof password!=="string"||password.length<1||password.length>256||!uuid.test(body.installation_id??"")||!["web","android"].includes(body.platform))return send(401,{error:"credentials"});
 const rows=await rest("wm_accounts?select=id,auth_user_id,auth_alias,password_change_required,enabled&login_id=eq."+eq(identifier)+"&enabled=eq.true&limit=1");
 const a=rows[0];if(!a)return send(401,{error:"credentials"});
 const auth=await fetch(url+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:anon,"Content-Type":"application/json"},body:JSON.stringify({email:a.auth_alias,password}),redirect:"error",cache:"no-store"});
 if(!auth.ok)return send(401,{error:"credentials"});
 const authData=await auth.json();if(authData.user?.id!==a.auth_user_id)return send(401,{error:"credentials"});
 // Do not return the GoTrue token, use a dedicated WideMeet opaque session instead.
 const ws=await workspaces(a.id);if(!ws.length)return send(403,{error:"scope"});
 const active=ws.find((w:any)=>w.kind==="individual")??ws[0];
 const access=token();
 const sessionId=await rest("rpc/wm_issue_device_session",{method:"POST",body:JSON.stringify({p_account:a.id,p_installation:body.installation_id,p_workspace:active.id,p_hash:await digest(access)})});
 const saved=(await rest("wm_device_sessions?select=expires_at&id=eq."+eq(sessionId)+"&revoked_at=is.null&limit=1"))[0];
 if(!saved)return send(403,{error:"scope"});
 return send(200,{app_id:"WIDEMEET",access_token:access,member_id:a.id,device_id:sessionId,expires_at:Date.parse(saved.expires_at),server_now:Date.now(),require_password_change:a.password_change_required,active_workspace_id:active.id,workspaces:ws});
 }
 if(action==="logout"){
 const access=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(!/^[a-f0-9]{64}$/.test(access))return send(401,{error:"credentials"});
 await rest("wm_device_sessions?token_hash=eq."+await digest(access)+"&revoked_at=is.null",{method:"PATCH",body:JSON.stringify({revoked_at:new Date().toISOString()})});
 return send(204,null);
 }
 return send(404,{error:"unavailable"});
 }catch{return send(503,{error:"unavailable"})}
});
