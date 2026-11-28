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
  await seller.page.reload();
  // A refresh may require login; use existing live browser session via a fresh workspace update if needed.
  // The mutation below uses the actual authenticated seller session and persistent backend.
  const event=randomUUID(),payload={item,qty:2,price:1000,received:2000};
  const first=await mutate(seller,'sell',payload,event);
  expect(first.total).toBe(2000);expect(await mutate(seller,'sell',payload,event)).toEqual(first);
  await mutate(seller,'sell',{item,qty:4,price:1000,received:4000},randomUUID(),400);
  const snap=await rpc(owner,{action:'snapshot',org,site,from:day,to:day});
  expect(snap.finance.ca).toBe(2000);expect(snap.finance.encaissements).toBe(2000);expect(snap.items.find(x=>x.id===item).remaining).toBe(3);
  const localSeller=await rpc(seller,{action:'snapshot',org,site,from:day,to:day});
  expect(localSeller.finance).toBeNull();
  const receipt=await rpc(seller,{action:'receipt',org,site,sale:event});expect(receipt.total).toBe(2000);
  await rpc(owner,{action:'logout'});await rpc(owner,{action:'snapshot',org,site,from:day,to:day},403);
  await rpc(seller,{action:'logout'});
 }finally{for(const c of contexts)await c.close();}
});
