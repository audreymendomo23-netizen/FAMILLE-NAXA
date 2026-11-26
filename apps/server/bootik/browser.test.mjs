import {test} from 'node:test';import assert from 'node:assert/strict';import {createServer} from 'node:https';import {readFileSync} from 'node:fs';import {randomUUID,randomBytes,createHash} from 'node:crypto';import pg from 'pg';import {chromium} from 'playwright';
import {createBootikService,verifier} from './service.mjs';import{captureCredit,reconcilePending}from './payment-worker.mjs';
test('Chromium real API, session, trial, persistent offline queue, payment and support', {timeout:180000},async()=>{
 const admin=new pg.Pool({connectionString:process.env.BOOTIK_TEST_ADMIN_URL});
 const db=new pg.Pool({connectionString:process.env.BOOTIK_DATABASE_URL});
 const paymentDb=new pg.Pool({connectionString:process.env.BOOTIK_TEST_PAYMENT_URL});
 const one=async(q,p=[]) => (await admin.query(q,p)).rows[0];
 const handle=createBootikService(db);
 const srv=createServer({key:readFileSync('/tmp/bootik-test-key.pem'),cert:readFileSync('/tmp/bootik-test-cert.pem')},async(req,res)=>{
  const h={'Access-Control-Allow-Origin':'http://127.0.0.1:4173','Access-Control-Allow-Headers':'Authorization, Content-Type','Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store','Content-Type':'application/json'};
  if(req.method==='OPTIONS'){res.writeHead(204,h).end();return}
  try{let raw='';for await(const c of req)raw+=c;const x=await handle(req.url.slice(1),JSON.parse(raw),String(req.headers.authorization||'').replace(/^Bearer /,''));res.writeHead(x.status,h).end(x.status===204?'':JSON.stringify(x.body))}catch{res.writeHead(400,h).end('{}')}
 });
 let browser;
 try{
 const {app_id:a}=await one('select app_id from bootik.bk_app_registration');
 const u=randomUUID(),o=randomUUID(),s=randomUUID(),other=randomUUID(),v=randomUUID(),i=randomUUID(),b=randomUUID(),identifier='browser-'+u;
 await one('insert into auth.users(id) values($1)',[u]);await one('insert into bootik.bk_organizations(organization_id,app_id,display_name) values($1,$2,$3)',[o,a,'Browser test']);
 await one('insert into bootik.bk_locations(id,organization_id,app_id,display_name) values($1,$2,$3,$4),($5,$2,$3,$6)',[s,o,a,'Site autorisé',other,'Site interdit']);
 await one('insert into bootik.bk_members values($1,$2,$3,$4,true)',[o,a,u,'manager']);await one('insert into bootik.bk_member_sites values($1,$2,$3,$4)',[o,a,u,s]);
 const salt=randomBytes(16).toString('hex');await one('insert into bootik.bk_credentials values($1,$2,$3,$4,$5,$6)',[o,a,u,identifier,salt,await verifier('browser-test-only',salt)]);
 await one('insert into bootik.bk_activities(id,app_id,organization_id,universe_code,profile_code,display_name,status) values($1,$2,$3,$4,$5,$6,$7)',[v,a,o,'retailer','boutique','Activity','active']);
 await one('insert into bootik.bk_activity_locations(app_id,organization_id,activity_id,location_id) values($1,$2,$3,$4)',[a,o,v,s]);
 await one('insert into bootik.bk_catalog_items(id,app_id,organization_id,activity_id,sku,display_name,base_unit_code) values($1,$2,$3,$4,$5,$6,$7)',[i,a,o,v,'SKU','Produit test','unit']);
 await one('insert into bootik.bk_item_units(app_id,organization_id,activity_id,item_id,unit_code,unit_role,to_base_factor) values($1,$2,$3,$4,$5,$6,1)',[a,o,v,i,'unit','base']);
 await one('insert into bootik.bk_inventory_balances(id,app_id,organization_id,activity_id,location_id,item_id,quantity_on_hand) values($1,$2,$3,$4,$5,$6,10)',[b,a,o,v,s,i]);
 await one('insert into bootik.bk_sale_prices values($1,$2,$3,$4,500)',[i,o,v,a]);
 const dest='BROWSER-TEST-MERCHANT',device=randomBytes(32).toString('hex');
 await one("insert into bootik.bk_payment_destinations(channel,reference,beneficiary,instructions) values('orange_money',$1,'Marchand test','Test uniquement')",[dest]);
 await one("insert into bootik.bk_merchant_devices(token_hash,channel,destination) values($1,'orange_money',$2)",[createHash('sha256').update(device).digest('hex'),dest]);
 await new Promise(resolve=>srv.listen(8787,'127.0.0.1',resolve));
 browser=await chromium.launch({headless:true});
 const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:390,height:844}});
 const page=await context.newPage();page.setDefaultTimeout(20000);const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:4173');
 async function login(){await page.getByLabel('Identifiant',{exact:true}).fill(identifier);await page.getByLabel('Mot de passe',{exact:true}).fill('browser-test-only');await page.getByRole('button',{name:'Se connecter',exact:true}).click();await page.getByLabel('Site actif').waitFor();assert.equal(await page.getByLabel('Site actif').locator('option').count(),1)}
 await login();await page.getByRole('button',{name:'Activer l’essai',exact:true}).click();await page.getByText(/Fin d’essai :/).waitFor();
 await page.getByRole('button',{name:'Actualiser le catalogue'}).click();await page.getByText('Catalogue actualisé',{exact:true}).waitFor();
 await page.getByLabel('Article',{exact:true}).selectOption(b);await page.getByLabel('Quantité',{exact:true}).fill('2');
 await context.setOffline(true);await page.getByRole('button',{name:'Mettre la vente en file'}).click();await page.getByText(/1 en attente ·/).waitFor();await context.setOffline(false);
 await page.reload();await login();await page.getByText(/1 en attente ·/).waitFor();
 await page.getByRole('button',{name:'Synchroniser',exact:true}).click();await page.getByText(/ — Confirmée/).waitFor();assert.equal(Number((await one('select quantity_on_hand from bootik.bk_inventory_balances where id=$1',[b])).quantity_on_hand),8);
 await page.getByLabel('Article',{exact:true}).selectOption(b);await page.getByLabel('Quantité',{exact:true}).fill('999');await page.getByRole('button',{name:'Mettre la vente en file'}).click();await page.getByText(/1 en attente ·/).waitFor();await page.getByRole('button',{name:'Synchroniser',exact:true}).click();await page.getByText(/Conflit \/ refus/).waitFor();await page.getByRole('button',{name:'Abandonner',exact:true}).click();await page.getByText(/ — Abandonnée/).waitFor();
 await page.getByLabel('Synchroniser automatiquement au retour du réseau').check();await context.setOffline(true);
 await page.getByLabel('Article',{exact:true}).selectOption(b);await page.getByLabel('Quantité',{exact:true}).fill('1');await page.getByRole('button',{name:'Mettre la vente en file'}).click();await page.getByText(/1 en attente ·/).waitFor();
 await context.setOffline(false);await page.getByText(/0 en attente ·/).waitFor();assert.equal(Number((await one('select quantity_on_hand from bootik.bk_inventory_balances where id=$1',[b])).quantity_on_hand),7);
 await page.getByLabel('Synchroniser automatiquement au retour du réseau').uncheck();
 await page.getByLabel('Canal',{exact:true}).selectOption('orange_money');await page.getByRole('button',{name:'Préparer le paiement',exact:true}).click();await page.getByText('Destination : '+dest,{exact:true}).waitFor();
 const ref='BROWSER-'+randomUUID().slice(0,8).toUpperCase(),when=new Date().toISOString();
 await page.getByLabel('SMS de débit volontairement partagé (sans PIN ni OTP)').fill('SMS de test de paiement '+ref);
 await page.getByLabel('Identifiant de transaction figurant sur le SMS').fill(ref);await page.getByLabel('Montant figurant sur le SMS').fill('4000');await page.getByLabel('Destination figurant sur le SMS').fill(dest);await page.getByLabel('Date et heure du paiement (Douala)').fill(when);
 await page.getByRole('button',{name:'Déclarer la preuve de débit'}).click();await page.getByText('État : En vérification',{exact:true}).waitFor();
 await captureCredit(paymentDb,device,{channel:'orange_money',direction:'merchant_credit',success:true,sender_origin_id:'OrangeMoney',reference:ref,amount_fcfa:4000,destination:dest,provider_at:when,evidence_sha:createHash('sha256').update('merchant test '+ref).digest('hex')});assert.equal(await reconcilePending(paymentDb),1);
 await page.getByRole('button',{name:'Vérifier le statut',exact:true}).click();await page.getByText('État : Confirmé',{exact:true}).waitFor();
 assert.equal(await page.getByRole('button',{name:'Visioconférence',exact:true}).isDisabled(),true);await page.getByLabel('Je consens à demander une session multimédia').check();await page.getByRole('button',{name:'Visioconférence',exact:true}).click();await page.getByText('Demande enregistrée, flux non démarré',{exact:true}).waitFor();await page.getByRole('button',{name:'Annuler la demande',exact:true}).click();await page.getByText('Demande annulée',{exact:true}).waitFor();
 await page.getByRole('button',{name:'Se déconnecter',exact:true}).click();await page.getByRole('button',{name:'Se connecter',exact:true}).waitFor();
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true);
 await page.setViewportSize({width:1280,height:800});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true);
 const manifest=await page.evaluate(async()=>await(await fetch('/manifest.webmanifest')).json());assert.equal(manifest.display,'standalone');assert.equal(errors.length,0,errors.join('\n'));await context.close();
 }finally{if(browser)await browser.close();if(srv.listening)await new Promise(resolve=>srv.close(resolve));await paymentDb.end();await db.end();await admin.end()}
});
