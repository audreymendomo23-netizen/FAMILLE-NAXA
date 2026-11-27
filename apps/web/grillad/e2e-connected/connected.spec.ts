import {test,expect} from '@playwright/test';
const org='12345678-1234-1234-1234-123456789abc',site='12345678-1234-1234-1234-123456789abd',item='12345678-1234-1234-1234-123456789abe';
test('connected client uses server scope and retries identical event after ambiguous response',async({page})=>{
 let sale=false,attempts:string[]=[];
 await page.route('https://grillad-fixture.supabase.co/functions/v1/grillad',async route=>{
  const req=route.request();const headers={'Access-Control-Allow-Origin':'http://127.0.0.1:4181','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
  if(req.method()==='OPTIONS'){await route.fulfill({status:204,headers});return}
  const b=req.postDataJSON();let result:any;
  if(b.action==='login'){expect(b.platform).toBe('web');result={access:'fixture-access',refresh:'fixture-refresh',sites:[{org,site,name:'Point test',organization:'Test',role:'owner'}]}}
  else {expect(req.headers()['authorization']).toBe('Bearer fixture-access');if(b.action==='snapshot'){expect(b.org).toBe(org);expect(b.site).toBe(site);result={role:'owner',items:[{id:item,name:'Poulet test',family:'Poulet',price:1000,remaining:sale?3:5}],sales:sale?[{id:'fixture-sale',item,qty:2,total:2000,cancelled:false}]:[],finance:{ca:sale?2000:0,sales_count:sale?1:0,cost:sale?800:0,charges:0},cash:{id:'cash',expected:sale?2000:0},generated_at:'test',from:b.from,to:b.to}}
  else if(b.action==='attendance_status')result={enabled:false,history:[]};else if(b.action==='notice_feed')result={items:[],preferences:{}};else if(b.action==='daily_list')result=[];else if(b.action==='connect_list')result={available:false,orders:[]};else if(b.action==='security_list')result={available:false,cameras:[],incidents:[]};else if(b.action==='pilotage_status')result={network_allowed:false,team:[]};
  else if(b.action==='mutate'){expect(b.operation).toBe('sell');expect(b.org).toBe(org);expect(b.site).toBe(site);expect(b.payload).toEqual({item,qty:2});attempts.push(b.event);if(attempts.length===1){sale=true;await route.fulfill({status:503,headers,json:{error:'SERVICE_UNAVAILABLE'}});return}expect(attempts[1]).toBe(attempts[0]);result={id:'fixture-sale',total:2000};}
  else if(b.action==='logout')result=true;else throw Error('Unexpected action '+b.action)}
  await route.fulfill({status:200,headers,json:{result}});
 });
 await page.goto('/');await page.getByLabel('Téléphone (+237…)').fill('+237699000001');await page.getByLabel('Mot de passe',{exact:true}).fill('fixture-password');await page.getByRole('button',{name:'Se connecter'}).click();await expect(page.getByText('CA net')).toBeVisible();await page.getByRole('button',{name:'Nouvelle vente'}).click();await page.getByLabel('Article').selectOption(item);await page.getByLabel('Quantité').fill('2');await page.getByRole('button',{name:'Enregistrer la vente'}).click();await expect(page.getByText(/Confirmation incertaine/)).toBeVisible();await expect(page.getByRole('button',{name:'Déconnexion'})).toBeDisabled();await page.getByRole('button',{name:'Vérifier / réessayer la même requête'}).click();await expect(page.getByText(/Poulet test × 2/)).toBeVisible();expect(attempts).toHaveLength(2);await page.getByRole('button',{name:'Déconnexion'}).click();await expect(page.getByRole('heading',{name:'Connexion'})).toBeVisible();
});
