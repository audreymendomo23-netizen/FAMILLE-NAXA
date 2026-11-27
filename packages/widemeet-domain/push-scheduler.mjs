// Dedicated WideMeet scheduler. One-use database tickets, not permanent credentials, travel in pg_net.
import {fingerprint,serviceAccount,accessToken,dispatchPush,FIREBASE_PROJECT_ID} from "./push-delivery.mjs";
// Fixed destination and validation-only payload. Never sends a notification in preflight.
export async function validateProvider({project,access,fetcher=fetch}){
 if(project!==FIREBASE_PROJECT_ID||typeof access!=="string"||!access)throw Error("FCM_SCOPE");
 const response=await fetcher("https://fcm.googleapis.com/v1/projects/"+project+"/messages:send",{method:"POST",headers:{Authorization:"Bearer "+access,"Content-Type":"application/json"},body:JSON.stringify({validate_only:true,message:{topic:"widemeet-qualification-no-delivery",data:{app_id:"WIDEMEET",qualification:"validate-only"},notification:{title:"WideMeet",body:"Qualification"}}}),redirect:"error",signal:AbortSignal.timeout(10000)});
 const result=await response.json().catch(()=>null);
 if(response.ok&&typeof result?.name==="string"&&result.name.startsWith("projects/"+project+"/messages/"))return "fcm_validated";
 if(response.status===403)return "fcm_permission_denied";
 return "fcm_validation_failed";
}
export async function runScheduler({request,rpc,env,oauth=accessToken,dispatch=dispatchPush,validate=validateProvider,hash=fingerprint}){
 const response=(status)=>new Response(null,{status,headers:{"Cache-Control":"no-store"}});
 if(request.method!=="POST"||request.headers.has("origin"))return response(403);
 const auth=request.headers.get("authorization")??"";
 if(!/^Bearer [a-f0-9]{64}$/.test(auth))return response(403);
 let ticket;
 try{ticket=await rpc("wm_push_scheduler_take",{p_hash:await hash(auth.slice(7))})}catch{return response(503)}
 if(!ticket||!["preflight","dispatch"].includes(ticket.mode)||typeof ticket.id!=="string")return response(403);
 let outcome="configuration_invalid";
 try{
  const encryptionKey=env("WM_PUSH_ENCRYPTION_KEY")??"",workerSecret=env("WM_PUSH_WORKER_SECRET")??"",project=env("WM_FIREBASE_PROJECT_ID")??"";
  if(!/^[a-f0-9]{64}$/.test(encryptionKey)||!/^[a-f0-9]{64}$/.test(workerSecret)||encryptionKey===workerSecret)throw Error("configuration");
  const account=serviceAccount(env("WM_FCM_SERVICE_ACCOUNT_JSON")??"",project);
  if(ticket.mode==="dispatch"&&(env("WM_PUSH_QUALIFIED")!=="true"||env("WM_AUTH_QUALIFIED")!=="true"))outcome="disabled";
  else{
   outcome="oauth_failed";
   const access=await oauth(account);
   if(typeof access!=="string"||!access)throw Error("oauth");
   outcome="oauth_verified";
   if(ticket.mode==="preflight"){outcome="fcm_validation_failed";outcome=await validate({project,access});if(!["fcm_validated","fcm_permission_denied","fcm_validation_failed"].includes(outcome))outcome="fcm_validation_failed";}
   if(ticket.mode==="dispatch"){
    outcome="dispatch_failed";
    const result=await dispatch({rpc,encryptionKey,project,access,limit:5});
    outcome=result.uncertain>0||result.rejected>0?"dispatch_attention":"dispatch_completed";
   }
  }
 }catch{/* Never expose or log credentials or provider response. */}
 try{if(await rpc("wm_push_scheduler_finish",{p_id:ticket.id,p_outcome:outcome})!==true)return response(503)}catch{return response(503)}
 return response(204);
}
