// Explicit opt-in server entrypoint, never run on a client or implicitly deploy.
import {setTimeout as sleep} from "node:timers/promises";
import {createWideMeetTranscription} from "../../packages/media-core/widemeet-transcription.mjs";
import {runAsrLoop} from "../../packages/media-core/widemeet-asr-loop.mjs";
if(process.env.WM_ASR_WORKER_ENABLED!=="true")throw Error("WideMeet ASR worker not enabled");
const stop=new AbortController();
process.once("SIGINT",()=>stop.abort());
process.once("SIGTERM",()=>stop.abort());
const worker=createWideMeetTranscription({supabaseUrl:process.env.SUPABASE_URL,serviceKey:process.env.SUPABASE_SERVICE_ROLE_KEY,python:process.env.WM_ASR_PYTHON,modelDir:process.env.WM_ASR_MODEL});
await runAsrLoop({worker,signal:stop.signal,wait:async(ms,signal)=>{try{await sleep(ms,undefined,{signal})}catch(e){if(e?.name!=="AbortError")throw e}},report:state=>{if(state!=="idle")console.log("WM_ASR_WORKER "+state)}});
