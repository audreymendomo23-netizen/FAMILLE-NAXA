import {test,expect} from '@playwright/test';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
const browserEndpoint='https://grillad-local-ci.supabase.co/functions/v1/grillad',local='http://127.0.0.1:4182/functions/v1/grillad';
const key=process.env.GRILLAD_LOCAL_ANON!;
const accounts=JSON.parse(readFileSync(process.env.RUNNER_TEMP+'/grillad-real-accounts.json','utf8'));
const org='d2000000-0000-0000-0000-000000000001',site='d3000000-0000-0000-0000-000000000001',other='d3000000-0000-0000-0000-000000000002';
const day=new Date(Date.now()+3600000).toISOString().slice(0,10);
test('real local Auth + Chromium + handler + PostgREST: sale, replay, persistence, roles and logout',async({browser})=>{
 const contexts=[];const sessions=[];
 try{
  for(const role of ['owner','seller']){
   const ctx=await browser.newContext({serviceWorkers:'block'});contexts.push(ctx);
   // Transport only: every browser HTTP call is forwarded to the actual local gateway.
   // No canned responses; no hosted endpoint contacted.
   await ctx.route(browserEndpoint,async route=>{
    const response=await route.fetch({url:local,maxRedirects:0});
    await route.fulfill({response});
   });
   const page=await ctx.newPage();await page.goto('/');
   await page.getByLabel('Téléphone (+237…)').fill(accounts[role].phone);
   await page.getByLabel('Mot de passe',{exact:true}).fill(accounts[role].password);
   const waiting=page.waitForResponse(r=>r.url()===browserEndpoint&&r.request().method()==='POST'&&r.request().postDataJSON()?.action==='login');
   await page.getByRole('button',{name:'Se connecter'}).click();
   const response=await waiting;expect(response.status(),'real GoTrue login '+role).toBe(200);
   const s=(await response.json()).result;
   expect(s.user_id===accounts[role].id,'actual local identity').toBe(true);
   expect(s.sites.some(x=>x.org===org&&x.site===site&&x.role===role)).toBe(true);
   await expect(page.getByRole('button',{name:'Déconnexion'})).toBeVisible();
   sessions.push({ctx,page,s});
  }
  const [owner,seller]=sessions;
  async function rpc(user,body,status=200){
   const r=await user.ctx.request.post(local,{headers:{apikey:key,Authorization:'Bearer '+user.s.access},data:body,maxRedirects:0});
   expect(r.status(),String(body.action)+' '+String(body.operation||'')).toBe(status);return (await r.json()).result;
  }
  async function mutate(user,operation,payload,event=randomUUID(),status=200){return rpc(user,{action:'mutate',org,site,event,operation,payload},status)}
  const item=randomUUID();
  await mutate(owner,'add_item',{name:'Poulet recette réelle',family:'Poulet',price:1000,cost:400},item);
  await mutate(owner,'prepare',{item,qty:5});await mutate(owner,'open_cash',{opening:0});
  await rpc(seller,{action:'snapshot',org,site:other,from:day,to:day},403);
  await mutate(seller,'change_price',{item,price:1200,reason:'interdit'},randomUUID(),403);
  // Reconnect in the same browser installation to reload actual persisted catalogue.
  await rpc(seller,{action:'logout'});
  await seller.page.reload();
  await seller.page.getByLabel('Téléphone (+237…)').fill(accounts.seller.phone);
  await seller.page.getByLabel('Mot de passe',{exact:true}).fill(accounts.seller.password);
  const login2=seller.page.waitForResponse(r=>r.url()===browserEndpoint&&r.request().method()==='POST'&&r.request().postDataJSON()?.action==='login');
  await seller.page.getByRole('button',{name:'Se connecter'}).click();
  const loginResponse=await login2;expect(loginResponse.status()).toBe(200);seller.s=(await loginResponse.json()).result;
  await seller.page.getByRole('button',{name:'Nouvelle vente'}).click();
  await seller.page.getByLabel('Article',{exact:true}).selectOption(item);
  await seller.page.getByLabel('Quantité',{exact:true}).fill('2');
  await seller.page.getByLabel('Montant net déclaré (FCFA)').fill('2000');
  const sold=seller.page.waitForResponse(r=>r.url()===browserEndpoint&&r.request().method()==='POST'&&r.request().postDataJSON()?.operation==='sell');
  await seller.page.getByRole('button',{name:'Enregistrer la vente'}).click();
  const soldResponse=await sold;expect(soldResponse.status()).toBe(200);
  const first=(await soldResponse.json()).result,event=first.id,payload={item,qty:2,price:1000,received:2000};
  await expect(seller.page.getByText('Opération confirmée par le serveur')).toBeVisible();
  expect(first.total).toBe(2000);expect(await mutate(seller,'sell',payload,event)).toEqual(first);
  await mutate(seller,'sell',{item,qty:4,price:1000,received:4000},randomUUID(),400);
  const snap=await rpc(owner,{action:'snapshot',org,site,from:day,to:day});
  expect(snap.finance.ca).toBe(2000);expect(snap.finance.encaissements).toBe(2000);expect(snap.items.find(x=>x.id===item).remaining).toBe(3);
  const localSeller=await rpc(seller,{action:'snapshot',org,site,from:day,to:day});
  expect(localSeller.finance).toBeNull();
  const receipt=await rpc(seller,{action:'receipt',org,site,sale:event});expect(receipt.total).toBe(2000);
  // Catalogue families, invalid family and atomic rejection, different payment declarations.
  for(const family of ['Porc','Poisson','Brochettes','Omelettes']){
   const id=randomUUID();await mutate(owner,'add_item',{name:family+' recette',family,price:500,cost:200},id);
   await mutate(owner,'prepare',{item:id,qty:2});
  }
  await mutate(owner,'add_item',{name:'Famille interdite',family:'Pizza',price:500},randomUUID(),400);
  await mutate(owner,'adjust_stock',{item,delta:-4,reason:'Stock insuffisant'},randomUUID(),400);
  await mutate(seller,'adjust_stock',{item,delta:1,reason:'Interdit'},randomUUID(),403);
  await mutate(owner,'expense',{label:'Bois',value:200,category:'Combustible'});
  const ex=randomUUID();await mutate(owner,'expense',{label:'Erreur',value:100},ex);
  const cancel=randomUUID();const reversed=await mutate(owner,'cancel_expense',{expense:ex,reason:'Saisie erronée'},cancel);
  expect(await mutate(owner,'cancel_expense',{expense:ex,reason:'Saisie erronée'},cancel)).toEqual(reversed);
  await mutate(owner,'cancel_expense',{expense:ex,reason:'Doublon'},randomUUID(),400);
  await mutate(owner,'target',{day,amount:5000});
  const mobile=randomUUID();await mutate(seller,'sell',{item,qty:1,price:1000,received:1000,method:'mtn_momo'},mobile);
  await mutate(owner,'reconcile_mobile',{receipt:mobile,source:'direct',amount:1000,reference:'LOCAL-ONLY-REF'});
  await mutate(seller,'sell',{item,qty:1,price:1000,received:1000,method:'orange_money'});
  const end=await rpc(owner,{action:'snapshot',org,site,from:day,to:day});
  expect(end.finance.ca).toBe(4000);expect(end.finance.encaissements).toBe(2000);
  expect(end.finance.mtn_declared).toBe(1000);expect(end.finance.orange_declared).toBe(1000);
  expect(end.items.find(x=>x.id===item).remaining).toBe(1);
  expect(end.finance.charges).toBe(200);
  await rpc(owner,{action:'logout'});
  const denied=await owner.ctx.request.post(local,{headers:{apikey:key,Authorization:'Bearer '+owner.s.access},data:{action:'snapshot',org,site,from:day,to:day},maxRedirects:0});expect([401,403]).toContain(denied.status());
  await rpc(seller,{action:'logout'});
 }finally{for(const c of contexts)await c.close();}
});
