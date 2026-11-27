// Server-only WideMeet audio recorder. Never imported by Web/Android clients.
// The database owns claims, consent intent and visibility. The private Egress
// service writes local quarantine files. No public object URLs are generated.
import {createHash} from "node:crypto";
import {readFile,stat,unlink,chmod} from "node:fs/promises";
import {resolve,basename} from "node:path";
import {EncodedFileOutput,EncodedFileType,EgressStatus} from "livekit-server-sdk";
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const terminal=s=>[EgressStatus.EGRESS_COMPLETE,EgressStatus.EGRESS_FAILED,EgressStatus.EGRESS_ABORTED,EgressStatus.EGRESS_LIMIT_REACHED].includes(s);
export function createWideMeetRecorder({supabaseUrl,serviceKey,egress,outputDirectory,verifyAudio,storage=null,fetcher=fetch}){
 const base=new URL(supabaseUrl);
 if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey||typeof verifyAudio!=="function")throw Error("invalid recorder configuration");
 const root=resolve(outputDirectory),headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json",Prefer:"return=representation"};
 const local=new Map(),locks=new Map();
 async function db(path,method="GET",body){
  const response=await fetcher(new URL("/rest/v1/"+path,base),{method,headers,body:body===undefined?undefined:JSON.stringify(body),cache:"no-store",redirect:"error",signal:AbortSignal.timeout(5000)});
  if(!response.ok)throw Error("recording ledger unavailable");return response.status===204?null:response.json();
 }
 const policy=room=>db("rpc/wm_recording_policy","POST",{p_room:room});
 const claim=(room,id)=>db("rpc/wm_recording_claim","POST",{p_room:room,p_request:id});
 const ledger=async id=>(await db("wm_recording_runs?id=eq."+id+"&limit=1"))[0];
 const patch=async(id,phases,data)=>(await db("wm_recording_runs?id=eq."+id+"&phase=in.("+phases.join(",")+")","PATCH",data))?.[0];
 const activeRows=room=>db("wm_recording_runs?room_id=eq."+room+"&phase=in.(starting,active,stopping)");
 async function provider(id){return (await egress.listEgress({egressId:id})).find(x=>x.egressId===id)??null}
 function pathFor(row){if(!UUID.test(row.id)||row.object_name!==row.id+".ogg"||basename(row.object_name)!==row.object_name)throw Error("invalid object");return resolve(root,row.object_name)}
 async function discard(row){await unlink(pathFor(row)).catch(e=>{if(e?.code!=="ENOENT")throw e})}
 async function finish(row,info){
  const current=await ledger(row.id);if(!current)return;
  const file=pathFor(current);let retain=current.disposition==="retain"&&current.phase==="stopping"&&info?.status===EgressStatus.EGRESS_COMPLETE;
  if(retain){
   let storedKey=null;
   try{
    await chmod(file,0o600);
    const size=(await stat(file)).size;if(size<1000||size>128*1024*1024)throw Error("invalid size");
    await verifyAudio(file);
    const bytes=await readFile(file),sha=createHash("sha256").update(bytes).digest("hex");
    if(storage)storedKey=await storage.put(current,bytes,sha);
    // Compare disposition again to avoid publishing a segment quarantined during verification.
    const rows=await db("wm_recording_runs?id=eq."+row.id+"&phase=eq.stopping&disposition=eq.retain","PATCH",{phase:"complete",finished_at:new Date().toISOString(),bytes:size,content_sha256:sha,...(storedKey?{storage_key:storedKey,stored_at:new Date().toISOString()}:{})});
    if(rows?.length===1){if(storedKey)try{await discard(current)}catch{console.warn("WideMeet local audio cleanup pending")}local.delete(row.room_id);return}
   }catch{retain=false}
   if(storedKey){const after=await ledger(row.id).catch(()=>null);if(after&&after.phase!=="complete")await storage.remove(storedKey).catch(()=>{});}
  }
  await discard(current);
  await patch(row.id,["starting","active","stopping"],{phase:"discarded",disposition:"discard",finished_at:new Date().toISOString()});
  local.delete(row.room_id);
 }
 async function stop(row,forceDiscard){
  const current=await ledger(row.id);
  if(!current){local.delete(row.room_id);return}
  if(!["starting","active","stopping"].includes(current.phase)){local.delete(row.room_id);return}
  await patch(row.id,["starting","active","stopping"],{phase:"stopping",...(forceDiscard?{disposition:"discard"}:{})});
  const pid=current.provider_id??local.get(row.room_id)?.provider_id;
  if(!pid){
   // A lost start response is not proof that recording never began. Quarantine
   // and reconcile any matching active provider run; never start another one.
   const runs=await egress.listEgress({roomName:"wm-"+row.room_id,active:true});
   for(const run of runs)if(run.egressId)await egress.stopEgress(run.egressId).catch(()=>{});
   if(runs.length)return;
   await finish(current,null);return
  }
  const info=await provider(pid);
  if(info&&terminal(info.status)){await finish(current,info);return}
  if(info&&info.status!==EgressStatus.EGRESS_ENDING)await egress.stopEgress(pid).catch(()=>{});
 }
 async function tick(room){
  let p;
  try{p=await policy(room)}catch(e){
   const r=local.get(room);if(r?.provider_id)await egress.stopEgress(r.provider_id).catch(()=>{});
   throw e
  }
  const rows=await activeRows(room);
  for(const row of rows){
   const current=local.get(room);local.set(room,{...row,provider_id:row.provider_id??current?.provider_id});
   if(row.phase==="stopping"||p?.permitted!==true||p.request_id!==row.request_id){
    await stop(row,row.disposition==="discard"||row.phase!=="stopping"||p?.permitted===true&&p.request_id!==row.request_id);return
   }
   if(!row.provider_id){
    // Unknown in-flight job after restart. Stop possible orphan, quarantine.
    await stop(row,true);return
   }
   const info=await provider(row.provider_id);
   if(!info||terminal(info.status)){await stop(row,true);return}
   if(info.status===EgressStatus.EGRESS_ACTIVE&&row.phase==="starting")await patch(row.id,["starting"],{phase:"active",started_at:new Date().toISOString()});
   return;
  }
  if(p?.permitted!==true||!UUID.test(p.request_id??""))return;
  const row=await claim(room,p.request_id);if(!row)return;
  local.set(room,row);
  try{
   const fresh=await policy(room);
   if(fresh?.permitted!==true||fresh.request_id!==row.request_id){await stop(row,true);return}
   const started=await egress.startRoomCompositeEgress("wm-"+room,new EncodedFileOutput({fileType:EncodedFileType.OGG,filepath:"/out/"+row.object_name}),{audioOnly:true});
   if(!started.egressId)throw Error("unconfirmed provider start");
   local.set(room,{...row,provider_id:started.egressId});
   // Persist ID even if consent changed during provider startup; stop immediately on next tick.
   await patch(row.id,["starting","stopping"],{provider_id:started.egressId});
   const after=await policy(room);if(after?.permitted!==true||after.request_id!==row.request_id)await stop(row,true);
  }catch(e){await stop(row,true).catch(()=>{});throw e}
 }
 async function reconcile(room){
  if(!UUID.test(room))throw Error("invalid room");
  if(locks.has(room))return locks.get(room);
  const job=tick(room).finally(()=>locks.delete(room));locks.set(room,job);return job
 }
 return {reconcile,async close(room){const row=(await activeRows(room))[0];if(row)await stop(row,true)}};
}
