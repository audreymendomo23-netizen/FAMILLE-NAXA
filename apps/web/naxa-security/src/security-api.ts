// Only public key and short-lived access token supplied by the dedicated SECURITY auth boundary.
export const SECURITY_URL="https://idupfjbkwjcavyisxteo.supabase.co";
export const resources=["sec_organizations","sec_sites","sec_devices","sec_incidents","sec_work_orders"] as const;
export type Resource=typeof resources[number];
export type SecuritySession={accessToken:string;publicKey:string;userId:string};
export async function request(session:SecuritySession,resource:Resource,options:{method?:"GET"|"POST";body?:Record<string,unknown>;site?:string}={},transport:typeof fetch=fetch){
 if(!resources.includes(resource)||!session.accessToken||!session.publicKey||!session.userId)throw Error("SECURITY_SESSION_REQUIRED");
 if(session.publicKey.startsWith("sb_secret_")||session.publicKey===session.accessToken)throw Error("INVALID_PUBLIC_KEY");
 const url=new URL("/rest/v1/"+resource,SECURITY_URL);
 if(options.site){if(!/^[0-9a-f-]{36}$/i.test(options.site))throw Error("INVALID_SITE");url.searchParams.set("site_id","eq."+options.site)}
 if(options.method!=="POST"){url.searchParams.set("select","*");url.searchParams.set("limit","100")}
 const r=await transport(url,{method:options.method??"GET",headers:{apikey:session.publicKey,Authorization:"Bearer "+session.accessToken,"Content-Type":"application/json",Prefer:"return=representation"},body:options.body?JSON.stringify(options.body):undefined,cache:"no-store",credentials:"omit",redirect:"error"});
 if(!r.ok)throw Error("SECURITY_HTTP_"+r.status);return await r.json();
}
export function manualReport(session:SecuritySession,organization_id:string,site_id:string,subject:string,priority:string,request_id:string){
 if(!subject.trim()||subject.trim().length>500||!["P2","P3","P4"].includes(priority))throw Error("INVALID_MANUAL_REPORT");
 return {organization_id,site_id,subject:subject.trim(),priority,state:"new",reporter_id:session.userId,request_id};
}
export function maintenanceRequest(session:SecuritySession,organization_id:string,site_id:string,subject:string,kind:string,request_id:string){
 if(!subject.trim()||subject.trim().length>500||!["preventive","corrective","inspection"].includes(kind))throw Error("INVALID_WORK_REQUEST");
 return {organization_id,site_id,subject:subject.trim(),kind,reporter_id:session.userId,request_id};
}
