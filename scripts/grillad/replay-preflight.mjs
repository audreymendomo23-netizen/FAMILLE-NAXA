// Read-only Replay preflight. Never print configuration values or access production.
import {appendFileSync} from 'node:fs';
import {configuredEndpoint} from '../../apps/web/grillad/src/connected-api.mjs';
const pinned='https://pwfftcsjyeibxxqhwysw.supabase.co';
const required=['NAXA_STORAGE_E2E_URL','NAXA_STORAGE_E2E_ANON_KEY','NAXA_REPLAY_GRILLAD_OWNER_PHONE','NAXA_REPLAY_GRILLAD_OWNER_PASSWORD','NAXA_REPLAY_GRILLAD_SELLER_PHONE','NAXA_REPLAY_GRILLAD_SELLER_PASSWORD'];
const missing=required.filter(k=>!process.env[k]);
if(missing.length){console.error('BLOCKED: missing authorized Replay configuration names: '+missing.join(', '));process.exit(1);}
if(process.env.NAXA_STORAGE_E2E_URL.replace(/\/$/,'')!==pinned){console.error('BLOCKED: target is not pinned NAXA Replay');process.exit(1);}
const endpoint=pinned+'/functions/v1/grillad',key=process.env.NAXA_STORAGE_E2E_ANON_KEY;
if(!configuredEndpoint(endpoint,key)){console.error('BLOCKED: invalid public key or endpoint');process.exit(1);}
const owner=process.env.NAXA_REPLAY_GRILLAD_OWNER_PHONE,seller=process.env.NAXA_REPLAY_GRILLAD_SELLER_PHONE;
if(!/^\+[1-9]\d{7,14}$/.test(owner)||!/^\+[1-9]\d{7,14}$/.test(seller)||owner===seller){console.error('BLOCKED: two distinct authorized test accounts required');process.exit(1);}
try{
 const r=await fetch(endpoint,{method:'OPTIONS',headers:{Origin:'http://127.0.0.1:4181','Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,apikey,content-type',apikey:key},redirect:'error',signal:AbortSignal.timeout(10000)});
 if(r.status!==204||r.headers.get('access-control-allow-origin')!=='http://127.0.0.1:4181'){console.error('BLOCKED: Replay GRILLAD endpoint or CORS unavailable; HTTP '+r.status);process.exit(1);}
}catch{console.error('BLOCKED: Replay GRILLAD endpoint unreachable');process.exit(1);}
appendFileSync(process.env.GITHUB_ENV,'VITE_GRILLAD_API_URL='+endpoint+'\nVITE_GRILLAD_PUBLIC_KEY='+key+'\n');
console.log('PASS: pinned Replay endpoint and browser origin; test account configuration present');
