import test from "node:test";
import assert from "node:assert/strict";
import pg from "pg";
import {randomUUID} from "node:crypto";
import {chromium} from "playwright";
import {createServer} from "node:https";
import {readFile} from "node:fs/promises";
import {resolve,extname,sep} from "node:path";
import {spawn} from "node:child_process";
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

async function browserRecipe({pw,org,member,site}){
 const root=resolve("apps/web/zipple/dist");
 const server=createServer({key:await readFile(process.env.ZIPPLE_TLS_KEY),cert:await readFile(process.env.ZIPPLE_TLS_CERT)},async(req,res)=>{
  try{
   const url=new URL(req.url,"https://127.0.0.1:4443");
   if(/^\/gateway\/(login|logout|recovery|sync)$/.test(url.pathname)&&req.method==="POST"){
    const chunks=[];let size=0;for await(const c of req){size+=c.length;if(size>8192){res.writeHead(413).end();return}chunks.push(c)}
    const auth=req.headers.authorization;
    const upstream=await fetch(edge+"/"+url.pathname.split("/").pop(),{method:"POST",headers:{"content-type":"application/json",origin:"https://zipple.test",...(auth?{authorization:auth}:{})},body:Buffer.concat(chunks)});
    res.writeHead(upstream.status,{"content-type":upstream.headers.get("content-type")??"application/json","cache-control":"no-store"});res.end(Buffer.from(await upstream.arrayBuffer()));return;
   }
   if(req.method!=="GET"){res.writeHead(405).end();return}
   const path=resolve(root,"."+decodeURIComponent(url.pathname==="/"?"/index.html":url.pathname));
   if(!path.startsWith(root+sep)){res.writeHead(403).end();return}
   const data=await readFile(path);const mime={".html":"text/html",".js":"application/javascript",".css":"text/css",".jpg":"image/jpeg",".svg":"image/svg+xml",".webmanifest":"application/manifest+json"};
   res.writeHead(200,{"content-type":mime[extname(path)]??"application/octet-stream"});res.end(data);
  }catch{res.writeHead(404).end()}
 });
 await new Promise((ok,fail)=>{server.once("error",fail);server.listen(4443,"127.0.0.1",ok)});
 let browser;
 try{
  browser=await chromium.launch({headless:true});
  const ctx=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:390,height:844}});
  const page=await ctx.newPage();await page.goto("https://127.0.0.1:4443/");
  await page.getByLabel("Identifiant").fill("fixture");await page.getByLabel("Mot de passe").fill(pw);
  const loginResponse=page.waitForResponse(r=>r.url().endsWith("/gateway/login")&&r.request().method()==="POST");
  await page.getByRole("button",{name:"Se connecter"}).click();assert.equal((await loginResponse).status(),200);
  await page.getByRole("heading",{name:"ZIPPLE fixture"}).waitFor();
  assert.equal(await page.getByLabel("Établissement autorisé").locator("option").count(),1);
  assert.equal(await page.getByLabel("Établissement autorisé").inputValue(),site);
  const eventId=randomUUID();
  await page.evaluate(async e=>{await new Promise((ok,fail)=>{const q=indexedDB.open("zipple-outbox-v1",1);q.onupgradeneeded=()=>q.result.createObjectStore("events",{keyPath:"eventId"});q.onerror=()=>fail(q.error);q.onsuccess=()=>{const db=q.result,tx=db.transaction("events","readwrite");tx.objectStore("events").add(e);tx.oncomplete=()=>{db.close();ok()};tx.onerror=()=>fail(tx.error)}})}, {eventId,orgId:org,memberId:member,siteId:site,sequence:2,aggregateType:"n1_probe",payload:'{"browser":true}',state:"queued"});
  const receiptPromise=page.waitForResponse(r=>r.url().endsWith("/gateway/sync")&&r.request().method()==="POST");
  await page.getByRole("button",{name:"Synchroniser"}).click();const response=await receiptPromise;assert.equal(response.status(),200);assert.equal((await response.json()).state,"acknowledged");
  await page.waitForFunction(async id=>await new Promise(ok=>{const q=indexedDB.open("zipple-outbox-v1",1);q.onsuccess=()=>{const db=q.result,r=db.transaction("events").objectStore("events").get(id);r.onsuccess=()=>{db.close();ok(r.result?.state==="acknowledged")}}}),eventId);
  assert.equal(Number((await db.query("select count(*) from public.zp_n1_receipts where event_id=$1",[eventId])).rows[0].count),1);
  const logoutPromise=page.waitForResponse(r=>r.url().endsWith("/gateway/logout")&&r.request().method()==="POST");
  await page.getByRole("button",{name:"Déconnexion"}).click();assert.equal((await logoutPromise).status(),200);
  await page.getByRole("button",{name:"Se connecter"}).waitFor();
  await page.reload();await page.getByRole("button",{name:"Se connecter"}).waitFor();
  console.log("ZIPPLE_N1_BROWSER_REAL_EDGE_PASS");
  if(process.env.ZIPPLE_ANDROID_LIVE==="1"){
   const nativeEvent=randomUUID();
   await new Promise((ok,fail)=>{
    const proc=spawn("gradle",["--no-daemon",":zipple:connectedDebugAndroidTest","-PZIPPLE_API_URL=https://127.0.0.1:4443/gateway","-Pandroid.testInstrumentationRunnerArguments.class=cm.naxa.zipple.N1LiveDeviceTest","-Pandroid.testInstrumentationRunnerArguments.zippleFixturePassword="+pw,"-Pandroid.testInstrumentationRunnerArguments.zippleFixtureEvent="+nativeEvent],{stdio:"inherit"});
    proc.on("error",fail);proc.on("exit",code=>code===0?ok():fail(Error("native connected recipe exit "+code)));
   });
   assert.equal(Number((await db.query("select count(*) from public.zp_n1_receipts where event_id=$1",[nativeEvent])).rows[0].count),1);
   console.log("ZIPPLE_N1_ANDROID_REAL_EDGE_PASS");
  }
 }finally{if(browser)await browser.close();await new Promise(ok=>server.close(ok))}
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
  assert.ok([200,204].includes(pre.status),"successful gateway preflight");assert.ok(["https://zipple.test","*"].includes(pre.headers.get("access-control-allow-origin")),"gateway preflight origin");
  // Kong may answer OPTIONS itself; actual POST must still enforce the app allowlist.
  const login=await call("login",{identifier:"FIXTURE",password:pw,remember_device:true});
  assert.equal(login.status,200,"Edge login status "+login.status);assert.ok(login.cache?.split(",").map(x=>x.trim().toLowerCase()).includes("no-store"),"session response must forbid caching");
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
  await browserRecipe({pw,org,member,site});
  // Independent central recovery operator, real GoTrue identity and server-only access.
  const operatorAlias="operator-"+randomUUID()+"@example.test",operatorPw="Operator-"+randomUUID()+"-Aa9!",operator=await createUser(operatorAlias,operatorPw);
  await db.query("insert into public.zp_recovery_operators values($1,true)",[operator]);
  const authOperator=await fetch(base+"/auth/v1/token?grant_type=password",{method:"POST",headers:headers(anon),body:JSON.stringify({email:operatorAlias,password:operatorPw})});
  assert.ok(authOperator.ok);const operatorJwt=(await authOperator.json()).access_token;
  const pendingLogin=await call("login",{identifier:"fixture",password:pw,remember_device:true});assert.equal(pendingLogin.status,200);
  const oldSession=pendingLogin.data;
  assert.equal((await call("admin/recovery/list",{},oldSession.access_token)).status,403);
  assert.equal((await call("admin/recovery/list",{},gotrue.access_token)).status,403);
  const listing=await call("admin/recovery/list",{},operatorJwt);assert.equal(listing.status,200);
  const reqId=listing.data.requests.find(q=>q.member_id===member&&q.state==="pending").id;
  const newPw="Replacement-"+randomUUID()+"-Aa9!";
  assert.equal((await call("admin/recovery/complete",{request_id:reqId,reason:"Fixture identity verified",new_password:newPw},operatorJwt)).status,200);
  assert.equal((await call("sync",event,oldSession.access_token)).status,403);
  assert.equal((await call("refresh",{refresh_token:oldSession.refresh_token})).status,401);
  assert.equal((await call("login",{identifier:"fixture",password:pw})).status,401);
  assert.equal((await call("login",{identifier:"fixture",password:newPw})).status,200);
  assert.equal((await db.query("select state from public.zp_recovery_requests where id=$1",[reqId])).rows[0].state,"resolved");
  assert.equal(Number((await db.query("select count(*) from public.zp_recovery_audit where request_id=$1",[reqId])).rows[0].count),2);
  console.log("ZIPPLE_N1_REAL_ADMIN_RECOVERY_PASS");
 }finally{await db.end()}
});
