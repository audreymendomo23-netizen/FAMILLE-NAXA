import test from "node:test";
import assert from "node:assert/strict";
import {runAsrLoop} from "./widemeet-asr-loop.mjs";
test("drains successful jobs, idles and backs off bounded failures, then stops",async()=>{
 const stop=new AbortController(),states=[],waits=[],jobs=[{claimed:true,completed:true},{claimed:false},null,null,null,{claimed:true,completed:true},{claimed:false}];
 let calls=0;
 await runAsrLoop({worker:{runOne:async()=>{const x=jobs[calls++];if(x===null)throw Error("private data");return x}},signal:stop.signal,idleMs:5,maxBackoffMs:15,report:s=>states.push(s),wait:async ms=>{waits.push(ms);if(calls===jobs.length)stop.abort()}});
 assert.equal(calls,7);assert.deepEqual(states,["completed","idle","failure","failure","failure","completed","idle"]);assert.deepEqual(waits,[5,10,15,15,5]);
});
test("pre-aborted worker makes no claim",async()=>{const stop=new AbortController();stop.abort();let calls=0;await runAsrLoop({worker:{runOne:async()=>{calls++}},signal:stop.signal,wait:async()=>{}});assert.equal(calls,0)});
test("shutdown drains active job without extra claim",async()=>{const stop=new AbortController();let calls=0;await runAsrLoop({worker:{runOne:async()=>{calls++;stop.abort();return {claimed:true,completed:true}}},signal:stop.signal,wait:async()=>{throw Error("unexpected wait")}});assert.equal(calls,1)});
