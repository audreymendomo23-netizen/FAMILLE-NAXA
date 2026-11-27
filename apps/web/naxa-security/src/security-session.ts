import {request,SECURITY_URL,type SecuritySession} from "./security-api";
export type Site={id:string;organization_id:string;name:string};
export type ActiveSession=SecuritySession&{sites:Site[];expiresAt:number};
const publicKey=String((import.meta.env as ImportMetaEnv & {VITE_SECURITY_PUBLISHABLE_KEY?:string}).VITE_SECURITY_PUBLISHABLE_KEY??"");
export function configured(){return publicKey.startsWith("sb_publishable_")}
export async function login(email:string,password:string):Promise<ActiveSession>{
 if(!configured())throw Error("CONFIGURATION_REQUIRED");
 const response=await fetch(SECURITY_URL+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:publicKey,"Content-Type":"application/json"},body:JSON.stringify({email:email.trim(),password}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!response.ok)throw Error("LOGIN_DENIED");
 const j=await response.json();
 if(typeof j.access_token!=="string"||typeof j.user?.id!=="string"||!Number.isFinite(j.expires_in)||j.expires_in<=0)throw Error("INVALID_SESSION");
 const session={accessToken:j.access_token,userId:j.user.id,publicKey,expiresAt:Date.now()+j.expires_in*1000};
 const sites=await request(session,"sec_sites") as Site[];
 if(!Array.isArray(sites)||!sites.length||sites.some(s=>!s.id||!s.organization_id))throw Error("SECURITY_ACCESS_DENIED");
 return {...session,sites};
}
export async function logout(session:ActiveSession){const r=await fetch(SECURITY_URL+"/auth/v1/logout?scope=local",{method:"POST",headers:{apikey:session.publicKey,Authorization:"Bearer "+session.accessToken},cache:"no-store",redirect:"error",credentials:"omit"});if(!r.ok)throw Error("LOGOUT_UNCONFIRMED");}
