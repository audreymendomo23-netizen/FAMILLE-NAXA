import test,{after} from "node:test";
import assert from "node:assert/strict";
import pg from "pg";
import {randomUUID as id} from "node:crypto";
const base=process.env.API_URL,dbUrl=process.env.DB_URL,service=process.env.SERVICE_ROLE_KEY;
assert.match(base??"",/^http:\/\/(127\.0\.0\.1|localhost):\d+$/);
assert.ok(["127.0.0.1","localhost"].includes(new URL(dbUrl).hostname));
const db=new pg.Pool({connectionString:dbUrl});
after(()=>db.end());
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0]??{})[0];
async function call(fn,action,body,token){
 const response=await fetch(base+"/functions/v1/"+fn+"/"+action,{method:"POST",redirect:"error",signal:AbortSignal.timeout(20000),headers:{origin:"https://zipple.test","content-type":"application/json",...(token?{authorization:"Bearer "+token}:{})},body:JSON.stringify({app_id:"ZIPPLE",...body})});
 return {status:response.status,body:await response.json()};
}
async function fixture(){
 const org=id(),site=id(),member=id(),login="qa-"+id(),email=id()+"@example.test",password="Fixture-"+id()+"-Aa9!";
 const created=await fetch(base+"/auth/v1/admin/users",{method:"POST",headers:{apikey:service,authorization:"Bearer "+service,"content-type":"application/json"},body:JSON.stringify({email,password,email_confirm:true})});assert.ok(created.ok,"local Auth fixture");
 const user=(await created.json()).id;
 await db.query("insert into zp_organizations values($1,'QA wave 2',true)",[org]);
 await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,'promoteur')",[member,org,user,login,email]);
 await db.query("insert into zp_sites values($1,$2,'QA restaurant',true)",[site,org]);await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);
 const auth=await call("zipple-n1","login",{identifier:login,password});assert.equal(auth.status,200);
 const b=(action,body={})=>call("zipple-business",action,{site_id:site,...body},auth.body.access_token);
 const ok=async(action,body={})=>{const response=await b(action,body);assert.equal(response.status,200,action+" "+String(response.body.error??""));return response.body.data};
 const premium=await ok("quote",{plan:"PREMIUM",cadence:"monthly",provider:"mtn_momo",request_id:id()});
 await scalar("select zp_confirm_subscription($1,'mtn_momo',$2,18000,'XAF')",[premium.id,id()]);
 await ok("mode",{space:"restaurant",bar:true,delivery:false});
 const makeOrder=async()=>{const item=await ok("menu_add",{name:"QA plat "+id(),post:"kitchen",price_xaf:500,qty:3});const order=await ok("order_create",{channel:"counter",request_id:id(),lines:[{item_id:item,qty:1}]});return {item,order:order.id}};
 return {org,site,b,ok,makeOrder};
}
async function denied(b,action,body,code){const r=await b(action,body);assert.equal(r.status,409,action);assert.equal(r.body.error,code)}
test("B3-016 FEFO then FIFO, actual production trace and concurrent shortage",async()=>{
 const {ok,b}=await fixture();
 const ingredient=await ok("ingredient_add",{name:"Matière FEFO",sku:"QA-FEFO",unit:"kg",reorder_milli:0,supplier_whatsapp:""});
 const date=n=>new Date(Date.now()+n*86400000).toISOString().slice(0,10);
 const receive=async(label,qty,cost,expires)=>ok("lot_receive",{ingredient_id:ingredient,request_id:id(),label,supplier:"Fournisseur QA",qty_milli:qty,cost_xaf:cost,expires_on:expires});
 const later=await receive("LOT-TARDIF",1000,800,date(30)),early=await receive("LOT-PROCHE",1000,400,date(10)),fifo=await receive("LOT-SANS-DATE-1",1000,900,null),fifo2=await receive("LOT-SANS-DATE-2",1000,1000,null);
 const item=await ok("menu_add",{name:"Plat FEFO",post:"kitchen",price_xaf:2000,qty:0});
 await ok("recipe_define",{item_id:item,components:[{ingredient_id:ingredient,qty_milli:1000}]});
 const first=await ok("produce",{item_id:item,request_id:id(),servings:2});
 const rows=(await db.query("select lot_id,qty_milli,cost_xaf from zp_production_consumption where batch_id=$1",[first.id])).rows;
 assert.deepEqual(rows.map(x=>x.lot_id).sort(),[early,later].sort());assert.equal(Number(first.cost_xaf),1200);
 const second=await ok("produce",{item_id:item,request_id:id(),servings:1});assert.equal(await scalar("select lot_id from zp_production_consumption where batch_id=$1",[second.id]),fifo);
 const concurrent=await Promise.all([b("produce",{item_id:item,request_id:id(),servings:1}),b("produce",{item_id:item,request_id:id(),servings:1})]);
 assert.equal(concurrent.filter(x=>x.status===200).length,1);assert.equal(concurrent.filter(x=>x.status===409).length,1);
 const success=concurrent.find(x=>x.status===200).body.data;
 assert.equal(await scalar("select lot_id from zp_production_consumption where batch_id=$1",[success.id]),fifo2);
 assert.equal(Number(await scalar("select sum(remaining_milli) from zp_ingredient_lots where ingredient_id=$1",[ingredient])),0);
 assert.equal(Number(await scalar("select sum(cost_xaf) from zp_production_consumption where lot_id=any($1::uuid[])",[[early,later,fifo,fifo2]])),3100);
 console.log("ZIPPLE_QA_CASE_PARTIAL B3-016 FEFO_FIFO_TRACE_CONCURRENCY_PASS");
});
test("B3-019 concurrent physical counts, losses and idempotent replay",async()=>{
 const {ok,b}=await fixture();
 const ingredient=await ok("ingredient_add",{name:"Matière comptage",sku:"QA-COUNT",unit:"kg",reorder_milli:0,supplier_whatsapp:""});
 const receive=label=>ok("lot_receive",{ingredient_id:ingredient,request_id:id(),label,supplier:"Fournisseur QA",qty_milli:1000,cost_xaf:500,expires_on:null});
 const first=await receive("QA-COUNT-1"),second=await receive("QA-COUNT-2");
 const payload={lot_id:first,request_id:id(),expected_milli:1000,counted_milli:600,reason:"Perte constatée"};
 const replies=await Promise.all([b("count_lot",payload),b("count_lot",{...payload,request_id:id(),counted_milli:800})]);
 assert.deepEqual(replies.map(x=>x.status).sort(),[200,409]);const winner=replies.findIndex(x=>x.status===200);const recorded=replies[winner].body.data;
 assert.equal(replies[1-winner].body.error,"STALE_INVENTORY_COUNT");
 const actual=winner===0?600:800;
 assert.equal(Number(await scalar("select remaining_milli from zp_ingredient_lots where id=$1",[first])),actual);
 assert.equal(Number(await scalar("select loss_cost from zp_inventory_counts where id=$1",[recorded])),(1000-actual)/2);
 // Reuse the successful persisted request, without fabricating a second key.
 const requestId=await scalar("select request_id from zp_inventory_counts where id=$1",[recorded]);
 assert.equal(await ok("count_lot",{...payload,request_id:requestId,counted_milli:actual}),recorded);
 await ok("count_lot",{lot_id:second,request_id:id(),expected_milli:1000,counted_milli:0,reason:"Lot détruit"});
 assert.equal(Number(await scalar("select remaining_cost from zp_ingredient_lots where id=$1",[second])),0);
 assert.equal(Number(await scalar("select count(*) from zp_inventory_counts where lot_id=any($1::uuid[])",[[first,second]])),2);
 console.log("ZIPPLE_QA_CASE_PARTIAL B3-019 COUNT_CONFLICT_LOSS_PASS");
});
