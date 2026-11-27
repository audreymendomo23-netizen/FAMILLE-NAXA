// B5 support-only adapter; pass to existing createMediaProxy on a separate
// private SFU / public signaling endpoint with distinct credentials. No meeting admission.
export function createWideMeetSupportAdmission({supabaseUrl,serviceKey,fetcher=fetch}){
 const base=new URL(supabaseUrl);
 if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey)throw Error("invalid support backend");
 return async grant=>{
  if(grant?.app!=="wm"||!/^wm-support-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(grant.room)||!/^[a-f0-9]{64}$/.test(grant.sessionHash??"")||grant.sources?.some(x=>!["microphone","screen_share"].includes(x)))return null;
  const r=await fetcher(new URL("/rest/v1/rpc/wm_support_media_admission",base),{method:"POST",headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"},body:JSON.stringify({p_hash:grant.sessionHash,p_call:grant.room.slice(11)}),cache:"no-store",redirect:"error",signal:AbortSignal.timeout(3000)});
  if(!r.ok)throw Error("support admission unavailable");
  const state=await r.json();
  if(!state||state.room!==grant.room||state.identity!==grant.identity||state.app!=="wm")return null;
  return state;
 };
}
