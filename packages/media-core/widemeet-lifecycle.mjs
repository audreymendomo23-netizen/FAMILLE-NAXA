// Trusted service runner. Explicit tick; deployment/scheduler is a separate decision.
export function createWideMeetLifecycle({supabaseUrl,serviceKey,fetcher=fetch}){
 const base=new URL(supabaseUrl);if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey)throw Error("invalid lifecycle configuration");
 let pending;
 return {tick(){if(pending)return pending;pending=(async()=>{const r=await fetcher(new URL("/rest/v1/rpc/wm_close_due_rooms",base),{method:"POST",headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"},body:JSON.stringify({p_limit:100}),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(5000)});if(!r.ok)throw Error("lifecycle ledger unavailable");const rows=await r.json();if(!Array.isArray(rows))throw Error("invalid lifecycle result");return rows.map(x=>x.room_id)})().finally(()=>pending=null);return pending}};
}
