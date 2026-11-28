// Only public key and short-lived access token supplied by the dedicated SECURITY auth boundary.
export const SECURITY_URL="https://idupfjbkwjcavyisxteo.supabase.co";
export const resources=["sec_organizations","sec_sites","sec_devices","sec_incidents","sec_work_orders","sec_attendance_drafts","sec_module_requests","sec_preferences","sec_service_register","sec_inbox","sec_support_messages","sec_payment_receipts","sec_device_observations","sec_media_grants","sec_payment_reconciliation","sec_patrols","sec_patrol_checks","sec_passage_logs","sec_internal_safety","sec_field_events","sec_observation_alerts","sec_site_admin_log","sec_subscriptions","sec_evidence_files","sec_preference_snapshots","sec_service_action_log"] as const;
export type Resource=typeof resources[number];
export type SecuritySession={accessToken:string;publicKey:string;userId:string};
export async function request(session:SecuritySession,resource:Resource,options:{method?:"GET"|"POST";body?:Record<string,unknown>;site?:string;organization?:string;record?:string;requestId?:string;order?:string}={},transport:typeof fetch=fetch){
 if(!resources.includes(resource)||!session.accessToken||!session.publicKey||!session.userId)throw Error("SECURITY_SESSION_REQUIRED");
 if(session.publicKey.startsWith("sb_secret_")||session.publicKey===session.accessToken)throw Error("INVALID_PUBLIC_KEY");
 const url=new URL("/rest/v1/"+resource,SECURITY_URL);
 if(options.site){if(!/^[0-9a-f-]{36}$/i.test(options.site))throw Error("INVALID_SITE");url.searchParams.set("site_id","eq."+options.site)}
 for(const [field,value] of [["organization_id",options.organization],["id",options.record],["request_id",options.requestId]] as const){if(value&&!(resource==="sec_organizations"&&field==="organization_id")){if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value))throw Error("INVALID_SCOPE");url.searchParams.set(field,"eq."+value)}}
 if(options.method!=="POST"){url.searchParams.set("select","*");url.searchParams.set("limit","100");if(options.order){if(!["created_at.desc","observed_at.desc","recorded_at.desc","provider_confirmed_at.desc"].includes(options.order))throw Error("INVALID_ORDER");url.searchParams.set("order",options.order)}}
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

export function browserAttendance(session:SecuritySession,organization_id:string,site_id:string,action:string,p:{lat:number;lon:number;accuracy:number;observed:number},request_id:string,now=Date.now()){
 if(!["arrival","departure"].includes(action)||!Number.isFinite(p.lat)||Math.abs(p.lat)>90||!Number.isFinite(p.lon)||Math.abs(p.lon)>180||!Number.isFinite(p.accuracy)||p.accuracy<=0||p.accuracy>100||!Number.isFinite(p.observed)||p.observed>now||now-p.observed>120000)throw Error("INVALID_ATTENDANCE");
 return {organization_id,site_id,reporter_id:session.userId,request_id,action,lat:p.lat,lon:p.lon,accuracy_m:p.accuracy,observed_at:new Date(p.observed).toISOString(),source:"browser",mock_reported:null};
}

// Review RPCs are deliberately allowlisted. Authorization is enforced again on the server.
export async function reviewRpc(session:SecuritySession,name:"sec_module_review_queue"|"sec_review_module_request"|"sec_read_inbox"|"sec_field_action"|"sec_site_members"|"sec_integration_list"|"sec_service_action"|"sec_evidence_download",body:Record<string,unknown>){
 if(!["sec_module_review_queue","sec_review_module_request","sec_read_inbox","sec_field_action","sec_site_members","sec_integration_list","sec_service_action","sec_evidence_download"].includes(name)||!session.userId||!session.accessToken||!session.publicKey||session.publicKey.startsWith("sb_secret_")||session.publicKey===session.accessToken)throw Error("INVALID_SESSION");
 const r=await fetch(new URL("/rest/v1/rpc/"+name,SECURITY_URL),{method:"POST",headers:{apikey:session.publicKey,Authorization:"Bearer "+session.accessToken,"Content-Type":"application/json"},body:JSON.stringify(body),cache:"no-store",credentials:"omit",redirect:"error"});if(!r.ok)throw Error("SECURITY_HTTP_"+r.status);return await r.json();
}
