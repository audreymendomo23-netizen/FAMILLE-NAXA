// Server-only local ASR. Input is an authenticated private object with a verified hash.
import {createHash,randomUUID} from "node:crypto";
import {mkdtemp,writeFile,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join,resolve} from "node:path";
import {execFile} from "node:child_process";
import {promisify} from "node:util";
import {fileURLToPath} from "node:url";
const execute=promisify(execFile);
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const script=fileURLToPath(new URL("../../scripts/widemeet/local-asr.py",import.meta.url));
// One execution path for the worker and the isolated synthetic preflight.
export async function runLocalAsr({python,modelDir,path,home}){
 const {stdout}=await execute(resolve(python),[script,resolve(modelDir),resolve(path)],{timeout:480000,maxBuffer:1048576,env:{PATH:process.env.PATH??"/usr/bin:/bin",HOME:home,HF_HOME:join(home,"hf"),HF_HUB_OFFLINE:"1",TRANSFORMERS_OFFLINE:"1",PYTHONUTF8:"1",PYTHONNOUSERSITE:"1",OMP_NUM_THREADS:"2",TOKENIZERS_PARALLELISM:"false"}});
 return JSON.parse(stdout);
}
export function localAsrFailure(e){
 const marker=typeof e?.stderr==="string"?e.stderr.match(/^WM_ASR_ERROR:(import|input|model|decode|segments|output):(ImportError|ModuleNotFoundError|ValueError|RuntimeError|OSError|FileNotFoundError|TypeError|AttributeError|other)$/m):null;
 return marker?marker[1]+":"+marker[2]:e?.code==="ENOENT"?"executable-missing":e?.killed?"subprocess-terminated":typeof e?.code==="number"?"subprocess-exit":"operation-failed";
}
export function createWideMeetTranscription({supabaseUrl,serviceKey,python,modelDir,fetcher=fetch}){
 const base=new URL(supabaseUrl);if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey||!python||!modelDir)throw Error("invalid ASR configuration");
 const headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey};
 async function rpc(action,recording,lease,result=null){const r=await fetcher(new URL("/rest/v1/rpc/wm_transcription_worker",base),{method:"POST",headers:{...headers,"Content-Type":"application/json"},body:JSON.stringify({p_action:action,p_recording:recording,p_lease:lease,p_result:result}),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(15000)});if(!r.ok)throw Error("ASR queue unavailable");return r.json()}
 async function runOne(){
  const lease=randomUUID(),source=await rpc("claim",null,lease);if(!source)return {claimed:false};
  let dir,stage="source";
  try{
   if(!uuid.test(source.recording_id)||!uuid.test(source.room_id)||source.lease!==lease||source.storage_key!==source.room_id+"/"+source.recording_id+".ogg"||!Number.isSafeInteger(source.bytes)||source.bytes<1000||source.bytes>134217728||!/^[a-f0-9]{64}$/.test(source.sha256))throw Error("invalid source");
   stage="bucket";
   const bucket=await fetcher(new URL("/storage/v1/bucket/wm-recordings",base),{headers,cache:"no-store",redirect:"error",signal:AbortSignal.timeout(30000)});if(!bucket.ok||(await bucket.json()).public!==false)throw Error("private storage unavailable");
   stage="download";
   const res=await fetcher(new URL("/storage/v1/object/authenticated/wm-recordings/"+source.storage_key,base),{headers,cache:"no-store",redirect:"error",signal:AbortSignal.timeout(60000)});
   if(!res.ok||!res.body)throw Error("source unavailable");
   const reader=res.body.getReader(),chunks=[];let size=0;const sha=createHash("sha256");
   try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>source.bytes)throw Error("source too large");sha.update(value);chunks.push(Buffer.from(value))}}catch(e){await reader.cancel().catch(()=>{});throw e}
   stage="integrity";
   if(size!==source.bytes||sha.digest("hex")!==source.sha256)throw Error("source integrity");
   stage="local-file";
   dir=await mkdtemp(join(tmpdir(),"wm-asr-"));const path=join(dir,"source.ogg");await writeFile(path,Buffer.concat(chunks),{mode:0o600});
   // No service credentials or remote model downloads in the subprocess.
   stage="inference";
   const result=await runLocalAsr({python,modelDir,path,home:dir});
   stage="result-persist";const saved=await rpc("finish",source.recording_id,lease,result);
   if(saved?.status!=="complete")throw Error("ASR unconfirmed");
   return {claimed:true,completed:true};
  }catch(e){const reason=stage==="inference"?localAsrFailure(e):"operation-failed";await rpc("fail",source.recording_id,lease).catch(()=>{});return {claimed:true,completed:false,stage,reason}}
  finally{if(dir)await rm(dir,{recursive:true,force:true})}
 }
 return {runOne};
}
