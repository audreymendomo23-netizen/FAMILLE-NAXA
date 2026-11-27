// Private scheduler entrypoint. Run only on a trusted server after explicit configuration.
import {setTimeout as sleep} from "node:timers/promises";
if(process.env.WM_PERIODIC_WORKER_ENABLED!=="true")throw Error("periodic worker disabled");
const url=new URL(process.env.SUPABASE_URL),key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!key||!(url.protocol==="https:"||url.protocol==="http:"&&["localhost","127.0.0.1"].includes(url.hostname))||url.username||url.password)throw Error("invalid configuration");
const stop=new AbortController();for(const event of ["SIGTERM","SIGINT"])process.once(event,()=>stop.abort());
while(!stop.signal.aborted){try{const r=await fetch(new URL("/rest/v1/rpc/wm_periodic_run",url),{method:"POST",headers:{apikey:key,Authorization:"Bearer "+key,"Content-Type":"application/json"},body:JSON.stringify({p_limit:25}),redirect:"error",signal:AbortSignal.timeout(60000)});if(!r.ok)throw Error("backend");const n=await r.json();if(!Number.isInteger(n)||n<0||n>25)throw Error("invalid result");console.log("WM_PERIODIC_GENERATED "+n);}catch{console.log("WM_PERIODIC_RETRY");}try{await sleep(60000,undefined,{signal:stop.signal})}catch(e){if(e.name!=="AbortError")throw e}}
