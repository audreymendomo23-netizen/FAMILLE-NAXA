import {readFileSync,readdirSync,writeFileSync,appendFileSync} from "node:fs";
import {join} from "node:path";
import assert from "node:assert/strict";
const wave=JSON.parse(readFileSync(new URL("./qualification-wave-02.json",import.meta.url),"utf8"));
const reg=readFileSync(new URL("../../docs/widemeet/REGISTRE_RECETTES_ACTIONS_B1_B6.md",import.meta.url),"utf8");
assert.equal(wave.entries.length,50);assert.equal(new Set(wave.entries.map(e=>e.id)).size,50);
assert.equal(wave.entries.filter(e=>e.kind==="action").length,8);assert.equal(wave.entries.filter(e=>e.kind==="recipe").length,42);
for(const e of wave.entries)assert.ok(reg.includes("**"+e.id+" —"),e.id);
const [dir,out]=process.argv.slice(2),sha=process.env.GITHUB_SHA,receipts=[];
function visit(d){for(const f of readdirSync(d,{withFileTypes:true})){const p=join(d,f.name);if(f.isDirectory())visit(p);else if(f.name.endsWith(".jsonl"))for(const line of readFileSync(p,"utf8").split("\n").filter(Boolean)){const x=JSON.parse(line);assert.equal(x.sha,sha);assert.ok(["replay","sfu","audio"].includes(x.suite));receipts.push(x);}}}
visit(dir);
const states={replay:process.env.REPLAY,sfu:process.env.SFU,audio:process.env.AUDIO};
const entries=wave.entries.map(e=>{const found=(e.markers||[]).filter(m=>receipts.some(x=>x.suite===m.suite&&x.marker===m.marker));const full=e.complete&&found.length===e.markers.length&&found.length>0&&found.every(m=>states[m.suite]==="success");return {...e,status:e.kind==="action"?(e.specialized_candidate?"SPECIALIZED_CANDIDATE":"SELECTED_NOT_CLOSED"):full?"SUCCESS":found.length?"PARTIAL_EVIDENCE":e.markers?.length?"NOT_OBSERVED":"NOT_MAPPED",observed:found};});
writeFileSync(out,JSON.stringify({wave:2,sha,suite_results:states,entries},null,2)+"\n");
appendFileSync(process.env.GITHUB_STEP_SUMMARY,"\n### Wave 02 — individual evidence\n| ID | State | Markers observed |\n|---|---|---:|\n"+entries.map(e=>"| "+e.id+" | "+e.status+" | "+e.observed.length+" |").join("\n")+"\n");
