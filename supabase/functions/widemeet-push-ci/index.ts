import {verifyCiToken} from "../../../packages/widemeet-domain/push-ci-oidc.mjs";
import {fingerprint,serviceAccount,accessToken,sendPush,validPushToken} from "../../../packages/widemeet-domain/push-delivery.mjs";
import {scope} from "./scope.ts";
const base=(Deno.env.get("SUPABASE_URL")??"").replace(/\/$/,""),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
const respond=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}});
const headers={apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json",Prefer:"return=minimal"};
Deno.serve(async request=>{
 if(request.method!=="POST"||request.headers.has("origin"))return respond(403,{error:"scope"});
 const auth=request.headers.get("authorization")??"";
 if(!auth.startsWith("Bearer ")||!base||!service||Deno.env.get("WM_PUSH_QUALIFIED")!=="true")return respond(403,{error:"scope"});
 const identity=await verifyCiToken(auth.slice(7),scope);if(!identity)return respond(403,{error:"scope"});
 try{
  const reader=request.body?.getReader();if(!reader)return respond(400,{error:"request"});
  let size=0,raw="";const decoder=new TextDecoder();
  for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>8192){await reader.cancel();return respond(413,{error:"request"})}raw+=decoder.decode(value,{stream:true})}raw+=decoder.decode();
  const b=JSON.parse(raw);
  if(!b||!["web-foreground","web-background","android"].includes(b.kind)||!validPushToken(b.token)||Object.keys(b).some(k=>!["kind","token"].includes(k)))return respond(400,{error:"request"});
  const id=crypto.randomUUID(),jtiHash=await fingerprint(identity.jti);
  const claim=await fetch(base+"/rest/v1/wm_push_ci_deliveries",{method:"POST",headers,body:JSON.stringify({campaign_sha:identity.sha,kind:b.kind,jti_hash:jtiHash,notification_id:id,provider_status:"claimed"}),redirect:"error",signal:AbortSignal.timeout(5000)});
  if(!claim.ok)return respond(claim.status===409?409:503,{error:"claim"});
  let outcome="uncertain";
  try{
   const project=Deno.env.get("WM_FIREBASE_PROJECT_ID")??"",account=serviceAccount(Deno.env.get("WM_FCM_SERVICE_ACCOUNT_JSON")??"",project);
   const access=await accessToken(account);
   outcome=(await sendPush({project,access,token:b.token,id})).status;
  }catch{/* do not log credentials or raw provider errors */}
  const saved=await fetch(base+"/rest/v1/wm_push_ci_deliveries?campaign_sha=eq."+identity.sha+"&kind=eq."+b.kind,{method:"PATCH",headers,body:JSON.stringify({provider_status:outcome,finished_at:new Date().toISOString()}),redirect:"error",signal:AbortSignal.timeout(5000)});
  if(!saved.ok||outcome!=="accepted")return respond(503,{error:"provider_unconfirmed"});
  return respond(200,{notification_id:id,provider_status:"accepted"});
 }catch{return respond(503,{error:"unconfirmed"})}
});
