// Full dump/restore rehearsal for the dedicated PostgreSQL CI service only.
import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {createCipheriv,createDecipheriv,randomBytes,createHash} from "node:crypto";
import {mkdtemp,readFile,writeFile,rm} from "node:fs/promises";
import {join} from "node:path";
import {tmpdir} from "node:os";
const id=process.env.WM_B6_PG_CONTAINER;
assert.ok(process.env.WM_B6_ISOLATED==="true"&&/^[a-f0-9]{12,64}$/.test(id??""));
function docker(args,input){const r=spawnSync("docker",["exec","-i",id,...args],{input,maxBuffer:32*1024*1024});if(r.status!==0)throw Error("isolated PostgreSQL command failed: "+args[0]);return r.stdout}
const root=await mkdtemp(join(tmpdir(),"wm-b6-pg-"));
try{
 const dump=docker(["pg_dump","-U","postgres","-Fc","postgres"]);assert.ok(dump.length>1000);
 const key=randomBytes(32),iv=randomBytes(12),cipher=createCipheriv("aes-256-gcm",key,iv),encrypted=Buffer.concat([cipher.update(dump),cipher.final()]);
 await writeFile(join(root,"db.enc"),Buffer.concat([iv,cipher.getAuthTag(),encrypted]),{mode:0o600,flag:"wx"});
 const saved=await readFile(join(root,"db.enc")),decipher=createDecipheriv("aes-256-gcm",key,saved.subarray(0,12));decipher.setAuthTag(saved.subarray(12,28));
 const clear=Buffer.concat([decipher.update(saved.subarray(28)),decipher.final()]);
 assert.equal(createHash("sha256").update(clear).digest("hex"),createHash("sha256").update(dump).digest("hex"));
 docker(["createdb","-U","postgres","wm_b6_restore"]);
 docker(["pg_restore","-U","postgres","--exit-on-error","-d","wm_b6_restore"],clear);
 const sql="select (select count(*) from public.wm_minutes_eligibility where content_purged_at is not null), (select count(*) from public.wm_minutes_versions where body='[expired]'), (select count(*) from public.wm_minutes_versions where body='private fresh body'), (select bool_and(relrowsecurity) from pg_class where oid in ('public.wm_minutes_versions'::regclass,'public.wm_recording_runs'::regclass,'public.wm_device_sessions'::regclass)), has_table_privilege('anon','public.wm_minutes_versions','SELECT'), has_table_privilege('authenticated','public.wm_recording_runs','SELECT'), has_function_privilege('anon','public.wm_b6_minutes_purge_one()','EXECUTE'), has_function_privilege('service_role','public.wm_b6_minutes_purge_one()','EXECUTE')";
 const query=db=>docker(["psql","-U","postgres","-d",db,"-At","-v","ON_ERROR_STOP=1","-c",sql]).toString().trim();
 const original=query("postgres"),restored=query("wm_b6_restore");
 assert.equal(original,"1|1|1|t|f|f|f|t");assert.equal(restored,original);
 console.log("PASS B6 actual PostgreSQL encrypted dump/restore, purge state and selected RLS/ACL preserved");
}finally{await rm(root,{recursive:true,force:true})}
