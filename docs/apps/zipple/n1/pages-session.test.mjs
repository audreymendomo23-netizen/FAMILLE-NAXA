import test from "node:test";
import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
const source=await readFile(new URL("../../../../apps/web/zipple/public/_worker.js",import.meta.url),"utf8");
const {sessionRoute}=await import("data:text/javascript;base64,"+Buffer.from(source).toString("base64"));
const origin="https://naxa-zipple.pages.dev";
const token="r".repeat(43),access="a".repeat(43);
function req(action,body={},extra={}){return new Request(origin+"/session/"+action,{method:"POST",headers:{origin,"content-type":"application/json",...extra},body:JSON.stringify(body)})}
const upstream=async(u,o)=>{assert.match(u,/supabase\.co\/functions\/v1\/zipple-n1\//);assert.equal(o.redirect,"error");return Response.json({app_id:"ZIPPLE",access_token:access,refresh_token:token})};
test("remembered login stores token in secure first-party cookie only",async()=>{const res=await sessionRoute(req("login",{identifier:"demo",password:"fiction"}),async(u,o)=>{assert.equal(JSON.parse(o.body).remember_device,true);return upstream(u,o)});assert.equal(res.status,200);assert.match(res.headers.get("set-cookie"),/__Host-zipple-refresh=.*; Path=\/; Secure; HttpOnly; SameSite=Strict/);assert.equal((await res.json()).refresh_token,undefined);assert.equal(res.headers.get("cache-control"),"no-store")});
test("refresh rotation and missing cookie fail closed",async()=>{assert.equal((await sessionRoute(req("refresh"),upstream)).status,401);const res=await sessionRoute(req("refresh",{},{"cookie":"__Host-zipple-refresh="+token}),async(u,o)=>{assert.equal(JSON.parse(o.body).refresh_token,token);return upstream(u,o)});assert.equal(res.status,200);assert.equal((await res.json()).refresh_token,undefined)});
test("untrusted origins denied without upstream",async()=>{const res=await sessionRoute(req("login",{identifier:"demo",password:"fiction"},{origin:"https://evil.invalid"}),()=>{throw Error("unexpected")});assert.equal(res.status,403)});
test("logout clears cookie even if upstream fails",async()=>{const res=await sessionRoute(req("logout",{access_token:access}),async(u,o)=>{assert.equal(o.headers.Authorization,"Bearer "+access);return new Response("denied",{status:401})});assert.match(res.headers.get("set-cookie"),/Max-Age=0/)});

test("explicit opt-out clears cookie and attempts revocation",async()=>{const calls=[];const res=await sessionRoute(req("forget",{},{"cookie":"__Host-zipple-refresh="+token}),async(u,o)=>{calls.push(u.split("/").pop());return upstream(u,o)});assert.deepEqual(calls,["refresh","logout"]);assert.match(res.headers.get("set-cookie"),/Max-Age=0/)});

test("temporary upstream failure preserves secure cookie for retry",async()=>{const res=await sessionRoute(req("refresh",{},{"cookie":"__Host-zipple-refresh="+token}),async()=>new Response("unavailable",{status:503}));assert.equal(res.status,503);assert.equal(res.headers.get("set-cookie"),null)});
