export function classifyQualification(classification,checks){
 if(!["replay","partial","development","external"].includes(classification)||!Array.isArray(checks))throw Error("Invalid qualification");
 const passing=checks.length>0&&checks.every(x=>x.passed===true);
 const evidenceStatus=checks.length===0?"NO_CHECKS":passing?"VERIFIED_SCOPED":"FAILED_OR_MISSING";
 const status=classification==="development"?"BLOCKED_DEVELOPMENT":classification==="external"?"BLOCKED_EXTERNAL":!passing?"FAILED_OR_UNVERIFIED":classification==="partial"?"PARTIAL_PROOF":"PASS_SCOPED";
 return {status,evidenceStatus,checksPassed:checks.filter(x=>x.passed===true).length,checksTotal:checks.length};
}
