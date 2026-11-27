import test from "node:test";
import assert from "node:assert/strict";
import {makeDisplayIntent,redeemDisplayIntent} from "./presentation-display.mjs";
import {signReceiverGrant,createReceiverAdmission,receiverIdentity} from "../media-core/widemeet-receiver.mjs";
import {verifyJoinToken,allowedJoin} from "../media-core/signaling-policy.mjs";
const now=100000,key="test-key",secret="a".repeat(64),id="0123456789012345678901",leaseId="abcdefghijklmnopqrstuv",roomId="11111111-1111-4111-8111-111111111111";
function fixture(){
 const ctx={meeting:{id:roomId,orgId:"org",status:"open",endMs:200000,confidentiality:"standard"},actor:{enabled:true,displayAllowed:true,orgId:"org",meetingId:roomId,memberId:"member"},source:{active:true,memberId:"member",orgId:"org",meetingId:roomId,id:"phone"},receiver:{approved:true,active:true,kind:"widemeet_receiver",memberId:"member",orgId:"org",id:"tv"},policy:{displayEnabled:true,confidentialDisplayAllowed:false}};
 const {lease}=redeemDisplayIntent(ctx,makeDisplayIntent(ctx,now,id),now+1,leaseId);return {ctx,lease};
}
test("B2 receiver token signs only subscribe permissions and distinct identity",()=>{
 const {ctx,lease}=fixture(),r=signReceiverGrant({ctx,lease,key,secret,now:now+1});
 assert.equal(r.identity,receiverIdentity(leaseId));assert.notEqual(r.identity,ctx.actor.memberId);
 const grant=verifyJoinToken(r.token,{key,secret,now:now+1});assert.ok(grant);assert.equal(grant.canPublish,false);assert.deepEqual(grant.sources,[]);assert.equal(grant.room,"wm-"+roomId);
 const claims=JSON.parse(Buffer.from(r.token.split(".")[1],"base64url"));for(const p of ["canPublishData","canUpdateOwnMetadata","roomAdmin","roomCreate","roomRecord","roomList"])assert.equal(claims.video[p],false);
});
test("B2 receiver live admission rechecks lease, source, room and scope",async()=>{
 const f=fixture(),r=signReceiverGrant({...f,key,secret,now:now+1}),g=verifyJoinToken(r.token,{key,secret,now:now+1});
 let current=now+2;
 const read=createReceiverAdmission({readLease:async id=>id===leaseId?f:null,clock:()=>current});
 assert.equal(allowedJoin(g,await read(g),current),true);
 for(const change of [{canPublish:true},{sources:["camera"]},{room:"wm-22222222-2222-4222-8222-222222222222"},{app:"ns"},{identity:"wm-display-otherinvalidlease"}])assert.equal(await read({...g,...change}),null);
 f.ctx.source.active=false;assert.equal(await read(g),null);f.ctx.source.active=true;
 f.ctx.meeting.status="paused";assert.equal(await read(g),null);f.ctx.meeting.status="open";
 f.lease.revoked=true;assert.equal(await read(g),null);f.lease.revoked=false;
 current=f.lease.expiresMs;assert.equal(await read(g),null);
});
test("B2 receiver grant fails closed for invalid lease or missing policy",()=>{
 const f=fixture();assert.throws(()=>signReceiverGrant({...f,lease:{...f.lease,canPublish:true},key,secret,now:now+1}));
 assert.throws(()=>signReceiverGrant({...f,lease:{...f.lease,expiresMs:now+60000},key,secret,now:now+1}));
 f.ctx.policy.displayEnabled=false;assert.throws(()=>signReceiverGrant({...f,key,secret,now:now+1}));
});
