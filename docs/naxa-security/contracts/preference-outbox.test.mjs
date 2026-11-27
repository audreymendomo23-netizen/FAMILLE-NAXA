import test from "node:test";import assert from "node:assert/strict";import{preferenceEvent,eventScope,eventBody,validPreferenceReceipt,samePending}from "../../../apps/web/naxa-security/src/preference-outbox.mjs";
const u=n=>"00000000-0000-0000-0000-"+String(n).padStart(12,"0"),scope={organization:u(1),site:u(2),user:u(3)},e=preferenceEvent(scope,"locale","en",u(4));
if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK==="B1"){
 test("only non-sensitive bounded preference data",()=>{assert.throws(()=>preferenceEvent(scope,"password","secret",u(4)));assert.throws(()=>preferenceEvent(scope,"locale","xx",u(4)));assert.deepEqual(e.payload,{locale:"en"});assert.equal(Object.hasOwn(eventBody(e),"token"),false)});
 test("scope includes actor, site and organization",()=>{assert.equal(eventScope(e,scope),true);for(const k of Object.keys(scope))assert.equal(eventScope(e,{...scope,[k]:u(5)}),false)});
 test("receipt must match all scope and payload",()=>{const v={...eventBody(e),state:"requested"};assert.equal(validPreferenceReceipt(e,v),true);assert.equal(validPreferenceReceipt(e,{...v,reporter_id:u(5)}),false);assert.equal(validPreferenceReceipt(e,{...v,payload:{locale:"fr"}}),false);assert.equal(validPreferenceReceipt(e,{...v,state:"failed"}),false)});
 test("same pending preference is idempotent, different value conflicts",()=>{assert.equal(samePending(e,preferenceEvent(scope,"locale","en",u(5))),true);assert.equal(samePending(e,preferenceEvent(scope,"locale","fr",u(5))),false)});
}
