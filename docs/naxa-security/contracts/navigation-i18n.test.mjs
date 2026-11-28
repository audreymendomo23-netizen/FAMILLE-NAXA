import test from "node:test";import assert from "node:assert/strict";import{readFileSync}from"node:fs";import{englishTitles,screenTitle,englishTabs}from"../../../apps/web/naxa-security/src/navigation-i18n.mjs";
if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK==="B1"){
 const registry=JSON.parse(readFileSync(new URL("../../../apps/web/naxa-security/src/screens.json",import.meta.url),"utf8"));
 test("all 181 registered navigation titles translated",()=>{assert.equal(registry.length,181);assert.equal(Object.keys(englishTitles).length,181);for(const s of registry){assert.ok(englishTitles[s.id]);assert.equal(screenTitle(s,"fr"),s.title);assert.equal(screenTitle(s,"en"),englishTitles[s.id])}});
 test("five translated tabs, explicit French fallback",()=>{assert.equal(Object.keys(englishTabs).length,5);assert.equal(screenTitle({id:"B1.02",title:"Bienvenue"},"ff-CM"),"Bienvenue")});
}
