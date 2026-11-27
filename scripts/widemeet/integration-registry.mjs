import {readFileSync,writeFileSync} from "node:fs";
import assert from "node:assert/strict";
const registry=readFileSync("docs/widemeet/REGISTRE_RECETTES_ACTIONS_B1_B6.md","utf8");
const expected=new Set(registry.match(/B[1-6]\.\d+-[AR]\d+/g)||[]);
const all=[];
for(let n=1;n<=7;n++){
 const wave=JSON.parse(readFileSync("scripts/widemeet/qualification-wave-"+String(n).padStart(2,"0")+".json","utf8"));
 assert.equal(wave.wave,n);assert.equal(wave.entries.length,wave.total);
 all.push(...wave.entries);
}
const ids=new Set(all.map(x=>x.id));
assert.equal(all.length,315);assert.equal(ids.size,315);assert.equal(expected.size,315);
assert.deepEqual([...ids].sort(),[...expected].sort());
const recipes=all.filter(x=>x.kind==="recipe"),actions=all.filter(x=>x.kind==="action");
assert.equal(recipes.length,269);assert.equal(actions.length,46);
const report={sha:process.env.GITHUB_SHA||"local",registry:ids.size,actions:actions.length,recipes:recipes.length,mapped:recipes.filter(x=>x.markers?.length).length,unmapped:recipes.filter(x=>!x.markers?.length).length,entries:all.map(x=>({id:x.id,kind:x.kind,status:"NOT_EVALUATED_ON_INTEGRATED_SHA",markers:x.markers||[]}))};
writeFileSync(process.argv[2]||"widemeet-integration-registry.json",JSON.stringify(report,null,2));
console.log("PASS exact 315 unique registry entries, 46 actions and 269 scenarios; no qualification inferred");
