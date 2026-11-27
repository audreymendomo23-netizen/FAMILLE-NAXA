import test from "node:test";
import assert from "node:assert/strict";
import {verifyCiToken} from "./push-ci-oidc.mjs";
const keys=await crypto.subtle.generateKey({name:"RSASSA-PKCS1-v1_5",modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},true,["sign","verify"]);
const jwk={...await crypto.subtle.exportKey("jwk",keys.publicKey),kid:"fixture",use:"sig",alg:"RS256"};
const now=Date.now(),sec=Math.floor(now/1000);
const scope={sha:"a".repeat(40),expiresAt:now+60000,audience:"https://fixture.invalid"};
const claims={iss:"https://token.actions.githubusercontent.com",aud:scope.audience,repository_id:"1457255045",repository_owner_id:"337470304",repository:"audreymendomo23-netizen/FAMILLE-NAXA",ref:"refs/heads/work/widemeet-n0-20261126",event_name:"push",sha:scope.sha,workflow_ref:"audreymendomo23-netizen/FAMILLE-NAXA/.github/workflows/widemeet-fcm-live.yml@refs/heads/work/widemeet-n0-20261126",runner_environment:"github-hosted",jti:"fixture-identity",iat:sec,nbf:sec-1,exp:sec+300};
const b64=o=>Buffer.from(JSON.stringify(o)).toString("base64url");
async function jwt(changes={},header={alg:"RS256",kid:"fixture"}){
 const data=b64(header)+"."+b64({...claims,...changes});const sig=await crypto.subtle.sign("RSASSA-PKCS1-v1_5",keys.privateKey,new TextEncoder().encode(data));return data+"."+Buffer.from(sig).toString("base64url");
}
let requests=0;const fetcher=async url=>{requests++;assert.equal(url,"https://token.actions.githubusercontent.com/.well-known/jwks");return new Response(JSON.stringify({keys:[jwk]}))};
test("CI FCM scope exact signature and claims",async()=>{assert.deepEqual(await verifyCiToken(await jwt(),scope,{now,fetcher}),{jti:"fixture-identity",sha:scope.sha});for(const change of [{sha:"b".repeat(40)},{aud:"foreign"},{event_name:"pull_request"},{repository_id:"0"},{repository_owner_id:"0"},{runner_environment:"self-hosted"},{workflow_ref:"other"},{exp:sec-1},{iat:sec+90},{nbf:sec+90}])assert.equal(await verifyCiToken(await jwt(change),scope,{now,fetcher}),null);assert.equal(await verifyCiToken(await jwt(),{...scope,expiresAt:now},{now,fetcher}),null);const token=await jwt(),[h,p,s]=token.split(".");assert.equal(await verifyCiToken(h+"."+p+"."+((s[0]==="A"?"B":"A")+s.slice(1)),scope,{now,fetcher}),null);assert.equal(await verifyCiToken(await jwt({}, {alg:"none",kid:"fixture"}),scope,{now,fetcher}),null);assert.ok(requests>=2)});
