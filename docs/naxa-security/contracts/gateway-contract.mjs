// Reference trusted-transport contract for EDGE. No hardware scanner, actuator or production credentials.
import{createHmac,timingSafeEqual}from"node:crypto";
const uuid=x=>typeof x==="string"&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x);
const fields=["gateway_id","organization_id","site_id","device_id","event_id","observed_at","status","metric","value"];
function normalize(v,now){if(!v||Object.keys(v).sort().join(",")!==[...fields].sort().join(",")||!fields.slice(0,5).every(k=>uuid(v[k]))||!Number.isFinite(now))throw Error("INVALID_EVENT");
 const t=Date.parse(v.observed_at);if(!Number.isFinite(t)||t>now||now-t>86400000||!["online","offline","fault"].includes(v.status))throw Error("INVALID_OBSERVATION");
 if(v.metric===null?v.value!==null:!["temperature","humidity","water","co","gas"].includes(v.metric)||typeof v.value!=="number"||!Number.isFinite(v.value)||Math.abs(v.value)>1000000||(v.metric!=="temperature"&&v.value<0)||(v.metric==="humidity"&&v.value>100))throw Error("INVALID_MEASURE");
 return Object.fromEntries(fields.map(k=>[k,k==="observed_at"?new Date(t).toISOString():v[k]]));
}
const mac=(payload,secret)=>{if(!Buffer.isBuffer(secret)||secret.length<32)throw Error("WEAK_SECRET");return createHmac("sha256",secret).update(JSON.stringify(payload)).digest("hex")};
export function signObservation(v,secret,now=Date.now()){const payload=normalize(v,now);return {payload,signature:mac(payload,secret)}}
export function verifyObservation(envelope,binding,secret,now=Date.now()){const p=normalize(envelope?.payload,now);
 if(!binding||binding.enabled!==true||p.gateway_id!==binding.gateway_id||p.organization_id!==binding.organization_id||p.site_id!==binding.site_id||!Array.isArray(binding.devices)||!binding.devices.includes(p.device_id)||typeof envelope.signature!=="string"||!/^[0-9a-f]{64}$/.test(envelope.signature)||!timingSafeEqual(Buffer.from(envelope.signature,"hex"),Buffer.from(mac(p,secret),"hex")))throw Error("GATEWAY_DENIED");return p}
export function checkReceipt(p,r){return !!r&&["gateway_id","organization_id","site_id","device_id","event_id"].every(k=>r[k]===p[k])&&uuid(r.observation_id)&&r.state==="recorded"&&r.physical_action===false&&Number.isInteger(r.warnings)&&r.warnings>=0&&r.warnings<=2}
export async function deliver(envelope,binding,secret,transport,now=Date.now()){const p=verifyObservation(envelope,binding,secret,now);const r=await transport(p);if(!checkReceipt(p,r))throw Error("UNCONFIRMED");return r}
