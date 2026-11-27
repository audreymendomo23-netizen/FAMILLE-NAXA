import assert from "node:assert/strict";
import {readFile,mkdir,writeFile} from "node:fs/promises";
const path="docs/naxa-services/NAXA_SERVICES_GLOBAL_QUALIFICATION_2026-11-27.json";
const matrix=JSON.parse(await readFile(path,"utf8"));
const expected=["technical-gate","replay-isolated","independent-reserves","backup-restore","cloudflare-preflight","hosted-device-test","release-readiness"];
assert.deepEqual(matrix.workflows,expected);
assert.equal(new Set(matrix.items.map(i=>i.id)).size,matrix.items.length);
for(const bulk of ["B1","B2","B3","B4","B5","B6"])assert.ok(matrix.items.some(i=>i.bulk===bulk));
for(const item of matrix.items){
 assert.ok(item.id.startsWith(item.bulk+"-"));
 assert.ok(expected.includes(item.workflow));
 assert.ok(Object.hasOwn(matrix.policy,item.status));
 assert.ok(item.title.length>0&&item.acceptance.length>20);
}
for(const name of expected){
 const yaml=await readFile(".github/workflows/naxa-services-"+name+".yml","utf8");
 const trigger=yaml.slice(0,yaml.indexOf("\npermissions:"));
 assert.ok(trigger.includes(path)&&trigger.includes("work/naxa-services-completion-20261120"),"Missing exact branch trigger "+name);
}
const release=await readFile(".github/workflows/naxa-services-release.yml","utf8");
assert.ok(!release.includes(path),"Commercial signing must not be triggered by qualification");
const count=Object.fromEntries(Object.keys(matrix.policy).map(s=>[s,matrix.items.filter(i=>i.status===s).length]));
await mkdir("artifacts/naxa-services-commercial",{recursive:true});
await writeFile("artifacts/naxa-services-commercial/global-qualification.json",JSON.stringify({commit:process.env.GITHUB_SHA??null,inventory:matrix,counts:count,qualification:"inventory only; actual run conclusions required"},null,2));
console.log("GLOBAL QUALIFICATION INVENTORY:",matrix.items.length,"criteria",JSON.stringify(count),"— NOT a global PASS");
