import {permitsSite} from './session.mjs';
const actions=new Set(['entitlement','trial','sale','support','support-cancel','catalog']);
export async function operation(base,session,site,action,payload,fetcher=fetch){
 if(!permitsSite(session,site)||session.app_id!=='BOOTIK'||!actions.has(action))throw Error('SCOPE_DENIED');
 const url=new URL(base.replace(/\/$/,'')+'/operation');
 if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash)throw Error('INVALID_API');
 const res=await fetcher(url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+session.access_token},body:JSON.stringify({app_id:'BOOTIK',site_id:site,action,payload}),cache:'no-store',redirect:'error'});
 if(!res.ok)throw Error('REQUEST_REJECTED');
 const j=await res.json();
 if(j.app_id!=='BOOTIK'||j.organization_id!==session.organization_id||j.site_id!==site||j.action!==action||j.state!=='acknowledged'||!j.result||typeof j.result!=='object')throw Error('INVALID_RECEIPT');
 return j.result;
}
