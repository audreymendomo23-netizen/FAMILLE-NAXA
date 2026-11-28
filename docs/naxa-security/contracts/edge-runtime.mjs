// NAXA EDGE: single-process durable telemetry spool. No actuation or device discovery.
import {mkdir,readdir,readFile,writeFile,rename,unlink,open,stat} from "node:fs/promises";
import {join} from "node:path";
import {randomUUID} from "node:crypto";
import {signObservation,verifyObservation,checkReceipt,deliver} from "./gateway-contract.mjs";
const eventName=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/;
export function createEdgeSpool({directory,binding,secret,transport,clock=Date.now,maxPending=1000}){
 if(!directory||typeof transport!=="function"||!Number.isInteger(maxPending)||maxPending<1||maxPending>10000)throw Error("INVALID_SPOOL");
 let chain=Promise.resolve();
 function exclusive(fn){const job=chain.then(fn);chain=job.catch(()=>{});return job}
 async function init(){await mkdir(directory,{recursive:true,mode:0o700});const s=await stat(directory);if(!s.isDirectory()||(s.mode&0o077)!==0)throw Error("UNSAFE_SPOOL_DIRECTORY")}
 async function names(){return (await readdir(directory)).filter(x=>eventName.test(x)).sort()}
 async function syncDirectory(){const d=await open(directory,"r");try{await d.sync()}finally{await d.close()}}
 async function persist(name,data){
  const tmp=join(directory,"."+randomUUID()+".tmp");const file=await open(tmp,"wx",0o600);
  try{await file.writeFile(JSON.stringify(data),"utf8");await file.sync()}finally{await file.close()}
  try{await rename(tmp,join(directory,name));await syncDirectory()}catch(e){await unlink(tmp).catch(()=>{});throw e}
 }
 async function enqueue(observation){return exclusive(async()=>{
  await init();const env=signObservation(observation,secret,clock());verifyObservation(env,binding,secret,clock());
  const name=env.payload.event_id.toLowerCase()+".json";let old;
  try{old=JSON.parse(await readFile(join(directory,name),"utf8"))}catch(e){if(e.code!=="ENOENT")throw e}
  if(old){if(JSON.stringify(old)!==JSON.stringify(env))throw Error("EVENT_CONFLICT");return {state:"queued",event_id:env.payload.event_id}}
  if((await names()).length>=maxPending)throw Error("SPOOL_FULL");
  await persist(name,env);return {state:"queued",event_id:env.payload.event_id}
 })}
 async function drain({limit=100}={}){return exclusive(async()=>{
  if(!Number.isInteger(limit)||limit<1||limit>1000)throw Error("INVALID_LIMIT");
  await init();const summary={confirmed:0,pending:0,expired:0,invalid:0};
  const entries=await names();
  // Sort by observation timestamp (UUIDs are not temporal); invalid entries remain visible for operator review.
  const batch=[];for(const name of entries){try{const p=join(directory,name);const st=await stat(p);if(st.size>16384)throw Error("OVERSIZE");const env=JSON.parse(await readFile(p,"utf8"));if(env?.payload?.event_id?.toLowerCase()+".json"!==name)throw Error("FILE_MISMATCH");batch.push({name,env,t:Date.parse(env.payload.observed_at)})}catch{summary.invalid++}}
  batch.sort((a,b)=>(a.t||0)-(b.t||0)||a.name.localeCompare(b.name));
  for(const {name,env,t} of batch.slice(0,limit)){
   const now=clock();if(!Number.isFinite(t)||t>now){summary.invalid++;continue}
   if(now-t>86400000){summary.expired++;continue} // retain for explicit supervised disposal; never silently delete.
   try{const p=verifyObservation(env,binding,secret,now);let receipt;try{receipt=await transport(p,env)}catch{summary.pending++;continue}
    if(!checkReceipt(p,receipt)){summary.pending++;continue}
    await unlink(join(directory,name));await syncDirectory();summary.confirmed++;
   }catch{summary.invalid++}
  }
  return {...summary,remaining:(await names()).length}
 })}
 return {enqueue,drain}
}
// Trusted ingress adapter. Credential resolution and SQL transport are injected, never client supplied.
export function createEdgeIngress({resolveGateway,store,clock=Date.now}){
 if(typeof resolveGateway!=="function"||typeof store!=="function")throw Error("INVALID_INGRESS");
 return async function ingest(envelope){
  const key=envelope?.payload?.gateway_id;
  if(typeof key!=="string"||!eventName.test(key.toLowerCase()+".json")||typeof envelope?.signature!=="string")throw Error("GATEWAY_DENIED");
  const config=await resolveGateway(key);
  if(!config)throw Error("GATEWAY_DENIED");
  return deliver(envelope,config.binding,config.secret,p=>store(p),clock())
 }
}
// HTTPS-only transport for the signed envelope; no redirect, no credentials in URL.
export function edgeHttpsTransport(endpoint,{fetcher=fetch,timeoutMs=15000}={}){
 const url=new URL(endpoint);
 if(url.protocol!=="https:"||url.username||url.password||url.search||url.hash||url.pathname!=="/security/edge/observations")throw Error("INVALID_ENDPOINT");
 return async(_p,envelope)=>{
  const res=await fetcher(url,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(envelope),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(timeoutMs)});
  if(!res.ok)throw Error("UNCONFIRMED");
  const text=await res.text();if(text.length>16384)throw Error("OVERSIZE_RECEIPT");return JSON.parse(text)
 }
}
