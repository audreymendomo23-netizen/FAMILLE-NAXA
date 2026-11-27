// Based on ZIPPLE's scope-bound outbox pattern. SECURITY persists only non-sensitive preferences.
export function preferenceEvent(scope,key,value,id){
 const uuid=s=>typeof s==="string"&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
 if(!scope||![scope.organization,scope.site,scope.user,id].every(uuid))throw Error("INVALID_SCOPE");
 const kind=key==="locale"?"language":"notification";
 if(kind==="language"?!["fr","en","ff-CM"].includes(value):!["push","sms","email","whatsapp"].includes(key)||!["enabled","disabled"].includes(value))throw Error("INVALID_PREFERENCE");
 return {key:[scope.organization,scope.site,scope.user,key].join(":"),organization:scope.organization,site:scope.site,user:scope.user,id,kind,payload:kind==="language"?{locale:value}:{channel:key,preference:value}};
}
export function eventScope(e,s){return !!e&&!!s&&e.organization===s.organization&&e.site===s.site&&e.user===s.user}
export function eventBody(e){return {organization_id:e.organization,site_id:e.site,reporter_id:e.user,request_id:e.id,kind:e.kind,payload:e.payload}}
export function validPreferenceReceipt(e,r){if(!r||r.request_id!==e.id||r.organization_id!==e.organization||r.site_id!==e.site||r.reporter_id!==e.user||r.kind!==e.kind||!["requested","reviewed","declined"].includes(r.state)||!r.payload)return false;const keys=Object.keys(e.payload);return Object.keys(r.payload).length===keys.length&&keys.every(k=>r.payload[k]===e.payload[k])}
export function samePending(a,b){return a.key===b.key&&a.kind===b.kind&&JSON.stringify(a.payload)===JSON.stringify(b.payload)}
