import test from "node:test";import assert from "node:assert/strict";import {classifyQualification as c} from "./qualification-status.mjs";
const yes=[{passed:true}],no=[{passed:false}];
test("only nonempty passing replay qualifies",()=>{assert.equal(c("replay",yes).status,"PASS_SCOPED");for(const a of [[],no,[...yes,...no]])assert.equal(c("replay",a).status,"FAILED_OR_UNVERIFIED");});
test("partial or external proofs never promote",()=>{for(const [k,v] of [["partial","PARTIAL_PROOF"],["development","BLOCKED_DEVELOPMENT"],["external","BLOCKED_EXTERNAL"]]){assert.equal(c(k,yes).status,v);assert.equal(c(k,yes).evidenceStatus,"VERIFIED_SCOPED");}});
test("missing or invalid evidence is not green",()=>{assert.equal(c("partial",no).status,"FAILED_OR_UNVERIFIED");assert.equal(c("external",[]).evidenceStatus,"NO_CHECKS");assert.throws(()=>c("invented",yes));assert.throws(()=>c("replay",null));});
