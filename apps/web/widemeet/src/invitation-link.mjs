// An invitation is a bearer secret; accept only the exact canonical value, never a truncated prefix.
const TOKEN=/^[a-f0-9]{64}$/;
export function invitationFromHash(hash){
 if(typeof hash!=="string"||!/^#invite=[a-f0-9]{64}$/.test(hash))return null;
 return hash.slice(8);
}
export function invitationFromInput(value){
 if(typeof value!=="string")return null;
 const v=value.trim();if(TOKEN.test(v))return v;
 try{const url=new URL(v);if(url.protocol!=="https:"&&url.protocol!=="http:")return null;return invitationFromHash(url.hash)}catch{return null}
}
