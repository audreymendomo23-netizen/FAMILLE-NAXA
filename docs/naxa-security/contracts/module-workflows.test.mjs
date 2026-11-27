import test from "node:test";import assert from "node:assert/strict";import{modules,evaluate,summarizeIncidents,csv,matchesReceipt,evidenceHash}from "../../../apps/web/naxa-security/src/module-workflows.mjs";
const selected=modules.filter(m=>!process.env.SECURITY_BULK||m.bulk===process.env.SECURITY_BULK);
for(const m of selected){
 const valid=Object.fromEntries(m.fields.map((k,i)=>[k,m.example[i]]));
 test(m.id+" valid workflow",()=>assert.equal(evaluate(m.id,valid).module,m.id));
 test(m.id+" rejects unexpected privilege field",()=>assert.throws(()=>evaluate(m.id,{...valid,approved:"yes"})));
 if(m.fields.length)test(m.id+" missing field denied",()=>{const x={...valid};delete x[m.fields[0]];assert.throws(()=>evaluate(m.id,x))});
}
if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK==="B6"){
 test("receipt scope",()=>{const b={request_id:"a",reporter_id:"b",organization_id:"c",site_id:"d",kind:"support",payload:{category:"technical",detail:"test"}};assert.equal(matchesReceipt({...b,state:"requested"},b),true);assert.equal(matchesReceipt({...b,state:"requested",site_id:"x"},b),false)});
 test("local digest",async()=>assert.equal(await evidenceHash(new TextEncoder().encode("abc").buffer),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"));
}
if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK==="B5"){
 test("CSV formula protection",()=>assert.equal(csv([["=1+1"]]),"\"'=1+1\""));
 test("real row aggregation",()=>assert.deepEqual(summarizeIncidents([{priority:"P1",state:"closed"},{priority:"P2",state:"new"}]),{total:2,closed:1,open:1,priorities:{P1:1,P2:1,P3:0,P4:0,unknown:0}}));
}
if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK==="B2")test("no media without consent",()=>assert.throws(()=>evaluate("NS-02",{device:"cam-01",purpose:"inspection",consent:"no"})));
if(!process.env.SECURITY_BULK||process.env.SECURITY_BULK==="B1")test("negative payment denied",()=>assert.throws(()=>evaluate("NS-24",{reference:"txn",amount:"-1",channel:"bank"})));
