export const plans=Object.freeze({Essentiel:{monthly:5000,annual:60000},Business:{monthly:20000,annual:200000},Professional:{monthly:50000,annual:500000}});
export function quote(plan,period){if(!Object.hasOwn(plans,plan)||!["monthly","annual"].includes(period))throw Error("INVALID_PLAN");return plans[plan][period]}
export function freshness(observed,now,maxAge=120000){if(!Number.isFinite(observed)||!Number.isFinite(now)||!Number.isFinite(maxAge)||maxAge<=0||observed>now||now-observed>maxAge)return "unknown";return "fresh"}
export function alarmPriority(source,signal){if(source==="fire_panel"&&signal==="alarm")return "P1";if(source==="smoke_detector"&&signal==="alarm")return "P1";if(signal==="fault"||signal==="prealarm")return "review";return "unknown"}
export function commandState(receipt,now){if(!receipt||!Number.isFinite(now)||!Number.isFinite(receipt.expires)||!receipt.authorized)return "denied";if(receipt.executed===true&&receipt.verified===true&&Number.isFinite(receipt.executedAt)&&receipt.executedAt<=now&&receipt.executedAt<=receipt.expires)return "executed";if(now>=receipt.expires)return "expired";return receipt.acknowledged?"acknowledged":receipt.sent?"sent":"authorized"}
export function positionEvidence(p,now){return !!p&&Number.isFinite(p.lat)&&Math.abs(p.lat)<=90&&Number.isFinite(p.lon)&&Math.abs(p.lon)<=180&&Number.isFinite(p.accuracy)&&p.accuracy>0&&p.accuracy<=100&&p.mock===false&&freshness(p.observed,now)==="fresh"?"pending_review":"rejected"}
export function patrolProgress(required,confirmed){if(!Array.isArray(required)||!Array.isArray(confirmed)||!required.length||new Set(required).size!==required.length)return {complete:false,count:0};const count=required.filter(id=>confirmed.includes(id)).length;return {complete:count===required.length,count}}
export function workDraft(subject,kind){const s=typeof subject==="string"?subject.trim():"";if(!s||s.length>500||!["preventive","corrective","inspection"].includes(kind))throw Error("INVALID_WORK");return {subject:s,kind,state:"draft"}}
export function incidentDraft(subject,priority){const s=typeof subject==="string"?subject.trim():"";if(!s||s.length>500||!["P2","P3","P4"].includes(priority))throw Error("INVALID_REPORT");return {subject:s,priority,state:"draft"}}
export function delegatedRead(grant,request,now){return !!grant&&!!request&&Number.isFinite(now)&&Number.isFinite(grant.expires)&&now<grant.expires&&grant.active===true&&["app","organization","site","resource"].every(k=>typeof grant[k]==="string"&&grant[k].length>0&&grant[k]===request[k])&&request.operation==="read"&&grant.operation==="read"}

/** Local eligibility preview, not an entitlement or authorization decision. */
export function siteEligibility(plan, count) {
  if (!Object.hasOwn(plans, plan) || !Number.isSafeInteger(count) || count < 1) return "denied";
  if (plan === "Essentiel" && count !== 1) return "denied";
  return "eligible_pending_quotas";
}
/** Never treat stale or unverified telemetry as operational availability. */
export function deviceHealth(report, now) {
  if (!report || report.verified !== true || freshness(report.observed, now) !== "fresh") return "unknown";
  return ["online", "offline", "fault"].includes(report.status) ? report.status : "unknown";
}
/** Read-only representation; acknowledgement cannot silence a local alarm. */
export function fireAlarmView(report) {
  if (!report || report.verified !== true || !["fire_panel", "smoke_detector"].includes(report.source)) return "unknown";
  if (["alarm", "evacuation"].includes(report.signal)) return report.acknowledged === true ? "alarm_acknowledged" : "alarm_active";
  if (report.signal === "restored") return report.inspected === true ? "restored_inspected" : "restored_pending_inspection";
  if (["fault", "prealarm"].includes(report.signal)) return "review";
  return "unknown";
}
/** A locally valid attendance draft remains pending until the server verifies it. */
export function attendanceDraft(action, position, now) {
  return ["arrival", "departure"].includes(action) && positionEvidence(position, now) === "pending_review" ? "pending_server_review" : "rejected";
}
/** Closing a work order requires a nonempty intervention report and confirmed completion. */
export function maintenanceClosure(record) {
  return !!record && record.completionConfirmed === true && typeof record.report === "string" && record.report.trim().length > 0 ? "ready_for_authorized_review" : "incomplete";
}
/** Preview of subject-scoped delegation; enforcement remains server-side. */
export function subjectDelegatedRead(grant, request, now) {
  return delegatedRead(grant, request, now) && typeof grant.subject === "string" && grant.subject.trim().length > 0 &&
    grant.subject === request.subject && Number.isFinite(grant.startsAt) && grant.startsAt <= now;
}
