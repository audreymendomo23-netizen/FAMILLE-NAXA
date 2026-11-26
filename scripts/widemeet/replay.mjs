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
 const w=await createWorkspace("Replay A"),other=await createWorkspace("Replay B");
 const h=await fixture(w,"promoteur"),g=await fixture(w,"staff"),o=await fixture(other,"promoteur");
 const code=await readFile("supabase/functions/widemeet-room/index.ts","utf8");
 const anchor="Deno.serve(async request=>{";
 assert.equal(code.split(anchor).length,2);
 await writeFile(roomCopy,code.replace(anchor,"Deno.serve({port:8001},async request=>{"));
 await launch("supabase/functions/widemeet-auth/index.ts",8000);await launch(roomCopy,8001);
 // Register real GoTrue accounts through the product gateway (test-only policy versions).
 for(const kind of ["individual","enterprise"]){
 const password="Qa7!"+randomBytes(18).toString("hex"),registration={installation_id:randomUUID(),request_id:randomUUID(),kind,display_name:"Replay "+kind,workspace_name:"Registration "+kind,password,accepted_terms:true,terms_version:"wm-replay-draft-20261126",privacy_version:"wm-replay-draft-20261126"};
 const registered=await ok(auth+"/register",registration);
 assert.match(registered.login_id,/^WM-[A-Z0-9]{8,24}$/);
 assert.deepEqual(await ok(auth+"/register",registration),registered);
 const session=await login({login:registered.login_id,password});
 assert.equal(session.workspaces.length,1);
 assert.equal(session.workspaces[0].kind,kind);
 assert.equal((await request(room+"/list",{},session.access_token)).status,403);
 assert.ok((await request(auth+"/register",{...registration,display_name:"Changed"})).status>=400);
 }
 pass("actual autonomous individual and enterprise registration, stable retry, no automatic entitlement");
 const hs=await login(h),gs=await login(g),os=await login(o);
 assert.equal(hs.member_id,h.id);assert.equal(gs.member_id,g.id);assert.equal(os.active_workspace_id,other);
 const denied=await request(auth+"/login",{identifier:h.login,password:"wrong",installation_id:randomUUID(),platform:"web"});assert.equal(denied.status,401);
 const rec=await ok(auth+"/request-recovery",{identifier:h.login,installation_id:randomUUID(),platform:"web"});const unknown=await ok(auth+"/request-recovery",{identifier:"WM-UNKNOWN123",installation_id:randomUUID(),platform:"web"});assert.deepEqual(rec,unknown);assert.equal(rec.accepted,true);
 pass("actual GoTrue login and neutral recovery intake");
 const contacts=await ok(room+"/contacts",{},hs.access_token);assert.equal(contacts.length,1);assert.equal(contacts[0].member_id,g.id);
 const rid=randomUUID(),create={room_id:rid,title:"Replay real meeting",description:"Scoped control plane",scheduled_ms:Date.now(),duration_minutes:30,invitees:[g.id]};
 assert.equal((await request(room+"/create",create,gs.access_token)).status,409);
 assert.equal((await request(room+"/create",{...create,invitees:[o.id]},hs.access_token)).status,409);
 let state=await ok(room+"/create",create,hs.access_token);
 assert.equal(state.status,"scheduled");
 assert.equal((await request(room+"/read",{room_id:rid},os.access_token)).status,404);
 assert.equal((await ok(room+"/list",{},os.access_token)).length,0);
 async function cmd(token,action,value=null,target=null){state=await ok(room+"/command",{room_id:rid,request_id:randomUUID(),expected_revision:state.revision,action,value,target},token);return state;}
 await cmd(gs.access_token,"respond","accepted");await cmd(hs.access_token,"start");assert.equal(state.status,"open");
 await cmd(gs.access_token,"chat","Hello from real account");
 assert.equal(state.events[0].value,"Hello from real account");
 await cmd(gs.access_token,"hand",true);
 await cmd(hs.access_token,"mute",null,g.id);
 assert.equal(state.participants.find(p=>p.memberId===g.id).mic,false);
 await cmd(hs.access_token,"consent",true);await cmd(gs.access_token,"consent",true);await cmd(hs.access_token,"record",true);
 assert.equal(state.recording,"requested");await cmd(gs.access_token,"consent",false);assert.equal(state.recording,"off");
 const pid=randomUUID();await cmd(hs.access_token,"poll",["Yes","No"],pid);await cmd(gs.access_token,"vote",0,pid);assert.equal(state.polls[0].counts[0],1);assert.equal(state.polls[0].votes,undefined);await cmd(hs.access_token,"close_poll",null,pid);
 await cmd(hs.access_token,"pause");await cmd(hs.access_token,"resume");await cmd(hs.access_token,"exclude",null,g.id);
 assert.equal((await request(room+"/read",{room_id:rid},gs.access_token)).status,404);
 await cmd(hs.access_token,"end");assert.equal(state.status,"ended");
 pass("actual Edge/PostgREST room create, RSVP, chat, moderation, consent, vote, exclusion, tenant isolation; no media capture");
 assert.equal((await request(room+"/media-grant",{room_id:rid},hs.access_token)).status,403);
 await ok(auth+"/logout",{},hs.access_token);assert.equal((await request(room+"/list",{},hs.access_token)).status,403);pass("real opaque session logout and revocation");
 // Test real browser with TLS restricted to isolated loopback. No mock HTTP or fake login.
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
 const hc=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"}),gc=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"}),hp=await hc.newPage(),gp=await gc.newPage();
 async function sign(page,f){
 await page.goto("https://127.0.0.1:8443");
 await page.getByRole("button",{name:"Se connecter",exact:true}).click();
 await page.getByLabel("Identifiant WideMeet",{exact:true}).fill(f.login);
 await page.getByLabel("Mot de passe",{exact:true}).fill(f.password);
 await page.getByRole("button",{name:"Se connecter",exact:true}).click();
 await page.getByText("Replay A",{exact:true}).waitFor();
 await page.getByRole("navigation").getByRole("button",{name:"Agenda"}).click();
 await page.getByRole("region",{name:"Réunions"}).waitFor();
 }
 await sign(hp,h);await hp.getByRole("region",{name:"Réunions"}).getByRole("button",{name:"Nouvelle réunion",exact:true}).click();
 await hp.getByLabel("Titre",{exact:true}).fill("Replay browser room");
 await hp.getByLabel("Replay staff",{exact:true}).check();
 await hp.getByRole("button",{name:"Créer",exact:true}).click();
 await hp.getByRole("heading",{name:"Replay browser room",exact:true}).waitFor();
 await sign(gp,g);await gp.getByRole("button",{name:/Replay browser room/}).click();
 await gp.getByRole("button",{name:"Accepter",exact:true}).click();
 await hp.getByRole("button",{name:"Actualiser",exact:true}).click();await hp.getByRole("button",{name:"Ouvrir la salle",exact:true}).click();
 await hp.getByText("Audio et vidéo indisponibles pour le moment.",{exact:true}).waitFor();
 await gp.getByRole("button",{name:"Actualiser",exact:true}).click();await gp.getByLabel("Message",{exact:true}).fill("Bonjour réel");
 await gp.getByRole("button",{name:"Envoyer",exact:true}).click();await gp.getByText(/Bonjour réel/).waitFor();
 await hp.getByRole("button",{name:"Actualiser",exact:true}).click();await hp.getByText(/Bonjour réel/).waitFor();
 pass("two real browser accounts: login, agenda, creation, RSVP, start, chat");
}finally{
 if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));
 for(const child of children)if(child.exitCode===null){child.kill("SIGTERM");await new Promise(r=>child.once("exit",r));}
 await unlink(roomCopy).catch(()=>{});
}
