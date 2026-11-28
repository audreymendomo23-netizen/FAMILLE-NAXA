import {readFileSync,realpathSync,statSync} from 'node:fs';
import {isAbsolute,relative} from 'node:path';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {configuredEndpoint} from '../../apps/web/grillad/src/connected-api.mjs';
const replay='https://pwfftcsjyeibxxqhwysw.supabase.co',endpoint=replay+'/functions/v1/grillad';
const personas=[{role:'OWNER',email:'naxa.e2e.promoteur@example.invalid',file:'NAXA_STORAGE_E2E_PROMOTEUR_PASSWORD_FILE',marker:m=>m?.naxa_e2e_promoteur===true},{role:'SELLER',email:'naxa.e2e.caisse@example.invalid',file:'NAXA_STORAGE_E2E_CAISSE_PASSWORD_FILE',marker:m=>m?.naxa_e2e_fixture==='NAXA-E2E-PHARMACY-STAFF-20261115'&&m?.naxa_e2e_persona==='caisse'}];
export function validateOrigin(env){
 if(env.GITHUB_ACTIONS!=='true'||env.GITHUB_REPOSITORY!=='audreymendomo23-netizen/NAXA'||env.GRILLAD_REPLAY_AUTHORIZED!=='yes')throw Error('BLOCKED: requires authorized NAXA runner');
 if(String(env.NAXA_STORAGE_E2E_URL??'').replace(/\/$/,'')!==replay||!configuredEndpoint(endpoint,env.NAXA_STORAGE_E2E_ANON_KEY))throw Error('BLOCKED: requires pinned Replay public configuration');
}
function secret(env,k){
 const root=realpathSync(env.RUNNER_TEMP),file=realpathSync(env[k]??'');
 const rel=relative(root,file);if(!rel||rel.startsWith('..')||isAbsolute(rel)||!statSync(file).isFile()||(statSync(file).mode&0o077)!==0)throw Error('BLOCKED: invalid ephemeral fixture file');
 const value=readFileSync(file,'utf8');if(!/^[A-Za-z0-9_!\-]{32,128}$/.test(value))throw Error('BLOCKED: invalid ephemeral fixture credential');
 return value;
}
export async function discover(env,fetcher=fetch,read=secret,mask=()=>{}){
 validateOrigin(env);const key=env.NAXA_STORAGE_E2E_ANON_KEY,accounts={};const ids=new Set();
 for(const p of personas){
  const password=read(env,p.file);mask(password);
  let token;
  try{
   const res=await fetcher(replay+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({email:p.email,password}),redirect:'error',signal:AbortSignal.timeout(15000)});
   if(!res.ok)throw Error('BLOCKED: Replay fixture login '+p.role+' HTTP '+res.status);
   const data=await res.json();token=data?.access_token;
   if(typeof token!=='string'||!token)throw Error('BLOCKED: Replay fixture session absent');mask(token);if(data.refresh_token)mask(data.refresh_token);
   const u=data.user;if(!u?.id||u.email!==p.email||!p.marker(u.user_metadata)||ids.has(u.id))throw Error('BLOCKED: unexpected NAXA fixture identity '+p.role);
   ids.add(u.id);
   // Profile metadata phone is NOT a verified Auth phone; never convert it or bypass phone login.
   const phone=String(u.phone??'');if(!u.phone_confirmed_at||!/^\+?[1-9]\d{7,14}$/.test(phone))throw Error('BLOCKED: same NAXA identity requires verified Auth phone ('+p.role+')');
   accounts['NAXA_REPLAY_GRILLAD_'+p.role+'_PHONE']='+'+phone.replace(/^\+/,'');accounts['NAXA_REPLAY_GRILLAD_'+p.role+'_PASSWORD']=password;
  }finally{
   if(token){const out=await fetcher(replay+'/auth/v1/logout?scope=local',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token},redirect:'error',signal:AbortSignal.timeout(15000)});if(!out.ok)throw Error('BLOCKED: Replay fixture session cleanup failed');}
  }
 }
 if(accounts.NAXA_REPLAY_GRILLAD_OWNER_PHONE===accounts.NAXA_REPLAY_GRILLAD_SELLER_PHONE)throw Error('BLOCKED: distinct Auth phones required');
 return accounts;
}
async function main(){
 const accounts=await discover(process.env,fetch,secret,v=>process.stdout.write('::add-mask::'+String(v).replace(/%/g,'%25').replace(/\r/g,'%0D').replace(/\n/g,'%0A')+'\n'));
 // Allowlist child environment: never pass NAXA Admin/service credentials or unrelated fixture secrets.
 const env={};for(const k of ['PATH','HOME','CI','GITHUB_ACTIONS','GITHUB_ENV','RUNNER_TEMP','PLAYWRIGHT_BROWSERS_PATH','TMPDIR','LANG'])if(process.env[k])env[k]=process.env[k];
 Object.assign(env,{NAXA_STORAGE_E2E_URL:replay,NAXA_STORAGE_E2E_ANON_KEY:process.env.NAXA_STORAGE_E2E_ANON_KEY,VITE_GRILLAD_API_URL:endpoint,VITE_GRILLAD_PUBLIC_KEY:process.env.NAXA_STORAGE_E2E_ANON_KEY},accounts);
 for(const [cmd,args] of [[process.execPath,['scripts/grillad/replay-preflight.mjs']],[process.execPath,['scripts/grillad/cloudflare-pages-build.mjs']],['npm',['exec','--workspace','@famille/grillad-web','--','playwright','test','--config','playwright.replay.config.ts']]]){
  const r=spawnSync(cmd,args,{env,stdio:'inherit',shell:false});if(r.error||r.status!==0)throw Error('BLOCKED: GRILLAD Replay step unsuccessful');
 }
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)main().catch(e=>{console.error(e?.message?.startsWith('BLOCKED:')?e.message:'BLOCKED: runner adapter failed');process.exitCode=1});
