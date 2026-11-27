export const endpoint="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/widemeet-push-ci";
export async function ciIdentity(){
 const u=new URL(process.env.ACTIONS_ID_TOKEN_REQUEST_URL);u.searchParams.set("audience",endpoint);
 const r=await fetch(u,{headers:{Authorization:"Bearer "+process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN},redirect:"error",signal:AbortSignal.timeout(10000)});
 if(!r.ok)throw Error("CI identity unavailable");
 const {value}=await r.json();if(typeof value!=="string"||value.length<100)throw Error("CI identity invalid");return value;
}
export async function liveSend(kind,token){
 const identity=await ciIdentity();
 const r=await fetch(endpoint,{method:"POST",headers:{Authorization:"Bearer "+identity,"Content-Type":"application/json"},body:JSON.stringify({kind,token}),redirect:"error",signal:AbortSignal.timeout(35000)});
 if(!r.ok)throw Error("FCM qualification sender HTTP "+r.status);
 const j=await r.json();if(j.provider_status!=="accepted"||! /^[a-f0-9-]{36}$/.test(j.notification_id??""))throw Error("FCM provider acceptance unconfirmed");return j.notification_id;
}
if(process.argv[2]==="identity")process.stdout.write(await ciIdentity());
