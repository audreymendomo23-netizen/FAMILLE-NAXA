import test from "node:test";import assert from "node:assert/strict";import {quote,referralWave,qualifiesFirstPayment,entitlementDecision} from "./zipple-policy.mjs";
for(const [plan,m,a] of [["ACCESS",5000,50000],["PREMIUM",18000,180000]]){test(plan+" monthly",()=>{assert.equal(quote(plan,"monthly").amount,m);assert.equal(quote(plan,"monthly").serviceMonths,1)});test(plan+" annual",()=>{assert.equal(quote(plan,"annual").amount,a);assert.equal(quote(plan,"annual").serviceMonths,12)})}
for(const p of ["quarterly","semiannual","3","6",3,6,"",null])test("reject "+p,()=>assert.throws(()=>quote("ACCESS",p),RangeError));
test("reject unknown plan",()=>assert.throws(()=>quote("PRO","monthly"),RangeError));
for(const [n,w,p] of [[0,0,0],[4,0,4],[5,1,0],[9,1,4],[10,2,0]])test("wave "+n,()=>{const r=referralWave(n,"monthly");assert.equal(r.completedWaves,w);assert.equal(r.progress,p)});
const event={"appId":"ZIPPLE","serverVerified":true,"firstPaid":true,"status":"confirmed","amount":5000,"eventId":"evt","subscriptionId":"sub","referrerOrg":"a","referredOrg":"b"};
test("eligible",()=>assert.equal(qualifiesFirstPayment(event),true));
for(const patch of [{appId:"NAXA_SERVICES"},{serverVerified:false},{firstPaid:false},{status:"pending"},{amount:0},{referredOrg:"a"},{eventId:""},{subscriptionId:""}])test("reject "+JSON.stringify(patch),()=>assert.equal(qualifiesFirstPayment({...event,...patch}),false));
test("annual reward",()=>assert.equal(referralWave(5,"annual").rewardKind,"annual_extension_month"));
test("core inheritance",()=>{for(const f of ["workspace","catalog","orders","cash","inventory","accounting_integrity","support","export","professional_referral"])for(const p of ["ACCESS","PREMIUM"])assert.equal(entitlementDecision(p,f),"core")});
test("scope",()=>{assert.equal(entitlementDecision("ACCESS","multilevel_management"),"deny");assert.equal(entitlementDecision("PREMIUM","multilevel_management"),"eligible")});
test("unapproved",()=>assert.equal(entitlementDecision("PREMIUM","advanced_ai"),"requires_explicit_grant"));
