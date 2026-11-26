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
  const org=id(),member=id(),site=id(),destination=id(),login="zipple-business-fixture",email=id()+"@example.test",password="Fixture-"+id()+"-Aa9!";
  const created=await fetch(base+"/auth/v1/admin/users",{method:"POST",headers:{apikey:service,authorization:"Bearer "+service,"content-type":"application/json"},body:JSON.stringify({email,password,email_confirm:true})});assert.ok(created.ok,"local Auth fixture");
  const user=(await created.json()).id;
  await db.query("insert into zp_organizations values($1,'ZIPPLE business fixture',true)",[org]);
  await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,'promoteur')",[member,org,user,login,email]);
  await db.query("insert into zp_sites values($1,$2,'Restaurant fixture',true)",[site,org]);await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);await db.query("insert into zp_sites values($1,$2,'Restaurant destination',true)",[destination,org]);await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,destination]);
  const auth=await call("zipple-n1","login",{identifier:login,password});assert.equal(auth.status,200);const token=auth.body.access_token;
  const b=(action,body={},authToken=token,guest=false)=>call("zipple-business",action,{site_id:site,...body},authToken,guest);
  const quote=await b("quote",{plan:"ACCESS",cadence:"monthly",provider:"mtn_momo",request_id:id()});assert.equal(quote.status,200);assert.equal(quote.body.data.amount_xaf,5000);
  assert.equal((await b("snapshot")).status,403);assert.equal((await b("confirm_subscription",{verified:true})).status,403);
  // Synthetic payment confirmation only through privileged SQL on the disposable database.
  const premium=await b("quote",{plan:"PREMIUM",cadence:"monthly",provider:"mtn_momo",request_id:id()});assert.equal(premium.status,200);assert.equal(premium.body.data.amount_xaf,18000);
  await scalar("select zp_confirm_subscription($1,'mtn_momo',$2,18000,'XAF')",[premium.body.data.id,id()]);
  assert.equal((await b("mode",{space:"restaurant",bar:true,delivery:false})).status,200);
  assert.equal((await b("mode",{site_id:destination,space:"restaurant",bar:false,delivery:false})).status,200);
  const destinationIngredient=await b("ingredient_add",{site_id:destination,name:"Farine destination",sku:"FAR-TEST",unit:"kg",reorder_milli:0,supplier_whatsapp:""});assert.equal(destinationIngredient.status,200);
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
  const staff=await context(),page=await staff.newPage();await page.goto(publicOrigin);await page.getByLabel("Identifiant").fill(login);await page.getByLabel("Mot de passe",{exact:true}).fill(password);await page.getByRole("button",{name:"Se connecter"}).click();await page.getByRole("heading",{name:"Gestion ZIPPLE"}).waitFor();await page.getByRole("combobox",{name:"Établissement autorisé",exact:true}).selectOption(site);await page.getByRole("heading",{name:"Nouvelle commande"}).waitFor();
  const guestCtx=await context(),guest=await guestCtx.newPage();await guest.goto(publicOrigin+"/#table="+qr);await guest.getByRole("heading",{name:"Commander sans compte"}).waitFor();await guest.getByRole("button",{name:"Voir la carte"}).click();await guest.getByLabel(/Plat recette/).fill("1");await guest.getByRole("button",{name:"Confirmer ma commande"}).click();await guest.getByRole("heading",{name:"Commande confirmée"}).waitFor();
  assert.equal(Number(await scalar("select count(*) from zp_orders where org_id=$1 and guest_id is not null",[org])),1);
  await guest.getByRole("button",{name:"J’ai été servi"}).click();await guest.getByText("Service confirmé par vous").waitFor();
  assert.equal(await scalar("select status from zp_orders where org_id=$1",[org]),"received");
  assert.ok(await scalar("select guest_served_at from zp_orders where org_id=$1",[org]));
  await page.getByRole("button",{name:"Actualiser"}).click();
  for(let i=0;i<3;i++){const next=page.getByRole("button",{name:"Étape suivante"});await next.waitFor();await next.click();await page.getByText("Plat recette × 1 · kitchen · "+["preparing","ready","served"][i],{exact:true}).waitFor()}
  await guest.getByRole("heading",{name:"Votre avis (facultatif)"}).waitFor({timeout:15000});await guest.getByRole("combobox",{name:"Note du poste kitchen"}).selectOption("4");await guest.getByRole("button",{name:"Envoyer mon avis"}).click();await guest.getByText("Merci pour votre avis.").waitFor();assert.equal(await scalar("select rating from zp_feedback_posts where org_id=$1 and post='kitchen'",[org]),4);
  assert.equal(Number(await scalar("select count(*) from zp_feedback where org_id=$1",[org])),1);
  assert.equal(await scalar("select available_qty from zp_menu_items where id=$1",[item.body.data]),2);
  await page.getByRole("button",{name:"Stocks & finances"}).click();await page.getByRole("heading",{name:"Stocks et finances"}).waitFor();
  await page.getByLabel("Nom de la matière").fill("Farine recette");await page.getByLabel("SKU",{exact:true}).fill("FAR-TEST");await page.getByRole("button",{name:"Ajouter la matière"}).click();
  await page.getByRole("combobox",{name:"Matière",exact:true}).locator("option").filter({hasText:"Farine recette (kg)"}).waitFor({state:"attached"});
  await page.getByRole("combobox",{name:"Matière",exact:true}).selectOption({label:"Farine recette (kg)"});
  await page.getByLabel("Numéro de lot").fill("LOT-TEST");await page.getByLabel("Fournisseur",{exact:true}).fill("Fournisseur recette");await page.getByLabel("Quantité reçue").fill("3");await page.getByLabel("Coût total du lot FCFA").fill("1500");await page.getByRole("button",{name:"Enregistrer la réception"}).click();
  await page.getByText(/LOT-TEST · Fournisseur recette/).waitFor();
  const ingredientId=await scalar("select id from zp_ingredients where org_id=$1 and name='Farine recette'",[org]);
  assert.equal(Number(await scalar("select remaining_milli from zp_ingredient_lots where ingredient_id=$1",[ingredientId])),3000);
  await page.getByRole("button",{name:"Dépenses",exact:true}).click();await page.getByLabel("Libellé de dépense").fill("Loyer recette");await page.getByLabel("Montant FCFA",{exact:true}).fill("2500");await page.getByLabel("Référence justificative").fill("LOYER-TEST");await page.getByRole("button",{name:"Enregistrer la dépense"}).click();await page.getByText(/Loyer recette ·/).waitFor();
  assert.equal(Number(await scalar("select amount_xaf from zp_expenses where org_id=$1",[org])),2500);
  await page.getByRole("button",{name:"Comptabilité",exact:true}).click();await page.getByText(/Coût des ventes non déterminé/).waitFor();
  console.log("ZIPPLE_N5_REAL_EDGE_STOCK_EXPENSE_UI_PASS");
  await page.getByRole("button",{name:"Achats",exact:true}).click();
  await page.getByLabel("Nom du fournisseur").fill("Grossiste recette");await page.getByRole("button",{name:"Créer le fournisseur"}).click();
  await page.getByRole("combobox",{name:"Fournisseur de la commande",exact:true}).selectOption({label:"Grossiste recette"});
  await page.getByRole("combobox",{name:"Matière commandée",exact:true}).selectOption({label:"Farine recette (kg)"});
  await page.getByLabel("Référence de commande").fill("ACH-RECETTE");await page.getByLabel("Quantité commandée").fill("2");await page.getByLabel("Coût total commandé FCFA").fill("1000");await page.getByRole("button",{name:"Créer la commande"}).click();
  await page.getByRole("combobox",{name:"Commande à traiter",exact:true}).selectOption({label:"ACH-RECETTE"});
  await page.getByLabel("Quantité réceptionnée").fill("1");await page.getByLabel("Lot de réception").fill("ACH-LOT");await page.getByRole("button",{name:"Confirmer la réception"}).click();
  await page.getByText(/Reçu : 1\/2/).waitFor();
  await page.getByLabel("Montant du règlement FCFA").fill("200");await page.getByLabel("Référence du règlement").fill("REG-RECETTE");await page.getByRole("button",{name:"Enregistrer le règlement"}).click();
  await page.getByText(/Dette fournisseur enregistrée : 300 FCFA/).waitFor();
  const purchase=await scalar("select id from zp_purchases where org_id=$1",[org]);assert.equal(Number(await scalar("select paid_xaf from zp_purchases where id=$1",[purchase])),200);
  console.log("ZIPPLE_N5_REAL_EDGE_PROCUREMENT_UI_PASS");
  await page.getByRole("button",{name:"Clients",exact:true}).click();await page.getByRole("heading",{name:"Relation client"}).waitFor();
  await page.getByLabel("Nom d’usage").fill("Client recette");await page.getByLabel("Téléphone volontaire (facultatif)").fill("237699000001");await page.getByLabel("Le client a volontairement communiqué ces informations.").check();await page.getByRole("button",{name:"Enregistrer la fiche"}).click();
  await page.getByRole("combobox",{name:"Client sélectionné"}).selectOption({label:"Client recette · 237699000001"});
  const orderId=await scalar("select id from zp_orders where org_id=$1",[org]);
  await page.getByRole("combobox",{name:"Commande à rattacher"}).selectOption(orderId);await page.getByRole("button",{name:"Rattacher la commande"}).click();await page.getByText(/Non réglée/).waitFor();
  await page.getByLabel("Objet du suivi").fill("Suivi recette");await page.getByLabel("Échéance du suivi").fill("2026-12-01");await page.getByRole("button",{name:"Créer le suivi"}).click();
  await page.getByRole("button",{name:"Clôturer le suivi"}).click();await page.getByText("Terminé",{exact:true}).waitFor();
  assert.ok(await scalar("select completed_at from zp_customer_followups where org_id=$1",[org]));
  console.log("ZIPPLE_CRM_REAL_EDGE_BROWSER_PASS");
  // Reuse the same real professional session for packaging and transfer, no mocked response.
  await page.getByRole("button",{name:"Stocks & finances"}).click();await page.getByRole("button",{name:"Consignes",exact:true}).click();
  await page.getByRole("combobox",{name:"Fiche de contrepartie",exact:true}).selectOption({label:"Grossiste recette"});
  await page.getByLabel("Type d'emballage").fill("Casiers recette");await page.getByLabel("Valeur unitaire de référence FCFA").fill("500");await page.getByRole("button",{name:"Créer le suivi de consigne"}).click();
  await page.getByRole("combobox",{name:"Emballage suivi",exact:true}).selectOption({label:"Casiers recette · Grossiste recette"});
  await page.getByLabel("Quantité",{exact:true}).fill("4");await page.getByRole("button",{name:"Enregistrer le mouvement"}).click();
  await page.getByText(/Grossiste recette · Casiers recette · 4 à rendre/).waitFor();
  assert.equal(await scalar("select outstanding from zp_container_accounts where org_id=$1",[org]),4);
  console.log("ZIPPLE_N5_REAL_EDGE_CONTAINER_UI_PASS");
  await page.getByRole("button",{name:"Transferts",exact:true}).click();
  const sourceLot=await scalar("select id from zp_ingredient_lots where org_id=$1 and lot_label='LOT-TEST'",[org]);
  await page.getByRole("combobox",{name:"Lot source",exact:true}).selectOption(sourceLot);
  await page.getByRole("combobox",{name:"Établissement destinataire",exact:true}).selectOption(destination);
  await page.getByRole("combobox",{name:"Matière correspondante",exact:true}).selectOption(destinationIngredient.body.data);
  await page.getByLabel("Quantité à transférer").fill("1");await page.getByRole("button",{name:"Demander le transfert"}).click();
  await page.getByRole("button",{name:"Approuver",exact:true}).click();await page.getByRole("button",{name:"Confirmer le départ"}).click();
  await page.getByText(/1 · in_transit/).waitFor();
  assert.equal(Number(await scalar("select remaining_milli from zp_ingredient_lots where id=$1",[sourceLot])),2000);
  await page.getByRole("combobox",{name:"Établissement autorisé",exact:true}).selectOption(destination);
  await page.getByRole("heading",{name:"Nouvelle commande"}).waitFor();await page.getByRole("button",{name:"Stocks & finances"}).click();await page.getByRole("button",{name:"Transferts",exact:true}).click();
  await page.getByRole("button",{name:"Confirmer la réception"}).click();await page.getByText(/1 · received/).waitFor();
  assert.equal(Number(await scalar("select remaining_milli from zp_ingredient_lots where ingredient_id=$1",[destinationIngredient.body.data])),1000);
  console.log("ZIPPLE_N5_REAL_EDGE_TRANSFER_UI_PASS");
  await page.getByRole("combobox",{name:"Établissement autorisé",exact:true}).selectOption(site);await page.getByRole("heading",{name:"Nouvelle commande"}).waitFor();
  await page.getByRole("button",{name:"Pilotage",exact:true}).click();await page.getByRole("heading",{name:"Pilotage et recommandations"}).waitFor();
  await page.getByText(/Historique insuffisant : 28 jours/).waitFor();
  await page.getByText(/Charges enregistrées : 2[\s\u00a0\u202f]500 FCFA/).waitFor();
  console.log("ZIPPLE_N7_REAL_EDGE_PILOTAGE_UI_PASS");
  await page.getByRole("button",{name:"Salles et réservations"}).click();
  await page.getByLabel("Nom de la zone").fill("Terrasse test");await page.getByRole("button",{name:"Créer la zone"}).click();
  await page.getByRole("combobox",{name:"Table à configurer"}).selectOption(tableId);
  await page.getByRole("combobox",{name:"Zone de la table"}).selectOption({label:"Terrasse test"});await page.getByLabel("Nombre de places").fill("6");await page.getByRole("button",{name:"Enregistrer la table"}).click();
  await page.getByRole("button",{name:"Afficher l’addition"}).click();await page.getByText(/Total : 2500 FCFA/).waitFor();
  assert.equal(await scalar("select seats from zp_tables where id=$1",[tableId]),6);
  console.log("ZIPPLE_BULK2_REAL_EDGE_FLOOR_BILL_FEEDBACK_PASS");
  // Verify the new boundary through actual GoTrue / PostgREST / Edge, not a mocked RPC.
  const tableSession=await scalar("select id from zp_table_sessions where table_id=$1 and closed_at is null",[tableId]);
  assert.equal((await b("snapshot",{site_id:id()})).status,403);
  assert.equal((await b("snapshot",{}, "a".repeat(64))).status,403);
  const invalidGuest=await b("guest_open",{qr:"b".repeat(64)},"",true);assert.equal(invalidGuest.status,429);
  const countBefore=Number(await scalar("select count(*) from zp_guest_sessions where table_session_id=$1",[tableSession]));
  await db.query("update zp_rate_windows set attempts=60,window_start=now() where bucket=$1",["ZIPPLE:guest-open:"+tableSession]);
  const blockedGuest=await b("guest_open",{qr},"",true);assert.equal(blockedGuest.status,429);
  assert.equal(Number(await scalar("select count(*) from zp_guest_sessions where table_session_id=$1",[tableSession])),countBefore);
  await db.query("update zp_rate_windows set window_start=now()-interval '6 minutes' where bucket=$1",["ZIPPLE:guest-open:"+tableSession]);
  const reopened=await b("guest_open",{qr},"",true);assert.equal(reopened.status,200);
  const openedToken=reopened.body.guest_token;assert.equal((await b("guest_order_read",{order_id:orderId},openedToken,true)).status,403);
  await db.query("update zp_subscription_periods set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where org_id=$1",[org]);
  assert.equal((await b("guest_menu",{},openedToken,true)).status,403);
  assert.equal((await b("snapshot")).status,403);
  assert.equal((await b("guest_open",{qr},"",true)).status,429);
  console.log("ZIPPLE_BULK1_REAL_EDGE_ACCESS_RATE_AND_EXPIRY_PASS");
  await staff.close();await guestCtx.close();
  console.log("ZIPPLE_BUSINESS_REAL_EDGE_PROFESSIONAL_AND_GUEST_BROWSER_PASS");
 }finally{if(browser)await browser.close();if(server)await new Promise(ok=>server.close(ok));await db.end()}
});
