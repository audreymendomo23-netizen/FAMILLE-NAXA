// Only copied into the disposable local Supabase project by the business CI.
// Do not deploy this test entrypoint to a hosted Supabase project.
import {createBusinessGateway} from "./business-gateway.mjs";
const env=(k:string)=>Deno.env.get(k)??"";
const base=env("SUPABASE_URL"),key=env("SUPABASE_SERVICE_ROLE_KEY");
if(env("ZIPPLE_BUSINESS_DISPOSABLE")!=="1"||!base||!key||!["kong","supabase_kong_zipple-business-ci","127.0.0.1","localhost"].includes(new URL(base).hostname))throw Error("LOCAL_RECIPE_ONLY");
const rpc=async(name:string,args:Record<string,unknown>)=>{
 const response=await fetch(base+"/rest/v1/rpc/"+encodeURIComponent(name),{method:"POST",headers:{apikey:key,Authorization:"Bearer "+key,"Content-Type":"application/json"},body:JSON.stringify(args),redirect:"error"});
 const raw=await response.text();let data=null;try{data=raw?JSON.parse(raw):null}catch{if(!response.ok)throw Error("OPERATION_UNAVAILABLE");return raw}
 if(!response.ok)throw Error(typeof data?.message==="string"?data.message:"OPERATION_UNAVAILABLE");
 return data;
};
Deno.serve(createBusinessGateway({rpc,origins:["https://zipple.test"],allowGuestOpen:true}));
