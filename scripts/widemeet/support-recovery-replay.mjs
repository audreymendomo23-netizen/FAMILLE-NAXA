// Disposable GoTrue/PostgREST/Edge replay; no hosted access, no production keys, no paid entitlement.
import assert from "node:assert/strict";
import {randomUUID,randomBytes} from "node:crypto";
import {spawn} from "node:child_process";
import {readFile,writeFile,unlink,stat} from "node:fs/promises";
import {createServer} from "node:https";
import {resolve,extname,sep} from "node:path";
import {chromium} from "@playwright/test";
const base=process.env.SUPABASE_URL,service=process.env.SUPABASE_SERVICE_ROLE_KEY,anon=process.env.SUPABASE_ANON_KEY;
assert.equal(base,"http://127.0.0.1:54321");assert.ok(service&&anon);
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const children=[];
let server,browser;
const roomCopy="supabase/functions/widemeet-room/replay-local.ts";
const pass=s=>console.log("PASS "+s);
async function json(url,body,token=service,key=service,method="POST"){
 const r=await fetch(url,{method,headers:{apikey:key,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation"},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const data=await r.json().catch(()=>null);return {status:r.status,data};
}
async function success(url,body,token=service,key=service,method="POST"){
 const r=await json(url,body,token,key,method);assert.ok(r.status>=200&&r.status<300,"HTTP "+r.status+" at "+new URL(url).pathname);return r.data;
}
const rest=(table,body)=>success(base+"/rest/v1/"+table,body);
async function createWorkspace(name){
 const [w]=await rest("wm_workspaces",{kind:"enterprise",name});await rest("wm_room_entitlements",{workspace_id:w.id,plan:"premium",valid_until:new Date(Date.now()+7200000).toISOString(),enabled:true});return w.id;
}
async function fixture(w,role){
 const email="wm-replay-"+randomUUID()+"@example.test",password="Qa7!"+randomBytes(18).toString("hex"),login="WM-"+randomBytes(8).toString("hex").toUpperCase();
 const user=await success(base+"/auth/v1/admin/users",{email,password,email_confirm:true,app_metadata:{app_code:"widemeet"}});
 const [a]=await rest("wm_accounts",{auth_user_id:user.id,login_id:login,auth_alias:email,display_name:"Replay "+role});
 await rest("wm_memberships",{account_id:a.id,workspace_id:w,role});return{id:a.id,login,password};
}
async function launch(file,port){
 const child=spawn("deno",["run","--allow-env","--allow-net=127.0.0.1:54321,0.0.0.0:"+port+",127.0.0.1:"+port,file],{stdio:["ignore","ignore","inherit"]});children.push(child);
 for(let i=0;i<60;i++){try{if((await fetch("http://127.0.0.1:"+port,{method:"OPTIONS"})).ok)return;}catch{}if(child.exitCode!==null)break;await wait(250)}
 throw Error("GATEWAY_START_FAILED_"+port);
}
const auth="http://127.0.0.1:8000",room="http://127.0.0.1:8001";
const request=(url,body,token)=>json(url,{...body,app_id:"WIDEMEET"},token??anon,anon);
async function ok(url,body,token){const r=await request(url,body,token);assert.ok(r.status>=200&&r.status<300,"HTTP "+r.status+" "+new URL(url).pathname+" "+String(r.data?.error??""));return r.data}
async function login(f){return ok(auth+"/login",{identifier:f.login,password:f.password,installation_id:randomUUID(),platform:"web"});}
try{
 const w=await createWorkspace("B5 requester"),other=await createWorkspace("B5 support");
 const h=await fixture(w,"promoteur"),g=await fixture(other,"staff"),v=await fixture(other,"staff"),x=await fixture(other,"staff");
 await rest("wm_support_agents",{account_id:g.id,enabled:true});
 await rest("wm_support_recovery_reviewers",{account_id:g.id,enabled:true});
 await rest("wm_support_recovery_reviewers",{account_id:v.id,enabled:true});
 await launch("supabase/functions/widemeet-auth/index.ts",8000);
 const hs=await login(h),hs2=await login(h),gs=await login(g),vs=await login(v),xs=await login(x);
 const sr=(t,action,data={})=>request(auth+"/identity",{action:"support-"+action,data},t);
 const sk=(t,action,data={})=>ok(auth+"/identity",{action:"support-"+action,data},t);
 const k=await ok(auth+"/recovery-enroll",{current_password:h.password,supervised:true},hs.access_token);
 assert.match(k.recovery_key,/^[a-f0-9]{64}$/);
 const intake={identifier:h.login,supervised:true,recovery_key:k.recovery_key,installation_id:randomUUID(),platform:"web"};
 assert.equal((await request(auth+"/request-recovery",{...intake,recovery_key:randomBytes(32).toString("hex")})).status,401);
 const c=await ok(auth+"/request-recovery",intake);assert.match(c.case_id,/^[a-f0-9-]{36}$/);
 assert.deepEqual(await ok(auth+"/request-recovery",intake),c);
 const reset={...intake,request_id:randomUUID(),new_password:"Qa7!"+randomBytes(18).toString("hex")};
 assert.equal((await request(auth+"/recover-key",reset)).status,401);
 assert.equal((await sr(xs.access_token,"recovery-queue")).status,403);
 const first={request_id:c.case_id,decision:"escalate",evidence_ref:randomUUID()};
 await sk(gs.access_token,"recovery-review",first);
 assert.equal((await request(auth+"/recover-key",reset)).status,401);
 assert.equal((await sr(vs.access_token,"recovery-review",first)).status,403);
 // Real Web UI for second independent reviewer; no mocked backend.
 const dir=resolve("apps/web/widemeet/dist");
 server=createServer({key:await readFile(process.env.WM_REPLAY_KEY),cert:await readFile(process.env.WM_REPLAY_CERT)},async(req,res)=>{
 try{
 const u=new URL(req.url,"https://127.0.0.1:8443");
 if(u.pathname.startsWith("/functions/v1/widemeet-auth/")||u.pathname.startsWith("/functions/v1/widemeet-room/")){
 const target=u.pathname.includes("/widemeet-auth/")?auth:room;
 const chunks=[];for await(const chunk of req)chunks.push(chunk);
 const rr=await fetch(target+u.pathname,{method:req.method,headers:{...req.headers,host:"127.0.0.1",connection:"close"},body:req.method==="POST"?Buffer.concat(chunks):undefined});
 res.writeHead(rr.status,Object.fromEntries(rr.headers));res.end(Buffer.from(await rr.arrayBuffer()));return;
 }
 const p=resolve(dir,"."+u.pathname);if(p!==dir&&!p.startsWith(dir+sep)){res.writeHead(403);res.end();return}
 const file=(await stat(p).catch(()=>null))?.isFile()?p:resolve(dir,"index.html");
 const types={".html":"text/html",".js":"text/javascript",".css":"text/css",".json":"application/json",".png":"image/png",".svg":"image/svg+xml",".webmanifest":"application/manifest+json"};
 res.writeHead(200,{"Content-Type":types[extname(file)]??"application/octet-stream","Cache-Control":"no-store"});res.end(await readFile(file));
 }catch{res.writeHead(502);res.end();}
 });
 await new Promise((r,reject)=>{server.once("error",reject);server.listen(8443,"127.0.0.1",r)});

 browser=await chromium.launch({headless:true});
 const ctx=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"}),vp=await ctx.newPage();
 async function sign(page,f,workspace){
  await page.goto("https://127.0.0.1:8443");
  await page.getByRole("button",{name:"Se connecter",exact:true}).click();
  await page.getByLabel("Identifiant WideMeet",{exact:true}).fill(f.login);
  await page.getByLabel("Mot de passe",{exact:true}).fill(f.password);
  await page.getByRole("button",{name:"Se connecter",exact:true}).click();
  await page.getByText(workspace,{exact:true}).waitFor({timeout:20000});
 }
 async function support(page){await page.getByRole("button",{name:"Options",exact:true}).click();await page.getByRole("button",{name:"Livechat et support ›",exact:true}).click();}
 await sign(vp,v,"B5 support");await support(vp);
 await vp.getByRole("button",{name:"Demandes de récupération supervisée",exact:true}).click();
 const article=vp.locator("article").filter({hasText:c.case_id});
 await article.getByRole("button",{name:"Examiner",exact:true}).click();
 await vp.getByLabel("Référence de dossier (UUID)",{exact:true}).fill(randomUUID());
 await vp.getByLabel("Décision d’examen").selectOption("escalate");
 vp.once("dialog",d=>d.accept());await vp.getByRole("button",{name:"Enregistrer l’examen",exact:true}).click();
 await article.getByText("Examen enregistré",{exact:true}).waitFor();
 assert.equal((await sk(gs.access_token,"recovery-queue")).items.find(q=>q.id===c.case_id).escalations,2);
 // Wrong backup secret and primary recovery path must not authorize this reset.
 assert.equal((await request(auth+"/recover-key",{...reset,recovery_key:randomBytes(32).toString("hex")})).status,401);
 assert.equal((await request(auth+"/recover-key",{...reset,supervised:false})).status,401);
 // Actual requester UI executes existing GoTrue recovery fence (5th attempt).
 const hc=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"}),hp=await hc.newPage();
 await hp.goto("https://127.0.0.1:8443");
 await hp.getByRole("button",{name:"Se connecter",exact:true}).click();
 await hp.getByLabel("Identifiant WideMeet",{exact:true}).fill(h.login);
 await hp.getByRole("button",{name:"Récupérer avec ma clé",exact:true}).click();
 await hp.getByLabel("Utiliser mon code de secours supervisé").check();
 await hp.getByLabel("Clé de récupération",{exact:true}).fill(k.recovery_key);
 await hp.getByRole("button",{name:"Ouvrir ou retrouver mon dossier",exact:true}).click();
 await hp.getByText(new RegExp(c.case_id)).waitFor();
 await hp.getByLabel("Nouveau mot de passe",{exact:true}).fill(reset.new_password);
 await hp.getByLabel("Confirmer",{exact:true}).fill(reset.new_password);
 await hp.getByRole("button",{name:"Récupérer",exact:true}).click();
 await hp.getByText("Compte récupéré. Connectez-vous.",{exact:true}).waitFor({timeout:20000});
 assert.equal((await sr(hs.access_token,"capabilities")).status,403);assert.equal((await sr(hs2.access_token,"capabilities")).status,403);
 assert.equal((await request(auth+"/login",{identifier:h.login,password:h.password,installation_id:randomUUID(),platform:"web"})).status,401);
 const fresh=await login({...h,password:reset.new_password});
 assert.equal(fresh.member_id,h.id);
 // Verify consumed backup is rejected at the database boundary (HTTP rate budget already exhausted).
 const hash=await crypto.subtle.digest("SHA-256",new TextEncoder().encode("wm-supervised-recovery:"+k.recovery_key));
 const digest=Buffer.from(hash).toString("hex");
 assert.equal(await success(base+"/rest/v1/rpc/wm_support_begin_fallback",{p_identifier:h.login,p_key_hash:digest,p_request:randomUUID(),p_commitment:"a".repeat(64)}),null);
 pass("B5 real supervised recovery via Web UI, two reviewers, proof-bound case, GoTrue change, old password and two old sessions rejected, one-use backup");
 // Also verify support UI independently from general profile/photo flow.
 await hp.getByLabel("Mot de passe",{exact:true}).fill(reset.new_password);
 await hp.getByRole("button",{name:"Se connecter",exact:true}).click();
 await hp.getByText("B5 requester",{exact:true}).waitFor();await support(hp);
 await hp.getByLabel("Sujet",{exact:true}).fill("B5 independent browser ticket");
 await hp.getByLabel("Description du problème",{exact:true}).fill("Synthetic B5 issue");
 await hp.getByRole("button",{name:"Envoyer la demande",exact:true}).click();
 await hp.getByRole("heading",{name:"B5 independent browser ticket",exact:true}).waitFor();
 const id=(await sk(fresh.access_token,"list")).items.find(q=>q.subject==="B5 independent browser ticket").id;
 await sk(gs.access_token,"claim",{ticket_id:id});
 await sk(gs.access_token,"reply",{ticket_id:id,message_id:randomUUID(),body:"Independent agent answer"});
 await hp.getByText("Independent agent answer",{exact:true}).waitFor({timeout:20000});
 hp.once("dialog",d=>d.accept());await hp.getByRole("button",{name:"Clôturer",exact:true}).click();
 await hp.getByLabel("Note sur 5",{exact:true}).selectOption("4");await hp.getByRole("button",{name:"Envoyer mon avis",exact:true}).click();
 await hp.getByText("Note enregistrée : 4/5",{exact:true}).waitFor();
 assert.equal((await sk(fresh.access_token,"read",{ticket_id:id})).feedback,4);
 pass("B5 independent browser support ticket, reply, closure and persisted feedback");
 await hp.getByRole("button",{name:"Retour aux demandes",exact:true}).click();
 await hp.getByLabel("Sujet",{exact:true}).fill("Synthetic privacy request");
 await hp.getByLabel("Catégorie",{exact:true}).selectOption("privacy_access");
 await hp.getByText(/aucune donnée n’est automatiquement exportée/).waitFor();
 await hp.getByLabel("Description du problème",{exact:true}).fill("Request for an authorized review only");
 await hp.getByRole("button",{name:"Envoyer la demande",exact:true}).click();
 await hp.getByRole("heading",{name:"Synthetic privacy request",exact:true}).waitFor();
 const privacyCase=(await sk(fresh.access_token,"list")).items.find(q=>q.subject==="Synthetic privacy request");
 assert.equal(privacyCase.category,"privacy_access");assert.equal(privacyCase.status,"open");
 assert.equal((await sr(xs.access_token,"read",{ticket_id:privacyCase.id})).status,403);
 assert.equal((await sr(gs.access_token,"read",{ticket_id:privacyCase.id})).status,403);
 await rest("wm_support_agents",{account_id:v.id,enabled:true});
 assert.equal((await sr(gs.access_token,"claim",{ticket_id:privacyCase.id})).status,403);
 assert.ok(!(await sk(gs.access_token,"queue")).items.some(q=>q.id===privacyCase.id));
 await rest("wm_privacy_reviewers",{account_id:g.id,workspace_id:w,enabled:true});
 await sk(gs.access_token,"claim",{ticket_id:privacyCase.id});
 assert.equal((await sk(gs.access_token,"read",{ticket_id:privacyCase.id})).category,"privacy_access");
 const privacyEvent={ticket_id:privacyCase.id,event_id:randomUUID(),decision:"reviewed"};
 assert.equal((await sr(fresh.access_token,"privacy-review",privacyEvent)).status,403);
 assert.equal((await sr(vs.access_token,"privacy-review",privacyEvent)).status,403);
 await sk(gs.access_token,"privacy-review",privacyEvent);await sk(gs.access_token,"privacy-review",privacyEvent);
 assert.equal((await sr(gs.access_token,"privacy-review",{...privacyEvent,decision:"escalated"})).status,403);
 assert.equal((await sk(fresh.access_token,"read",{ticket_id:privacyCase.id})).privacy_history.length,1);
 assert.equal((await sr(fresh.access_token,"call-request",{ticket_id:privacyCase.id,call_id:randomUUID()})).status,403);
 await success(base+"/rest/v1/wm_privacy_reviewers?account_id=eq."+g.id+"&workspace_id=eq."+w,{enabled:false},service,service,"PATCH");
 assert.equal((await sr(gs.access_token,"read",{ticket_id:privacyCase.id})).status,403);
 assert.equal((await sr(gs.access_token,"privacy-review",{...privacyEvent,event_id:randomUUID()})).status,403);
 assert.equal((await sk(fresh.access_token,"read",{ticket_id:privacyCase.id})).privacy_history.length,1);
 pass("B6 dedicated scoped privacy reviewer, immutable review tracking, revoked access and no media");
 assert.equal((await sr(xs.access_token,"read",{ticket_id:privacyCase.id})).status,403);
 for(const category of ["privacy_rectify","privacy_erase"]){const p={ticket_id:randomUUID(),message_id:randomUUID(),subject:"Synthetic "+category,category,body:"Authorized review requested"};await sk(fresh.access_token,"create",p);await sk(fresh.access_token,"create",p);assert.equal((await sk(fresh.access_token,"read",{ticket_id:p.ticket_id})).category,category)}
 assert.equal((await sr(fresh.access_token,"create",{ticket_id:randomUUID(),message_id:randomUUID(),subject:"Invalid",category:"privacy_execute",body:"Invalid"})).status,403);
 pass("B6 real privacy rights intake, three structured categories, exact retry, assigned access and third party denial");
}finally{
 if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));
 for(const child of children)if(child.exitCode===null){child.kill("SIGTERM");await new Promise(r=>child.once("exit",r))}
}
