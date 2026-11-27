import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {randomUUID} from "node:crypto";import {chromium} from "playwright";import {createServer} from "node:https";import {readFile,mkdir} from "node:fs/promises";import {resolve,extname,sep} from "node:path";
const base=process.env.API_URL,dbUrl=process.env.DB_URL,service=process.env.SERVICE_ROLE_KEY;
assert.ok(/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(base));assert.ok(["127.0.0.1","localhost"].includes(new URL(dbUrl).hostname));
const db=new pg.Pool({connectionString:dbUrl}),origin="https://zipple.test",publicOrigin="https://127.0.0.1:4443",configured="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-business";
const id=()=>randomUUID();
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0]??{})[0];
async function call(fn,action,body,token,guest=false){const res=await fetch(base+"/functions/v1/"+fn+"/"+action,{method:"POST",headers:{origin,"Content-Type":"application/json",...(token?{authorization:(guest?"Guest ":"Bearer ")+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})});return {status:res.status,body:await res.json()}}
test("ZIPPLE professional workspace pages on real GoTrue, Edge, PostgreSQL and browser",async()=>{
 let server,browser;
 try{
  const org=id(),member=id(),site=id(),destination=id(),login="zipple-portal-fixture",email=id()+"@example.test",password="Fixture-"+id()+"-Aa9!";
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

  const evidenceDir=resolve(process.env.RUNNER_TEMP??".","zipple-workspace-evidence");await mkdir(evidenceDir,{recursive:true});
  const shot=async name=>page.screenshot({path:resolve(evidenceDir,name+".png"),fullPage:true});
  // Exercise each new workspace through actual browser, authenticated Edge and SQL.
  const openPortal=async(name,id)=>{await page.getByRole("button",{name,exact:true}).click();const root=page.getByTestId("portal-"+id);await root.waitFor();return root};
  const profilePage=await openPortal("Profil","profile");await profilePage.getByLabel("Nom affiché",{exact:true}).fill("Profil recette ZIPPLE");await profilePage.getByLabel("Téléphone professionnel",{exact:true}).fill("699123456");
  await profilePage.getByRole("button",{name:"Enregistrer le profil",exact:true}).click();await profilePage.getByText("Opération enregistrée",{exact:true}).waitFor();assert.equal(await scalar("select display_name from zp_profile_details where member_id=$1",[member]),"Profil recette ZIPPLE");
  await shot("01-profile");const teamPage=await openPortal("Équipe","team");await teamPage.getByLabel("Employé",{exact:true}).selectOption(member);await teamPage.getByLabel("Poste occupé",{exact:true}).fill("Responsable recette");await teamPage.getByLabel("Compétences",{exact:true}).fill("Service");
  await teamPage.getByRole("button",{name:"Enregistrer le dossier",exact:true}).click();await teamPage.getByText("Opération enregistrée",{exact:true}).waitFor();
  assert.equal(await scalar("select job_title from zp_team_details where site_id=$1 and member_id=$2",[site,member]),"Responsable recette");
  await shot("02-team");const ticketPage=await openPortal("Support professionnel","tickets");await ticketPage.getByLabel("Intitulé",{exact:true}).fill("Ticket navigateur");await ticketPage.getByLabel("Description",{exact:true}).fill("Demande interne");await ticketPage.getByLabel("Catégorie",{exact:true}).selectOption("technical");
  await ticketPage.getByRole("button",{name:"Créer",exact:true}).click();await ticketPage.getByText("Ticket navigateur · Ouvert",{exact:true}).waitFor();
  await ticketPage.getByRole("button",{name:"Ouvrir le dossier",exact:true}).click();await ticketPage.getByLabel("Message ou observation",{exact:true}).fill("Réponse navigateur");
  await ticketPage.getByRole("button",{name:"Envoyer",exact:true}).click();await ticketPage.getByText(/Réponse navigateur/).waitFor();await ticketPage.getByRole("button",{name:"En cours",exact:true}).click();await ticketPage.getByText("Ticket navigateur · En cours",{exact:true}).waitFor();
  await ticketPage.getByRole("button",{name:"Terminé",exact:true}).click();await ticketPage.getByText("Ticket navigateur · Terminé",{exact:true}).waitFor();
  await shot("03-support");const inboxPage=await openPortal("Notifications","notifications");const ticketNotice=inboxPage.locator(".business-panel").filter({hasText:"Ticket navigateur"}).first();await ticketNotice.waitFor();await ticketNotice.getByRole("button",{name:"Marquer comme lu",exact:true}).click();await ticketNotice.getByText(/^Lu ·/).waitFor();await ticketNotice.getByRole("button",{name:"Ouvrir l’espace concerné",exact:true}).click();await page.getByTestId("portal-tickets").waitFor();await openPortal("Notifications","notifications");
  await shot("04-notifications");for(const [tab,pid,title] of [["Plannings","planning","Service de recette"],["Objectifs","objectives","Objectif de recette"],["Formation","training","Formation de recette"],["Feedback interne","incidents","Incident de recette"]]){
   const root=await openPortal(tab,pid);await root.getByLabel("Intitulé",{exact:true}).fill(title);await root.getByLabel("Description",{exact:true}).fill("Suivi réel navigateur");
   if(pid==="incidents")await root.getByLabel("Catégorie",{exact:true}).selectOption("service");else await root.getByLabel("Thème",{exact:true}).fill("Service");
   await root.getByLabel("Employé affecté",{exact:true}).selectOption(member);
   if(pid==="planning")await root.getByLabel("Début (heure Douala)",{exact:true}).fill("2027-01-01T08:00");
   await root.getByLabel("Échéance (heure Douala)",{exact:true}).fill("2027-01-01T12:00");await root.getByRole("button",{name:"Créer",exact:true}).click();await root.getByText(title+" · Ouvert",{exact:true}).waitFor();await shot("workspace-"+pid);
  }
  const hrPage=await openPortal("Absences et rémunérations","hr");
  await hrPage.getByLabel("Début",{exact:true}).fill("2027-02-01");await hrPage.getByLabel("Fin",{exact:true}).fill("2027-02-02");await hrPage.getByLabel("Motif professionnel",{exact:true}).fill("Demande congé navigateur");
  await hrPage.getByRole("button",{name:"Soumettre la demande",exact:true}).click();await hrPage.getByText(/Absence · Profil recette ZIPPLE · À valider/).waitFor();
  await hrPage.getByLabel("Motif de décision",{exact:true}).fill("Planning vérifié navigateur");await hrPage.getByRole("button",{name:"Approuvé",exact:true}).click();await hrPage.getByText(/Absence · Profil recette ZIPPLE · Approuvé/).waitFor();
  await hrPage.getByLabel("Type de demande",{exact:true}).selectOption("bonus");await hrPage.getByLabel("Montant FCFA",{exact:true}).fill("5000");await hrPage.getByLabel("Motif professionnel",{exact:true}).fill("Prime recette navigateur");await hrPage.getByRole("button",{name:"Soumettre la demande",exact:true}).click();
  const bonus=hrPage.locator(".business-panel").filter({hasText:"Prime · Profil recette ZIPPLE · À valider"});await bonus.getByLabel("Motif de décision",{exact:true}).fill("Montant vérifié navigateur");await bonus.getByRole("button",{name:"Approuvé",exact:true}).click();await hrPage.getByText(/Prime · Profil recette ZIPPLE · Approuvé/).waitFor();
  await hrPage.getByLabel("Filtrer par type",{exact:true}).selectOption("bonus");assert.equal(await hrPage.locator(".business-panel").count(),1);await hrPage.getByText(/Montants approuvés dans cette sélection.*5000 FCFA/).waitFor();await hrPage.getByLabel("Filtrer par statut",{exact:true}).selectOption("pending");await hrPage.getByText("Aucune demande correspondante.").waitFor();await hrPage.getByRole("button",{name:"Réinitialiser les filtres"}).click();assert.equal(await hrPage.locator(".business-panel").count(),2);
  console.log("ZIPPLE_QA_CASE_PARTIAL B5-005 HR_HISTORY_FILTERS_PASS");console.log("ZIPPLE_QA_CASE_PARTIAL B5-007 APPROVED_AMOUNT_SUMMARY_PASS");await shot("13-hr");
  console.log("ZIPPLE_REAL_BROWSER_HR_APPROVAL_PASS");
  const intelligencePage=await openPortal("ZIPPLE Intelligence","intelligence");await intelligencePage.getByRole("heading",{name:"Pilotage et recommandations",exact:true}).waitFor();await intelligencePage.getByText("Ventes enregistrées",{exact:true}).waitFor();
  console.log("ZIPPLE_BULK45_REAL_BROWSER_NINE_WORKSPACES_PASS");await shot("09-intelligence");
  const openCommerce=async(name,pid)=>{await page.getByRole("button",{name,exact:true}).click();const root=page.getByTestId("commerce-"+pid);await root.waitFor();return root};
  const sponsor=(await b("customer_add",{name:"Parrain navigateur",phone:""})).body.data,customer=(await b("customer_add",{name:"Filleul navigateur",phone:""})).body.data;
  const loyalty=await openCommerce("Fidélité et parrainage","loyalty");
  for(const [label,value] of [["Tranche FCFA","100"],["Points par tranche","1"],["Bonus du parrain","10"],["Bonus du filleul","5"],["Référence de validation","Barème synthétique navigateur"]])await loyalty.getByLabel(label,{exact:true}).fill(value);
  await loyalty.getByLabel("Activer le barème",{exact:true}).selectOption("yes");await loyalty.getByRole("button",{name:"Valider le barème",exact:true}).click();await loyalty.getByText("Opération enregistrée",{exact:true}).waitFor();
  await loyalty.getByLabel("Client",{exact:true}).selectOption(sponsor);await loyalty.getByRole("button",{name:"Générer le code personnel",exact:true}).click();
  await loyalty.getByRole("img",{name:"QR de parrainage",exact:true}).waitFor();const code=await scalar("select id from zp_loyalty_codes where customer_id=$1 and revoked_at is null",[sponsor]);
  await loyalty.getByLabel("Client",{exact:true}).selectOption(customer);await loyalty.getByLabel("Code du parrain",{exact:true}).fill(code);await loyalty.getByRole("button",{name:"Rattacher le parrain",exact:true}).click();await loyalty.getByText(/Parrain navigateur → Filleul navigateur · En attente/).waitFor();
  await loyalty.getByRole("button",{name:"Générer la carte de fidélité",exact:true}).click();await loyalty.getByRole("img",{name:"QR de carte de fidélité",exact:true}).waitFor();const card=await scalar("select id from zp_loyalty_cards where customer_id=$1 and revoked_at is null",[customer]);
  const guestCtx=await context(),guest=await guestCtx.newPage();await guest.goto(publicOrigin+"/#table="+qr);const openedGuest=guest.waitForResponse(r=>r.url().endsWith("/guest_open")&&r.status()===200);await guest.getByRole("button",{name:"Voir la carte",exact:true}).click();const guestToken=(await (await openedGuest).json()).guest_token;assert.ok(guestToken);await guest.getByLabel(/Plat recette/).fill("1");await guest.getByRole("button",{name:"Confirmer ma commande",exact:true}).click();await guest.getByRole("heading",{name:"Commande confirmée",exact:true}).waitFor();
  await guest.getByText("Fidélité (facultatif)",{exact:true}).click();await guest.getByLabel("Code de carte de fidélité",{exact:true}).fill(card);await guest.getByLabel("Code du parrain (facultatif)",{exact:true}).fill(code);await guest.getByLabel("J’autorise le rattachement de cette commande à ma fiche de fidélité.",{exact:true}).check();await guest.getByRole("button",{name:"Rattacher ma commande",exact:true}).click();await guest.getByText("Commande rattachée à votre carte.",{exact:true}).waitFor();
  assert.equal(Number(await scalar("select count(*) from zp_customer_order_links where customer_id=$1 and guest_id is not null",[customer])),1);await guest.screenshot({path:resolve(evidenceDir,"14-guest-loyalty.png"),fullPage:true});
  const linkedOrder=await scalar("select order_id from zp_customer_order_links where customer_id=$1 and guest_id is not null",[customer]);
  assert.equal((await b("guest_receipt",{order_id:linkedOrder},guestToken,true)).body.data.available,false);
  assert.equal(await guest.getByRole("button",{name:"Télécharger mon reçu PDF",exact:true}).count(),0);
  for(const next of ["preparing","ready","served"])assert.equal((await b("line_advance",{order_id:linkedOrder,item_id:item.body.data,next})).status,200);
  const cash=(await b("cash_open",{opening_xaf:0})).body.data;
  const receipt=(await b("cash_record",{cash_id:cash,order_id:linkedOrder,request_id:id(),method:"cash",amount_xaf:2500})).body.data;assert.ok(receipt);
  const receiptButton=guest.getByRole("button",{name:"Télécharger mon reçu PDF",exact:true});await receiptButton.waitFor();
  const receiptData=await b("guest_receipt",{order_id:linkedOrder},guestToken,true);assert.equal(receiptData.status,200);assert.equal(receiptData.body.data.receipt_id,receipt);assert.equal(receiptData.body.data.paid_xaf,2500);
  const downloadPromise=guest.waitForEvent("download");await receiptButton.click();const downloaded=await downloadPromise;assert.equal(downloaded.suggestedFilename(),"zipple-recu-"+receipt+".pdf");const pdfBytes=await readFile(await downloaded.path());assert.equal(pdfBytes.subarray(0,5).toString(),"%PDF-");assert.ok(pdfBytes.includes(Buffer.from("2500 FCFA")));await downloaded.saveAs(resolve(evidenceDir,"15-receipt.pdf"));
  const otherGuest=await b("guest_open",{qr},"",true);assert.equal(otherGuest.status,200);assert.equal((await b("guest_receipt",{order_id:linkedOrder},otherGuest.body.guest_token,true)).status,403);
  assert.equal((await b("guest_receipt",{order_id:linkedOrder},"",true)).status,401);
  console.log("ZIPPLE_GUEST_PAID_PDF_RECEIPT_PASS");
  await loyalty.getByRole("button",{name:"Actualiser",exact:true}).click();await loyalty.getByLabel("Reçu réglé à qualifier",{exact:true}).selectOption(receipt);await loyalty.getByRole("button",{name:"Attribuer les points vérifiés",exact:true}).click();await loyalty.getByText(/Filleul navigateur · 30 points disponibles/).waitFor();
  await loyalty.getByLabel("Nom de l’avantage",{exact:true}).fill("Service de fidélité");await loyalty.getByLabel("Points requis",{exact:true}).fill("5");await loyalty.getByLabel("Motif de validation",{exact:true}).fill("Avantage non financier testé");await loyalty.getByRole("button",{name:"Enregistrer l’avantage",exact:true}).click();
  // A click starts an asynchronous Edge mutation; wait for the refreshed snapshot before reading SQL.
  const benefitSelect=loyalty.getByLabel("Avantage à remettre",{exact:true});
  const benefitOption=benefitSelect.locator("option").filter({hasText:/^Service de fidélité · 5 pts$/});
  await benefitOption.waitFor({state:"attached"});
  const benefit=await scalar("select id from zp_loyalty_benefits where org_id=$1 and site_id=$2 and label=$3 and points=5 and enabled",[org,site,"Service de fidélité"]);
  assert.ok(typeof benefit==="string"&&benefit.length===36,"persisted active benefit");
  assert.equal(await benefitOption.getAttribute("value"),benefit,"refreshed UI must expose the persisted benefit");
  await benefitSelect.selectOption(benefit);
  const later=(await b("order_create",{channel:"counter",request_id:id(),lines:[{item_id:item.body.data,qty:1}]})).body.data;assert.ok(later.id);assert.equal((await b("customer_attach",{customer_id:customer,order_id:later.id})).status,200);for(const next of ["preparing","ready","served"])assert.equal((await b("line_advance",{order_id:later.id,item_id:item.body.data,next})).status,200);
  const laterReceipt=(await b("cash_record",{cash_id:cash,order_id:later.id,request_id:id(),method:"cash",amount_xaf:2500})).body.data;assert.ok(laterReceipt);
  await loyalty.getByRole("button",{name:"Actualiser",exact:true}).click();await loyalty.getByLabel("Commande ultérieure réglée",{exact:true}).selectOption(laterReceipt);await loyalty.getByLabel("Preuve de remise de l’avantage",{exact:true}).fill("Avantage remis et vérifié");await loyalty.getByRole("button",{name:"Confirmer la remise et utiliser les points",exact:true}).click();await loyalty.getByText(/Filleul navigateur · 25 points disponibles/).waitFor();
  assert.equal(Number(await scalar("select count(*) from zp_loyalty_redemptions where receipt_id=$1 and benefit_id=$2 and customer_id=$3 and points=5",[laterReceipt,benefit,customer])),1);await shot("10-loyalty");const activeSession=await scalar("select id from zp_table_sessions where table_id=$1 and closed_at is null",[tableId]);assert.equal((await b("table_close",{table_session_id:activeSession})).status,200);assert.equal((await b("guest_order_read",{order_id:linkedOrder},guestToken,true)).status,403);assert.equal((await b("guest_receipt",{order_id:linkedOrder},guestToken,true)).body.data.receipt_id,receipt);await db.query("update zp_guest_sessions set expires_at=now()-interval '1 second' where token_hash=encode(digest($1,'sha256'),'hex')",[guestToken]);assert.equal((await b("guest_receipt",{order_id:linkedOrder},guestToken,true)).status,403);console.log("ZIPPLE_RECEIPT_SCOPE_CLOSED_TABLE_EXPIRY_PASS");await guestCtx.close();console.log("ZIPPLE_REAL_BROWSER_GUEST_CARD_AND_REDEMPTION_PASS");
  // Fresh public table and independent guest sessions for mixed and split tender receipts.
  const paymentTable=(await b("table_create",{label:"Table reçus multi-moyens"})).body.data;
  assert.ok(paymentTable.id&&paymentTable.qr);assert.equal((await b("table_open",{table_id:paymentTable.id})).status,200);
  const paymentItem=(await b("menu_add",{name:"Plat paiement multiple",post:"kitchen",price_xaf:1000,qty:2})).body.data;
  assert.ok(paymentItem);
  async function paymentGuest(){
   const ctx=await context(),g=await ctx.newPage();await g.goto(publicOrigin+"/#table="+paymentTable.qr);
   const opened=g.waitForResponse(r=>r.url().endsWith("/guest_open")&&r.status()===200);
   await g.getByRole("button",{name:"Voir la carte",exact:true}).click();const token=(await (await opened).json()).guest_token;
   await g.getByLabel(/Plat paiement multiple/).fill("1");
   const created=g.waitForResponse(r=>r.url().endsWith("/guest_order_create")&&r.status()===200);
   await g.getByRole("button",{name:"Confirmer ma commande",exact:true}).click();const order=(await (await created).json()).data.id;
   await g.getByRole("heading",{name:"Commande confirmée",exact:true}).waitFor();
   for(const next of ["preparing","ready","served"])assert.equal((await b("line_advance",{order_id:order,item_id:paymentItem,next})).status,200);
   const read=()=>b("guest_receipt",{order_id:order},token,true);
   const button=g.getByRole("button",{name:"Télécharger mon reçu PDF",exact:true});
   assert.equal((await read()).body.data.available,false);assert.equal(await button.count(),0);
   return {ctx,g,order,read,button};
  }
  async function verifyPaymentPdf(g,amounts,filename){
   const data=(await g.read()).body.data;assert.equal(data.available,true);assert.equal(data.paid_xaf,1000);
   assert.deepEqual(Object.fromEntries(data.methods.map(m=>[m.method,Number(m.amount_xaf)])),amounts);
   assert.ok(data.methods.every(m=>!("reference" in m)&&!("member_id" in m)));
   await g.button.waitFor();const pending=g.g.waitForEvent("download");await g.button.click();const dl=await pending;
   assert.equal(dl.suggestedFilename(),"zipple-recu-"+data.receipt_id+".pdf");
   const bytes=await readFile(await dl.path());assert.equal(bytes.subarray(0,5).toString(),"%PDF-");
   for(const amount of Object.values(amounts))assert.ok(bytes.includes(Buffer.from(amount+" FCFA")));
   await dl.saveAs(resolve(evidenceDir,filename));await g.ctx.close();
  }
  const mixedGuest=await paymentGuest();
  const mixedPayment=await b("cash_record_mixed",{cash_id:cash,order_id:mixedGuest.order,request_id:id(),tenders:[{method:"cash",amount_xaf:400,reference:null},{method:"mtn_momo",amount_xaf:600,reference:"GUEST-MIX-"+id()}]});
  assert.equal(mixedPayment.status,200);await verifyPaymentPdf(mixedGuest,{cash:400,mtn_momo:600},"16-receipt-mixed.pdf");
  const splitGuest=await paymentGuest();
  const part=(payer,amount,method,reference)=>b("split_collect",{cash_id:cash,order_id:splitGuest.order,request_id:id(),payer,amount_xaf:amount,method,reference,allocations:[]});
  const firstPart=await part("Personne A",300,"cash",null);assert.equal(firstPart.status,200);assert.equal(firstPart.body.data.balance_xaf,700);
  assert.equal((await splitGuest.read()).body.data.available,false);
  await splitGuest.g.getByText(/Solde restant/).waitFor();assert.equal(await splitGuest.button.count(),0);
  const finalPart=await part("Personne B",700,"orange_money","GUEST-SPLIT-"+id());assert.equal(finalPart.status,200);assert.equal(finalPart.body.data.balance_xaf,0);
  await verifyPaymentPdf(splitGuest,{cash:300,orange_money:700},"17-receipt-split.pdf");
  console.log("ZIPPLE_GUEST_MIXED_AND_SPLIT_RECEIPTS_PASS");
  const delivery=await openCommerce("Livraison Restaurant","delivery");await delivery.getByLabel("Nom de zone",{exact:true}).fill("Zone navigateur");await delivery.getByLabel("Périmètre et consignes",{exact:true}).fill("Secteur de recette");await delivery.getByLabel("Frais FCFA",{exact:true}).fill("500");await delivery.getByRole("button",{name:"Enregistrer la zone",exact:true}).click();await delivery.getByText(/Zone navigateur · 500 FCFA/).waitFor();
  await delivery.getByLabel("Livreur de l'établissement",{exact:true}).selectOption(member);await delivery.getByRole("button",{name:"Enregistrer le livreur",exact:true}).click();await delivery.getByText(/Livreur affecté : Profil recette ZIPPLE/).waitFor();
  await delivery.getByRole("button",{name:"Modifier la zone : Zone navigateur"}).click();assert.equal(await delivery.getByLabel("Frais FCFA",{exact:true}).inputValue(),"500");await delivery.getByLabel("Frais FCFA",{exact:true}).fill("750");await delivery.getByLabel("Zone active dans le projet",{exact:true}).selectOption("no");await delivery.getByRole("button",{name:"Enregistrer la zone",exact:true}).click();await delivery.getByText(/Zone navigateur · 750 FCFA.*Inactive/).waitFor();assert.equal(Number(await scalar("select count(*) from zp_delivery_zones where site_id=$1 and label='Zone navigateur' and fee_xaf=750 and not active",[site])),1);
  await delivery.getByRole("button",{name:"Retirer l’affectation : Profil recette ZIPPLE"}).click();await delivery.getByText(/Livreur affecté : Profil recette ZIPPLE/).waitFor({state:"detached"});assert.equal(await scalar("select active from zp_delivery_couriers where site_id=$1 and member_id=$2",[site,member]),false);console.log("ZIPPLE_QA_CASE_PARTIAL B4-017 ZONE_EDIT_DEACTIVATE_COURIER_PASS");
  assert.equal(await scalar("select delivery_enabled from zp_site_modes where site_id=$1",[site]),false);await shot("11-delivery");
  const connections=await openCommerce("NAXA SECURITY et partenaires","connections");await connections.getByLabel("Solution",{exact:true}).selectOption("naxa_security");await connections.getByLabel("Référence de l'établissement partenaire",{exact:true}).fill("SITE-TEST");await connections.getByLabel("Motif du raccordement",{exact:true}).fill("Demande navigateur de test");await connections.getByRole("button",{name:"Enregistrer la demande de raccordement",exact:true}).click();await connections.getByText(/SITE-TEST · Demande enregistrée — non connectée/).waitFor();await shot("12-connections");
  await connections.getByRole("button",{name:"Annuler la demande",exact:true}).click();await connections.getByText(/SITE-TEST · Annulée/).waitFor();
  console.log("ZIPPLE_BULK4_REAL_BROWSER_LOYALTY_DELIVERY_CONNECTIONS_PASS");
  const locale=await openPortal("Profil","profile");await locale.getByLabel("Langue préférée",{exact:true}).selectOption("en");await locale.getByRole("button",{name:"Enregistrer le profil",exact:true}).click();await page.getByRole("heading",{name:"ZIPPLE management",exact:true}).waitFor();
  await page.getByRole("button",{name:"Sign out",exact:true}).click();await page.getByLabel("Identifier",{exact:true}).fill(login);await page.getByLabel("Password",{exact:true}).fill(password);await page.getByRole("button",{name:"Sign in",exact:true}).click();await page.getByRole("heading",{name:"ZIPPLE management",exact:true}).waitFor();
  assert.equal(await scalar("select language from zp_profile_details where member_id=$1",[member]),"en");console.log("ZIPPLE_PROFILE_LANGUAGE_APPLIED_PASS");
  await staff.close();
 }finally{if(browser)await browser.close();if(server)await new Promise(ok=>server.close(ok));await db.end()}
});
