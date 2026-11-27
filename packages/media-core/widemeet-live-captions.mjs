// Server-only caption worker. Reuses the *already active* consented Egress file;
// never requests a microphone, creates a recording, or transmits raw audio.
import {execFile} from "node:child_process";
import {promisify} from "node:util";
import {mkdtemp,rm,stat} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {runLocalAsr} from "./widemeet-transcription.mjs";
const exec=promisify(execFile),uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export function createLiveCaptions({supabaseUrl,serviceKey,outputDirectory,python,modelDir,fetcher=fetch,onDiagnostic=()=>{}}){
 const base=new URL(supabaseUrl),root=resolve(outputDirectory),offsets=new Map(),locks=new Set();
 if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey||!python||!modelDir)throw Error("invalid captions configuration");
 const headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"};
 async function db(path,body){const r=await fetcher(new URL("/rest/v1/"+path,base),{method:body===undefined?"GET":"POST",headers,body:body===undefined?undefined:JSON.stringify(body),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(5000)});if(!r.ok)throw Error("caption backend");return r.json()}
 async function permitted(row){const p=await db("rpc/wm_recording_policy",{p_room:row.room_id});return p?.permitted===true&&p.request_id===row.request_id}
 async function one(row){
  if(!uuid.test(row.id)||!uuid.test(row.room_id)||row.object_name!==row.id+".ogg"||locks.has(row.id)||!(await permitted(row)))return false;
  locks.add(row.id);let dir,stage="stat";
  const note=(reason)=>{try{onDiagnostic({stage,reason})}catch{}};
  try{
   const file=resolve(root,row.object_name);if((await stat(file)).size<1000){note("buffer_not_ready");return false;}
   stage="cursor";
   const previous=(await db("wm_live_captions?recording_id=eq."+row.id+"&select=end_ms"))[0];
   const elapsed=Math.max(0,Date.now()-Date.parse(row.started_at));
   // Never advance an unconfirmed cursor solely from wall time: Egress may buffer output.
   const offset=Math.max(offsets.get(row.id)??0,previous?.end_ms??0);
   if(offset>elapsed){note("cursor_ahead_of_elapsed");return false;}
   dir=await mkdtemp(join(tmpdir(),"wm-live-cues-"));const wav=join(dir,"window.wav");
   // Read only a bounded 8 s window; tolerate the not-yet-finalized Ogg stream.
   stage="decode";
   await exec("ffmpeg",["-nostdin","-v","error","-y","-ss",String(offset/1000),"-i",file,"-t","8","-vn","-ac","1","-ar","16000","-c:a","pcm_s16le",wav],{timeout:12000,maxBuffer:65536});
   if((await stat(wav)).size<160000){note("window_not_ready");return false;}
   if(!(await permitted(row)))return false;
   stage="asr";
   const source=await runLocalAsr({python,modelDir,path:wav,home:dir,timeout:15000});
   if(source.duration_ms<5000||source.duration_ms>8100){note("window_duration");return false;}
   const original=source.segments.map(x=>x.text).join(" ").trim().slice(0,4000);
   let english=source.language==="en"?original:null,uncertain=source.segments.some(x=>x.uncertain);
   // Actual Whisper speech translation to English; no fabricated support for other targets.
   if(source.language==="fr"&&original&&await permitted(row)){
    try{const translated=await runLocalAsr({python,modelDir,path:wav,home:dir,translate:true,timeout:15000});english=translated.segments.map(x=>x.text).join(" ").trim().slice(0,4000)||null;uncertain||=translated.segments.some(x=>x.uncertain)}catch{}
   }
   if(!(await permitted(row)))return false;
   const end=offset+source.duration_ms;
   stage="write";
   const ok=await db("rpc/wm_live_caption_write",{p_room:row.room_id,p_recording:row.id,p_offset:offset,p_end:end,p_language:source.language,p_original:original,p_english:english,p_uncertain:uncertain});
   if(ok===true)offsets.set(row.id,end);else note("policy_or_cursor_rejected");return ok===true;
  }catch{note("stage_failed");return false}finally{locks.delete(row.id);if(dir)await rm(dir,{recursive:true,force:true})}
 }
 return {async tick(){const rows=await db("wm_recording_runs?phase=eq.active&disposition=eq.retain&select=id,room_id,request_id,object_name,started_at&order=started_at&limit=20");const active=new Set(rows.map(x=>x.id));for(const id of offsets.keys())if(!active.has(id))offsets.delete(id);let published=0;for(const row of rows)if(await one(row))published++;return published}};
}
