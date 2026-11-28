import {classifyQualification} from "./qualification-status.mjs";
import {readFile,mkdir,writeFile,appendFile} from "node:fs/promises";
import {execFileSync,spawnSync} from "node:child_process";
const baseline=process.env.GITHUB_SHA;
if(!/^[0-9a-f]{40}$/.test(baseline??""))throw Error("Missing exact candidate SHA");
const matrix=JSON.parse(await readFile("docs/naxa-services/NAXA_SERVICES_GLOBAL_QUALIFICATION_2026-11-27.json","utf8"));
const jobs={
  "replay": {
    "workflow": "naxa-services-replay-isolated.yml",
    "name": "Real GoTrue sessions, Storage and tenant isolation"
  },
  "finance": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "NAXA SERVICES payment, commission and fiscal policy tests"
  },
  "web": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "NAXA SERVICES Web build"
  },
  "android": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "Assemble NAXA SERVICES Android debug APK"
  },
  "sql": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "NAXA SERVICES PostgreSQL 17 schema and runtime RLS tests"
  },
  "inventory": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "Cross-application offline synchronization contract"
  },
  "media": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "NAXA SERVICES media token security contract"
  },
  "push": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "NAXA SERVICES remote notifications and FCM contract"
  },
  "promo": {
    "workflow": "naxa-services-technical-gate.yml",
    "name": "NAXA SERVICES customer referral and promotion contract"
  },
  "reboot": {
    "workflow": "naxa-services-independent-reserves.yml",
    "name": "actual-emulator-reboot"
  },
  "pwa": {
    "workflow": "naxa-services-independent-reserves.yml",
    "name": "hosted-pwa"
  },
  "backup": {
    "workflow": "naxa-services-backup-restore.yml",
    "name": "PostgreSQL 17 encrypted backup and clean restore"
  },
  "build": {
    "workflow": "naxa-services-cloudflare-preflight.yml",
    "name": "production-web-build"
  },
  "edge": {
    "workflow": "naxa-services-cloudflare-preflight.yml",
    "name": "hosted-edge-preflight"
  },
  "match": {
    "workflow": "naxa-services-cloudflare-preflight.yml",
    "name": "cloudflare-live-match"
  },
  "apk": {
    "workflow": "naxa-services-hosted-device-test.yml",
    "name": "hosted-debug"
  },
  "signer": {
    "workflow": "naxa-services-release-readiness.yml",
    "name": "release-readiness"
  }
};
const evidence={
  "B1-01": [
    {
      "job": "replay",
      "markers": [
        "PASS real subordinate roles: no organization offline grant",
        "PASS B4 payroll role site_manager / other site"
      ]
    }
  ],
  "B1-02": [
    {
      "job": "replay",
      "markers": [
        "PASS two browser accounts: published roster",
        "PASS Bulk B1 real browser: roster lost response exact retry",
        "PASS Bulk B1 real browser: leave request, conflict refusal, atomic substitute"
      ]
    }
  ],
  "B1-03": [
    {
      "job": "reboot",
      "markers": []
    }
  ],
  "B1-04": [
    {
      "job": "replay",
      "markers": [
        "PASS real offline customer creation",
        "PASS real offline recovery after durable commit",
        "PASS real offline scope proof B/C"
      ]
    }
  ],
  "B1-05": [
    {
      "job": "replay",
      "markers": [
        "PASS expired staged attendance rejected",
        "PASS Bulk B real stage retry immutable UUID/time",
        "PASS commercial proof review"
      ]
    }
  ],
  "B1-06": [
    {
      "job": "replay",
      "markers": [
        "PASS expired staged attendance rejected"
      ]
    }
  ],
  "B1-07": [
    {
      "job": "apk",
      "markers": []
    }
  ],
  "B2-01": [
    {
      "job": "replay",
      "markers": [
        "PASS real browser recurring series, lost acknowledgement retry",
        "PASS two browser accounts: initial agenda, RSVP"
      ]
    }
  ],
  "B2-02": [
    {
      "job": "replay",
      "markers": [
        "PASS real media authorization: host/guest bound to one room",
        "PASS two browser accounts: initial agenda, RSVP, language preference, chat, hand, reaction, moderator restriction"
      ]
    }
  ],
  "B2-03": [
    {
      "job": "media",
      "markers": []
    }
  ],
  "B2-04": [
    {
      "job": "media",
      "markers": []
    }
  ],
  "B2-05": [
    {
      "job": "apk",
      "markers": []
    }
  ],
  "B3-01": [
    {
      "job": "replay",
      "markers": [
        "PASS two browser accounts: initial agenda, RSVP, language preference, chat, hand, reaction, moderator restriction and recording consent withdrawal; no media capture"
      ]
    }
  ],
  "B3-02": [
    {
      "job": "replay",
      "markers": [
        "PASS two browser accounts: initial agenda, RSVP"
      ]
    }
  ],
  "B3-03": [],
  "B3-04": [],
  "B3-05": [],
  "B3-06": [
    {
      "job": "replay",
      "markers": [
        "PASS B3 historical daily briefing: previous day, scope isolation, cleared old report and FR/EN labels"
      ]
    }
  ],
  "B3-07": [
    {
      "job": "replay",
      "markers": [
        "PASS real scoped partial briefing text and language selection",
        "PASS B3 private server report archive: create, read, cross-member denial and delete","PASS B3 scoped period questions: exact completed count and no personal finance","PASS B3 private archive notification: one owner inbox record, redacted payload","PASS B3 annual authorized period, exact dates, no personal finance and oversized range refused"
      ]
    }
  ],
  "B3-08": [
    {
      "job": "apk",
      "markers": []
    }
  ],
  "B4-01": [
    {
      "job": "replay",
      "markers": [
        "PASS B4 real Chromium exhaustive profile/mode matrix: 39/39 complete lifecycles",
        "PASS B4 finance: five document types",
        "PASS B4 stock transfer:",
        "PASS B4 loyalty:",
        "PASS B4 objective:",
        "PASS B4 charges:",
        "PASS B4 appointments:"
      ]
    }
  ],
  "B4-02": [
    {
      "job": "finance",
      "markers": [
        "# pass ",
        "# fail 0"
      ]
    },
    {
      "job": "replay",
      "markers": [
        "PASS B4 payroll role network_manager / source / manage=true permissions verified",
        "PASS B4 payroll role site_manager / source / manage=true permissions verified",
        "PASS B4 payroll role workstation_manager / source / manage=false permissions verified",
        "PASS B4 payroll role receptionist / source / manage=false permissions verified",
        "PASS B4 payroll role hair_stylist / source / manage=false permissions verified",
        "PASS B4 payroll role pressing_operator / source / manage=false permissions verified",
        "PASS B4 payroll role stock_manager / source / manage=false permissions verified",
        "PASS B4 payroll role accountant / source / manage=false permissions verified",
        "PASS B4 payroll role site_manager / other site / manage=true permissions verified",
        "PASS B4 payroll role site_manager / source / manage=false permissions verified"
      ]
    }
  ],
  "B4-03": [{"job":"finance","markers":["# fail 0"]},{"job":"sql","markers":["PASS: automatic commission configuration, promoter scope, default disabled, explicit rates, exact retry, overlap, retirement and no ledger mutation","PASS: commission scope site member service activity, no applicable policy, overlap rejection and exact scoped calculation"]},{"job":"replay","markers":["PASS B4 real browser commission configuration: default disabled, promoter approval, employee denied, retirement and disable"]}],
  "B4-04": [{"job":"sql","markers":["PASS: transverse operational cockpit, commission approval, exact replay and confirmed full refund adjustment","PASS: explicit multiline commission allocation, two executors, exact replay, scoped approval and no duplicate","PASS: deferred explicit commission plan, unpaid wait, completion and payment recheck, one pending entry and exact replay","PASS: commission event worker, unpaid wait, completion and payment wakeup, one pending entry and idempotent drain","PASS: commission event reservation and revoked promoter block without ledger mutation","PASS: explicit same-line commission shares, exact sum, worker settlement and scoped approval","PASS: explicit partial refund allocation, immutable adjustments, exact retry and final balance reversal","PASS: pressing completion and direct confirmed payment, automatic ledger without fictitious sale or appointment"]},{"job":"finance","markers":["# fail 0"]}],
  "B4-05": [
    {
      "job": "web",
      "markers": []
    },
    {
      "job": "android",
      "markers": []
    },
    {
      "job": "replay",
      "markers": [
        "PASS B4 peer sync: second device settlement"
      ]
    }
  ],
  "B4-06": [
    {
      "job": "apk",
      "markers": []
    }
  ],
  "B4-07": [],
  "B5-01": [
    {
      "job": "edge",
      "markers": []
    }
  ],
  "B5-02": [
    {
      "job": "replay",
      "markers": [
        "PASS official Auth Admin first promoter bootstrap"
      ]
    }
  ],
  "B5-03": [
    {
      "job": "finance",
      "markers": []
    },
    {
      "job": "replay",
      "markers": [
        "PASS real JWT MTN and Orange intent lifecycle"
      ]
    }
  ],
  "B5-04": [
    {
      "job": "push",
      "markers": []
    },
    {
      "job": "replay",
      "markers": [
        "PASS real notification registration, encryption, inbox, revocation; no FCM send"
      ]
    }
  ],
  "B5-05": [],
  "B5-06": [
    {
      "job": "backup",
      "markers": [
        "PASS: refusal of unapproved target",
        "Restore verified structurally into database:",
        "NAXA SERVICES schema, restored permissions and runtime regression drill passed."
      ]
    }
  ],
  "B5-07": [
    {
      "job": "backup",
      "markers": []
    }
  ],
  "B5-08": [
    {
      "job": "build",
      "markers": []
    },
    {
      "job": "match",
      "markers": [
        "All files in the exact candidate match the immutable deployment URL.",
        "Stable Pages alias matches candidate shell."
      ]
    },
    {
      "job": "edge",
      "markers": [
        "auth: official status=204",
        "auth: foreign status=204",
        "accounting: official status=204",
        "accounting: foreign status=204",
        "referrals: official status=204",
        "referrals: foreign status=204",
        "customer-promotions: official status=204",
        "customer-promotions: foreign status=204",
        "notifications: official status=204",
        "notifications: foreign status=204"
      ]
    }
  ],
  "B5-09": [
    {
      "job": "promo",
      "markers": []
    },
    {
      "job": "replay",
      "markers": [
        "PASS R19-R21: all three actual gateways admit the unlocked promoter"
      ]
    }
  ],
  "B6-01": [
    {
      "job": "inventory",
      "markers": [
        "Commercial audit:",
        "Locale resource parity FR/EN/ff-CM:"
      ]
    }
  ],
  "B6-02": [],
  "B6-03": [
    {
      "job": "pwa",
      "markers": [
        "PASS hosted PWA shell and offline navigation at 320px",
        "PASS hosted PWA shell and offline navigation at 390px",
        "PASS hosted PWA shell and offline navigation at 1440px"
      ]
    }
  ],
  "B6-04": [
    {
      "job": "sql",
      "markers": [
        "PASS: strict site scope",
        "PASS: 22 callable SECURITY DEFINER functions reject unbound authenticated identity"
      ]
    },
    {
      "job": "web",
      "markers": []
    },
    {
      "job": "android",
      "markers": []
    }
  ],
  "B6-05": [
    {
      "job": "apk",
      "markers": []
    }
  ],
  "B6-06": [
    {
      "job": "signer",
      "markers": [
        "Approved signer certificate matches; no release signed."
      ]
    }
  ],
  "B6-07": []
};
const direct={
  "B4-02": [
    [
      "node",
      "--test",
      "packages/finance-core/test/finance.test.js"
    ]
  ],
  "B4-03": [
    [
      "node",
      "--test",
      "--test-name-pattern=commission",
      "packages/finance-core/test/finance.test.js"
    ]
  ],
  "B4-04": [
    [
      "node",
      "--test",
      "--test-name-pattern=commission|reversal",
      "packages/finance-core/test/finance.test.js"
    ]
  ],
  "B5-03": [
    [
      "node",
      "--test",
      "--test-name-pattern=payment|provider",
      "packages/finance-core/test/finance.test.js"
    ]
  ],
  "B6-01": [
    [
      "node",
      "scripts/naxa-services/audit-commercial-interactions.mjs"
    ]
  ]
};
const repo=process.env.GITHUB_REPOSITORY;
if(!repo||!process.env.GH_TOKEN)throw Error("GitHub context required");
const api=(path)=>execFileSync("gh",["api",...(path.endsWith("/logs")?["--allow-escape-sequences"]:[]),path],{encoding:"utf8",maxBuffer:40*1024*1024,timeout:60000});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const branch="work/naxa-services-completion-20261120";
const proofFile="artifacts/candidate-evidence/evidence.json";
if(process.env.NS_COLLECT==="true"){
 const runIds={}, found={}, sources={};
 const groups=[...new Set(Object.values(jobs).map(j=>j.workflow))];
 // One collector polls each source, not 43 independent API polling loops.
 for(let attempt=0;attempt<85;attempt++){
  for(const workflow of groups){
   if(Object.keys(jobs).filter(k=>jobs[k].workflow===workflow).every(k=>found[k]?.status==="completed"))continue;
   try{
    if(!runIds[workflow]){
     const runs=JSON.parse(api("repos/"+repo+"/actions/workflows/"+workflow+"/runs?head_sha="+baseline+"&branch="+encodeURIComponent(branch)+"&per_page=10")).workflow_runs;
     const run=runs.find(r=>r.head_sha===baseline&&r.head_branch===branch);
     if(!run)continue;runIds[workflow]=run.id;
    }
    const list=JSON.parse(api("repos/"+repo+"/actions/runs/"+runIds[workflow]+"/jobs?per_page=100&filter=latest")).jobs;
    for(const [key,j] of Object.entries(jobs))if(j.workflow===workflow){
     const match=list.find(x=>x.name===j.name&&x.head_sha===baseline&&x.run_id===runIds[workflow]);
     if(match)found[key]=match;
    }
   }catch(e){console.log("Source lookup deferred:",workflow,String(e.message).slice(0,160));}
  }
  if(Object.keys(jobs).every(k=>found[k]?.status==="completed"))break;
  if(attempt<84)await sleep(30000);
 }
 for(const [key,j] of Object.entries(jobs)){
  const job=found[key],specs=Object.values(evidence).flat().filter(s=>s.job===key);
  const requested=[...new Set(specs.flatMap(s=>s.markers))];
  const record={workflow:j.workflow,runId:runIds[j.workflow]??null,jobId:job?.id??null,status:job?.status==="completed"?job.conclusion:"PENDING_OR_MISSING",markers:{}};
  if(record.status==="success"&&requested.length){
   try{
    const raw=api("repos/"+repo+"/actions/jobs/"+job.id+"/logs");
    const output=raw.split("\n").filter(line=>!line.includes("\u001b[36;1m")).map(line=>line.replace(/^\d{4}-\d{2}-\d{2}T[^ ]+Z\s*/,"").trim());
    record.markers=Object.fromEntries(requested.map(m=>[m,output.some(l=>l.startsWith(m))]));
   }catch(e){record.status="EVIDENCE_ERROR";}
  }
  sources[key]=record;
 }
 await mkdir("artifacts/candidate-evidence",{recursive:true});
 await writeFile(proofFile,JSON.stringify({candidateCommit:baseline,branch,sources},null,2));
 console.log("Exact-SHA evidence collected",baseline,Object.keys(sources).length);
 process.exit(0);
}
const id=process.env.NS_CRITERION;
const item=matrix.items.find(x=>x.id===id);
if(!item||!Object.hasOwn(evidence,id)||matrix.items.length!==43)throw Error("Unknown criterion or incomplete matrix");
const result={id,title:item.title,acceptance:item.acceptance,classification:item.status,residual:item.residual??item.acceptance,campaignCommit:baseline,orchestrationCommit:baseline,checks:[],status:"UNVERIFIED"};
const proof=JSON.parse(await readFile(proofFile,"utf8"));
if(proof.candidateCommit!==baseline||proof.branch!==branch)throw Error("Evidence scope mismatch");
async function verify(spec){
 const s=proof.sources[spec.job];
 if(!s||s.workflow!==jobs[spec.job].workflow||s.status!=="success")return {source:spec.job,jobId:s?.jobId,status:s?.status??"MISSING",passed:false};
 const markers=spec.markers.map(m=>({marker:m,found:s.markers[m]===true}));
 return {source:spec.job,runId:s.runId,jobId:s.jobId,status:"SUCCESS",passed:markers.every(m=>m.found),markers};
}
try{
 for(const cmd of direct[id]??[]){
  const p=spawnSync(cmd[0],cmd.slice(1),{encoding:"utf8",timeout:120000});
  console.log(p.stdout??"");if(p.stderr)console.error(p.stderr);
  result.checks.push({direct:cmd.join(" "),passed:p.status===0});
 }
 const checks=await Promise.all(evidence[id].map(async spec=>{try{return await verify(spec)}catch(e){return {source:spec.job,passed:false,status:"EVIDENCE_ERROR",error:String(e.message).slice(0,300)}}}));
 result.checks.push(...checks);
 for(const check of checks)if(!check.passed)console.log(JSON.stringify({source:check.source,status:check.status,error:check.error??null,missingMarkers:check.markers?.filter(m=>!m.found).map(m=>m.marker)??[]}));
 Object.assign(result,classifyQualification(item.status,result.checks));
}catch(e){result.status="FAILED_OR_UNVERIFIED";result.error=String(e.message).slice(0,300);}
await mkdir("artifacts/individual-qualification",{recursive:true});
await writeFile("artifacts/individual-qualification/"+id+".json",JSON.stringify(result,null,2));
const summary="### "+id+" — "+result.status+"\n\n"+item.title+"\n\nCondition: "+item.acceptance+"\n\n"+result.checks.map(c=>"- "+(c.source??c.direct)+": "+(c.passed?"proof verified":"not verified")).join("\n")+"\n";
if(process.env.GITHUB_STEP_SUMMARY)await appendFile(process.env.GITHUB_STEP_SUMMARY,summary);
console.log(id,result.status);
if(result.status!=="PASS_SCOPED"){console.error("::error::"+id+" "+result.status+" — "+item.acceptance);process.exitCode=1;}
