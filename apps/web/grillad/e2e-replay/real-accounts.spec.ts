import {test,expect} from '@playwright/test';
import type {Page,BrowserContext} from '@playwright/test';
const endpoint='https://pwfftcsjyeibxxqhwysw.supabase.co/functions/v1/grillad';
const key=process.env.NAXA_STORAGE_E2E_ANON_KEY!;
type Session={user_id:string,access:string,sites:{org:string,site:string,role:string}[],renewal_only?:boolean};
const day=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Douala',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
async function login(page:Page,role:'OWNER'|'SELLER'):Promise<Session>{
 const phone=process.env['NAXA_REPLAY_GRILLAD_'+role+'_PHONE'],password=process.env['NAXA_REPLAY_GRILLAD_'+role+'_PASSWORD'];
 if(!phone||!password)throw Error('BLOCKED: authorized Replay accounts missing');
 await page.goto('/');
 await page.getByLabel('Identifiant ou téléphone').fill(phone);
 await page.getByLabel('Mot de passe',{exact:true}).fill(password);
 const response=page.waitForResponse(r=>r.url()===endpoint&&r.request().method()==='POST'&&r.request().postDataJSON()?.action==='login');
 await page.getByRole('button',{name:'Se connecter'}).click();
 const res=await response;
 expect(res.status(),'Replay login HTTP status').toBe(200);
 const session=(await res.json()).result as Session;
 expect(Boolean(session?.access&&session?.user_id&&session?.sites?.length&&!session.renewal_only),'active GRILLAD test workspace').toBe(true);
 return session;
}
async function call(ctx:BrowserContext,s:Session,body:object){
 return ctx.request.post(endpoint,{headers:{apikey:key,Authorization:'Bearer '+s.access},data:body,maxRedirects:0,timeout:20000});
}
async function logout(ctx:BrowserContext,s:Session){
 const r=await call(ctx,s,{action:'logout'});
 expect(r.status(),'Replay logout').toBe(200);
}
test('Replay real Auth — owner and seller browser logins, permitted snapshot and cross-site denial',async({browser})=>{
 const oc=await browser.newContext(),sc=await browser.newContext();let owner:Session|undefined,seller:Session|undefined;
 try{
  const op=await oc.newPage(),sp=await sc.newPage();
  owner=await login(op,'OWNER');seller=await login(sp,'SELLER');
  expect(owner.user_id!==seller.user_id,'distinct actual identities').toBe(true);
  const a=seller.sites.find(s=>s.role==='seller');
  expect(Boolean(a),'seller scoped workspace').toBe(true);
  const allowed=owner.sites.find(s=>s.role==='owner'&&s.org===a!.org&&s.site===a!.site);
  const denied=owner.sites.find(s=>s.role==='owner'&&s.org===a!.org&&s.site!==a!.site&&!seller!.sites.some(t=>t.org===s.org&&t.site===s.site));
  expect(Boolean(allowed&&denied),'two authorized fixture sites and restricted seller').toBe(true);
  await expect(op.getByText('CA net')).toBeVisible();
  await expect(sp.getByRole('button',{name:'Déconnexion'})).toBeVisible();
  for(const [ctx,s,site] of [[oc,owner,allowed],[sc,seller,a]] as const){
   const res=await call(ctx,s,{action:'snapshot',org:site!.org,site:site!.site,from:day,to:day});
   expect(res.status(),'allowed snapshot').toBe(200);
   const x=(await res.json()).result;
   expect(Boolean(x&&Array.isArray(x.items)),'persisted server snapshot').toBe(true);
   if(s===seller)expect(x.finance===null,'seller finance concealed').toBe(true);
  }
  const refused=await call(sc,seller,{action:'snapshot',org:denied!.org,site:denied!.site,from:day,to:day});
  expect(refused.status(),'cross-site refusal').toBe(403);
 }finally{
  try{if(seller)await logout(sc,seller);}finally{try{if(owner)await logout(oc,owner);}finally{await Promise.all([oc.close(),sc.close()]);}}
 }
});
