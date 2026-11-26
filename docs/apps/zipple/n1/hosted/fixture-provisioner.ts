// One-run CI fixture, no user-supplied org, role, email or ID. Deployment pins expected SHA.
const expectedSha="__EXPECTED_SHA__";
const issuer="https://token.actions.githubusercontent.com",aud="zipple-n1-hosted-recipe";
const repo="audreymendomo23-netizen/FAMILLE-NAXA";
const workflow=repo+"/.github/workflows/zipple-n1-hosted-positive.yml@refs/heads/main";
const org="1f68a6e8-9d60-4aa7-a146-2c7834f04bc1",member="2f68a6e8-9d60-4aa7-a146-2c7834f04bc1",site="3f68a6e8-9d60-4aa7-a146-2c7834f04bc1";
const login="zipple-ci-n1-2c7834f04bc1",alias=login+"@example.test";
const base=Deno.env.get("SUPABASE_URL")!,key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const deny=()=>{throw Error("DENIED")};
const decode=(s:string)=>Uint8Array.from(atob(s.replace(/-/g,"+").replace(/_/g,"/").padEnd(Math.ceil(s.length/4)*4,"=")),c=>c.charCodeAt(0));
async function verified(token:string){
 if(token.length>12000)deny();
 const parts=token.split(".");if(parts.length!==3)deny();
 const h=JSON.parse(new TextDecoder().decode(decode(parts[0]))),c=JSON.parse(new TextDecoder().decode(decode(parts[1])));
 const now=Math.floor(Date.now()/1000);
 if(h.alg!=="RS256"||typeof h.kid!=="string"||c.iss!==issuer||c.aud!==aud||c.repository_id!=="1457255045"||c.repository_owner_id!=="337470304"||c.repository!==repo||c.workflow_ref!==workflow||c.sha!==expectedSha||c.ref!=="refs/heads/main"||c.event_name!=="push"||String(c.run_attempt)!=="1"||!Number.isInteger(c.exp)||!Number.isInteger(c.iat)||c.exp<=now||c.iat>now+30||c.iat<now-600||(c.nbf&&c.nbf>now+30))deny();
 const jwks=await fetch(issuer+"/.well-known/jwks",{redirect:"error",signal:AbortSignal.timeout(10000)});
 if(!jwks.ok)deny();const j=(await jwks.json()).keys.find((x:any)=>x.kid===h.kid&&x.kty==="RSA");if(!j)deny();
 const pub=await crypto.subtle.importKey("jwk",j,{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["verify"]);
 if(!await crypto.subtle.verify("RSASSA-PKCS1-v1_5",pub,decode(parts[2]),new TextEncoder().encode(parts[0]+"."+parts[1])))deny();
}
async function call(path:string,method="GET",body?:unknown){
 const r=await fetch(base+path,{method,headers:{apikey:key,authorization:"Bearer "+key,"content-type":"application/json"},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:"error",signal:AbortSignal.timeout(15000)});
 if(!r.ok)throw Error("UPSTREAM_"+r.status);
 const raw=await r.text();return raw?JSON.parse(raw):null;
}
const rest=(table:string,method="GET",body?:unknown,filter="")=>call("/rest/v1/"+table+filter,method,body);
async function cleanup(authId?:string){
 const rows=await rest("zp_members","GET",undefined,"?id=eq."+member+"&org_id=eq."+org+"&select=auth_user_id,login_id");
 if(rows.length){if(rows[0].login_id!==login)deny();authId=rows[0].auth_user_id;}
 const requests=await rest("zp_recovery_requests","GET",undefined,"?member_id=eq."+member+"&select=id");
 for(const row of requests)await rest("zp_recovery_audit","DELETE",undefined,"?request_id=eq."+row.id);
 for(const table of ["zp_recovery_requests","zp_sessions","zp_n1_receipts","zp_site_scopes"])await rest(table,"DELETE",undefined,"?member_id=eq."+member);
 await rest("zp_members","DELETE",undefined,"?id=eq."+member+"&org_id=eq."+org);
 await rest("zp_sites","DELETE",undefined,"?id=eq."+site+"&org_id=eq."+org);
 await rest("zp_organizations","DELETE",undefined,"?id=eq."+org);
 if(authId)await call("/auth/v1/admin/users/"+authId,"DELETE");
}
Deno.serve(async req=>{
 const response=(status:number,body:unknown)=>Response.json(body,{status,headers:{"cache-control":"no-store"}});
 try{
  if(req.method!=="POST"||!req.headers.get("authorization")?.startsWith("Bearer "))deny();
  await verified(req.headers.get("authorization")!.slice(7));
  const action=new URL(req.url).pathname.split("/").pop();
  if(action==="cleanup"){await cleanup();return response(200,{cleaned:true})}
  if(action!=="provision")deny();
  // Insert the unique organization first; replay or concurrent requests cannot create another identity.
  await rest("zp_organizations","POST",{id:org,name:"ZIPPLE fixture",active:true});
  let authId:string|undefined;
  try{
   const password="Zp!"+crypto.randomUUID()+crypto.randomUUID();
   const u=await call("/auth/v1/admin/users","POST",{email:alias,password,email_confirm:true});authId=u.id;
   if(!authId)throw Error("NO_AUTH_ID");
   await rest("zp_members","POST",{id:member,org_id:org,auth_user_id:authId,login_id:login,auth_alias:alias,role_code:"promoteur"});
   await rest("zp_sites","POST",{id:site,org_id:org,name:"Site A",active:true});
   await rest("zp_site_scopes","POST",{member_id:member,org_id:org,site_id:site});
   return response(200,{login,password,org,member,site});
  }catch(e){try{await cleanup(authId)}catch{};return response(500,{error:"FIXTURE_PROVISION_FAILED"})}
 }catch(e){return response(403,{error:"DENIED"})}
});
