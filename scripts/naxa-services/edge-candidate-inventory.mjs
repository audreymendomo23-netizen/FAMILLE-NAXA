// Read-only candidate inventory. Never contacts or deploys to a hosted project.
import {readFileSync,mkdirSync,writeFileSync} from "node:fs";
import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import assert from "node:assert/strict";
const root=new URL("../../",import.meta.url);
const report=JSON.parse(readFileSync(new URL("docs/naxa-services/EDGE_SOURCE_PARITY_2026-11-27.json",root),"utf8"));
const names=["auth","accounting","referrals","customer-promotions","notifications"];
assert.match(report.repositoryCommit,/^[0-9a-f]{40}$/);
assert.deepEqual(report.functions.map(f=>f.slug).sort(),names.map(n=>"naxa-services-"+n).sort());
const records=[...report.functions.map(f=>({slug:f.slug,path:f.slug+"/index.ts",equal:f.equal})),...report.dependencies.map(d=>({...d,slug:"naxa-services-"+d.slug}))];
assert.equal(new Set(records.map(r=>r.slug+":"+r.path)).size,records.length);
const rows=records.map(r=>{
 assert.ok(names.some(n=>r.slug==="naxa-services-"+n));
 assert.ok(typeof r.equal==="boolean"&&/^(?:_shared|naxa-services-[a-z-]+)\/[a-zA-Z0-9_-]+\.ts$/.test(r.path));
 const source=readFileSync(new URL("supabase/functions/"+r.path,root),"utf8").replace(/\r\n/g,"\n").trim();
 assert.ok(source.length>0);
 return {bundle:r.slug,path:r.path,historicalEqual:r.equal,candidateSha256:createHash("sha256").update(source).digest("hex")};
});
const candidateCommit=execFileSync("git",["rev-parse","HEAD"],{cwd:fileURLToPath(root),encoding:"utf8"}).trim();
assert.match(candidateCommit,/^[0-9a-f]{40}$/);
if(process.env.GITHUB_SHA)assert.equal(candidateCommit,process.env.GITHUB_SHA,"candidate checkout must match workflow SHA");
const output=JSON.stringify({candidateCommit,historicalComparisonCommit:report.repositoryCommit,occurrences:rows.length,historicalDifferences:rows.filter(r=>!r.historicalEqual).length,hostedParity:"NOT_VERIFIED",deployment:"NOT_AUTHORIZED_BY_THIS_CHECK",rows},null,2);
const dir=new URL("artifacts/naxa-services-commercial/",root);mkdirSync(dir,{recursive:true});writeFileSync(new URL("edge-candidate-inventory.json",dir),output+"\n");console.log(output);
