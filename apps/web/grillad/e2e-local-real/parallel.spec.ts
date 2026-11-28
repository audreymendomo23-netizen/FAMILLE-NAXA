import {run as runPushWorker} from '../../../../supabase/functions/grillad-push/worker.mjs';
import {test,expect} from '@playwright/test';
import {randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const endpoint='http://127.0.0.1:4182/functions/v1/grillad', key=process.env.GRILLAD_LOCAL_ANON!;
const accounts=JSON.parse(readFileSync(process.env.RUNNER_TEMP+'/grillad-real-accounts.json','utf8'));
const org='d2000000-0000-0000-0000-000000000001',site='d3000000-0000-0000-0000-000000000001',other='d3000000-0000-0000-0000-000000000002',day=new Date(Date.now()+3600000).toISOString().slice(0,10);
async function invoke(request,body,token?,status=200){
 const r=await request.post(endpoint,{headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{})},data:body,maxRedirects:0});
 expect(r.status(),String(body.action)+' '+String(body.operation||'')).toBe(status);
 return (await r.json()).result;
}
async function login(request,role){
 const a=accounts[role],s=await invoke(request,{action:'login',phone:a.phone,password:a.password,installation:randomUUID(),platform:'web'});
 expect(s.user_id===a.id).toBe(true);expect(s.sites.some(x=>x.site===site&&x.role===role)).toBe(true);return s.access;
}
function scoped(request,token){return (body,status=200)=>invoke(request,{org,site,...body},token,status)}
function mutation(call){return (operation,payload,event=randomUUID(),status=200)=>call({action:'mutate',event,operation,payload},status)}
async function close(request,token){if(token)await invoke(request,{action:'logout'},token)}
test('@identity separate identities, wrong credentials, anonymous denial, role scope and logout',async({request})=>{
 await invoke(request,{action:'snapshot',org,site,from:day,to:day},undefined,401);
 await invoke(request,{action:'login',phone:accounts.owner.phone,password:'not-the-password',installation:randomUUID(),platform:'web'},undefined,401);
 const owner=await login(request,'owner'),seller=await login(request,'seller');
 try{
  const a=await invoke(request,{action:'workspace'},owner),b=await invoke(request,{action:'workspace'},seller);
  expect(a.some(x=>x.site===other)).toBe(true);expect(b.some(x=>x.site===other)).toBe(false);
  await scoped(request,seller)({action:'snapshot',site:other,from:day,to:day},403);
  await scoped(request,seller)({action:'snapshot',org:randomUUID(),from:day,to:day},403);
  const p=await scoped(request,owner)({action:'profile_get'});
  await scoped(request,owner)({action:'profile_set',name:'Propriétaire recette',revision:p.revision});
  const q=await scoped(request,seller)({action:'profile_get'});expect(q.display_name).not.toBe('Propriétaire recette');
 }finally{await close(request,seller);await close(request,owner)}
});
test('@catalogue five families, boundaries, history and unauthorized changes',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner),s=scoped(request,seller),m=mutation(o),v=mutation(s);
 try{
  for(const family of ['Porc','Poulet','Poisson','Brochettes','Omelettes']){
   const item=randomUUID();await m('add_item',{name:family+' test',family,price:1000,cost:400},item);
   await m('prepare',{item,qty:0},randomUUID(),400);await m('prepare',{item,qty:-1},randomUUID(),400);
   await m('prepare',{item,qty:3});
   const change=await m('change_price',{item,price:1200,reason:'Tarif test'});
   expect(change.old_price).toBe(1000);expect(change.new_price).toBe(1200);
   await v('change_price',{item,price:1500,reason:'Interdit'},randomUUID(),403);
   await m('set_item_active',{item,active:false,reason:'Stock restant'},randomUUID(),400);
   await m('adjust_stock',{item,delta:-4,reason:'Impossible'},randomUUID(),400);
   await m('adjust_stock',{item,delta:-3,reason:'Correction de recette'});
   await m('set_item_active',{item,active:false,reason:'Archive test'});
   await m('set_item_active',{item,active:true,reason:'Réactivation'});
  }
  await m('add_item',{name:'Interdit',family:'Pizza',price:100},randomUUID(),400);
  const x=await o({action:'snapshot',from:day,to:day});expect(x.items).toHaveLength(5);
 }finally{await close(request,seller);await close(request,owner)}
});
test('@cash tender declaration, reconcile, cancel, cash closing and replay',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner),s=scoped(request,seller),m=mutation(o),v=mutation(s);
 try{
  const item=randomUUID();await m('add_item',{name:'Poulet test',family:'Poulet',price:1000,cost:400},item);await m('prepare',{item,qty:10});
  await m('open_cash',{opening:0});
  const sale=randomUUID(),p={item,qty:1,price:1000,received:1000};
  const one=await v('sell',p,sale);expect(await v('sell',p,sale)).toEqual(one);
  await v('sell',{...p,received:999},randomUUID(),400);
  const mobile=randomUUID();await v('sell',{...p,method:'mtn_momo'},mobile);
  await m('reconcile_mobile',{receipt:mobile,source:'direct',amount:1000,reference:'CI-REF-ONLY'});
  await v('sell',{...p,method:'orange_money'});
  const doomed=randomUUID();await v('sell',p,doomed);
  await v('cancel_sale',{sale:doomed,reason:'Interdit'},randomUUID(),403);
  const cancel=randomUUID(),cp={sale:doomed,reason:'Saisie erronée'};const c=await m('cancel_sale',cp,cancel);expect(await m('cancel_sale',cp,cancel)).toEqual(c);
  await m('expense',{label:'Bois',value:100});
  const snap=await o({action:'snapshot',from:day,to:day});expect(snap.finance.ca).toBe(3000);expect(snap.finance.encaissements).toBe(1000);expect(snap.finance.mtn_declared).toBe(1000);expect(snap.finance.orange_declared).toBe(1000);
  await m('close_cash',{counted:899},randomUUID(),400);
  const closing=await m('close_cash',{counted:900});expect(closing.difference).toBe(0);
  await v('sell',p,randomUUID(),400);
 }finally{await close(request,seller);await close(request,owner)}
});
test('@read-models reports, profile, notices, attendance, prediction and absent external services',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner),s=scoped(request,seller);
 try{
  const x=await o({action:'snapshot',from:day,to:day});expect(x.finance.ca).toBe(0);
  const y=await s({action:'snapshot',from:day,to:day});expect(y.finance).toBeNull();
  await o({action:'report',from:day,to:day,network:false});
  await s({action:'report',from:day,to:day,network:true},403);
  for(const action of ['notice_feed','daily_list','attendance_status','prediction','pilotage_status','connect_list','security_list','profile_get']){
   const result=await o({action});expect(result!==undefined,action).toBe(true);
  }
  await o({action:'notice_set',category:'stock',enabled:false});
  const z=await o({action:'security_list'});expect(z.live_request_available).toBe(false);
  // Unknown partner token must fail closed; malformed and unknown QR have no public catalogue.
  await invoke(request,{action:'connect_catalog',qr:'unconfigured_local_qr_token_0123456789'},undefined,403);
  await invoke(request,{action:'connect_catalog',qr:'short'},undefined,403);
  // Renewal-only endpoint is intentionally unavailable during a valid subscription.
  await o({action:'renewal_status'},403);await s({action:'renewal_status'},403);
  // Controlled state transition in this job's disposable local DB only.
  function subscriptionState(expired:boolean){
   if(process.env.GRILLAD_CI_LOCAL!=='1'||process.env.GITHUB_ACTIONS!=='true'||process.env.GITHUB_REPOSITORY!=='audreymendomo23-netizen/FAMILLE-NAXA'||process.env.GITHUB_REF!=='refs/heads/work/grillad-foundation-20261127'||!['http://127.0.0.1:54321','http://localhost:54321'].includes(process.env.GRILLAD_LOCAL_API||''))throw Error('LOCAL_ONLY');
   const sql="update famille_core.subscriptions set status='"+(expired?"expired":"active")+"',ends_at=now()"+(expired?"-interval '1 hour'":"+interval '1 day'")+" where organization_id='"+org+"' and app_id=(select id from famille_core.applications where code='grillad')";
   const out=execFileSync('psql',['-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','54322','-U','postgres','-d','postgres','-c',sql],{encoding:'utf8',env:{PATH:process.env.PATH,PGPASSWORD:'postgres'}});
   expect(out.trim()).toBe('UPDATE 1');
  }
  subscriptionState(true);
  try{
   await o({action:'snapshot',from:day,to:day},403);
   await s({action:'snapshot',from:day,to:day},403);
   const list=await o({action:'renewal_status'});expect(list.central_requests).toEqual([]);
   await s({action:'renewal_status'},403);await o({action:'renewal_status',site:other},403);
   const event=randomUUID(),body={action:'renewal_action',event,operation:'renewal_request',payload:{plan:'grillad_premium_month'}};
   const renewal=await o(body);expect(renewal.status).toBe('pending');expect(await o(body)).toEqual(renewal);
   const history=await o({action:'renewal_status'});expect(history.central_requests.some(x=>x.id===event&&x.status==='pending'&&x.amount===6000)).toBe(true);
   const cancel={action:'renewal_action',event:randomUUID(),operation:'central_request_cancel',payload:{request:event,reason:'Fin de recette locale'}};
   expect((await o(cancel)).status).toBe('cancelled');
  }finally{subscriptionState(false)}
  expect((await o({action:'snapshot',from:day,to:day})).finance.ca).toBe(0);
  await o({action:'renewal_status'},403);
 }finally{await close(request,seller);await close(request,owner)}
});
test('@resilience competing real HTTP sales and replay, no oversell',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner),s=scoped(request,seller),m=mutation(o);
 try{
  const item=randomUUID();await m('add_item',{name:'Poisson concurrence',family:'Poisson',price:1000,cost:400},item);await m('prepare',{item,qty:3});await m('open_cash',{opening:0});
  const events=[randomUUID(),randomUUID(),randomUUID(),randomUUID()];const p={item,qty:1,price:1000,received:1000};
  const responses=await Promise.all(events.map(event=>request.post(endpoint,{headers:{apikey:key,Authorization:'Bearer '+seller},data:{action:'mutate',org,site,event,operation:'sell',payload:p}})));
  expect(responses.filter(r=>r.status()===200)).toHaveLength(3);expect(responses.filter(r=>r.status()===400)).toHaveLength(1);
  const i=responses.findIndex(r=>r.status()===200);const first=(await responses[i].json()).result;
  expect(await mutation(s)('sell',p,events[i])).toEqual(first);
  const snap=await o({action:'snapshot',from:day,to:day});expect(snap.finance.ca).toBe(3000);expect(snap.items.find(x=>x.id===item).remaining).toBe(0);
 }finally{await close(request,seller);await close(request,owner)}
});

// Three independent Auth users; manager is bound to site A and has no network-wide grant.
test('@manager third real identity, site isolation and manager operations',async({request})=>{
 let owner,seller,manager;
 try{
  owner=await login(request,'owner');seller=await login(request,'seller');manager=await login(request,'manager');
  expect(new Set([owner,seller,manager]).size).toBe(3);
  const w=await invoke(request,{action:'workspace'},manager);
  expect(w.some(x=>x.site===site&&x.role==='manager')).toBe(true);
  expect(w.some(x=>x.site===other)).toBe(false);
  const m=scoped(request,manager),o=scoped(request,owner),s=scoped(request,seller);
  await m({action:'snapshot',site:other,from:day,to:day},403);
  await m({action:'snapshot',org:randomUUID(),from:day,to:day},403);
  expect((await m({action:'snapshot',from:day,to:day})).finance).not.toBeNull();
  expect((await s({action:'snapshot',from:day,to:day})).finance).toBeNull();
  const item=randomUUID();
  await mutation(o)('add_item',{name:'Poulet responsable',family:'Poulet',price:1000,cost:400},item);
  await mutation(m)('prepare',{item,qty:2});
  await mutation(m)('open_cash',{opening:0});
  await mutation(s)('sell',{item,qty:1,price:1000,received:1000});
  expect((await m({action:'snapshot',from:day,to:day})).finance.ca).toBe(1000);
  const c=await mutation(m)('close_cash',{counted:1000});expect(c.difference).toBe(0);
  await m({action:'report',site:other,from:day,to:day,network:false},403);
  await m({action:'report',from:day,to:day,network:false});
 }finally{for(const token of [manager,seller,owner])await close(request,token)}
});

function localSql(sql:string){
 if(process.env.GRILLAD_CI_LOCAL!=='1'||process.env.GITHUB_ACTIONS!=='true'||process.env.GITHUB_REPOSITORY!=='audreymendomo23-netizen/FAMILLE-NAXA'||process.env.GITHUB_REF!=='refs/heads/work/grillad-foundation-20261127'||!['http://127.0.0.1:54321','http://localhost:54321'].includes(process.env.GRILLAD_LOCAL_API||''))throw Error('LOCAL_ONLY');
 return execFileSync('psql',['-XAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','54322','-U','postgres','-d','postgres','-c',sql],{encoding:'utf8',env:{PATH:process.env.PATH,PGPASSWORD:'postgres'}}).trim();
}
const partnerOrg='d7000000-0000-4000-8000-000000000001',partnerSite='d7000000-0000-4000-8000-000000000002',link='d7000000-0000-4000-8000-000000000003',camera='d7000000-0000-4000-8000-000000000004';
function partnerFixture(kind:'zipple'|'naxa_security'){
 localSql("insert into famille_core.organizations(id,legal_name,organization_type,status) values('"+partnerOrg+"','LOCAL CI partner','retail','active'); update famille_core.applications set status='active' where code='"+kind+"'; insert into famille_core.organization_apps(organization_id,app_id,status) select '"+partnerOrg+"',id,'active' from famille_core.applications where code='"+kind+"'; insert into famille_core.locations(id,organization_id,name) values('"+partnerSite+"','"+partnerOrg+"','LOCAL CI partner'); insert into famille_core.plans(app_id,code,name,amount_fcfa,billing_period) select id,'grillad-local-partner-fixture','Fixture',1,'monthly' from famille_core.applications where code='"+kind+"'; insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select '"+partnerOrg+"',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad-local-partner-fixture';");
}
test('@zipple bilateral consent, paired QR, independent sale and revocation via actual gateway',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner),m=mutation(o),qr='grillad_local_partner_qr_0123456789',table='9'.repeat(64),item=randomUUID();
 try{
  partnerFixture('zipple');
  const h="encode(sha256(convert_to('"+qr+"','UTF8')),'hex')",th="encode(sha256(convert_to('"+table+"','UTF8')),'hex')";
  await invoke(request,{action:'connect_catalog',qr},undefined,403);
  localSql("select public.grillad_partner_approval('zipple','"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"','"+accounts.owner.id+"',repeat('a',64),repeat('b',64)); select public.grillad_partner_zipple('"+link+"','"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"',"+h+",now()+interval '1 day');");
  await invoke(request,{action:'connect_pair',qr,table},undefined,403);
  localSql("select public.grillad_connect_pair_set('"+link+"',"+th+",'"+accounts.owner.id+"',repeat('c',64),true)");
  expect(await invoke(request,{action:'connect_pair',qr,table})).toMatchObject({approved:true,separate_orders:true,separate_tenders:true});
  await m('add_item',{name:'Poulet Connect CI',family:'Poulet',price:1000,cost:400},item);await m('prepare',{item,qty:3});await m('open_cash',{opening:0});
  await m('connect_item_set',{link,item,enabled:true,reason:'Recette locale'});
  const cat=await invoke(request,{action:'connect_catalog',qr});expect(cat.items).toHaveLength(1);expect(cat.items[0]).not.toHaveProperty('cost');expect(cat.items[0]).not.toHaveProperty('remaining');
  const order=randomUUID(),body={action:'connect_submit',qr,order,lines:[{item,qty:2}]};
  expect((await invoke(request,body)).total).toBe(2000);expect((await invoke(request,body)).id).toBe(order);
  for(const next of ['accepted','preparing','ready','handed'])await o({action:'connect_transition',order,event:randomUUID(),next,...(next==='handed'?{received:2000}:{})});
  expect((await invoke(request,{action:'connect_status',qr,order})).status).toBe('handed');
  const x=await o({action:'snapshot',from:day,to:day});expect(x.finance.ca).toBe(2000);expect(x.finance.connect_ca).toBe(2000);expect(x.items.find(x=>x.id===item).remaining).toBe(1);
  await scoped(request,seller)({action:'connect_list'},403);
  localSql("select public.grillad_connect_pair_set('"+link+"',"+th+",'"+accounts.owner.id+"',repeat('c',64),false)");
  await invoke(request,{action:'connect_pair',qr,table},undefined,403);
  await m('connect_link_set',{link,enabled:false,reason:'Fin recette'});
  await invoke(request,{action:'connect_catalog',qr},undefined,403);
 }finally{await close(request,seller);await close(request,owner)}
});
test('@security actual database projection, scoped access and source revocation',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner);
 try{
  partnerFixture('naxa_security');
  localSql("create table public.sec_organizations(id uuid primary key,active boolean not null); create table public.sec_sites(id uuid primary key,organization_id uuid not null,active boolean not null); create table public.sec_devices(id uuid primary key,organization_id uuid not null,site_id uuid not null,label text,kind text,observed_at timestamptz); create table public.sec_incidents(id uuid primary key,organization_id uuid not null,site_id uuid not null,device_id uuid,occurred_at timestamptz); insert into public.sec_organizations values('"+partnerOrg+"',true); insert into public.sec_sites values('"+partnerSite+"','"+partnerOrg+"',true); insert into public.sec_devices values('"+camera+"','"+partnerOrg+"','"+partnerSite+"','Camera CI','camera',now());");
  localSql("select public.grillad_partner_approval('security','"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"','"+accounts.owner.id+"',repeat('d',64),repeat('e',64)); select public.grillad_security_bind('"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"','"+partnerOrg+"','"+partnerSite+"'); select public.grillad_security_project('"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"');");
  let x=await o({action:'security_list'});expect(x.available).toBe(true);expect(x.cameras.some(c=>c.id===camera)).toBe(true);expect(x.live_request_available).toBe(false);
  await scoped(request,seller)({action:'security_list'},403);
  await o({action:'security_live_session',camera},503);
  localSql("update public.sec_sites set active=false where id='"+partnerSite+"'");
  x=await o({action:'security_list'});expect(x.available).toBe(false);expect(x.cameras).toEqual([]);
 }finally{await close(request,seller);await close(request,owner)}
});
test('@billing-recovery hosted contracts in real local Auth, independent proof and recovery request',async({request})=>{
 const owner=await login(request,'owner'),seller=await login(request,'seller'),o=scoped(request,owner);
 try{
  const recovery=await invoke(request,{action:'recovery',phone:accounts.owner.phone});expect(recovery.received).toBe(true);
  expect(Number(localSql("select count(*) from famille_private.recovery_requests where app_code='grillad' and login_hash=encode(sha256(convert_to('grillad:"+accounts.owner.phone+"','UTF8')),'hex')"))).toBeGreaterThan(0);
  localSql("select public.grillad_subscription_destination_set('orange_money','LOCAL CI beneficiary','FIXTURE-DEST',true); update famille_core.subscriptions set status='expired',ends_at=now()-interval '1 hour' where organization_id='"+org+"'");
  const event=randomUUID();await o({action:'renewal_action',event,operation:'renewal_request',payload:{plan:'grillad_premium_month'}});
  const q=await o({action:'payment_quote',request:event,channel:'orange_money'});expect(q.amount).toBe(6000);expect(q.provider_connected).toBe(false);
  await scoped(request,seller)({action:'payment_quote',request:event,channel:'orange_money'},403);
  const proof=await o({action:'subscription_declare',request:event,reference:'LOCAL-CI-PROOF',amount:6000,payer:'699000011',occurred:new Date().toISOString()});
  expect(proof).toBeTruthy();await o({action:'snapshot',from:day,to:day},403);
  expect(localSql("select status from famille_core.subscriptions where organization_id='"+org+"'")).toBe('expired');
 }finally{await close(request,seller);await close(request,owner)}
});
test('@push true Android-tagged Auth registration, preference and opt-out without external FCM',async({request})=>{
 const a=accounts.seller,s=await invoke(request,{action:'login',phone:a.phone,password:a.password,installation:randomUUID(),platform:'android'}),seller=s.access;
 const owner=await login(request,'owner'),o=scoped(request,owner),v=scoped(request,seller);
 try{
  const item=randomUUID();await mutation(o)('add_item',{name:'Push CI',family:'Poulet',price:1000,cost:400},item);
  await v({action:'push_register',enabled:true,token:'local-fixture-token-not-fcm-'+'x'.repeat(40),project:'wrong'},400);
  expect((await v({action:'push_register',enabled:true,token:'local-fixture-token-not-fcm-'+'x'.repeat(40),project:'grillad'})).registered).toBe(true);
  const event=randomUUID();await mutation(v)('prepare',{item,qty:1},event);
  const feed=await v({action:'notice_feed'});expect(feed.items.some(x=>x.id==='event:'+event)).toBe(true);
  const claims=JSON.parse(localSql("select public.grillad_push_claim(50)"));expect(claims.length).toBeGreaterThan(0);expect(claims.every(x=>!('token' in x))).toBe(true);
  expect((await v({action:'push_register',enabled:false})).registered).toBe(false);
  for(const c of claims)expect(localSql("select public.grillad_push_start('"+c.id+"') is null")).toBe('t');
  expect(Number(localSql("select count(*) from grillad_private.push_attempts where status='skipped'"))).toBe(claims.length);
 }finally{await close(request,seller);await close(request,owner)}
});

test('@finance-review incomplete cost, immutable historical sale and independently approved cash recount',async({request})=>{
 const owner=await login(request,'owner'),manager=await login(request,'manager'),seller=await login(request,'seller'),o=scoped(request,owner),m=mutation(o),g=mutation(scoped(request,manager)),s=mutation(scoped(request,seller));
 try{
  const item=randomUUID();await m('add_item',{name:'Cout CI',family:'Poulet',price:1000},item);
  await m('set_cost_composition',{item,reason:'Incomplet',components:[{label:'Intrant',amount:400},{label:'Charbon',amount:null}]});
  let x=await o({action:'snapshot',from:day,to:day});expect(x.items.find(i=>i.id===item).cost_quality).toBe('incomplete');
  await m('set_cost_composition',{item,reason:'Lot',batch_units:3,components:[{label:'Intrant',amount:1000},{label:'Charbon',amount:100}]});
  x=await o({action:'snapshot',from:day,to:day});expect(x.items.find(i=>i.id===item).cost).toBe(367);
  await g('prepare',{item,qty:3});await g('open_cash',{opening:0});const sale=randomUUID();await s('sell',{item,qty:1,price:1000,received:1000},sale);
  await m('set_cost_composition',{item,reason:'Nouvelle estimation',components:[{label:'Intrant',amount:600}]});
  const pre=await o({action:'snapshot',from:day,to:day});expect(pre.finance.ca).toBe(1000);expect(pre.finance.cost).toBe(367);
  const cash=pre.cash.id;await g('close_cash',{counted:1000});const req=randomUUID(),data={cash,counted:950,reason:'Recomptage CI'};
  expect((await g('cash_recount_request',data,req)).status).toBe('pending');
  await g('cash_recount_decide',{request:req,decision:'approved',reason:'Interdit'},randomUUID(),403);
  await m('cash_recount_decide',{request:req,decision:'approved',reason:'Vérifié'});
  x=await o({action:'snapshot',from:day,to:day});expect(x.cash_history.find(c=>c.id===cash)).toMatchObject({counted:1000,reviewed_counted:950,reviewed_difference:-50});expect(x.finance.ca).toBe(1000);
  await s('sell',{item,qty:1,price:1000,received:1000},randomUUID(),400);
 }finally{for(const t of [seller,manager,owner])await close(request,t)}
});
test('@attendance-review separate missing departure proof and independent approval',async({request})=>{
 const owner=await login(request,'owner'),manager=await login(request,'manager'),seller=await login(request,'seller'),o=scoped(request,owner),s=scoped(request,seller),m=mutation(scoped(request,manager));
 try{
  await mutation(o)('set_attendance_policy',{enabled:true,staff_informed:true,reason:'CI',latitude:4.05,longitude:9.7,radius_m:200,max_accuracy_m:50,max_age_seconds:300,photo_retention_days:1});
  const arrival=randomUUID(),at=new Date(Date.now()-120000).toISOString(),photo=Buffer.from('ffd8ff000000000000000000000000ffd9','hex').toString('base64');
  const proof={action:'attendance_capture',event:arrival,kind:'arrival',at,lat:4.05,lon:9.7,accuracy:10,photo};
  await s({...proof,lat:5},400);await s(proof);await s(proof);
  const event=randomUUID(),payload={arrival,seconds:30,reason:'Départ oublié CI'};expect((await mutation(s)('missing_departure_request',payload,event)).status).toBe('pending');
  await mutation(s)('missing_departure_decide',{request:event,decision:'approved',reason:'Interdit'},randomUUID(),403);
  await m('missing_departure_decide',{request:event,decision:'approved',reason:'Contrôlé'});
  const status=await s({action:'attendance_status'});expect(status.history).toHaveLength(1);expect(status.history[0].kind).toBe('arrival');expect(status.history[0].open_arrival).toBe(false);expect(status.missing_departures.find(x=>x.id===event).status).toBe('approved');
 }finally{for(const t of [seller,manager,owner])await close(request,t)}
});
test('@push-worker real RPC lifecycle and FCM transport boundary stub, no external delivery',async({request})=>{
 const a=accounts.seller,s=await invoke(request,{action:'login',phone:a.phone,password:a.password,installation:randomUUID(),platform:'android'}),seller=s.access;
 const owner=await login(request,'owner'),o=scoped(request,owner),v=scoped(request,seller);
 try{
  const item=randomUUID();await mutation(o)('add_item',{name:'Worker CI',family:'Poulet',price:1000,cost:400},item);
  await v({action:'push_register',enabled:true,token:'fixture-worker-not-real-fcm-'+'x'.repeat(40),project:'grillad'});
  const event=randomUUID();await mutation(v)('prepare',{item,qty:1},event);
  let sent=0;
  const fixtureFetch=async(url,init)=>{
   const u=new URL(String(url));if(u.origin==='https://idupfjbkwjcavyisxteo.supabase.co'&&/^\/rest\/v1\/rpc\/grillad_push_(claim|start|finish)$/.test(u.pathname))return fetch('http://127.0.0.1:54321'+u.pathname,init);
   if(u.href==='https://fcm.googleapis.com/v1/projects/grillad/messages:send'){sent++;const m=JSON.parse(init.body).message;expect(m.data).toEqual({app:'grillad',kind:'inbox'});expect(m).not.toHaveProperty('notification');return new Response(JSON.stringify({name:'projects/grillad/messages/local-fixture'}),{status:200})}
   throw Error('EXTERNAL_NETWORK_FORBIDDEN');
  };
  const secret='local-fixture-job-secret-'.padEnd(40,'x'),env={url:'https://idupfjbkwjcavyisxteo.supabase.co',service:process.env.GRILLAD_LOCAL_SERVICE,jobSecret:secret,account:JSON.stringify({type:'service_account',project_id:'grillad',client_email:'fixture@grillad.iam.gserviceaccount.com',private_key:'-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----'})};
  const job=()=>runPushWorker(new Request('http://127.0.0.1/job',{method:'POST',headers:{'x-grillad-job-secret':secret}}),env,fixtureFetch,async()=> 'local-fixture-bearer');
  const first=await job();expect(first.status).toBe(200);expect((await first.json()).accepted).toBeGreaterThan(0);expect(sent).toBeGreaterThan(0);
  expect(Number(localSql("select count(*) from grillad_private.push_attempts where notice_id='event:"+event+"' and status='accepted'"))).toBe(1);
  const before=sent,second=await job();expect(second.status).toBe(200);expect(sent).toBe(before);
 }finally{await close(request,seller);await close(request,owner)}
});
test('@zipple-mobile manual tender and no double imputation or external debit',async({request})=>{
 const owner=await login(request,'owner'),o=scoped(request,owner),m=mutation(o),qr='grillad_local_mobile_qr_0123456789',item=randomUUID();
 try{
  partnerFixture('zipple');
  const h="encode(sha256(convert_to('"+qr+"','UTF8')),'hex')";
  localSql("select public.grillad_partner_approval('zipple','"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"','"+accounts.owner.id+"',repeat('a',64),repeat('b',64)); select public.grillad_partner_zipple('"+link+"','"+org+"','"+site+"','"+partnerOrg+"','"+partnerSite+"',"+h+",now()+interval '1 day');");
  await m('add_item',{name:'Mobile Connect',family:'Poulet',price:1000,cost:400},item);await m('prepare',{item,qty:3});await m('open_cash',{opening:0});await m('connect_item_set',{link,item,enabled:true,reason:'CI'});
  const order=randomUUID();await invoke(request,{action:'connect_submit',qr,order,lines:[{item,qty:1}]});
  for(const next of ['accepted','preparing','ready'])await o({action:'connect_transition',order,event:randomUUID(),next});
  const handed={action:'connect_transition',order,event:randomUUID(),next:'handed',received:1000,method:'mtn_momo'};
  await o(handed);await o(handed);
  const x=await o({action:'snapshot',from:day,to:day});expect(x.finance.ca).toBe(1000);expect(x.finance.connect_ca).toBe(1000);expect(x.finance.mtn_declared).toBe(1000);expect(x.finance.encaissements).toBe(0);
  expect((await m('close_cash',{counted:0})).difference).toBe(0);
 }finally{await close(request,owner)}
});
