import test from "node:test";import assert from "node:assert/strict";import{encryptToken,decryptToken,sendPush,serviceAccount}from"./push-delivery.mjs";
test("B2 push encrypted token roundtrip and bound fingerprint",async()=>{const key="ab".repeat(32),token="test-fixture-"+"x".repeat(64),r=await encryptToken(token,key);assert.notEqual(r.ciphertext,token);assert.equal(await decryptToken(r,key),token);await assert.rejects(decryptToken({...r,fingerprint:"00".repeat(32)},key));await assert.rejects(decryptToken(r,"cd".repeat(32)))});
test("B2 push provider acceptance is scoped and uncertain is not success",async()=>{const args={project:"widemeet-qualification",access:"fixture",token:"x".repeat(60),id:"00000000-0000-4000-8000-000000000001"};
const send=reply=>sendPush({...args,fetcher:async(u,o)=>{const m=JSON.parse(o.body).message;assert.equal(m.notification.body,"Nouvelle notification / New notification");assert.equal(m.data.app_id,"WIDEMEET");return reply}});
assert.equal((await send(new Response(JSON.stringify({name:"projects/widemeet-qualification/messages/abc"})))).status,"accepted");
assert.equal((await send(new Response(JSON.stringify({name:"projects/other/messages/abc"})))).status,"uncertain");
assert.equal((await send(new Response(JSON.stringify({error:{details:[{errorCode:"UNREGISTERED"}]}}),{status:404}))).revoke,true);
assert.throws(()=>serviceAccount("{}","naxatechnologie"));});
