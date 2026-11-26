import test from "node:test";
import assert from "node:assert/strict";
import pg from "pg";
import {randomUUID} from "node:crypto";
const base=process.env.API_URL,anon=process.env.ANON_KEY,service=process.env.SERVICE_ROLE_KEY;
const db=new pg.Pool({connectionString:process.env.DB_URL});
const edge=base+"/functions/v1/zipple-n1";
const headers=(key,token=key)=>({apikey:key,authorization:"Bearer "+token,"content-type":"application/json"});
const rest=(path,key,token=key)=>fetch(base+"/rest/v1/"+path,{headers:headers(key,token)});
async function call(action,body,token,origin="https://zipple.test"){
 const r=await fetch(edge+"/"+action,{method:"POST",headers:{"content-type":"application/json",origin,...(token?{authorization:"Bearer "+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})});
 let j;try{j=await r.json()}catch{j={}}
 return {status:r.status,data:j,cors:r.headers.get("access-control-allow-origin"),cache:r.headers.get("cache-control")};
}
async function createUser(email,password){
 const r=await fetch(base+"/auth/v1/admin/users",{method:"POST",headers:headers(service),body:JSON.stringify({email,password,email_confirm:true})});
 assert.ok(r.ok,"local GoTrue provisioning status "+r.status);
 const j=await r.json();assert.ok(j.id);return j.id;
}
test("actual GoTrue, PostgREST and Edge runtime on isolated local Supabase",async()=>{
 try{
  assert.ok(/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(base),"local only");
  const pw="Fixture-"+randomUUID()+"-Aa9!",alias="zipple-"+randomUUID()+"@example.test",u=await createUser(alias,pw),other=await createUser("other-"+randomUUID()+"@example.test",pw);
  const org=randomUUID(),site=randomUUID(),member=randomUUID(),org2=randomUUID(),site2=randomUUID();
  await db.query("insert into public.zp_organizations values($1,'ZIPPLE fixture',true),($2,'Other tenant',true)",[org,org2]);
  await db.query("insert into public.zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,'fixture',$4,'promoteur')",[member,org,u,alias]);
  await db.query("insert into public.zp_sites values($1,$2,'Site A',true),($3,$4,'Site B',true)",[site,org,site2,org2]);
  await db.query("insert into public.zp_site_scopes values($1,$2,$3)",[member,org,site]);
  assert.equal((await call("login",{identifier:"fixture",password:"wrong"})).status,401);
  assert.equal((await call("login",{identifier:"other",password:pw})).status,401);
  assert.equal((await call("login",{identifier:"fixture",password:pw},null,"https://evil.test")).status,403);
  const pre=await fetch(edge+"/login",{method:"OPTIONS",headers:{origin:"https://zipple.test","access-control-request-method":"POST","access-control-request-headers":"content-type"}});
  assert.equal(pre.status,204);assert.equal(pre.headers.get("access-control-allow-origin"),"https://zipple.test");
  const login=await call("login",{identifier:"FIXTURE",password:pw,remember_device:true});
  assert.equal(login.status,200,"Edge login status "+login.status);assert.equal(login.cache,"no-store");
  const s=login.data;assert.equal(s.app_id,"ZIPPLE");assert.equal(s.member_id,member);assert.deepEqual(s.sites.map(x=>x.id),[site]);assert.equal(s.access_token.length,64);
  const direct=await rest("zp_members?select=id",anon);assert.ok(!direct.ok,"anon direct table must be denied");
  const jwt=await fetch(base+"/auth/v1/token?grant_type=password",{method:"POST",headers:headers(anon),body:JSON.stringify({email:alias,password:pw})});assert.ok(jwt.ok);const gotrue=await jwt.json();
  assert.ok(!(await rest("zp_members?select=id",anon,gotrue.access_token)).ok,"authenticated direct table must be denied");
  const badRpc=await fetch(base+"/rest/v1/rpc/zp_rate_limit",{method:"POST",headers:headers(anon,gotrue.access_token),body:JSON.stringify({p_bucket:"test"})});assert.ok(!badRpc.ok);
  const event={event_id:randomUUID(),organization_id:org,member_id:member,site_id:site,sequence:1,aggregate_type:"n1_probe",payload:{probe:true}};
  assert.equal((await call("sync",event,s.access_token)).data.state,"acknowledged");
  assert.equal((await call("sync",event,s.access_token)).data.state,"acknowledged");
  assert.equal((await call("sync",{...event,payload:{probe:false}},s.access_token)).data.state,"conflict");
  assert.equal((await call("sync",{...event,site_id:site2},s.access_token)).status,403);
  assert.equal((await call("sync",{...event,aggregate_type:"sale"},s.access_token)).status,403);
  const refresh=await call("refresh",{refresh_token:s.refresh_token});assert.equal(refresh.status,200);
  assert.equal((await call("refresh",{refresh_token:s.refresh_token})).status,401);
  assert.equal((await call("sync",event,s.access_token)).status,403);
  assert.equal((await call("sync",event,refresh.data.access_token)).status,200);
  assert.equal((await call("logout",{},refresh.data.access_token)).status,200);
  assert.equal((await call("sync",event,refresh.data.access_token)).status,403);
  assert.equal((await call("refresh",{refresh_token:refresh.data.refresh_token})).status,401);
  assert.equal((await call("recovery",{identifier:"fixture"})).status,202);
  assert.equal((await call("recovery",{identifier:"unknown"})).status,202);
  assert.equal(Number((await db.query("select count(*) from public.zp_recovery_requests")).rows[0].count),1);
  assert.equal(Number((await db.query("select count(*) from public.zp_n1_receipts")).rows[0].count),1);
  console.log("ZIPPLE_N1_LOCAL_SUPABASE_EDGE_PASS");
 }finally{await db.end()}
});
