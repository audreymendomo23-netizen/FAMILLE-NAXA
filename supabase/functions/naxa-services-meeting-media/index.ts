import {parseMediaGrant,signJoinToken,validMediaUrl} from "./media_contract.ts";
type Env={base:string;anon:string;url:string;key:string;secret:string;enabled:boolean;allowedOrigins:string[]};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function handleMediaRequest(req:Request,env:Env,transport:typeof fetch=fetch):Promise<Response>{
 const origin=req.headers.get("origin");const headers=new Headers({"Content-Type":"application/json","Cache-Control":"no-store","Vary":"Origin","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"});
 if(origin&&!env.allowedOrigins.includes(origin))return new Response(null,{status:403,headers});
 if(origin)headers.set("Access-Control-Allow-Origin",origin);
 const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
 if(req.method!=="POST")return reply(405,{error:"METHOD_NOT_ALLOWED"});
 // Flag remains false until lifecycle (active participant eviction), provider credentials, and device media recipes are proven.
 if(!env.enabled)return reply(503,{error:"MEDIA_UNAVAILABLE"});
 const token=req.headers.get("authorization");
 if(!token||!/^Bearer [^\s]+$/.test(token))return reply(401,{error:"AUTHENTICATION_REQUIRED"});
 let id:string;
 try{const raw=await req.json();id=raw?.meeting_id;if(typeof id!=="string"||!uuid.test(id))throw Error();}catch{return reply(400,{error:"INVALID_MEETING_ID"});}
 try{
  const base=new URL(env.base);if(base.protocol!=="https:"||base.username||base.password||base.pathname!=="/"||base.search||base.hash||env.anon.length<20)throw Error("MEDIA_CONFIG_INVALID");
  const url=validMediaUrl(env.url);
  const authHeaders={apikey:env.anon,Authorization:token};
  const user=await transport(base.origin+"/auth/v1/user",{headers:authHeaders,redirect:"error"});
  if(!user.ok)return reply(401,{error:"AUTHENTICATION_REQUIRED"});
  const result=await transport(base.origin+"/rest/v1/rpc/ns_meeting_media_grant",{method:"POST",headers:{...authHeaders,"Content-Type":"application/json"},body:JSON.stringify({p_id:id}),redirect:"error"});
  if(!result.ok)return reply(403,{error:"MEDIA_FORBIDDEN"});
  const grant=parseMediaGrant(await result.json(),id);
  return reply(200,{url,token:await signJoinToken(grant,env.key,env.secret),expires_in:90});
 }catch{return reply(503,{error:"MEDIA_UNAVAILABLE"});}
}
if(import.meta.main)Deno.serve(req=>handleMediaRequest(req,{
 base:Deno.env.get("SUPABASE_URL")??"",anon:Deno.env.get("SUPABASE_ANON_KEY")??"",
 url:Deno.env.get("NS_LIVEKIT_URL")??"",key:Deno.env.get("NS_LIVEKIT_API_KEY")??"",secret:Deno.env.get("NS_LIVEKIT_API_SECRET")??"",
 enabled:Deno.env.get("NS_MEDIA_LIFECYCLE_QUALIFIED")==="true",allowedOrigins:(Deno.env.get("NS_ALLOWED_ORIGINS")??"").split(",").map(x=>x.trim()).filter(Boolean)
}));
