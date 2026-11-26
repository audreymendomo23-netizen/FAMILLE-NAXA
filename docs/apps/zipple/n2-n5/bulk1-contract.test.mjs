import test from "node:test";import assert from "node:assert/strict";import {readFileSync} from "node:fs";
import {quote,entitlementDecision} from "../contracts/zipple-policy.mjs";
const read=p=>readFileSync(new URL(p,import.meta.url),"utf8");
const parseSet=(source,pattern)=>{const match=source.match(pattern);assert.ok(match);return [...match[1].matchAll(/"([a-z_]+)"/g)].map(m=>m[1]).sort()};
test("professional Android and server action allowlists are identical, consumer and privileged actions excluded",()=>{
 const gateway=read("./business-gateway.mjs"),android=read("../../../../apps/android/zipple/src/main/java/cm/naxa/zipple/ZippleBusiness.kt");
 const server=parseSet(gateway,/const professionalActions=new Set\(\[(.*?)\]\)/s),native=parseSet(android,/private val actions=setOf\((.*?)\)/s);
 assert.deepEqual(native,server);assert.equal(new Set(server).size,server.length);assert.ok(!server.includes("confirm_subscription"));assert.ok(!server.includes("guest_open"));
 const guest=parseSet(gateway,/const publicActions=new Set\(\[(.*?)\]\)/s);assert.ok(guest.every(x=>!server.includes(x)));
});
test("all commercial SQL prices match canonical family-approved policy without invented quotas",()=>{
 const sql=read("./schema.sql"),policy=JSON.parse(read("../POLITIQUE_COMMERCIALE_ZIPPLE.json"));
 const rows=[...sql.matchAll(/\('(ACCESS|PREMIUM)','(monthly|annual)',(\d+),(\d+)\)/g)];assert.equal(rows.length,4);
 for(const [,plan,period,amount,months] of rows){assert.equal(Number(amount),quote(plan,period).amount);assert.equal(Number(months),quote(plan,period).serviceMonths);assert.equal(Number(amount),policy.plans[plan][period]);}
 assert.equal(policy.entitlements.detailedLimits,"pending_explicit_approval");assert.equal(entitlementDecision("PREMIUM","advanced_ai"),"requires_explicit_grant");
});
