import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {randomUUID} from "node:crypto";import {createServer} from "node:https";import {readFile} from "node:fs/promises";import {spawn,spawnSync} from "node:child_process";
const base=process.env.API_URL,dbUrl=process.env.DB_URL,service=process.env.SERVICE_ROLE_KEY;
assert.match(base,/^http:\/\/(127\.0\.0\.1|localhost):\d+$/);assert.ok(["127.0.0.1","localhost"].includes(new URL(dbUrl).hostname));
const db=new pg.Pool({connectionString:dbUrl}),origin="https://zipple.test",id=()=>randomUUID();
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0]??{})[0];
async function call(fn,action,body,token){const res=await fetch(base+"/functions/v1/"+fn+"/"+action,{method:"POST",headers:{origin,"content-type":"application/json",...(token?{authorization:"Bearer "+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})});const result=await res.json();assert.equal(res.status,200,action+" "+JSON.stringify(result));return fn==="zipple-business"?result.data:result}
test("native Android business screen reaches disposable GoTrue and Edge, posts unique split sale",async()=>{
 let server;let lostRequest=null,socketRequest=null;const submitted=new Map();let retryCount=0,socketRetryCount=0;
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
 const mixedItem=await ok("menu_add",{name:"Multi-règlement natif",post:"kitchen",price_xaf:1000,qty:1});
 const mixedOrder=await ok("order_create",{channel:"counter",request_id:id(),lines:[{item_id:mixedItem,qty:1}]});
 for(const next of ["preparing","ready","served"])await ok("line_advance",{order_id:mixedOrder.id,item_id:mixedItem,next});
 // A fixed local HTTPS bridge forwards only the two isolated gateways. No production endpoint or credentials.
 server=createServer({key:await readFile(process.env.ZIPPLE_TLS_KEY),cert:await readFile(process.env.ZIPPLE_TLS_CERT)},async(req,res)=>{
  try{const path=new URL(req.url,"https://127.0.0.1:4443").pathname,m=path.match(/^\/(gateway|zipple-business)\/([a-z_]+)$/);
  if(req.method!=="POST"||!m){res.writeHead(404).end();return}
  const chunks=[];for await(const chunk of req)chunks.push(chunk);
  const payload=m[2]==="split_collect"?JSON.parse(Buffer.concat(chunks).toString()):null;
  if(payload){const prior=submitted.get(payload.request_id);if(prior){assert.deepEqual(payload,prior);if(payload.request_id===lostRequest)retryCount++;if(payload.request_id===socketRequest)socketRetryCount++;}else submitted.set(payload.request_id,payload);}
  const response=await fetch(base+"/functions/v1/"+(m[1]==="gateway"?"zipple-n1":"zipple-business")+"/"+m[2],{method:"POST",headers:{origin,"content-type":"application/json",...(req.headers.authorization?{authorization:req.headers.authorization}:{})},body:Buffer.concat(chunks)});
  const responseBytes=Buffer.from(await response.arrayBuffer());
  if(payload?.order_id===order.id&&response.ok&&lostRequest===null){lostRequest=payload.request_id;console.log("ZIPPLE_BULK2_NATIVE_ACK_WITHHELD_AFTER_COMMIT");/* The isolated bridge has committed the payment but cannot confirm it to the client. An explicit upstream unavailable response avoids platform-dependent automatic socket retry. */res.writeHead(503,{"content-type":"application/json","cache-control":"no-store","connection":"close"});res.end(JSON.stringify({error:"OPERATION_UNAVAILABLE"}));return}
  if(payload?.order_id===secondOrder.id&&response.ok&&socketRequest===null){socketRequest=payload.request_id;console.log("ZIPPLE_BULK2_NATIVE_SOCKET_LOST_AFTER_COMMIT");res.destroy();return}
  if(m[2]==="split_collect")console.log("ZIPPLE_BULK2_NATIVE_SPLIT_RESPONSE",response.status);
  res.writeHead(response.status,{"content-type":"application/json","cache-control":"no-store"});res.end(responseBytes);
  }catch{res.writeHead(503).end()}
 });
 await new Promise((ok,fail)=>{server.once("error",fail);server.listen(4443,"127.0.0.1",ok)});
 const firstNo=await scalar("select service_number from zp_orders where id=$1",[order.id]),secondNo=await scalar("select service_number from zp_orders where id=$1",[secondOrder.id]),mixedNo=await scalar("select service_number from zp_orders where id=$1",[mixedOrder.id]);
 await new Promise((resolve,reject)=>{const proc=spawn("gradle",["--no-daemon",":zipple:connectedDebugAndroidTest","-PZIPPLE_API_URL=https://127.0.0.1:4443/gateway","-PZIPPLE_BUSINESS_API_URL=https://127.0.0.1:4443/zipple-business","-Pandroid.testInstrumentationRunnerArguments.class=cm.naxa.zipple.Bulk2LiveDeviceTest","-Pandroid.testInstrumentationRunnerArguments.zippleBulk2Local=1","-Pandroid.testInstrumentationRunnerArguments.zippleFixtureLogin="+login,"-Pandroid.testInstrumentationRunnerArguments.zippleFixturePassword="+password,"-Pandroid.testInstrumentationRunnerArguments.zippleSplitNumber="+firstNo,"-Pandroid.testInstrumentationRunnerArguments.zippleAmountNumber="+secondNo,"-Pandroid.testInstrumentationRunnerArguments.zippleMixedNumber="+mixedNo],{stdio:"inherit"});proc.on("error",reject);proc.on("exit",code=>{const diag=spawnSync("adb",["logcat","-d","-s","ZIPPLE_BULK2_TEST:I","*:S"],{encoding:"utf8"});if(diag.stdout)console.log(diag.stdout);return code===0?resolve():reject(Error("Android real business recipe failed: "+code))})});
 assert.ok(lostRequest);assert.ok(socketRequest);assert.ok(retryCount>=1,"the first unconfirmed payment must be retried with the original request");assert.ok(socketRetryCount>=1,"the socket failure must replay the original request");
 for(const request of [lostRequest,socketRequest])assert.equal(Number(await scalar("select count(*) from zp_credit_payments where request_id=$1",[request])),1);
 console.log("ZIPPLE_BULK2_NATIVE_RETRY_IDEMPOTENCE_PASS");
 for(const [oid,expected,count] of [[order.id,3000,2],[secondOrder.id,800,2]]){
 assert.equal(Number(await scalar("select count(*) from zp_cash_receipts where order_id=$1",[oid])),1);
 assert.equal(Number(await scalar("select paid_xaf from zp_credit_sales where order_id=$1",[oid])),expected);
 assert.equal(Number(await scalar("select count(*) from zp_credit_payments p join zp_credit_sales s on s.id=p.sale_id where s.order_id=$1",[oid])),count);
 assert.equal(await scalar("select zp_credit_status($1)",[oid]),"paid");
 }
 assert.equal(Number(await scalar("select count(*) from zp_cash_tenders t join zp_cash_receipts r on r.id=t.receipt_id where r.order_id=$1",[mixedOrder.id])),3);
 assert.equal(Number(await scalar("select sum(t.amount_xaf) from zp_cash_tenders t join zp_cash_receipts r on r.id=t.receipt_id where r.order_id=$1",[mixedOrder.id])),1000);
 assert.equal(Number(await scalar("select count(*) from zp_suppliers where site_id=$1 and name='Fournisseur ERP natif'",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_purchases where site_id=$1 and reference='NATIVE-PURCHASE' and received_milli=3000 and paid_xaf=1000",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_ledger_mapping_posts p join zp_ledger_entries e on e.id=p.entry_id where e.site_id=$1 and e.amount_xaf=750",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_finance_documents where site_id=$1 and label='Justificatif ERP natif'",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_erp_sync_reviews v join zp_erp_sync_receipts r on r.event_id=v.event_id where v.site_id=$1 and r.state='conflict'",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_expenses where site_id=$1 and reference='NATIVE-AFTER-REVIEW'",[site])),1);
 assert.equal(await scalar("select display_name from zp_profile_details where member_id=$1",[member]),"Profil ERP natif");
 assert.equal(Number(await scalar("select count(*) from zp_work_items where site_id=$1 and title='Ticket ERP natif' and state='done'",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_delivery_zones where site_id=$1 and label='Zone ERP native' and fee_xaf=500",[site])),1);
 assert.equal(Number(await scalar("select count(*) from zp_hr_requests r join zp_hr_decisions d on d.request_id=r.id where r.site_id=$1 and r.reason='Congé ERP natif' and d.decision='approved'",[site])),1);
 const nativeTableHash=await scalar("select qr_hash from zp_tables where site_id=$1 and org_id=$2 and label='Table QR native'",[site,org]);
 assert.match(nativeTableHash,/^[0-9a-f]{64}$/);
 console.log("ZIPPLE_NATIVE_TABLE_QR_PERSISTENCE_PASS");
 const nativeCustomer=await scalar("select id from zp_customers where org_id=$1 and display_name='Client QR natif'",[org]);assert.ok(nativeCustomer);
 const card=await scalar("select id from zp_loyalty_cards where customer_id=$1 and org_id=$2 and revoked_at is null",[nativeCustomer,org]);
 const referral=await scalar("select id from zp_loyalty_codes where customer_id=$1 and org_id=$2 and revoked_at is null",[nativeCustomer,org]);
 assert.ok(card&&referral);assert.notEqual(card,referral);console.log("ZIPPLE_NATIVE_LOYALTY_QR_PERSISTENCE_PASS");
 console.log("ZIPPLE_BULK45_NATIVE_WORKSPACE_PERSISTENCE_PASS");
 console.log("ZIPPLE_BULK3_ANDROID_REAL_ERP_LEDGER_EVIDENCE_OFFLINE_REVIEW_PASS");
 const closed=await ok("cash_close",{cash_id:cash,counted_xaf:4900});assert.equal(closed.variance_xaf,0);
 console.log("ZIPPLE_BULK2_ANDROID_REAL_EDGE_SPLIT_QUANTITY_AMOUNT_AND_CASH_PASS");
 }finally{if(server)await new Promise(ok=>server.close(ok));await db.end()}
});
