// Dedicated short-lived CI qualification scope; no client or customer identity.
const issuer="https://token.actions.githubusercontent.com";
const bytes=s=>Uint8Array.from(atob(s.replaceAll("-","+").replaceAll("_","/")+"=".repeat((4-s.length%4)%4)),c=>c.charCodeAt(0));
const parse=s=>JSON.parse(new TextDecoder().decode(bytes(s)));
export async function verifyCiToken(token,scope,{now=Date.now(),fetcher=fetch}={}){
 if(!scope.sha||!Number.isFinite(scope.expiresAt)||now>=scope.expiresAt||typeof token!=="string"||token.length>12000)return null;
 try{
  const parts=token.split(".");if(parts.length!==3||parts.some(p=>!/^[A-Za-z0-9_-]+$/.test(p)))return null;
  const [h,p,s]=parts,header=parse(h),c=parse(p),sec=Math.floor(now/1000);
  if(header.alg!=="RS256"||typeof header.kid!=="string"||header.kid.length>200||c.iss!==issuer||c.aud!==scope.audience||c.repository_id!=="1457255045"||c.repository_owner_id!=="337470304"||c.repository!=="audreymendomo23-netizen/FAMILLE-NAXA"||c.ref!=="refs/heads/work/widemeet-n0-20261126"||c.event_name!=="push"||c.sha!==scope.sha||c.workflow_ref!=="audreymendomo23-netizen/FAMILLE-NAXA/.github/workflows/widemeet-fcm-live.yml@refs/heads/work/widemeet-n0-20261126"||c.runner_environment!=="github-hosted"||typeof c.jti!=="string"||c.jti.length<8||c.jti.length>200)return null;
  if(![c.iat,c.nbf,c.exp].every(Number.isSafeInteger)||c.exp<=sec||c.nbf>sec+30||c.iat>sec+30||c.exp-c.iat>600||c.iat<sec-600)return null;
  const r=await fetcher(issuer+"/.well-known/jwks",{redirect:"error",signal:AbortSignal.timeout(5000)});if(!r.ok)return null;
  const keys=(await r.json()).keys;if(!Array.isArray(keys))return null;
  const matches=keys.filter(k=>k.kid===header.kid&&k.kty==="RSA"&&(!k.alg||k.alg==="RS256")&&(!k.use||k.use==="sig"));if(matches.length!==1)return null;
  const key=await crypto.subtle.importKey("jwk",matches[0],{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["verify"]);
  if(!await crypto.subtle.verify("RSASSA-PKCS1-v1_5",key,bytes(s),new TextEncoder().encode(h+"."+p)))return null;
  return {jti:c.jti,sha:c.sha};
 }catch{return null}
}
