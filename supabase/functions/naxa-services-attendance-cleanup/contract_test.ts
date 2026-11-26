import {cleanup} from "./contract.ts";
const path="20000000-0000-4000-8000-000000000091/30000000-0000-4000-8000-000000000091/60000000-0000-4000-8000-000000000092/70000000-0000-4000-8000-000000000190.jpg";
const env={url:"https://qa.example.invalid",key:"fixture-service-key-not-real",secret:"fixture-worker-secret-not-real-at-least-32",enabled:true};
const check=(v:unknown)=>{if(!v)throw Error("ASSERTION_FAILED");};
const req=(secret=env.secret)=>new Request("https://worker.example.invalid",{method:"POST",headers:{"x-ns-cleanup-secret":secret},body:JSON.stringify({bucket:"other",prefixes:["../../evil"]})});
Deno.test("disabled and unauthorized never touch storage",async()=>{
 const transport:typeof fetch=async()=>{throw Error("MUST_NOT_CALL");};
 check((await cleanup(req(),{...env,enabled:false},transport)).status===503);
 check((await cleanup(req("wrong"),env,transport)).status===403);
});
Deno.test("purge, inventory and fixed bucket API only; no caller paths",async()=>{
 const calls:string[]=[];
 const transport:typeof fetch=async(input,init)=>{const url=String(input);calls.push(url);
  if(url.endsWith("/ns_purge_expired_attendance_staging"))return Response.json(2);
  if(url.endsWith("/ns_attendance_orphan_candidates"))return Response.json([{object_name:path},{object_name:path}]);
  check(url.endsWith("/storage/v1/object/ns-attendance-selfies")&&init?.method==="DELETE");
  check(JSON.stringify(JSON.parse(String(init?.body)))===JSON.stringify({prefixes:[path]}));
  return Response.json([{name:path}]);
 };
 const r=await cleanup(req(),env,transport);const b=await r.json();check(r.status===200&&b.removed_files===1&&b.purged_staging===2&&calls.length===3);
});
Deno.test("invalid paths fail closed and partial deletion is not a success",async()=>{
 for(const invalid of [true,false]){
  let deletes=0;
  const transport:typeof fetch=async(input)=>{const url=String(input);
   if(url.endsWith("/ns_purge_expired_attendance_staging"))return Response.json(0);
   if(url.endsWith("/ns_attendance_orphan_candidates"))return Response.json([{object_name:invalid?"../evil.jpg":path}]);
   deletes++;return Response.json([]);
  };
  check((await cleanup(req(),env,transport)).status===502&&deletes===(invalid?0:1));
 }
});
