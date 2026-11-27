// Real private Storage/GoTrue/PostgREST test, strictly on disposable Supabase.
import assert from "node:assert/strict";
import {randomUUID,randomBytes,createHash} from "node:crypto";
import {mkdtemp,writeFile,readFile,stat,rm} from "node:fs/promises";
import {join} from "node:path";
import {tmpdir} from "node:os";
import {createWideMeetRecordingStorage} from "../../packages/media-core/widemeet-recording-storage.mjs";
import {createWideMeetAudioPurge} from "../../packages/media-core/widemeet-b6-audio-purge.mjs";
import {sealArchive,restoreArchive} from "../../packages/media-core/widemeet-b6-backup.mjs";
const base=process.env.SUPABASE_URL,serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY,anon=process.env.SUPABASE_ANON_KEY;
assert.equal(base,"http://127.0.0.1:54321");assert.ok(serviceKey&&anon&&process.env.WM_B6_ISOLATED==="true");
const root=await mkdtemp(join(tmpdir(),"wm-b6-storage-"));
const headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json",Prefer:"return=representation"};
async function call(path,method="GET",body){const r=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),redirect:"error",cache:"no-store"});assert.ok(r.ok,method+" "+path.split("?")[0]+" HTTP "+r.status);return r.status===204?null:r.json()}
const rest=(table,body)=>call("/rest/v1/"+table,"POST",body);
const get=async key=>fetch(base+"/storage/v1/object/authenticated/wm-recordings/"+key,{headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey},redirect:"error",cache:"no-store"});
const sha=b=>createHash("sha256").update(b).digest("hex");
const storage=createWideMeetRecordingStorage({supabaseUrl:base,serviceKey});
try{
 await call("/storage/v1/bucket","POST",{id:"wm-recordings",name:"wm-recordings",public:false,file_size_limit:134217728,allowed_mime_types:["audio/ogg"]});
 const email="wm-b6-"+randomUUID()+"@example.test",user=await call("/auth/v1/admin/users","POST",{email,password:"Qa7!"+randomBytes(18).toString("hex"),email_confirm:true,app_metadata:{app_code:"widemeet"}});
 const [h]=await rest("wm_accounts",{auth_user_id:user.id,login_id:"WM-"+randomBytes(8).toString("hex").toUpperCase(),auth_alias:email,display_name:"B6 fixture"});
 const [w]=await rest("wm_workspaces",{kind:"enterprise",name:"B6 isolated"});
 await rest("wm_memberships",{account_id:h.id,workspace_id:w.id,role:"promoteur"});
 const rid=randomUUID();await rest("wm_rooms",{id:rid,workspace_id:w.id,host_id:h.id,revision:1,state:{id:rid,workspaceId:w.id,hostId:h.id,revision:1,status:"ended"}});
 const old={id:randomUUID(),room_id:rid},fresh={id:randomUUID(),room_id:rid},bytes=randomBytes(2048),freshBytes=randomBytes(2048);
 for(const [row,data,age] of [[old,bytes,91],[fresh,freshBytes,1]]){
  const key=await storage.put(row,data,sha(data)),date=new Date(Date.now()-age*86400000).toISOString();
  await rest("wm_recording_runs",{...row,request_id:randomUUID(),phase:"complete",disposition:"retain",object_name:row.id+".ogg",finished_at:date,content_sha256:sha(data),bytes:data.length,stored_at:date,storage_key:key});
  await writeFile(join(root,row.id+".ogg"),data,{mode:0o600});
 }
 const oldKey=rid+"/"+old.id+".ogg",freshKey=rid+"/"+fresh.id+".ogg";
 await rest("wm_transcription_jobs",{recording_id:old.id,room_id:rid,requester_id:h.id,status:"running",lease:randomUUID(),lease_until:new Date(Date.now()+60000).toISOString()});
 // Back up only currently eligible content, no expired entry in the encrypted manifest.
 const candidates=await call("/rest/v1/wm_recording_runs?phase=eq.complete&select=id,storage_key,finished_at");
 const eligible=candidates.filter(r=>Date.parse(r.finished_at)>Date.now()-90*86400000);
 assert.deepEqual(eligible.map(r=>r.id),[fresh.id]);
 const response=await get(freshKey);assert.ok(response.ok);
 const key=randomBytes(32),archive=sealArchive([{path:freshKey,bytes:Buffer.from(await response.arrayBuffer())}],key);
 const backupPath=join(root,"backup.enc");await writeFile(backupPath,archive,{mode:0o600});
 const purge=createWideMeetAudioPurge({supabaseUrl:base,serviceKey,outputDirectory:root,storage,isolated:true});
 assert.deepEqual(await purge.runOnce(),{claimed:true,purged:true});
 assert.deepEqual(await purge.runOnce(),{claimed:false});
 assert.equal((await get(oldKey)).ok,false);
 await assert.rejects(stat(join(root,old.id+".ogg")),e=>e.code==="ENOENT");
 assert.equal((await call("/rest/v1/wm_transcription_jobs?recording_id=eq."+old.id)).length,0);
 const [expired]=await call("/rest/v1/wm_recording_runs?id=eq."+old.id);
 assert.ok(expired.purged_at);assert.equal(expired.storage_key,null);assert.equal(expired.content_sha256,null);
 assert.equal(sha(Buffer.from(await (await get(freshKey)).arrayBuffer())),sha(freshBytes));
 console.log("PASS B6 real Storage purge, local deletion, transcript removal, idempotence and fresh content preserved");
 // Simulate loss of the eligible private object; restore only authenticated backup entries.
 await storage.removeVerified(freshKey);assert.equal((await get(freshKey)).ok,false);
 const restored=await restoreArchive(await readFile(backupPath),key,root);
 assert.equal(restored.restored,1);
 const restoredBytes=await readFile(join(restored.root,freshKey));
 assert.equal(await storage.put(fresh,restoredBytes,sha(freshBytes)),freshKey);
 assert.equal(sha(Buffer.from(await (await get(freshKey)).arrayBuffer())),sha(freshBytes));
 assert.equal((await get(oldKey)).ok,false);
 const publicRes=await fetch(base+"/storage/v1/object/public/wm-recordings/"+freshKey);
 const unauthorized=await fetch(base+"/storage/v1/object/authenticated/wm-recordings/"+freshKey,{headers:{apikey:anon,Authorization:"Bearer "+anon}});
 assert.equal(publicRes.ok,false);assert.equal(unauthorized.ok,false);
 assert.equal((await call("/storage/v1/bucket/wm-recordings")).public,false);
 console.log("PASS B6 real encrypted backup restored to private Storage, hash equal, anonymous denial, expired object not resurrected");
}finally{await rm(root,{recursive:true,force:true})}
