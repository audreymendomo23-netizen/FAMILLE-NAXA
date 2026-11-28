import {publicKeyAllowed} from "./zipple-recovery.mjs";
export async function grilladOverview({url,key,token,fetcher=fetch}){
 if(url!=="https://idupfjbkwjcavyisxteo.supabase.co"||!publicKeyAllowed(key)||typeof token!=="string"||!token)throw Error("ACCESS_DENIED");
 const r=await fetcher(url+"/rest/v1/rpc/grillad_central_overview",{method:"POST",headers:{apikey:key,authorization:"Bearer "+token,"content-type":"application/json"},body:"{}",redirect:"error",cache:"no-store",signal:AbortSignal.timeout(20000)});
 if(!r.ok)throw Error("ACCESS_DENIED");
 const d=await r.json();
 if(d?.app!=="grillad"||!["organizations","active_subscriptions","open_support"].every(k=>Number.isSafeInteger(d[k])&&d[k]>=0))throw Error("INVALID_RESPONSE");
 return {organizations:d.organizations,active_subscriptions:d.active_subscriptions,open_support:d.open_support};
}
