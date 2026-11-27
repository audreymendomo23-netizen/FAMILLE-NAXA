// Opt-in deployment entry point on the private Egress runner. No implicit start.
import {setTimeout as sleep} from "node:timers/promises";
import {createLiveCaptions} from "../../packages/media-core/widemeet-live-captions.mjs";
if(process.env.WM_LIVE_CAPTIONS_WORKER_ENABLED!=="true")throw Error("live caption worker disabled");
const stop=new AbortController();process.once("SIGINT",()=>stop.abort());process.once("SIGTERM",()=>stop.abort());
const worker=createLiveCaptions({supabaseUrl:process.env.SUPABASE_URL,serviceKey:process.env.SUPABASE_SERVICE_ROLE_KEY,outputDirectory:process.env.WM_EGRESS_OUT,python:process.env.WM_ASR_PYTHON,modelDir:process.env.WM_ASR_MODEL});
while(!stop.signal.aborted){
 try{await worker.tick()}catch{console.error("WM_LIVE_CAPTION_WORKER unavailable")}
 try{await sleep(2000,undefined,{signal:stop.signal})}catch(e){if(e?.name!=="AbortError")throw e}
}
