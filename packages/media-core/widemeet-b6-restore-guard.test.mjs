import test from "node:test";
import assert from "node:assert/strict";
import {randomBytes,randomUUID,createHash} from "node:crypto";
import {sealArchive} from "./widemeet-b6-backup.mjs";
import {restoreEligibleAudio} from "./widemeet-b6-restore-guard.mjs";
function fixture(){
 const id=randomUUID(),room_id=randomUUID(),bytes=randomBytes(2048),path=room_id+"/"+id+".ogg",key=randomBytes(32),archive=sealArchive([{path,bytes}],key);
 const row={id,room_id,storage_key:path,phase:"complete",disposition:"retain",purge_requested_at:null,purged_at:null,finished_at:new Date().toISOString(),content_sha256:createHash("sha256").update(bytes).digest("hex"),bytes:bytes.length};
 const calls=[],storage={put:async(...args)=>{calls.push(["put",...args])},removeVerified:async p=>{calls.push(["remove",p])}};
 return {archive,key,row,path,calls,storage};
}
test("historical archive cannot restore a purged recording",async()=>{const f=fixture();assert.deepEqual(await restoreEligibleAudio({...f,lookup:async()=>({...f.row,purged_at:new Date().toISOString()})}),{restored:0,skipped:1});assert.equal(f.calls.length,0)});
test("current ledger unavailable or integrity mismatch fails before any write",async()=>{const f=fixture();await assert.rejects(restoreEligibleAudio({...f,lookup:async()=>{throw Error("offline")}}),/offline/);await assert.rejects(restoreEligibleAudio({...f,lookup:async()=>({...f.row,content_sha256:"bad"})}),/digest mismatch/);assert.equal(f.calls.length,0)});
test("revocation during upload triggers verified compensating deletion",async()=>{const f=fixture();let n=0;await assert.rejects(restoreEligibleAudio({...f,lookup:async()=>++n<3?f.row:null}),/authorization changed/);assert.deepEqual(f.calls.map(x=>x[0]),["put","remove"]);assert.equal(f.calls[1][1],f.path)});
test("current valid object is restored",async()=>{const f=fixture();assert.deepEqual(await restoreEligibleAudio({...f,lookup:async()=>f.row}),{restored:1,skipped:0});assert.deepEqual(f.calls.map(x=>x[0]),["put"])});
