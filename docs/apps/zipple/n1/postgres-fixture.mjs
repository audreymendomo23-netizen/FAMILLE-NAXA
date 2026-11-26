// Test-only SQL-backed provider for the N1 boundary. No production auth substitute.
import {randomBytes,createHash,scryptSync,timingSafeEqual} from "node:crypto";
import {createAuthHandler,scopedSession} from "./auth-boundary.mjs";
const hash=x=>createHash("sha256").update(x).digest("hex");
export const passwordHash=(p,salt=randomBytes(16).toString("hex"))=>salt+":"+scryptSync(p,salt,32).toString("hex");
const check=(p,v)=>{const [salt,digest]=v.split(":");return timingSafeEqual(Buffer.from(digest,"hex"),scryptSync(p,salt,32))};
const token=()=>randomBytes(32).toString("hex");
const deny=()=>{throw Error("DENIED")};
export async function createFixture(pool){
 const issue=async(db,m,remember)=>{
  if(!m||m.app_id!=="ZIPPLE"||!m.active)deny();
  const a=token(),f=remember?token():null,expiry=Date.now()+300000;
  await db.query("insert into zipple_n1.sessions(access_hash,refresh_hash,member_id,expires_at) values($1,$2,$3,$4)",[hash(a),f?hash(f):null,m.id,expiry]);
  const {rows:sites}=await db.query("select s.id,s.name,s.active from zipple_n1.sites s join zipple_n1.scopes sc on sc.site_id=s.id where sc.member_id=$1 and s.app_id=$2 and s.org_id=$3",[m.id,m.app_id,m.org_id]);
  return {app_id:m.app_id,active:m.active,session_active:true,member_id:m.id,organization_id:m.org_id,organization_name:m.org_id,role:m.role,access_token:a,refresh_token:f,expires_at:expiry,active_sites:sites,scopes:sites.map(s=>({scope_type:"site",site_id:s.id}))};
 };
 const attempts=new Map();
 const provider={
  rateLimit:async({action,identifier})=>{const k=action+":"+String(identifier??"fixture");const n=(attempts.get(k)??0)+1;attempts.set(k,n);if(n>20)deny()},
  authenticate:async({identifier,password,remember_device})=>{
   const {rows:[m]}=await pool.query("select * from zipple_n1.members where identifier=$1 and app_id='ZIPPLE'",[identifier]);
   if(!m||!m.active||!check(password,m.password_hash))deny();return issue(pool,m,remember_device)
  },
  rotate:async({refresh_token})=>{const c=await pool.connect();try{await c.query("begin");const {rows:[m]}=await c.query("update zipple_n1.sessions s set revoked=true from zipple_n1.members m where s.refresh_hash=$1 and s.member_id=m.id and not s.revoked and m.active and m.app_id='ZIPPLE' returning m.*",[hash(refresh_token)]);if(!m)deny();const x=await issue(c,m,true);await c.query("commit");return x}catch(e){await c.query("rollback");throw e}finally{c.release()}},
  recover:async()=>{}, // generic acknowledgement only; no account reset in fixture
  revoke:async({access_token})=>{const x=await pool.query("update zipple_n1.sessions set revoked=true where access_hash=$1 and not revoked",[hash(access_token)]);if(!x.rowCount)deny()}
 };
 const auth=createAuthHandler(provider);
 return async(req)=>{
  if(!new URL(req.url).pathname.endsWith("/sync"))return auth(req);
  try{
   if(req.method!=="POST")deny();
   const bearer=req.headers.get("authorization")||"";if(!bearer.startsWith("Bearer "))deny();
   const body=await req.json();
   if(body.app_id!=="ZIPPLE"||typeof body.event_id!=="string"||!body.event_id||!Number.isSafeInteger(body.sequence)||body.sequence<0||!body.payload||typeof body.payload!=="object")deny();
   const {rows:[m]}=await pool.query("select m.id,m.org_id from zipple_n1.sessions a join zipple_n1.members m on m.id=a.member_id join zipple_n1.scopes sc on sc.member_id=m.id join zipple_n1.sites s on s.id=sc.site_id where a.access_hash=$1 and not a.revoked and a.expires_at>$2 and m.active and m.app_id='ZIPPLE' and s.active and s.app_id=m.app_id and s.org_id=m.org_id and s.id=$3",[hash(bearer.slice(7)),Date.now(),body.site_id]);
   if(!m||m.org_id!==body.organization_id||m.id!==body.member_id)deny();
   const digest=hash(JSON.stringify([body.sequence,body.aggregate_type??null,body.payload]));
   await pool.query("insert into zipple_n1.receipts values('ZIPPLE',$1,$2,$3,$4,$5) on conflict do nothing",[m.org_id,m.id,body.site_id,body.event_id,digest]);
   const {rows:[stored]}=await pool.query("select digest from zipple_n1.receipts where app_id='ZIPPLE' and org_id=$1 and member_id=$2 and site_id=$3 and event_id=$4",[m.org_id,m.id,body.site_id,body.event_id]);
   return Response.json({app_id:"ZIPPLE",event_id:body.event_id,organization_id:m.org_id,site_id:body.site_id,state:stored.digest===digest?"acknowledged":"conflict"},{headers:{"cache-control":"no-store"}});
  }catch{return Response.json({error:"DENIED"},{status:403})}
 };
}
