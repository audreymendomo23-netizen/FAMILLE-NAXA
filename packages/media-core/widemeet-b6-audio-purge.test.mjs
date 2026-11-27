import test from "node:test";
import assert from "node:assert/strict";
import {createWideMeetAudioPurge} from "./widemeet-b6-audio-purge.mjs";
import {createWideMeetRecordingStorage} from "./widemeet-recording-storage.mjs";
const id="10000000-0000-4000-8000-000000000086",room="20000000-0000-4000-8000-000000000086";
const key=room+"/"+id+".ogg",row={id,room_id:room,object_name:id+".ogg",storage_key:key};
const base="http://127.0.0.1:54321",serviceKey="fixture";
function setup({claim=row,failStorage=false,failFile=false,ack=true}={}){
 const calls=[];
 const runner=createWideMeetAudioPurge({supabaseUrl:base,serviceKey,outputDirectory:"/tmp/wm-fixture",isolated:true,
 fetcher:async(url,options)=>{const action=url.pathname.split("/").at(-1);calls.push([action,JSON.parse(options.body)]);return Response.json(action.endsWith("claim")?claim:ack)},
 storage:{removeVerified:async k=>{calls.push(["storage",k]);if(failStorage)throw Error("storage unavailable")}},
 removeFile:async p=>{calls.push(["local",p]);if(failFile)throw Object.assign(Error("denied"),{code:"EACCES"})}});
 return {runner,calls};
}
test("success orders fence, verified remote deletion, local deletion, ack",async()=>{const {runner,calls}=setup();assert.deepEqual(await runner.runOnce(),{claimed:true,purged:true});assert.deepEqual(calls.map(x=>x[0]),["wm_b6_audio_purge_claim","storage","local","wm_b6_audio_purge_ack"]);assert.deepEqual(calls.at(-1)[1],{p_id:id,p_key:key})});
test("empty queue does not delete",async()=>{const {runner,calls}=setup({claim:null});assert.deepEqual(await runner.runOnce(),{claimed:false});assert.equal(calls.length,1)});
test("invalid object cannot be deleted",async()=>{const {runner,calls}=setup({claim:{...row,object_name:"../other.ogg"}});await assert.rejects(runner.runOnce(),/invalid purge/);assert.equal(calls.length,1)});
test("failed remote verification leaves claim unacknowledged",async()=>{const {runner,calls}=setup({failStorage:true});await assert.rejects(runner.runOnce(),/storage unavailable/);assert.equal(calls.length,2)});
test("failed local deletion leaves claim unacknowledged",async()=>{const {runner,calls}=setup({failFile:true});await assert.rejects(runner.runOnce(),/denied/);assert.equal(calls.length,3)});
test("failed acknowledgement is not a success",async()=>{const {runner}=setup({ack:false});await assert.rejects(runner.runOnce(),/confirmation unavailable/)});
test("production host and missing opt-in are refused",()=>{const config={supabaseUrl:base,serviceKey,outputDirectory:"/tmp/wm-fixture",storage:{removeVerified:async()=>{}}};assert.throws(()=>createWideMeetAudioPurge(config));assert.throws(()=>createWideMeetAudioPurge({...config,isolated:true,supabaseUrl:"https://example.invalid"}))});
test("storage verifies absence and refuses retained object",async()=>{let retained=true;const storage=createWideMeetRecordingStorage({supabaseUrl:base,serviceKey,fetcher:async url=>Response.json(url.pathname.includes("/bucket/")?{public:false}:url.pathname.includes("/list/")?(retained?[{name:id+".ogg"}]:[]):[])});await assert.rejects(storage.removeVerified(key),/not confirmed/);retained=false;await storage.removeVerified(key);await assert.rejects(storage.removeVerified("../other.ogg"),/invalid key/)});
