import {runScheduler} from "../../../packages/widemeet-domain/push-scheduler.mjs";
const url=(Deno.env.get("SUPABASE_URL")??"").replace(/\/$/,"");
const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
async function rpc(name:string,args:Record<string,unknown>){
 const r=await fetch(url+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:key,Authorization:"Bearer "+key,"Content-Type":"application/json"},body:JSON.stringify(args),redirect:"error",signal:AbortSignal.timeout(5000)});
 if(!r.ok)throw Error("backend");return r.json();
}
Deno.serve(request=>runScheduler({request,rpc,env:(name:string)=>Deno.env.get(name)}));
