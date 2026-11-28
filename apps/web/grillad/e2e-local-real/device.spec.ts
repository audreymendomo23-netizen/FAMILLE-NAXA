import {test,expect} from '@playwright/test';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
const target='https://grillad-local-ci.supabase.co/functions/v1/grillad',local='http://127.0.0.1:4182/functions/v1/grillad',origin='http://127.0.0.1:4181',key=process.env.GRILLAD_LOCAL_ANON!;
const accounts=JSON.parse(readFileSync(process.env.RUNNER_TEMP+'/grillad-real-accounts.json','utf8'));
const org='d2000000-0000-0000-0000-000000000001',site='d3000000-0000-0000-0000-000000000001',other='d3000000-0000-0000-0000-000000000002';
const day=new Date(Date.now()+3600000).toISOString().slice(0,10);
test('@device virtual camera/GPS, private evidence, PWA shell and network cut',async({browser,request})=>{
 const call=async(body,token?,expected=200)=>{const r=await request.post(local,{headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{})},data:body});expect(r.status(),body.action).toBe(expected);return (await r.json()).result};
 const owner=await call({action:'login',phone:accounts.owner.phone,password:accounts.owner.password,installation:randomUUID(),platform:'web'});
 const ctx=await browser.newContext({serviceWorkers:'block',permissions:['geolocation','camera'],geolocation:{latitude:4.05,longitude:9.7,accuracy:10},viewport:{width:390,height:844}});let seller,cut=false;
 try{
  const mutate=(operation,payload,event=randomUUID())=>call({action:'mutate',org,site,operation,payload,event},owner.access);
  await mutate('set_attendance_policy',{enabled:true,staff_informed:true,reason:'Recette locale virtuelle',latitude:4.05,longitude:9.7,radius_m:200,max_accuracy_m:50,max_age_seconds:120,photo_retention_days:1});
  const item=randomUUID();await mutate('add_item',{name:'Poulet hors ligne CI',family:'Poulet',price:1000,cost:400},item);await mutate('prepare',{item,qty:3});await mutate('open_cash',{opening:0});
  await ctx.route(target,async route=>{if(cut){await route.abort('internetdisconnected');return}await route.fulfill({response:await route.fetch({url:local,maxRedirects:0})})});
  const page=await ctx.newPage();await page.goto('/');
  await page.getByLabel('Téléphone (+237…)').fill(accounts.seller.phone);await page.getByLabel('Mot de passe',{exact:true}).fill(accounts.seller.password);
  let response=page.waitForResponse(r=>r.url()===target&&r.request().postDataJSON()?.action==='login');await page.getByRole('button',{name:'Se connecter'}).click();seller=(await (await response).json()).result;
  await expect(page.getByRole('button',{name:'Déconnexion'})).toBeVisible();
  await page.getByRole('button',{name:'Plus',exact:true}).click();
  await page.getByRole('button',{name:'Équipe',exact:true}).click();
  await page.getByRole('button',{name:'Ouvrir la caméra'}).click();
  await expect.poll(()=>page.locator('video').evaluate((v:HTMLVideoElement)=>v.videoWidth)).toBeGreaterThan(0);
  response=page.waitForResponse(r=>r.url()===target&&r.request().postDataJSON()?.action==='attendance_capture');await page.getByRole('button',{name:'Capturer et envoyer'}).click();expect((await response).status()).toBe(200);
  await expect(page.getByText('Opération confirmée par le serveur')).toBeVisible();
  const history=await call({action:'attendance_status',org,site},seller.access);const proof=history.history.find(x=>x.kind==='arrival');expect(proof.photo_available).toBe(true);expect(proof).not.toHaveProperty('latitude');
  expect((await call({action:'attendance_photo',org,site,id:proof.id},owner.access)).jpeg.length).toBeGreaterThan(16);
  await call({action:'attendance_photo',org,site:other,id:proof.id},seller.access,403);
  await page.getByRole('button',{name:'Vente',exact:true}).click();
  await page.getByLabel('Article du lot').selectOption(item);await page.getByLabel('Quantité du lot').fill('1');await page.getByLabel('Montant net déclaré du lot').fill('1000');await page.getByRole('button',{name:'Ajouter au lot'}).click();
  cut=true;await ctx.setOffline(true);await page.getByRole('button',{name:'Enregistrer et synchroniser le lot'}).click();await expect(page.getByText('Confirmation incertaine : ne créez pas de nouvelle opération.')).toBeVisible();
  cut=false;await ctx.setOffline(false);
  expect((await call({action:'snapshot',org,site,from:day,to:day},owner.access)).finance.ca).toBe(0);
  response=page.waitForResponse(r=>r.url()===target&&r.request().postDataJSON()?.action==='offline_batch');await page.getByRole('button',{name:'Vérifier / réessayer la même requête'}).click();expect((await response).status()).toBe(200);
  expect((await call({action:'snapshot',org,site,from:day,to:day},owner.access)).finance.ca).toBe(1000);
 }finally{await ctx.close();if(seller?.access)await call({action:'logout'},seller.access);await call({action:'logout'},owner.access)}
 const pwa=await browser.newContext();try{const page=await pwa.newPage();await page.goto(origin);await page.evaluate(()=>navigator.serviceWorker.ready);await expect.poll(()=>page.evaluate(()=>!!navigator.serviceWorker.controller)).toBe(true);const manifest=await page.evaluate(async()=>await (await fetch('/manifest.webmanifest')).json());expect(manifest.display).toBe('standalone');await pwa.setOffline(true);await page.reload();await expect(page.getByRole('heading',{name:'Connexion'})).toBeVisible()}finally{await pwa.close()}
});
