import {readFileSync,writeFileSync} from "node:fs";
import assert from "node:assert/strict";
const source=readFileSync(new URL("../../docs/widemeet/REGISTRE_RECETTES_ACTIONS_B1_B6.md",import.meta.url),"utf8");
const entries=[...source.matchAll(/^- \[ \] \*\*(B([1-6])\.\d+-(A|R)\d{2}) — (?:Action|Recette) :\*\* (.+)$/gm)].map((m)=>({id:m[1],bulk:"B"+m[2],kind:m[3]==="A"?"action":"recipe",description:m[4],status:"NOT_EVALUATED",evidence:[]}));
assert.equal(entries.length,315,"registry count");
assert.equal(new Set(entries.map(x=>x.id)).size,315,"unique IDs");
assert.equal(entries.filter(x=>x.kind==="recipe").length,269);
assert.equal(entries.filter(x=>x.kind==="action").length,46);
for(const [bulk,actions,recipes] of [["B1",7,45],["B2",9,60],["B3",7,37],["B4",7,42],["B5",6,30],["B6",10,55]]){
 const subset=entries.filter(e=>e.bulk===bulk);
 assert.equal(subset.filter(e=>e.kind==="action").length,actions);
 assert.equal(subset.filter(e=>e.kind==="recipe").length,recipes);
}
const dest=process.argv[2];assert.ok(dest,"output path required");
writeFileSync(dest,JSON.stringify({schema_version:1,revision:process.env.GITHUB_SHA??null,scope:"registry inventory only; no inferred execution result",entries},null,2)+"\n");
console.log("REGISTRY_INTEGRITY_PASS: 315 unique entries, 269 recipes, 46 actions; no recipe result inferred");
