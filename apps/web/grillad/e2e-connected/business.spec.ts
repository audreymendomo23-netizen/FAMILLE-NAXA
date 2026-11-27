import {test,expect,type Page} from '@playwright/test';
const org='12345678-1234-1234-1234-123456789abc',site='12345678-1234-1234-1234-123456789abd',item='12345678-1234-1234-1234-123456789abe',seller='12345678-1234-1234-1234-123456789abf',owner='12345678-1234-1234-1234-123456789ac0',expense='12345678-1234-1234-1234-123456789ac1',cashId='12345678-1234-1234-1234-123456789ac2',departure='12345678-1234-1234-1234-123456789ac3',correction='12345678-1234-1234-1234-123456789ac4';
async function fixture(page:Page,role='owner',withRequest=false){
 let state={remaining:5,adjustments:[] as any[],expenseCancelled:false,centralized:false,service:null as any,corrections:withRequest?[{id:correction,departure,requester:seller,proposed_seconds:1800,reason:'Pause',status:'pending'}]:[] as any[],effective:3600};
 const user=role==='seller'?seller:owner;const operations:any[]=[];
 await page.route('https://grillad-fixture.supabase.co/functions/v1/grillad',async route=>{
  const req=route.request(),headers={'Access-Control-Allow-Origin':'http://127.0.0.1:4181','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
  if(req.method()==='OPTIONS'){await route.fulfill({status:204,headers});return}
  const b=req.postDataJSON();let result:any;
  if(b.action==='login')result={user_id:user,access:'fixture-access',refresh:'fixture-refresh',sites:[{org,site,name:'Point test',organization:'Test',role}]};
  else{
   expect(req.headers().authorization).toBe('Bearer fixture-access');expect(b.org).toBe(org);expect(b.site).toBe(site);
   if(b.action==='snapshot')result={role,items:[{id:item,name:'Poulet test',family:'Poulet',price:1000,prepared:5,adjustment_net:state.remaining-5,sold:0,remaining:state.remaining}],sales:[],finance:role==='seller'?null:{ca:0,sales_count:0,cost:0,charges:state.expenseCancelled?0:200},cash:{id:cashId,expected:state.expenseCancelled?500:300},expenses:role==='seller'?[]:[{id:expense,cash:cashId,label:'Bois',value:200,cancelled_at:state.expenseCancelled?'2026-11-27T12:00:00Z':null,cancel_reason:state.expenseCancelled?'Erreur de saisie':null}],stock_adjustments:state.adjustments,generated_at:'fixture',from:b.from,to:b.to};
   else if(b.action==='attendance_status')result={enabled:true,history:[{id:departure,actor:seller,kind:'departure',captured_at:'2026-11-27T12:00:00Z',duration_seconds:3600,effective_duration_seconds:state.effective,photo_available:false}],corrections:state.corrections};
   else if(b.action==='notice_feed')result={items:[],preferences:{}};
   else if(b.action==='daily_list')result=[];
   else if(b.action==='connect_list')result={available:false,orders:[]};
   else if(b.action==='security_list')result={available:false,cameras:[],incidents:[]};
   else if(b.action==='pilotage_status')result={network_allowed:state.centralized,service:state.service,team:[]};
   else if(b.action==='prediction')result={items:[],ca_estimate:null};
   else if(b.action==='mutate'){
    expect(b.event).toMatch(/^[0-9a-f-]{36}$/);operations.push(b);
    const p=b.payload;
    switch(b.operation){
     case 'adjust_stock':expect(p).toEqual({item,delta:-2,reason:'Perte'});state.remaining-=2;state.adjustments.push({id:b.event,delta:-2,reason:'Perte',created_at:'fixture'});break;
     case 'cancel_expense':expect(p).toEqual({expense,reason:'Erreur de saisie'});state.expenseCancelled=true;break;
     case 'set_network_mode':expect(p).toEqual({centralized:true,reason:'Pilotage'});state.centralized=true;break;
     case 'set_service_hours':expect(p.start_minute).toBe(1080);expect(p.reason).toBe('Service soir');expect(p.effective_from).toMatch(/^\d{4}-\d{2}-\d{2}$/);state.service={...p,enabled:true};break;
     case 'attendance_request':expect(p).toEqual({departure,seconds:1800,reason:'Pause'});state.corrections.push({id:b.event,departure,requester:seller,proposed_seconds:1800,reason:'Pause',status:'pending'});break;
     case 'attendance_decide':expect(p).toEqual({request:correction,decision:'approved',reason:'Vérifié'});state.corrections[0]={...state.corrections[0],status:'approved',decision_reason:'Vérifié'};state.effective=1800;break;
     default:throw Error('Unexpected operation '+b.operation)
    }
    result={id:b.event};
   }else throw Error('Unexpected action '+b.action)
  }
  await route.fulfill({status:200,headers,json:{result}});
 });
 await page.goto('/');await page.getByLabel('Téléphone (+237…)').fill('+237699000001');await page.getByLabel('Mot de passe',{exact:true}).fill('fixture-password');await page.getByRole('button',{name:'Se connecter'}).click();await expect(page.getByText('Actualisé : fixture')).toBeVisible();
 return {operations}
}
async function go(page:Page,group:string,sub:string){const nav=page.getByRole('navigation');await nav.getByRole('button',{name:group,exact:true}).click();await nav.getByRole('button',{name:sub,exact:true}).click()}
test('stock correction retains prepared count and shows signed history',async({page})=>{const {operations}=await fixture(page);await go(page,'Vente','Préparations');const form=page.getByRole('heading',{name:'Corriger les quantités'}).locator('..');await form.getByLabel('Article').selectOption(item);await form.getByLabel('Variation signée').fill('-2');await form.getByLabel('Motif de correction').fill('Perte');await form.getByRole('button',{name:'Enregistrer la correction'}).click();await expect(page.getByText(/préparé 5 · ajustements -2 · vendu 0 · restant 3/)).toBeVisible();await expect(page.getByText(/Ajustement -2 · Perte/)).toBeVisible();expect(operations).toHaveLength(1)});
test('expense reversal displays original expense and refreshed cash',async({page})=>{const {operations}=await fixture(page);await go(page,'Activité','Dépenses');await page.getByLabel('Motif d’annulation de dépense').fill('Erreur de saisie');await page.getByRole('button',{name:'Annuler la dépense'}).click();await expect(page.getByText('Annulée · Erreur de saisie')).toBeVisible();await page.getByRole('navigation').getByRole('button',{name:'Caisse',exact:true}).click();await expect(page.getByText(/500\s*F/)).toBeVisible();expect(operations).toHaveLength(1)});
test('owner changes network mode and explicitly initializes service time',async({page})=>{const {operations}=await fixture(page);await go(page,'Plus','Profil');await page.getByLabel('Mode de gestion').selectOption('centralized');await page.getByLabel('Motif du changement').fill('Pilotage');await page.getByRole('button',{name:'Confirmer le mode'}).click();await expect(page.locator('p').filter({hasText:/^Centralisé$/})).toBeVisible();await page.getByLabel('Heure de début du service').fill('18:00');await page.getByLabel('Motif de configuration').fill('Service soir');await page.getByRole('button',{name:'Configurer le service'}).click();await expect(page.getByText(/Configuré : 18 h 00/)).toBeVisible();expect(operations).toHaveLength(2)});
test('seller requests regularization and cannot approve own request',async({page})=>{const {operations}=await fixture(page,'seller');await go(page,'Plus','Équipe');await page.getByLabel('Durée corrigée en secondes').fill('1800');await page.getByLabel('Motif de régularisation').fill('Pause');await page.getByRole('button',{name:'Demander une correction'}).click();await expect(page.getByText(/1800 s · Pause · En attente/)).toBeVisible();await expect(page.getByRole('button',{name:'Confirmer la décision'})).toHaveCount(0);expect(operations).toHaveLength(1)});
test('owner approves separate request without overwriting original proof duration',async({page})=>{const {operations}=await fixture(page,'owner',true);await go(page,'Plus','Équipe');await page.getByLabel('Décision',{exact:true}).selectOption('approved');await page.getByLabel('Motif de décision').fill('Vérifié');await page.getByRole('button',{name:'Confirmer la décision'}).click();await expect(page.getByText(/1800 s · Pause · Approuvée/)).toBeVisible();await expect(page.getByText(/Durée constatée : 3600 s · retenue : 1800 s/)).toBeVisible();expect(operations).toHaveLength(1)});
