// Isolated server-side purge runner. No production scheduler or commercial retention policy.
import {unlink} from "node:fs/promises";
import {resolve} from "node:path";
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export function createWideMeetAudioPurge({supabaseUrl,serviceKey,outputDirectory,storage,isolated=false,fetcher=fetch,removeFile=unlink}){
 const base=new URL(supabaseUrl);
 if(isolated!==true||base.origin!=="http://127.0.0.1:54321"||base.pathname!=="/"||base.username||base.password||base.search||base.hash||!serviceKey||!outputDirectory||typeof storage?.removeVerified!=="function")throw Error("isolated purge configuration required");
 const root=resolve(outputDirectory),headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"};
 async function rpc(name,body){const r=await fetcher(new URL("/rest/v1/rpc/"+name,base),{method:"POST",headers,body:JSON.stringify(body),cache:"no-store",redirect:"error",signal:AbortSignal.timeout(15000)});if(!r.ok)throw Error("purge ledger unavailable");return r.json()}
 async function runOnce(){
  const row=await rpc("wm_b6_audio_purge_claim",{});if(row===null)return {claimed:false};
  if(!UUID.test(row.id??"")||!UUID.test(row.room_id??"")||row.object_name!==row.id+".ogg"||(row.storage_key!==null&&row.storage_key!==row.room_id+"/"+row.id+".ogg"))throw Error("invalid purge record");
  if(row.storage_key!==null)await storage.removeVerified(row.storage_key);
  try{await removeFile(resolve(root,row.object_name))}catch(e){if(e?.code!=="ENOENT")throw e}
  if(await rpc("wm_b6_audio_purge_ack",{p_id:row.id,p_key:row.storage_key})!==true)throw Error("purge confirmation unavailable");
  return {claimed:true,purged:true};
 }
 return {runOnce};
}
