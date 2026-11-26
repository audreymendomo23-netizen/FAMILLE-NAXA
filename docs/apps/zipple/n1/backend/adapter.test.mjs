import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {createSupabaseZipple} from "./adapter.mjs";
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL});
const id={a:"10000000-0000-4000-8000-000000000001",b:"10000000-0000-4000-8000-000000000002",m:"20000000-0000-4000-8000-000000000001",u:"30000000-0000-4000-8000-000000000001",s:"40000000-0000-4000-8000-000000000001",x:"40000000-0000-4000-8000-000000000002"};
const rpc={zp_rate_limit:["p_bucket"],zp_issue:["p_member","p_auth_user","p_epoch","p_access","p_refresh"],zp_rotate:["p_previous","p_access","p_refresh"],zp_revoke:["p_access"],zp_recovery:["p_login"],zp_probe_receipt:["p_access","p_org","p_member","p_site","p_event","p_digest"]};
const response=(x,status=200)=>Response.json(x,{status});
let gotrueLogout=0;
async function bridge(input,opt){
 const u=new URL(input),body=opt.body?JSON.parse(opt.body):{};
 if(u.pathname==="/auth/v1/token"){assert.equal(opt.headers.apikey,"test-anon");return body.email==="fixture@zipple.invalid"&&body.password==="test-only"?response({access_token:"internal-gotrue-token",user:{id:id.u}}):response({},400)}
 if(u.pathname==="/auth/v1/logout"){assert.equal(opt.headers.Authorization,"Bearer internal-gotrue-token");gotrueLogout++;return new Response(null,{status:204})}
 assert.equal(opt.headers.apikey,"test-server-only");
 const db=await pool.connect();try{
  await db.query("set role service_role");
  if(u.pathname==="/rest/v1/zp_members"){
   const login=u.searchParams.get("login_id").slice(3);
   return response((await db.query("select id,auth_user_id,auth_alias,credential_epoch from public.zp_members where active and not reset_pending and login_id=$1 limit 2",[login])).rows)
  }
  const fn=u.pathname.split("/").pop(),params=rpc[fn];assert.ok(params);
  const sql="select public."+fn+"("+params.map((_,i)=>"$"+(i+1)).join(",")+") as value";
  const {rows:[row]}=await db.query(sql,params.map(k=>body[k]));
  return response(row.value);
 }catch{return response({},400)}finally{await db.query("reset role");db.release()}
}
test("Supabase adapter candidate: SQL permissions, alias, rotations, scope, recovery and probe",async()=>{try{
 await pool.query("insert into auth.users(id) values($1)",[id.u]);
 await pool.query("insert into public.zp_organizations values($1,'Test',true),($2,'Other',true)",[id.a,id.b]);
 await pool.query("insert into public.zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,'fixture','fixture@zipple.invalid','promoteur')",[id.m,id.a,id.u]);
 await pool.query("insert into public.zp_sites values($1,$2,'Site',true),($3,$4,'Other',true)",[id.s,id.a,id.x,id.b]);
 await pool.query("insert into public.zp_site_scopes values($1,$2,$3)",[id.m,id.a,id.s]);
 await assert.rejects(pool.query("insert into public.zp_site_scopes values($1,$2,$3)",[id.m,id.a,id.x]));
 for(const role of ["anon","authenticated"]){const c=await pool.connect();try{await c.query("set role "+role);await assert.rejects(c.query("select * from public.zp_members"),/permission denied/);await assert.rejects(c.query("select public.zp_rate_limit('test')"),/permission denied/)}finally{await c.query("reset role");c.release()}}
 const gateway=createSupabaseZipple({url:"https://fixture.test",anonKey:"test-anon",serviceKey:"test-server-only",origins:["https://zipple.test"],fetcher:bridge});
 const req=(action,body,token,origin="https://zipple.test")=>gateway(new Request("https://gateway.test/"+action,{method:"POST",headers:{origin,...(token?{authorization:"Bearer "+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})}));
 assert.equal((await req("login",{identifier:"fixture",password:"wrong"})).status,401);
 assert.equal((await req("login",{identifier:"fixture",password:"test-only"},null,"https://evil.test")).status,403);
 const a=await req("login",{identifier:"Fixture",password:"test-only",remember_device:true});assert.equal(a.status,200);const s=await a.json();
 assert.equal(gotrueLogout,1);assert.equal(s.member_id,id.m);assert.equal(s.organization_id,id.a);assert.deepEqual(s.sites.map(s=>s.id),[id.s]);assert.notEqual(s.access_token,"internal-gotrue-token");
 const stored=(await pool.query("select access_hash,refresh_hash from public.zp_sessions")).rows[0];assert.notEqual(stored.access_hash,s.access_token);assert.notEqual(stored.refresh_hash,s.refresh_token);
 const ev={event_id:"e",organization_id:id.a,member_id:id.m,site_id:id.s,sequence:1,aggregate_type:"n1_probe",payload:{probe:true}};
 const send=(body,t=s.access_token)=>req("sync",body,t);
 assert.equal((await(await send(ev)).json()).state,"acknowledged");
 assert.equal((await(await send(ev)).json()).state,"acknowledged");
 assert.equal((await(await send({...ev,payload:{probe:false}})).json()).state,"conflict");
 assert.equal((await send({...ev,site_id:id.x})).status,403);assert.equal((await send({...ev,aggregate_type:"sale"})).status,403);
 const rr=await req("refresh",{refresh_token:s.refresh_token});assert.equal(rr.status,200);const next=await rr.json();
 assert.equal((await req("refresh",{refresh_token:s.refresh_token})).status,401);assert.equal((await send(ev)).status,403);
 assert.equal((await send(ev,next.access_token)).status,200);
 assert.equal((await req("logout",{},next.access_token)).status,200);assert.equal((await send(ev,next.access_token)).status,403);
 assert.equal((await req("refresh",{refresh_token:next.refresh_token})).status,401);
 assert.equal((await req("recovery",{identifier:"fixture"})).status,202);assert.equal((await req("recovery",{identifier:"unknown"})).status,202);
 assert.equal(Number((await pool.query("select count(*) from public.zp_recovery_requests")).rows[0].count),1);
 assert.equal(Number((await pool.query("select count(*) from public.zp_n1_receipts")).rows[0].count),1);
 // Recovery failure must leave the account locked; retry is explicit and audited.
 const operator="30000000-0000-4000-8000-000000000002",attempt="50000000-0000-4000-8000-000000000001",retry="50000000-0000-4000-8000-000000000002";
 await pool.query("insert into auth.users(id) values($1)",[operator]);
 await pool.query("insert into public.zp_recovery_operators values($1,true)",[operator]);
 const reqId=(await pool.query("select id from public.zp_recovery_requests where member_id=$1",[id.m])).rows[0].id;
 await assert.rejects(pool.query("select public.zp_admin_recovery_list($1)",[id.u]),/DENIED/);
 await assert.rejects(pool.query("select public.zp_admin_recovery_begin($1,$2,$3,$4)",[id.u,reqId,"Fixture identity verified",attempt]),/DENIED/);
 assert.equal((await pool.query("select public.zp_admin_recovery_begin($1,$2,$3,$4) as target",[operator,reqId,"Fixture identity verified",attempt])).rows[0].target,id.u);
 assert.equal((await pool.query("select reset_pending from public.zp_members where id=$1",[id.m])).rows[0].reset_pending,true);
 await assert.rejects(pool.query("select public.zp_issue($1,$2,$3,$4,$5)",[id.m,id.u,0,"stale-test-access",null]),/DENIED/);
 await pool.query("select public.zp_admin_recovery_finish($1,$2,$3,false)",[operator,reqId,attempt]);
 assert.equal((await pool.query("select reset_pending from public.zp_members where id=$1",[id.m])).rows[0].reset_pending,true);
 assert.equal((await pool.query("select state from public.zp_recovery_requests where id=$1",[reqId])).rows[0].state,"failed");
 await pool.query("select public.zp_admin_recovery_begin($1,$2,$3,$4)",[operator,reqId,"Fixture retry after verified failure",retry]);
 await assert.rejects(pool.query("select public.zp_admin_recovery_finish($1,$2,$3,true)",[operator,reqId,attempt]),/DENIED/);
 await pool.query("select public.zp_admin_recovery_finish($1,$2,$3,true)",[operator,reqId,retry]);
 const recovered=(await pool.query("select reset_pending,credential_epoch from public.zp_members where id=$1",[id.m])).rows[0];
 assert.equal(recovered.reset_pending,false);assert.equal(recovered.credential_epoch,2);
 await assert.rejects(pool.query("select public.zp_issue($1,$2,$3,$4,$5)",[id.m,id.u,0,"stale-test-access",null]),/DENIED/);
 assert.equal(Number((await pool.query("select count(*) from public.zp_recovery_audit where request_id=$1",[reqId])).rows[0].count),4);
 console.log("ZIPPLE_ADMIN_RECOVERY_FAILURE_CLOSED_PASS");
 console.log("ZIPPLE_SUPABASE_ADAPTER_SQL_PASS");
 }finally{await pool.end()}});
