export const plans:Readonly<Record<string,{monthly:number;annual:number}>>;
export function quote(plan:string,period:string):number;
export function freshness(observed:number|null,now:number,maxAge?:number):string;
export function alarmPriority(source:string,signal:string):string;
export function commandState(receipt:Record<string,unknown>|null,now:number):string;
export function positionEvidence(p:Record<string,unknown>|null,now:number):string;
export function patrolProgress(required:string[],confirmed:string[]):{complete:boolean;count:number};
export function workDraft(subject:string,kind:string):{subject:string;kind:string;state:string};
export function incidentDraft(subject:string,priority:string):{subject:string;priority:string;state:string};
export function delegatedRead(grant:Record<string,unknown>|null,request:Record<string,unknown>|null,now:number):boolean;

export function siteEligibility(plan:string,count:number):"denied"|"eligible_pending_quotas";
export function deviceHealth(report:Record<string,unknown>|null,now:number):string;
export function fireAlarmView(report:Record<string,unknown>|null):string;
export function attendanceDraft(action:string,position:Record<string,unknown>|null,now:number):string;
export function maintenanceClosure(record:Record<string,unknown>|null):string;
export function subjectDelegatedRead(grant:Record<string,unknown>|null,request:Record<string,unknown>|null,now:number):boolean;
