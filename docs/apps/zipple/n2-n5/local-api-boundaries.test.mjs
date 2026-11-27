import test from "node:test";
import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import {randomUUID} from "node:crypto";
const base=process.env.API_URL;
assert.match(base??"",/^http:\/\/(127\.0\.0\.1|localhost):\d+$/);
const source=await readFile(new URL("./business-gateway.mjs",import.meta.url),"utf8");
const extract=name=>{const m=source.match(new RegExp("const "+name+"=new Set\\(\\[([^\\]]+)\\]\\)"));assert.ok(m,name);return [...m[1].matchAll(/"([a-z_]+)"/g)].map(x=>x[1])};
const pro=extract("professionalActions"),pub=extract("publicActions");
const manifest=JSON.parse(await readFile(new URL("./qa-waves.json",import.meta.url),"utf8"));
const registered=manifest.api.flatMap(w=>w.actions);
assert.deepEqual([...registered].sort(),[...pro,...pub].sort(),"Every exposed action appears exactly once in waves");
assert.equal(new Set(registered).size,registered.length);
assert.ok(manifest.api.every(w=>w.actions.length>0&&w.actions.length<=50));
const wave=Number(process.env.ZIPPLE_API_WAVE??1);
const chosen=manifest.api.find(w=>w.wave===wave);assert.ok(chosen);
const all=chosen.actions.map(action=>({action,guest:pub.includes(action)}));
async function request(action,body,origin="https://zipple.test",auth){
 const response=await fetch(base+"/functions/v1/zipple-business/"+action,{method:"POST",redirect:"error",signal:AbortSignal.timeout(20000),headers:{origin,"content-type":"application/json",...(auth?{authorization:auth}:{})},body:JSON.stringify(body)});
 return {status:response.status,body:await response.json()};
}
for(const {action,guest} of all){
 test("API boundary "+action,async()=>{
  const body={app_id:"ZIPPLE",site_id:randomUUID()};
  const denied=await request(action,body,"https://invalid.example");
  assert.equal(denied.status,403);assert.equal(denied.body.error,"DENIED");
  const invalid=await request(action,{...body,app_id:"NOT_ZIPPLE"});
  assert.equal(invalid.status,400);assert.equal(invalid.body.error,"INVALID_INPUT");
  const unauth=await request(action,body);
  assert.equal(unauth.status,action==="guest_open"?400:401);
  assert.equal(unauth.body.error,action==="guest_open"?"INVALID_INPUT":"DENIED");
  if(action!=="guest_open"){
    const wrong=await request(action,body,"https://zipple.test",(guest?"Bearer ":"Guest ")+"a".repeat(64));
    assert.equal(wrong.status,401);assert.equal(wrong.body.error,"DENIED");
  }
  console.log("ZIPPLE_QA_API_BOUNDARY_PASS "+action);
 });
}
