import test from "node:test";import assert from "node:assert/strict";import {freshOperatorTotp,createSupabaseZipple} from "./backend/adapter.mjs";
const now=1700000000,user={id:"operator"},claims={sub:"operator",role:"authenticated",aal:"aal2",session_id:"session",exp:now+100,amr:[{method:"totp",timestamp:now}]};
const jwt=c=>"eyJhbGciOiJIUzI1NiJ9."+Buffer.from(JSON.stringify(c)).toString("base64url")+".fixture";
test("operator MFA policy: fresh verified user, subject, session, method and expiry",()=>{
 assert.equal(freshOperatorTotp(user,jwt(claims),now),true);
 for(const c of [{aal:"aal1"},{sub:"other"},{role:"service_role"},{session_id:""},{exp:now},{is_anonymous:true},{amr:[{method:"password",timestamp:now}]},{amr:[{method:"totp",timestamp:now-601}]},{amr:[{method:"totp",timestamp:now+31}]}])assert.equal(freshOperatorTotp(user,jwt({...claims,...c}),now),false);
 assert.equal(freshOperatorTotp(null,jwt(claims),now),false);assert.equal(freshOperatorTotp(user,"opaque",now),false);
});
test("unverified token and single-factor operator never reach administrative RPC",async()=>{
 let rpc=0;
 const gateway=createSupabaseZipple({url:"https://fixture.test",anonKey:"test-anon",serviceKey:"test-only",fetcher:async(url)=>{if(url.endsWith("/auth/v1/user"))return Response.json({id:"operator"});rpc++;return Response.json([])}});
 const res=await gateway(new Request("https://fixture.test/admin/recovery/list",{method:"POST",headers:{authorization:"Bearer "+jwt({...claims,aal:"aal1"})},body:JSON.stringify({app_id:"ZIPPLE"})}));
 assert.equal(res.status,403);assert.equal(rpc,0);
 const denied=createSupabaseZipple({url:"https://fixture.test",anonKey:"test-anon",serviceKey:"test-only",fetcher:async(url)=>{if(url.endsWith("/auth/v1/user"))return Response.json({}, {status:401});rpc++;return Response.json([])}});
 const res2=await denied(new Request("https://fixture.test/admin/recovery/list",{method:"POST",headers:{authorization:"Bearer "+jwt({...claims,exp:Date.now()/1000+100,amr:[{method:"totp",timestamp:Date.now()/1000}]})},body:JSON.stringify({app_id:"ZIPPLE"})}));
 assert.equal(res2.status,403);assert.equal(rpc,0);
});
