import {test} from "node:test";
import assert from "node:assert/strict";
import {createHmac} from "node:crypto";
import {verifyJoinToken,allowedJoin} from "./signaling-policy.mjs";
const now=Date.parse("2026-11-27T12:00:00Z"),key="fixture-key",secret="fixture-secret-never-production-123456";
const room="ns-70000000-0000-4000-8000-000000000105",identity="60000000-0000-4000-8000-000000000092";
const video={room,roomJoin:true,canPublish:true,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:["camera","microphone"],roomAdmin:false,roomCreate:false,roomRecord:false,roomList:false};
function token(patch={},v=video){const header=Buffer.from(JSON.stringify({alg:"HS256",typ:"JWT"})).toString("base64url");const body=Buffer.from(JSON.stringify({iss:key,sub:identity,nbf:now/1000-5,exp:now/1000+90,video:v,...patch})).toString("base64url");return header+"."+body+"."+createHmac("sha256",secret).update(header+"."+body).digest("base64url");}
const verify=(t)=>verifyJoinToken(t,{key,secret,now});
test("shared WideMeet policy accepts NAXA join-only grant without widening room or sources",()=>{const grant=verify(token());assert.ok(grant);assert.equal(grant.app,"ns");assert.equal(grant.room,room);assert.deepEqual(grant.sources,["camera","microphone"]);const state={app:"ns",room,identity,enabled:true,admitted:true,status:"open",endMs:now+300000,sources:["camera","microphone"],canPublish:true};assert.equal(allowedJoin(grant,state,now),true);for(const patch of [{app:"wm"},{room:room+"-foreign"},{identity:"foreign"},{enabled:false},{admitted:false},{status:"closed"},{endMs:now},{sources:["camera"]},{canPublish:false}])assert.equal(allowedJoin(grant,{...state,...patch},now),false);});
test("shared signaling rejects expired, tampered and administrative tokens",()=>{for(const t of [token({exp:now/1000}),token({iss:"wrong"}),token({}, {...video,roomAdmin:true}),token({}, {...video,roomRecord:true}),token({}, {...video,canPublishSources:["camera","camera"]}),token({}, {...video,canPublishData:true}),token().slice(0,-10)+"AAAAAAAAAA"])assert.equal(verify(t),null);});
