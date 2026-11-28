import {createRecoveryClient} from '../../admin-console/src/zipple-recovery.mjs';
export function createControlClient({url,key,fetcher=fetch}){
 const auth=createRecoveryClient({url,key,fetcher});
 async function rpc(name,body,token){if(!token)throw Error('ACCESS_DENIED');const r=await fetcher(url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(body),redirect:'error',cache:'no-store',signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('ACCESS_DENIED');return r.json()}
 return {login:auth.login,verify:auth.verify,logout:auth.logout,dashboard:(token,app=null)=>rpc('naxa_control_dashboard',{p_app:app},token),transition:(token,ticket,expected,next,reason)=>rpc('naxa_control_ticket_transition',{p_ticket:ticket,p_expected:expected,p_next:next,p_reason:reason},token)};
}
