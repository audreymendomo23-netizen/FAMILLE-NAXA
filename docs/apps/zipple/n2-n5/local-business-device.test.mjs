import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {randomUUID} from "node:crypto";import {createServer} from "node:https";import {readFile} from "node:fs/promises";import {spawn} from "node:child_process";
const base=process.env.API_URL,dbUrl=process.env.DB_URL,service=process.env.SERVICE_ROLE_KEY;
assert.match(base,/^http:\/\/(127\.0\.0\.1|localhost):\d+$/);assert.ok(["127.0.0.1","localhost"].includes(new URL(dbUrl).hostname));
const db=new pg.Pool({connectionString:dbUrl}),origin="https://zipple.test",id=()=>randomUUID();
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0]??{})[0];
async function call(fn,action,body,token){const res=await fetch(base+"/functions/v1/"+fn+"/"+action,{method:"POST",headers:{origin,"content-type":"application/json",...(token?{authorization:"Bearer "+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})});const result=await res.json();assert.equal(res.status,200,action+" "+JSON.stringify(result));return fn==="zipple-business"?result.data:result}
test("native Android business screen reaches disposable GoTrue and Edge, posts unique split sale",async()=>{
 let server;let lostRequest=null;
 try{
 const org=id(),site=id(),member=id(),login="zipple-native-"+id(),email=id()+"@example.test",password="Fixture-"+id()+"-Aa9!";
 const created=await fetch(base+"/auth/v1/admin/users",{method:"POST",headers:{apikey:service,authorization:"Bearer "+service,"content-type":"application/json"},body:JSON.stringify({email,password,email_confirm:true})});assert.ok(created.ok);
 const user=(await created.json()).id;
 await db.query("insert into zp_organizations values($1,'ZIPPLE native fixture',true)",[org]);
 await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,'promoteur')",[member,org,user,login,email]);
 await db.query("insert into zp_sites values($1,$2,'Restaurant native',true)",[site,org]);await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);
 const auth=await call("zipple-n1","login",{identifier:login,password}),token=auth.access_token;
 const ok=(action,body={})=>call("zipple-business",action,{site_id:site,...body},token);
 const quote=await ok("quote",{plan:"PREMIUM",cadence:"monthly",provider:"mtn_momo",request_id:id()});
 await scalar("select zp_confirm_subscription($1,'mtn_momo',$2,18000,'XAF')",[quote.id,id()]);
 await ok("mode",{space:"restaurant",bar:true,delivery:false});
 const cash=await ok("cash_open",{opening_xaf:100});
 const item=await ok("menu_add",{name:"Assiette native",post:"kitchen",price_xaf:1000,qty:3});
 const order=await ok("order_create",{channel:"counter",request_id:id(),lines:[{item_id:item,qty:3}]});
 for(const next of ["preparing","ready","served"])await ok("line_advance",{order_id:order.id,item_id:item,next});
 const secondItem=await ok("menu_add",{name:"Montant natif",post:"kitchen",price_xaf:800,qty:1});
 const secondOrder=await ok("order_create",{channel:"counter",request_id:id(),lines:[{item_id:secondItem,qty:1}]});
 for(const next of ["preparing","ready","served"])await ok("line_advance",{order_id:secondOrder.id,item_id:secondItem,next});
 // A fixed local HTTPS bridge forwards only the two isolated gateways. No production endpoint or credentials.
 server=createServer({key:await readFile(process.env.ZIPPLE_TLS_KEY),cert:await readFile(process.env.ZIPPLE_TLS_CERT)},async(req,res)=>{
  try{const path=new URL(req.url,"https://127.0.0.1:4443").pathname,m=path.match(/^\/(gateway|zipple-business)\/([a-z_]+)$/);
  if(req.method!=="POST"||!m){res.writeHead(404).end();return}
  const chunks=[];for await(const chunk of req)chunks.push(chunk);
  const response=await fetch(base+"/functions/v1/"+(m[1]==="gateway"?"zipple-n1":"zipple-business")+"/"+m[2],{method:"POST",headers:{origin,"content-type":"application/json",...(req.headers.authorization?{authorization:req.headers.authorization}:{})},body:Buffer.concat(chunks)});
  const responseBytes=Buffer.from(await response.arrayBuffer());
  if(m[1]==="zipple-business"&&m[2]==="split_collect"&&response.ok&&lostRequest===null){lostRequest=JSON.parse(Buffer.concat(chunks).toString()).request_id;res.destroy();return}
  res.writeHead(response.status,{"content-type":"application/json","cache-control":"no-store"});res.end(responseBytes);
  }catch{res.writeHead(503).end()}
 });
 await new Promise((ok,fail)=>{server.once("error",fail);server.listen(4443,"127.0.0.1",ok)});
 const firstNo=await scalar("select service_number from zp_orders where id=$1",[order.id]),secondNo=await scalar("select service_number from zp_orders where id=$1",[secondOrder.id]);
 await new Promise((resolve,reject)=>{const proc=spawn("gradle",["--no-daemon",":zipple:connectedDebugAndroidTest","-PZIPPLE_API_URL=https://127.0.0.1:4443/gateway","-PZIPPLE_BUSINESS_API_URL=https://127.0.0.1:4443/zipple-business","-Pandroid.testInstrumentationRunnerArguments.class=cm.naxa.zipple.Bulk2LiveDeviceTest","-Pandroid.testInstrumentationRunnerArguments.zippleBulk2Local=1","-Pandroid.testInstrumentationRunnerArguments.zippleFixtureLogin="+login,"-Pandroid.testInstrumentationRunnerArguments.zippleFixturePassword="+password,"-Pandroid.testInstrumentationRunnerArguments.zippleSplitNumber="+firstNo,"-Pandroid.testInstrumentationRunnerArguments.zippleAmountNumber="+secondNo],{stdio:"inherit"});proc.on("error",reject);proc.on("exit",code=>code===0?resolve():reject(Error("Android real business recipe failed: "+code)))});
 assert.ok(lostRequest);assert.equal(Number(await scalar("select count(*) from zp_credit_payments where request_id=$1",[lostRequest])),1);
 for(const [oid,expected,count] of [[order.id,3000,2],[secondOrder.id,800,2]]){
 assert.equal(Number(await scalar("select count(*) from zp_cash_receipts where order_id=$1",[oid])),1);
 assert.equal(Number(await scalar("select paid_xaf from zp_credit_sales where order_id=$1",[oid])),expected);
 assert.equal(Number(await scalar("select count(*) from zp_credit_payments p join zp_credit_sales s on s.id=p.sale_id where s.order_id=$1",[oid])),count);
 assert.equal(await scalar("select zp_credit_status($1)",[oid]),"paid");
 }
 const closed=await ok("cash_close",{cash_id:cash,counted_xaf:3900});assert.equal(closed.variance_xaf,0);
 console.log("ZIPPLE_BULK2_ANDROID_REAL_EDGE_SPLIT_QUANTITY_AMOUNT_AND_CASH_PASS");
 }finally{if(server)await new Promise(ok=>server.close(ok));await db.end()}
});
