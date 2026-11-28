// Explicitly bounded read-only media and local data tooling; no untrusted device URL.
export function trustedMediaGrant(row,scope,origin,now){
 if(!row||!scope||!origin||!Number.isFinite(now)||row.organization_id!==scope.organization||row.site_id!==scope.site||row.user_id!==scope.user||row.device_id!==scope.device||row.media!==scope.media||row.revoked_at!=null)throw Error("MEDIA_DENIED");
 const exp=Date.parse(row.expires_at);if(!Number.isFinite(exp)||exp<=now||exp-now>300000)throw Error("MEDIA_EXPIRED");
 const base=new URL(origin),url=new URL(row.playback_url);
 if(base.protocol!=="https:"||base.username||base.password||base.pathname!=="/"||base.search||base.hash||url.origin!==base.origin||url.username||url.password||url.hash||url.search||!/^\/security\/media\/[A-Za-z0-9_-]{16,160}$/.test(url.pathname))throw Error("MEDIA_ORIGIN_DENIED");
 return {url:url.href,expiresAt:exp,media:row.media};
}
export function paymentMatch(request,receipts){
 if(!request||request.kind!=="payment"||!request.payload||!Array.isArray(receipts))throw Error("INVALID_PAYMENT");
 const p=request.payload;if(!Number.isSafeInteger(p.amount_fcfa)||p.amount_fcfa<=0)throw Error("INVALID_PAYMENT");
 const rows=receipts.filter(x=>x.organization_id===request.organization_id&&x.site_id===request.site_id&&x.channel===p.channel&&x.reference===p.reference&&Number.isFinite(Date.parse(x.provider_confirmed_at)));
 if(rows.length!==1)return "unmatched";
 return Number(rows[0].amount_fcfa)===p.amount_fcfa?"matched":"amount_mismatch";
}
export function riskSummary(rows,now){if(!Array.isArray(rows)||!Number.isFinite(now))throw Error("INVALID_OBSERVATIONS");const latest=new Map();
 for(const r of rows){if(!r||typeof r.device_id!=="string")continue;const t=Date.parse(r.observed_at);if(!Number.isFinite(t)||t>now)continue;const old=latest.get(r.device_id);if(!old||t>old.t)latest.set(r.device_id,{r,t});}
 const reasons=[];let fresh=0,unknown=0;for(const {r,t} of latest.values()){if(now-t>120000){unknown++;continue}fresh++;if(r.status==="fault"||r.status==="offline")reasons.push(r.device_id+" : "+r.status);else if(r.status!=="online")unknown++;}
 return {fresh,unknown,reasons,requiresHumanDecision:true,status:reasons.length?"review":unknown||!fresh?"unknown":"no_fault_in_loaded_observations"};
}
const validScope=s=>s&&typeof s.organization==="string"&&typeof s.site==="string"&&s.organization&&s.site;
export async function snapshotSummary(scope,counts,now=Date.now()){
 if(!validScope(scope)||!Number.isFinite(now)||!counts||Object.keys(counts).sort().join(",")!=="closed,open,total"||!Object.values(counts).every(x=>Number.isSafeInteger(x)&&x>=0)||counts.closed+counts.open!==counts.total)throw Error("INVALID_SNAPSHOT");
 const payload={version:1,organization:scope.organization,site:scope.site,createdAt:new Date(now).toISOString(),counts:{total:counts.total,open:counts.open,closed:counts.closed}};
 const digest=await hashText(JSON.stringify(payload));return {payload,digest};
}
async function hashText(s){const bytes=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));return Array.from(new Uint8Array(bytes),x=>x.toString(16).padStart(2,"0")).join("")}
export async function verifySnapshot(text,scope){
 if(typeof text!=="string"||text.length>16384||!validScope(scope))throw Error("INVALID_SNAPSHOT");
 const v=JSON.parse(text),p=v?.payload;if(!p||Object.keys(p).sort().join(",")!=="counts,createdAt,organization,site,version"||p.version!==1||p.organization!==scope.organization||p.site!==scope.site||typeof v.digest!=="string")throw Error("SNAPSHOT_SCOPE");
 const rebuilt=await snapshotSummary(scope,p.counts,Date.parse(p.createdAt));if(rebuilt.digest!==v.digest||JSON.stringify(rebuilt.payload)!==JSON.stringify(p))throw Error("SNAPSHOT_DIGEST");
 return rebuilt.payload.counts;
}
