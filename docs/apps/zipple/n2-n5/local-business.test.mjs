import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {randomUUID} from "node:crypto";import {chromium} from "playwright";import {createServer} from "node:https";import {readFile} from "node:fs/promises";import {resolve,extname,sep} from "node:path";
const base=process.env.API_URL,dbUrl=process.env.DB_URL,service=process.env.SERVICE_ROLE_KEY;
assert.ok(/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(base));assert.ok(["127.0.0.1","localhost"].includes(new URL(dbUrl).hostname));
const db=new pg.Pool({connectionString:dbUrl}),origin="https://zipple.test",publicOrigin="https://127.0.0.1:4443",configured="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-business";
const id=()=>randomUUID();
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0]??{})[0];
async function call(fn,action,body,token,guest=false){const res=await fetch(base+"/functions/v1/"+fn+"/"+action,{method:"POST",headers:{origin,"Content-Type":"application/json",...(token?{authorization:(guest?"Guest ":"Bearer ")+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})});return {status:res.status,body:await res.json()}}
test("actual GoTrue, PostgREST, ZIPPLE business Edge, professional browser and guest browser",async()=>{
 let server,browser;
 try{
  const org=id(),member=id(),site=id(),login="zipple-business-fixture",email=id()+"@example.test",password="Fixture-"+id()+"-Aa9!";
  const created=await fetch(base+"/auth/v1/admin/users",{method:"POST",headers:{apikey:service,authorization:"Bearer "+service,"content-type":"application/json"},body:JSON.stringify({email,password,email_confirm:true})});assert.ok(created.ok,"local Auth fixture");
  const user=(await created.json()).id;
  await db.query("insert into zp_organizations values($1,'ZIPPLE business fixture',true)",[org]);
  await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,'promoteur')",[member,org,user,login,email]);
  await db.query("insert into zp_sites values($1,$2,'Restaurant fixture',true)",[site,org]);await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);
  const auth=await call("zipple-n1","login",{identifier:login,password});assert.equal(auth.status,200);const token=auth.body.access_token;
  const b=(action,body={},authToken=token,guest=false)=>call("zipple-business",action,{site_id:site,...body},authToken,guest);
  const quote=await b("quote",{plan:"ACCESS",cadence:"monthly",provider:"mtn_momo",request_id:id()});assert.equal(quote.status,200);assert.equal(quote.body.data.amount_xaf,5000);
  assert.equal((await b("snapshot")).status,403);assert.equal((await b("confirm_subscription",{verified:true})).status,403);
  // Synthetic payment confirmation only through privileged SQL on the disposable database.
  await scalar("select zp_confirm_subscription($1,'mtn_momo',$2,5000,'XAF')",[quote.body.data.id,id()]);
  assert.equal((await b("mode",{space:"restaurant",bar:true,delivery:false})).status,200);
  const item=await b("menu_add",{name:"Plat recette",post:"kitchen",price_xaf:2500,qty:3});assert.equal(item.status,200);
  const table=await b("table_create",{label:"Table 1"});assert.equal(table.status,200);const tableId=table.body.data.id,qr=table.body.data.qr;
  assert.equal((await b("table_open",{table_id:tableId})).status,200);
  const root=resolve("apps/web/zipple/dist");
  server=createServer({key:await readFile(process.env.ZIPPLE_TLS_KEY),cert:await readFile(process.env.ZIPPLE_TLS_CERT)},async(req,res)=>{
   try{const u=new URL(req.url,publicOrigin);if(u.pathname.startsWith("/gateway/")&&req.method==="POST"){const chunks=[];for await(const c of req)chunks.push(c);const response=await fetch(base+"/functions/v1/zipple-n1/"+u.pathname.split("/").pop(),{method:"POST",headers:{origin,"content-type":"application/json",...(req.headers.authorization?{authorization:req.headers.authorization}:{})},body:Buffer.concat(chunks)});res.writeHead(response.status,{"content-type":"application/json","cache-control":"no-store"});res.end(Buffer.from(await response.arrayBuffer()));return}
    if(req.method!=="GET"){res.writeHead(405).end();return}const path=resolve(root,"."+decodeURIComponent(u.pathname==="/"?"/index.html":u.pathname));if(!path.startsWith(root+sep)){res.writeHead(403).end();return}const data=await readFile(path);const mime={".html":"text/html",".js":"application/javascript",".css":"text/css",".png":"image/png",".svg":"image/svg+xml",".webp":"image/webp",".jpg":"image/jpeg",".json":"application/json",".webmanifest":"application/manifest+json"};res.writeHead(200,{"content-type":mime[extname(path)]??"application/octet-stream","cache-control":"no-store"});res.end(data)
   }catch{res.writeHead(404).end()}
  });await new Promise((ok,fail)=>{server.once("error",fail);server.listen(4443,"127.0.0.1",ok)});
  browser=await chromium.launch({headless:true});
  async function context(){const ctx=await browser.newContext({ignoreHTTPSErrors:true,reducedMotion:"reduce",serviceWorkers:"block",viewport:{width:390,height:844}});await ctx.route("**/*",async route=>{const req=route.request(),url=req.url();if(url.startsWith(publicOrigin+"/"))return route.continue();if(!url.startsWith(configured+"/"))return route.abort();const action=url.slice(configured.length+1);if(!/^[a-z_]+$/.test(action))return route.abort();const cors={"access-control-allow-origin":publicOrigin,"access-control-allow-headers":"authorization,content-type","access-control-allow-methods":"POST,OPTIONS","cache-control":"no-store"};if(req.method()==="OPTIONS")return route.fulfill({status:204,headers:cors});if(req.method()!=="POST")return route.abort();const response=await fetch(base+"/functions/v1/zipple-business/"+action,{method:"POST",headers:{origin,"content-type":"application/json",...(req.headers().authorization?{authorization:req.headers().authorization}:{})},body:req.postDataBuffer()??Buffer.from("{}")});return route.fulfill({status:response.status,headers:{...cors,"content-type":"application/json"},body:Buffer.from(await response.arrayBuffer())})});return ctx}
  const staff=await context(),page=await staff.newPage();await page.goto(publicOrigin);await page.getByLabel("Identifiant").fill(login);await page.getByLabel("Mot de passe",{exact:true}).fill(password);await page.getByRole("button",{name:"Se connecter"}).click();await page.getByRole("heading",{name:"Gestion ZIPPLE"}).waitFor();await page.getByRole("heading",{name:"Nouvelle commande"}).waitFor();
  const guestCtx=await context(),guest=await guestCtx.newPage();await guest.goto(publicOrigin+"/#table="+qr);await guest.getByRole("heading",{name:"Commander sans compte"}).waitFor();await guest.getByRole("button",{name:"Voir la carte"}).click();await guest.getByLabel(/Plat recette/).fill("1");await guest.getByRole("button",{name:"Confirmer ma commande"}).click();await guest.getByRole("heading",{name:"Commande confirmée"}).waitFor();
  assert.equal(Number(await scalar("select count(*) from zp_orders where org_id=$1 and guest_id is not null",[org])),1);
  await page.getByRole("button",{name:"Actualiser"}).click();
  for(let i=0;i<3;i++){const next=page.getByRole("button",{name:"Étape suivante"});await next.waitFor();await next.click();await page.getByText("Plat recette × 1 · kitchen · "+["preparing","ready","served"][i],{exact:true}).waitFor()}
  await guest.getByRole("heading",{name:"Votre avis (facultatif)"}).waitFor({timeout:15000});await guest.getByRole("button",{name:"Envoyer mon avis"}).click();await guest.getByText("Merci pour votre avis.").waitFor();
  assert.equal(Number(await scalar("select count(*) from zp_feedback where org_id=$1",[org])),1);
  assert.equal(await scalar("select available_qty from zp_menu_items where id=$1",[item.body.data]),2);
  await staff.close();await guestCtx.close();
  console.log("ZIPPLE_BUSINESS_REAL_EDGE_PROFESSIONAL_AND_GUEST_BROWSER_PASS");
 }finally{if(browser)await browser.close();if(server)await new Promise(ok=>server.close(ok));await db.end()}
});
