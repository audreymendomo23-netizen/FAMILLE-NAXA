import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import {chromium} from "playwright";
import {createServer} from "node:https";
import {readFile,writeFile} from "node:fs/promises";
import {resolve,extname,sep} from "node:path";
import {spawn} from "node:child_process";
const base="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1",edge=base+"/zipple-n1",fixture=base+"/zipple-n1-ci-fixture";
async function oidc(){
 const url=new URL(process.env.ACTIONS_ID_TOKEN_REQUEST_URL);url.searchParams.set("audience","zipple-n1-hosted-recipe");
 const r=await fetch(url,{headers:{authorization:"Bearer "+process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN}});
 assert.ok(r.ok,"OIDC request failed");return (await r.json()).value;
}
async function ci(action){
 const r=await fetch(fixture+"/"+action,{method:"POST",headers:{authorization:"Bearer "+await oidc()},signal:AbortSignal.timeout(45000)});
 const data=await r.json();return {status:r.status,data};
}
async function call(action,body,token){
 const r=await fetch(edge+"/"+action,{method:"POST",headers:{"content-type":"application/json",...(token?{authorization:"Bearer "+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body}),signal:AbortSignal.timeout(20000)});
 return {status:r.status,data:await r.json()};
}
let f,server,browser,provisioned=false;
try{
 const p=await ci("provision");assert.equal(p.status,200,"CI fixture provisioning");f=p.data;provisioned=true;console.log("::add-mask::"+f.password);
 const {login,password,org,member,site}=f;
 assert.equal((await call("login",{identifier:login,password:"wrong"})).status,401);
 const signed=await call("login",{identifier:login,password,remember_device:true});assert.equal(signed.status,200);
 const s=signed.data;assert.equal(s.organization_id,org);assert.equal(s.member_id,member);assert.deepEqual(s.sites.map(x=>x.id),[site]);
 const e={event_id:randomUUID(),organization_id:org,member_id:member,site_id:site,sequence:1,aggregate_type:"n1_probe",payload:{hosted:true}};
 assert.equal((await call("sync",e,s.access_token)).data.state,"acknowledged");
 assert.equal((await call("sync",e,s.access_token)).data.state,"acknowledged");
 assert.equal((await call("sync",{...e,payload:{hosted:false}},s.access_token)).data.state,"conflict");
 assert.equal((await call("sync",{...e,site_id:randomUUID()},s.access_token)).status,403);
 assert.equal((await call("sync",{...e,organization_id:randomUUID()},s.access_token)).status,403);
 assert.equal((await call("sync",{...e,aggregate_type:"sale"},s.access_token)).status,403);
 const next=await call("refresh",{refresh_token:s.refresh_token});assert.equal(next.status,200);
 assert.equal((await call("refresh",{refresh_token:s.refresh_token})).status,401);
 assert.equal((await call("sync",e,s.access_token)).status,403);
 assert.equal((await call("logout",{},next.data.access_token)).status,200);
 assert.equal((await call("sync",e,next.data.access_token)).status,403);
 assert.equal((await call("recovery",{identifier:login})).status,202);
 console.log("ZIPPLE_HOSTED_POSITIVE_API_PASS");
 const root=resolve("apps/web/zipple/dist");
 server=createServer({key:await readFile(process.env.ZIPPLE_TLS_KEY),cert:await readFile(process.env.ZIPPLE_TLS_CERT)},async(req,res)=>{
  try{
   const u=new URL(req.url,"https://127.0.0.1:4443");
   if(/^\/gateway\/(login|logout|recovery|sync)$/.test(u.pathname)&&req.method==="POST"){
    const chunks=[];let size=0;for await(const c of req){size+=c.length;if(size>8192){res.writeHead(413).end();return}chunks.push(c)}
    const upstream=await fetch(edge+"/"+u.pathname.split("/").pop(),{method:"POST",headers:{"content-type":"application/json",...(req.headers.authorization?{authorization:req.headers.authorization}:{})},body:Buffer.concat(chunks)});
    res.writeHead(upstream.status,{"content-type":"application/json","cache-control":"no-store"});res.end(Buffer.from(await upstream.arrayBuffer()));return;
   }
   if(req.method!=="GET"){res.writeHead(405).end();return}
   const file=resolve(root,"."+decodeURIComponent(u.pathname==="/"?"/index.html":u.pathname));if(!file.startsWith(root+sep)){res.writeHead(403).end();return}
   const mime={".html":"text/html",".js":"application/javascript",".css":"text/css",".jpg":"image/jpeg",".svg":"image/svg+xml",".webmanifest":"application/manifest+json"};
   res.writeHead(200,{"content-type":mime[extname(file)]??"application/octet-stream"});res.end(await readFile(file));
  }catch{res.writeHead(404).end()}
 });
 await new Promise((ok,fail)=>{server.once("error",fail);server.listen(4443,"127.0.0.1",ok)});
 browser=await chromium.launch({headless:true});
 const ctx=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:390,height:844}});const page=await ctx.newPage();
 await page.goto("https://127.0.0.1:4443/");
 await page.getByLabel("Identifiant").fill(login);await page.getByLabel("Mot de passe").fill(password);
 await page.getByRole("button",{name:"Se connecter"}).click();await page.getByRole("heading",{name:"ZIPPLE fixture"}).waitFor();
 assert.equal(await page.getByLabel("Établissement autorisé").inputValue(),site);
 const eventId=randomUUID();
 await page.evaluate(async e=>{await new Promise((ok,fail)=>{const q=indexedDB.open("zipple-outbox-v1",1);q.onupgradeneeded=()=>q.result.createObjectStore("events",{keyPath:"eventId"});q.onerror=()=>fail(q.error);q.onsuccess=()=>{const db=q.result,tx=db.transaction("events","readwrite");tx.objectStore("events").add(e);tx.oncomplete=()=>{db.close();ok()};tx.onerror=()=>fail(tx.error)}})},{eventId,orgId:org,memberId:member,siteId:site,sequence:2,aggregateType:"n1_probe",payload:'{"browser":true}',state:"queued"});
 const response=page.waitForResponse(r=>r.url().endsWith("/gateway/sync")&&r.request().method()==="POST");await page.getByRole("button",{name:"Synchroniser"}).click();
 const rec=await response;assert.equal(rec.status(),200);assert.equal((await rec.json()).state,"acknowledged");
 await page.waitForFunction(async id=>await new Promise(ok=>{const q=indexedDB.open("zipple-outbox-v1",1);q.onsuccess=()=>{const db=q.result,r=db.transaction("events").objectStore("events").get(id);r.onsuccess=()=>{db.close();ok(r.result?.state==="acknowledged")}}}),eventId);
 const logout=page.waitForResponse(r=>r.url().endsWith("/gateway/logout")&&r.request().method()==="POST");await page.getByRole("button",{name:"Déconnexion"}).click();assert.equal((await logout).status(),200);
 await page.getByRole("button",{name:"Se connecter"}).waitFor();await page.reload();await page.getByRole("button",{name:"Se connecter"}).waitFor();
 console.log("ZIPPLE_HOSTED_BROWSER_PROXY_PASS");
 await browser.close();browser=null;
 // Android connects directly to the hosted HTTPS endpoint, without custom TLS trust.
 const nativeEvent=randomUUID();
 await new Promise((ok,fail)=>{const proc=spawn("gradle",["--no-daemon",":zipple:connectedDebugAndroidTest","-PZIPPLE_API_URL="+edge,"-Pandroid.testInstrumentationRunnerArguments.class=cm.naxa.zipple.N1LiveDeviceTest","-Pandroid.testInstrumentationRunnerArguments.zippleFixtureLogin="+login,"-Pandroid.testInstrumentationRunnerArguments.zippleFixturePassword="+password,"-Pandroid.testInstrumentationRunnerArguments.zippleFixtureEvent="+nativeEvent],{stdio:"inherit"});proc.on("error",fail);proc.on("exit",code=>code===0?ok():fail(Error("Native recipe failed")))});
 const {readdir}=await import("node:fs/promises");const dir="apps/android/zipple/build/outputs/androidTest-results/connected/debug";async function walk(p){const files=await readdir(p,{withFileTypes:true});return (await Promise.all(files.map(x=>x.isDirectory()?walk(p+"/"+x.name):[p+"/"+x.name]))).flat()}
 const xmls=(await walk(dir)).filter(x=>x.endsWith(".xml"));const xml=(await Promise.all(xmls.map(x=>readFile(x,"utf8")))).join("\n");
 assert.match(xml,/name="authenticatedNativeAndPersistedSync"/);assert.doesNotMatch(xml,/<skipped|<failure|<error/);
 console.log("ZIPPLE_HOSTED_ANDROID_DIRECT_PASS");
 const verify=await call("login",{identifier:login,password});assert.equal(verify.status,200);
 const nativeProbe={event_id:nativeEvent,organization_id:org,member_id:member,site_id:site,sequence:3,aggregate_type:"n1_probe",payload:{android:false}};
 assert.equal((await call("sync",nativeProbe,verify.data.access_token)).data.state,"conflict","native receipt previously persisted");
 assert.equal((await call("logout",{},verify.data.access_token)).status,200);
 console.log("ZIPPLE_HOSTED_NATIVE_RECEIPT_PASS");
}finally{
 if(browser)await browser.close();if(server)await new Promise(ok=>server.close(ok));
 if(provisioned){const c=await ci("cleanup");assert.equal(c.status,200,"fixture cleanup");console.log("ZIPPLE_HOSTED_FIXTURE_CLEANED")}
}
