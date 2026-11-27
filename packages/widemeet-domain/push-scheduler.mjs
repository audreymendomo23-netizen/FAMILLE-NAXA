// Dedicated WideMeet scheduler. One-use database tickets, not permanent credentials, travel in pg_net.
import {fingerprint,serviceAccount,accessToken,dispatchPush} from "./push-delivery.mjs";
export async function runScheduler({request,rpc,env,oauth=accessToken,dispatch=dispatchPush,hash=fingerprint}){
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
