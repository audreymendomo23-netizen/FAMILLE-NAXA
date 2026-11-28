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
