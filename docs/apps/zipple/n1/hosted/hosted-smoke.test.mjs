import test from "node:test";
import assert from "node:assert/strict";
const base="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-n1";
async function request(path,body,headers={}){
 const r=await fetch(base+path,{method:"POST",headers:{"Content-Type":"application/json",...headers},body:JSON.stringify(body),redirect:"error",signal:AbortSignal.timeout(20000)});
 const data=await r.json();
 assert.ok(r.headers.get("cache-control")?.split(",").map(v=>v.trim()).includes("no-store"),"no-store required");
 return {status:r.status,data};
}
test("hosted Edge rejects untrusted calls",async()=>{
 assert.deepEqual(await request("/login",{app_id:"NAXA_SERVICES",identifier:"unused",password:"unused"}),{status:403,data:{error:"DENIED"}});
 assert.deepEqual(await request("/login",{app_id:"ZIPPLE",identifier:"",password:""}),{status:400,data:{error:"INVALID"}});
 assert.deepEqual(await request("/login",{app_id:"ZIPPLE",identifier:"unused",password:"unused"},{origin:"https://untrusted.example.invalid"}),{status:403,data:{error:"DENIED"}});
 assert.deepEqual(await request("/logout",{app_id:"ZIPPLE"}),{status:401,data:{error:"DENIED"}});
 assert.deepEqual(await request("/admin/recovery/list",{app_id:"ZIPPLE"}),{status:403,data:{error:"DENIED"}});
 assert.deepEqual(await request("/sync",{app_id:"ZIPPLE",aggregate_type:"sale"}),{status:403,data:{error:"DENIED"}});
 assert.deepEqual(await request("/refresh",{app_id:"ZIPPLE",refresh_token:"invalid-synthetic-refresh-token-for-n1"}),{status:401,data:{error:"DENIED"}});
 assert.deepEqual(await request("/sync",{app_id:"ZIPPLE",aggregate_type:"n1_probe",event_id:"invalid-synthetic-event",organization_id:"1f68a6e8-9d60-4aa7-a146-2c7834f04bc1",member_id:"2f68a6e8-9d60-4aa7-a146-2c7834f04bc1",site_id:"3f68a6e8-9d60-4aa7-a146-2c7834f04bc1",sequence:1,payload:{probe:true}},{authorization:"Bearer invalid-synthetic-access-token"}),{status:403,data:{error:"DENIED"}});
 console.log("ZIPPLE_HOSTED_EDGE_FAIL_CLOSED_PASS");
});
test("hosted recovery generic acknowledgement for synthetic unknown identifier",async()=>{
 const id="zipple-ci-unknown-"+Date.now();
 assert.deepEqual(await request("/recovery",{app_id:"ZIPPLE",identifier:id}),{status:202,data:{accepted:true}});
 console.log("ZIPPLE_HOSTED_RECOVERY_RPC_PASS");
});
