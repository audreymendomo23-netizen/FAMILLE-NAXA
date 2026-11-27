import test from "node:test";import assert from "node:assert/strict";import {quote,freshness,alarmPriority,commandState,positionEvidence,patrolProgress,workDraft,incidentDraft,delegatedRead} from "../../../apps/web/naxa-security/src/domain.mjs";
const now=1000000;const p={lat:4,lon:9,accuracy:10,mock:false,observed:now};const g={app:"zipple",organization:"o",site:"s",resource:"r",operation:"read",active:true,expires:now+100};
const cases=[
["B1","essential annual",()=>assert.equal(quote("Essentiel","annual"),60000)],["B1","business annual",()=>assert.equal(quote("Business","annual"),200000)],["B1","professional monthly",()=>assert.equal(quote("Professional","monthly"),50000)],["B1","unknown plan",()=>assert.throws(()=>quote("Other","annual"))],["B1","unsupported period",()=>assert.throws(()=>quote("Essentiel","quarter"))],
["B2","fresh event",()=>assert.equal(freshness(now-100,now),"fresh")],["B2","stale event",()=>assert.equal(freshness(now-120001,now),"unknown")],["B2","future event",()=>assert.equal(freshness(now+1,now),"unknown")],["B2","missing timestamp",()=>assert.equal(freshness(null,now),"unknown")],
["B3","fire critical",()=>assert.equal(alarmPriority("fire_panel","alarm"),"P1")],["B3","smoke alarm critical",()=>assert.equal(alarmPriority("smoke_detector","alarm"),"P1")],["B3","fault review",()=>assert.equal(alarmPriority("fire_panel","fault"),"review")],["B3","sent not executed",()=>assert.equal(commandState({authorized:true,sent:true,expires:now+1},now),"sent")],["B3","ack not executed",()=>assert.equal(commandState({authorized:true,acknowledged:true,expires:now+1},now),"acknowledged")],["B3","expired",()=>assert.equal(commandState({authorized:true,sent:true,expires:now},now),"expired")],["B3","unverified execution",()=>assert.equal(commandState({authorized:true,executed:true,expires:now+1},now),"authorized")],["B3","verified execution",()=>assert.equal(commandState({authorized:true,executed:true,verified:true,executedAt:now-1,expires:now+1},now),"executed")],["B3","manual report",()=>assert.equal(incidentDraft(" incident ","P2").subject,"incident")],["B3","manual P1 rejected",()=>assert.throws(()=>incidentDraft("incident","P1"))],
["B4","position pending",()=>assert.equal(positionEvidence(p,now),"pending_review")],["B4","mock rejected",()=>assert.equal(positionEvidence({...p,mock:true},now),"rejected")],["B4","accuracy rejected",()=>assert.equal(positionEvidence({...p,accuracy:101},now),"rejected")],["B4","stale rejected",()=>assert.equal(positionEvidence({...p,observed:now-120001},now),"rejected")],["B4","missing checkpoint",()=>assert.equal(patrolProgress(["a","b"],["a","a"]).complete,false)],["B4","complete checkpoint list",()=>assert.equal(patrolProgress(["a","b"],["b","a"]).complete,true)],["B4","empty patrol",()=>assert.equal(patrolProgress([],[]).complete,false)],
["B5","maintenance draft",()=>assert.equal(workDraft(" pompe ","corrective").state,"draft")],["B5","empty subject",()=>assert.throws(()=>workDraft(" ","inspection"))],["B5","unknown kind",()=>assert.throws(()=>workDraft("x","other"))],["B5","long subject",()=>assert.throws(()=>workDraft("x".repeat(501),"preventive"))],
["B6","exact delegation",()=>assert.equal(delegatedRead(g,g,now),true)],["B6","cross site",()=>assert.equal(delegatedRead(g,{...g,site:"other"},now),false)],["B6","cross app",()=>assert.equal(delegatedRead(g,{...g,app:"bootik"},now),false)],["B6","expired",()=>assert.equal(delegatedRead(g,g,now+100),false)],["B6","write denied",()=>assert.equal(delegatedRead(g,{...g,operation:"write"},now),false)],["B6","revoked",()=>assert.equal(delegatedRead({...g,active:false},g,now),false)]];
for(const [bulk,name,fn] of cases)if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK===bulk)test(bulk+" "+name,fn);

import {siteEligibility,deviceHealth,fireAlarmView,attendanceDraft,maintenanceClosure,subjectDelegatedRead} from "../../../apps/web/naxa-security/src/domain.mjs";
const extra = [
["B1","one site eligible",()=>assert.equal(siteEligibility("Essentiel",1),"eligible_pending_quotas")],
["B1","essential rejects multisite",()=>assert.equal(siteEligibility("Essentiel",2),"denied")],
["B1","business no invented quota",()=>assert.equal(siteEligibility("Business",2),"eligible_pending_quotas")],
["B1","invalid site count",()=>assert.equal(siteEligibility("Professional",1.5),"denied")],
["B2","verified fresh device",()=>assert.equal(deviceHealth({verified:true,observed:now,status:"online"},now),"online")],
["B2","stale device unknown",()=>assert.equal(deviceHealth({verified:true,observed:now-120001,status:"online"},now),"unknown")],
["B2","unverified device unknown",()=>assert.equal(deviceHealth({verified:false,observed:now,status:"online"},now),"unknown")],
["B2","fault stays fault",()=>assert.equal(deviceHealth({verified:true,observed:now,status:"fault"},now),"fault")],
["B3","ack leaves alarm active",()=>assert.equal(fireAlarmView({verified:true,source:"fire_panel",signal:"alarm",acknowledged:true}),"alarm_acknowledged")],
["B3","restored needs inspection",()=>assert.equal(fireAlarmView({verified:true,source:"smoke_detector",signal:"restored"}),"restored_pending_inspection")],
["B3","unverified alarm unknown",()=>assert.equal(fireAlarmView({verified:false,source:"fire_panel",signal:"alarm"}),"unknown")],
["B3","evacuation active",()=>assert.equal(fireAlarmView({verified:true,source:"fire_panel",signal:"evacuation"}),"alarm_active")],
["B4","valid arrival remains pending",()=>assert.equal(attendanceDraft("arrival",p,now),"pending_server_review")],
["B4","mock departure rejected",()=>assert.equal(attendanceDraft("departure",{...p,mock:true},now),"rejected")],
["B4","unknown action rejected",()=>assert.equal(attendanceDraft("approve",p,now),"rejected")],
["B4","missing position rejected",()=>assert.equal(attendanceDraft("arrival",null,now),"rejected")],
["B5","report required",()=>assert.equal(maintenanceClosure({completionConfirmed:true,report:" "}),"incomplete")],
["B5","confirmation required",()=>assert.equal(maintenanceClosure({completionConfirmed:false,report:"Inspection"}),"incomplete")],
["B5","report enters review only",()=>assert.equal(maintenanceClosure({completionConfirmed:true,report:"Inspection"}),"ready_for_authorized_review")],
["B5","null order incomplete",()=>assert.equal(maintenanceClosure(null),"incomplete")],
["B6","subject scoped grant",()=>assert.equal(subjectDelegatedRead({...g,subject:"u",startsAt:now},{...g,subject:"u"},now),true)],
["B6","different subject denied",()=>assert.equal(subjectDelegatedRead({...g,subject:"u",startsAt:now},{...g,subject:"v"},now),false)],
["B6","future grant denied",()=>assert.equal(subjectDelegatedRead({...g,subject:"u",startsAt:now+1},{...g,subject:"u"},now),false)],
["B6","missing subject denied",()=>assert.equal(subjectDelegatedRead({...g,startsAt:now},g,now),false)]
];
for (const [bulk,name,fn] of extra) if (!process.env.SECURITY_BULK || process.env.SECURITY_BULK===bulk) test(bulk+" "+name,fn);
