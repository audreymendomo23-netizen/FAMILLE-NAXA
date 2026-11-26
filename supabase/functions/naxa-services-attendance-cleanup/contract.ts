// Server-only cleanup candidate; no user-supplied file paths or bucket.
const uuid="[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
const pathPattern=new RegExp("^"+uuid+"/"+uuid+"/"+uuid+"/"+uuid+"[.]jpg$");
type Env={url:string;key:string;secret:string;enabled:boolean};
function secureEqual(a:string,b:string){const x=new TextEncoder().encode(a),y=new TextEncoder().encode(b);let d=x.length^y.length;for(let i=0;i<Math.max(x.length,y.length);i++)d|=(x[i]??0)^(y[i]??0);return d===0;}
export async function cleanup(req:Request,env:Env,transport:typeof fetch=fetch):Promise<Response>{
 const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}});
 if(req.method!=="POST")return reply(405,{error:"METHOD_NOT_ALLOWED"});
 if(!env.enabled||env.secret.length<32||env.key.length<20)return reply(503,{error:"CLEANUP_DISABLED"});
 if(!secureEqual(req.headers.get("x-ns-cleanup-secret")??"",env.secret))return reply(403,{error:"FORBIDDEN"});
 // The scheduler cannot override the grace interval, limit or target bucket.
 try{
  const u=new URL(env.url);if(u.protocol!=="https:"||u.username||u.password||u.pathname!=="/"||u.search||u.hash)throw Error();
  const headers={apikey:env.key,Authorization:"Bearer "+env.key,"Content-Type":"application/json"};
  const request=async(path:string,method:string,body:unknown)=>{
   const res=await transport(u.origin+path,{method,headers,body:JSON.stringify(body),redirect:"error",cache:"no-store"});
   if(!res.ok)throw Error("UPSTREAM_FAILURE");return await res.json();
  };
  const purged=await request("/rest/v1/rpc/ns_purge_expired_attendance_staging","POST",{p_limit:100});
  if(!Number.isInteger(purged)||purged<0||purged>100)throw Error();
  const inventory=await request("/rest/v1/rpc/ns_attendance_orphan_candidates","POST",{p_limit:100});
  if(!Array.isArray(inventory)||inventory.length>100||inventory.some(x=>!x||typeof x.object_name!=="string"||!pathPattern.test(x.object_name)))throw Error();
  const paths=[...new Set(inventory.map(x=>x.object_name as string))];
  if(paths.length===0)return reply(200,{purged_staging:purged,removed_files:0});
  const deleted=await request("/storage/v1/object/ns-attendance-selfies","DELETE",{prefixes:paths});
  if(!Array.isArray(deleted))throw Error();
  // Count only confirmed returned exact names. Partial responses are explicit.
  const confirmed=new Set(deleted.map(x=>x?.name).filter(x=>typeof x==="string"&&paths.includes(x)));
  return reply(confirmed.size===paths.length?200:502,{purged_staging:purged,requested_files:paths.length,removed_files:confirmed.size});
 }catch{return reply(502,{error:"CLEANUP_UNCONFIRMED"});}
}
