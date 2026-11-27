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
 await db.query("insert into zp_organizations values($1,'QA wave 1',true)",[org]);
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
test("B2-019 legal and illegal line transitions, repeated action",async()=>{
 const {b,ok,makeOrder}=await fixture();const {item,order}=await makeOrder();
 const advance=next=>({order_id:order,item_id:item,next});
 await denied(b,"line_advance",advance("served"),"INVALID_TRANSITION");
 assert.equal(await ok("line_advance",advance("preparing")),"preparing");
 assert.equal(await ok("line_advance",advance("preparing")),"preparing");
 await denied(b,"line_advance",advance("served"),"INVALID_TRANSITION");
 assert.equal(await ok("line_advance",advance("ready")),"ready");
 await denied(b,"line_advance",advance("preparing"),"INVALID_TRANSITION");
 assert.equal(await ok("line_advance",advance("served")),"served");
 assert.equal(await scalar("select status from zp_orders where id=$1",[order]),"served");
 assert.equal(Number(await scalar("select count(*) from zp_order_events where order_id=$1 and event_type='line_state'",[order])),3);
 console.log("ZIPPLE_QA_CASE_PARTIAL B2-019 LINE_TRANSITIONS_PASS");
});
test("B2-022 repeated justified ETA changes preserve original and history",async()=>{
 const {b,ok,makeOrder}=await fixture();const {order}=await makeOrder();
 const initial=await scalar("select initial_promised_at::text from zp_orders where id=$1",[order]);assert.ok(initial);
 const first=await ok("delay",{order_id:order,minutes:20,reason:"Première prolongation"});
 const second=await ok("delay",{order_id:order,minutes:30,reason:"Deuxième prolongation"});
 assert.ok(Date.parse(second)>Date.parse(first));
 assert.equal(await scalar("select initial_promised_at::text from zp_orders where id=$1",[order]),initial);
 const events=(await db.query("select payload from zp_order_events where order_id=$1 and event_type='delay_explained' order by created_at",[order])).rows.map(x=>x.payload);
 assert.equal(events.length,2);assert.equal(events[0].reason,"Première prolongation");assert.equal(events[1].reason,"Deuxième prolongation");assert.equal(Date.parse(events[1].previous),Date.parse(first));assert.equal(Date.parse(events[1].initial),Date.parse(initial));
 assert.equal((await b("delay",{order_id:order,minutes:0,reason:"Interdit"})).status,400);
 assert.equal(Number(await scalar("select count(*) from zp_order_events where order_id=$1 and event_type='delay_explained'",[order])),2);
 console.log("ZIPPLE_QA_CASE_PARTIAL B2-022 ETA_HISTORY_PASS");
});
test("B2-032 capacity, concurrent booking, idempotency and expiration",async()=>{
 const {b,ok}=await fixture();const table=(await ok("table_create",{label:"QA salle"})).id;
 await ok("table_config",{table_id:table,zone_id:null,seats:4});
 const args={table_id:table,guest_name:"QA réservation",party_size:2,starts_at:new Date(Date.now()+3600000).toISOString(),ends_at:new Date(Date.now()+7200000).toISOString(),request_id:id()};
 await denied(b,"reserve_table",{...args,party_size:5},"RESERVATION_CAPACITY");
 const other={...args,guest_name:"QA concurrent",request_id:id()};
 const replies=await Promise.all([b("reserve_table",args),b("reserve_table",other)]);
 assert.deepEqual(replies.map(x=>x.status).sort(),[200,409]);const winner=replies.findIndex(x=>x.status===200),booking=replies[winner].body.data;assert.equal(replies[1-winner].body.error,"RESERVATION_OVERLAP");
 assert.equal(await ok("reserve_table",winner===0?args:other),booking);
 await denied(b,"reservation_transition",{reservation_id:booking,next:"seated"},"RESERVATION_UNAVAILABLE");
 await denied(b,"reservation_transition",{reservation_id:booking,next:"expired"},"INVALID_TRANSITION");
 // Disposable fixture only: simulate elapsed time, no bypass in the application.
 await db.query("update zp_reservations set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour' where id=$1",[booking]);
 await denied(b,"reservation_transition",{reservation_id:booking,next:"seated"},"RESERVATION_UNAVAILABLE");
 assert.equal(await ok("reservation_transition",{reservation_id:booking,next:"expired"}),"expired");
 assert.equal(await ok("reservation_transition",{reservation_id:booking,next:"expired"}),"expired");
 assert.equal(await scalar("select state from zp_reservations where id=$1",[booking]),"expired");
 assert.equal(Number(await scalar("select count(*) from zp_table_sessions where table_id=$1",[table])),0);
 assert.equal(Number(await scalar("select count(*) from zp_reservations where table_id=$1",[table])),1);
 console.log("ZIPPLE_QA_CASE_PARTIAL B2-032 CONCURRENT_CAPACITY_EXPIRY_PASS");
});
test("B3-003 bar unit conversion exactness and incompatible units",async()=>{
 const {b,ok}=await fixture();const ingredient=await ok("ingredient_add",{name:"Boisson QA",sku:"BAR-QA",unit:"L",reorder_milli:0,supplier_whatsapp:""});
 const other=await ok("ingredient_add",{name:"Farine QA",sku:"FAR-QA",unit:"kg",reorder_milli:0,supplier_whatsapp:""});
 const rules={};for(const [label,ratio] of [["verre",125],["bouteille",650],["pack",3900],["casier",7800]])rules[label]=await ok("conversion_add",{ingredient_id:ingredient,request_id:id(),label,base_milli_per_unit:ratio});
 const receipt={ingredient_id:ingredient,conversion_id:rules.casier,request_id:id(),label:"QA-CASIER",supplier:"Fournisseur QA",qty_milli:1500,cost_xaf:7800,expires_on:null};
 const lot=await ok("lot_receive_converted",receipt);assert.equal(await ok("lot_receive_converted",receipt),lot);
 assert.equal(Number(await scalar("select remaining_milli from zp_ingredient_lots where id=$1",[lot])),11700);
 for(const [label,quantity] of [["verre",125],["bouteille",650],["pack",3900]]){const l=await ok("lot_receive_converted",{...receipt,conversion_id:rules[label],request_id:id(),label:"QA-"+label,qty_milli:1000});assert.equal(Number(await scalar("select remaining_milli from zp_ingredient_lots where id=$1",[l])),quantity)}
 await denied(b,"lot_receive_converted",{...receipt,conversion_id:rules.bouteille,request_id:id(),label:"QA-INEXACT",qty_milli:1},"CONVERSION_PRECISION_OR_RANGE");
 assert.equal((await b("lot_receive_converted",{...receipt,ingredient_id:other,request_id:id()})).status,403);
 assert.equal(Number(await scalar("select count(*) from zp_ingredient_lots where ingredient_id=$1",[ingredient])),4);
 console.log("ZIPPLE_QA_CASE_PARTIAL B3-003 BAR_CONVERSIONS_PASS");
});
