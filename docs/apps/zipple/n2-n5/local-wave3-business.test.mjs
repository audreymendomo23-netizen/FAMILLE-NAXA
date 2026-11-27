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
 await db.query("insert into zp_organizations values($1,'QA wave 3',true)",[org]);
 await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,'promoteur')",[member,org,user,login,email]);
 await db.query("insert into zp_sites values($1,$2,'QA restaurant',true)",[site,org]);await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);
 const auth=await call("zipple-n1","login",{identifier:login,password});assert.equal(auth.status,200);
 const b=(action,body={})=>call("zipple-business",action,{site_id:site,...body},auth.body.access_token);
 const ok=async(action,body={})=>{const response=await b(action,body);assert.equal(response.status,200,action+" "+String(response.body.error??""));return response.body.data};
 const premium=await ok("quote",{plan:"PREMIUM",cadence:"monthly",provider:"mtn_momo",request_id:id()});
 await scalar("select zp_confirm_subscription($1,'mtn_momo',$2,18000,'XAF')",[premium.id,id()]);
 await ok("mode",{space:"restaurant",bar:true,delivery:false});
 const makeOrder=async()=>{const item=await ok("menu_add",{name:"QA plat "+id(),post:"kitchen",price_xaf:500,qty:3});const order=await ok("order_create",{channel:"counter",request_id:id(),lines:[{item_id:item,qty:1}]});return {item,order:order.id}};
 return {org,site,member,b,ok,makeOrder};
}
async function denied(b,action,body,code){const r=await b(action,body);assert.equal(r.status,409,action);assert.equal(r.body.error,code)}
async function actor(org,site,role){
 const member=id(),login="qa-"+id(),email=id()+"@example.test",password="Fixture-"+id()+"-Aa9!";
 const created=await fetch(base+"/auth/v1/admin/users",{method:"POST",headers:{apikey:service,authorization:"Bearer "+service,"content-type":"application/json"},body:JSON.stringify({email,password,email_confirm:true})});assert.ok(created.ok);
 await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,$6)",[member,org,(await created.json()).id,login,email,role]);
 await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);
 const auth=await call("zipple-n1","login",{identifier:login,password});assert.equal(auth.status,200);
 const b=(action,body={})=>call("zipple-business",action,{site_id:site,...body},auth.body.access_token);
 const ok=async(action,body={})=>{const res=await b(action,body);assert.equal(res.status,200,action+" "+String(res.body.error??""));return res.body.data};
 return {member,b,ok};
}

test("B5-005 HR private history, absence overlap and authorized decisions",async()=>{
 const {org,site,b,ok}=await fixture();const staff=await actor(org,site,"staff"),other=await actor(org,site,"staff"),manager=await actor(org,site,"manager");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 const absence={kind:"absence",member_id:staff.member,from_day:"2027-05-01",to_day:"2027-05-03",amount_xaf:null,reason:"Absence test QA"};
 assert.equal((await other.b("hr_write",write("submit",absence))).status,403);
 const draft=write("submit",absence);const created=await staff.ok("hr_write",draft);assert.equal((await staff.ok("hr_write",draft)).id,created.id);
 await denied(staff.b,"hr_write",write("submit",{...absence,from_day:"2027-05-02"}),"ABSENCE_OVERLAP");
 assert.equal((await other.ok("hr_snapshot")).rows.length,0);
 const decision=write("decide",{id:created.id,decision:"approved",reason:"Planning vérifié"});
 assert.equal((await staff.b("hr_write",decision)).status,403);
 assert.equal((await manager.ok("hr_write",decision)).id,created.id);
 assert.equal((await staff.ok("hr_snapshot")).rows.find(x=>x.id===created.id).state,"approved");
 assert.equal((await other.ok("hr_snapshot")).rows.length,0);
 assert.equal(Number(await scalar("select count(*) from zp_hr_decisions where request_id=$1",[created.id])),1);
 console.log("ZIPPLE_QA_CASE_PARTIAL B5-005 HR_SCOPE_OVERLAP_HISTORY_PASS");
});
test("B5-007 variable compensation submission and owner approval, not payroll",async()=>{
 const {org,site,b,ok}=await fixture();const staff=await actor(org,site,"staff"),manager=await actor(org,site,"manager");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 for(const [kind,amount] of [["bonus",4500],["commission",3200],["advance",1000]]){
  const payload={kind,member_id:staff.member,from_day:"2027-05-01",to_day:"2027-05-31",amount_xaf:amount,reason:"Élément rémunération QA"};
  assert.equal((await staff.b("hr_write",write("submit",payload))).status,403);
  const row=await manager.ok("hr_write",write("submit",payload));
  const decision=write("decide",{id:row.id,decision:"approved",reason:"Montant contrôlé QA"});
  assert.equal((await manager.b("hr_write",decision)).status,403);
  assert.equal((await ok("hr_write",decision)).id,row.id);
  assert.equal((await ok("hr_write",decision)).id,row.id);
  assert.equal(Number(await scalar("select count(*) from zp_hr_decisions where request_id=$1",[row.id])),1);
 }
 const snapshot=await staff.ok("hr_snapshot");assert.equal(snapshot.rows.length,3);assert.equal(snapshot.rows.reduce((sum,x)=>sum+x.amount_xaf,0),8700);
 assert.ok(snapshot.rows.every(x=>x.state==="approved"));assert.equal(snapshot.can_approve_pay,false);
 console.log("ZIPPLE_QA_CASE_PARTIAL B5-007 VARIABLE_PAY_APPROVAL_PASS");
});

test("B5-003 concurrent shift overlap, replay and authorized cancellation",async()=>{
 const {org,site,ok,b}=await fixture();const staff=await actor(org,site,"staff"),manager=await actor(org,site,"manager");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 const shift={kind:"shift",title:"QA planning",detail:"Service prévu",category:"service",priority:"normal",assignee_id:staff.member,starts_at:"2027-05-01T07:00:00Z",due_at:"2027-05-01T11:00:00Z"};
 const a=write("work_create",shift),other=write("work_create",{...shift,title:"Chevauchement"});
 assert.equal((await staff.b("workspace_write",a)).status,403);
 const replies=await Promise.all([b("workspace_write",a),manager.b("workspace_write",other)]);assert.deepEqual(replies.map(x=>x.status).sort(),[200,409]);
 const winner=replies.findIndex(x=>x.status===200);assert.equal(replies[1-winner].body.error,"SHIFT_OVERLAP");
 const chosen=winner===0?a:other,owner=winner===0?ok:manager.ok,record=replies[winner].body.data.id;
 assert.equal((await owner("workspace_write",chosen)).id,record);
 assert.equal((await staff.ok("workspace_snapshot",{page:"planning"})).rows.length,1);
 assert.equal((await staff.b("workspace_write",write("work_state",{work_id:record,expected_state:"open",state:"cancelled"}))).status,403);
 await ok("workspace_write",write("work_state",{work_id:record,expected_state:"open",state:"cancelled"}));
 const next=await ok("workspace_write",write("work_create",shift));assert.notEqual(next.id,record);
 assert.equal(Number(await scalar("select count(*) from zp_work_items where site_id=$1 and kind='shift' and state<>'cancelled'",[site])),1);
 console.log("ZIPPLE_QA_CASE_PARTIAL B5-003 SHIFT_SCOPE_OVERLAP_REPLAY_PASS");
});
test("B5-009 assigned incident dialogue, manager state and immutable closed history",async()=>{
 const {org,site,ok}=await fixture();const staff=await actor(org,site,"staff"),other=await actor(org,site,"staff");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 const record=await ok("workspace_write",write("work_create",{kind:"incident",title:"Incident QA",detail:"Correction service",category:"quality",priority:"urgent",assignee_id:staff.member,due_at:"2027-05-03T12:00:00Z"}));
 assert.equal((await other.ok("workspace_snapshot",{page:"incidents"})).rows.length,0);
 const reply=write("work_reply",{work_id:record.id,body:"Correction proposée"});
 assert.equal((await other.b("workspace_write",reply)).status,403);
 const message=await staff.ok("workspace_write",reply);assert.equal((await staff.ok("workspace_write",reply)).id,message.id);
 await ok("workspace_write",write("work_state",{work_id:record.id,expected_state:"open",state:"in_progress"}));
 await ok("workspace_write",write("work_state",{work_id:record.id,expected_state:"in_progress",state:"done"}));
 await denied(staff.b,"workspace_write",write("work_reply",{work_id:record.id,body:"Message tardif"}),"INVALID_TRANSITION");
 const saved=(await staff.ok("workspace_snapshot",{page:"incidents"})).rows.find(x=>x.id===record.id);
 assert.equal(saved.state,"done");assert.equal(saved.messages.length,1);assert.equal(saved.messages[0].body,"Correction proposée");
 console.log("ZIPPLE_QA_CASE_PARTIAL B5-009 INCIDENT_SCOPE_AND_CLOSURE_PASS");
});

test("B5-006 B5-008 objectives and training scoped lifecycle and validation",async()=>{
 const {org,site,ok}=await fixture();const staff=await actor(org,site,"staff"),other=await actor(org,site,"staff"),manager=await actor(org,site,"manager");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 for(const [kind,page] of [["objective","objectives"],["training","training"]]){
  const payload={kind,title:"QA "+kind,detail:"Suivi et validation humaine",category:"service",priority:"urgent",assignee_id:staff.member,due_at:"2027-05-04T12:00:00Z"};
  assert.equal((await staff.b("workspace_write",write("work_create",payload))).status,403);
  const req=write("work_create",payload),record=await manager.ok("workspace_write",req);assert.equal((await manager.ok("workspace_write",req)).id,record.id);
  const assigned=(await staff.ok("workspace_snapshot",{page})).rows.find(x=>x.id===record.id);assert.equal(assigned.priority,"urgent");assert.equal(assigned.assignee_id,staff.member);assert.equal(assigned.state,"open");
  assert.equal((await other.ok("workspace_snapshot",{page})).rows.some(x=>x.id===record.id),false);
  assert.equal((await staff.b("workspace_write",write("work_state",{work_id:record.id,expected_state:"open",state:"in_progress"}))).status,403);
  await manager.ok("workspace_write",write("work_state",{work_id:record.id,expected_state:"open",state:"in_progress"}));
  await denied(manager.b,"workspace_write",write("work_state",{work_id:record.id,expected_state:"open",state:"cancelled"}),"INVALID_TRANSITION");
  await staff.ok("workspace_write",write("work_reply",{work_id:record.id,body:"Travail soumis au contrôle"}));
  await manager.ok("workspace_write",write("work_state",{work_id:record.id,expected_state:"in_progress",state:"done"}));
  const saved=(await staff.ok("workspace_snapshot",{page})).rows.find(x=>x.id===record.id);assert.equal(saved.state,"done");assert.equal(saved.messages.length,1);
  assert.equal(Number(await scalar("select count(*) from zp_work_items where id=$1 and site_id=$2 and state='done'",[record.id,site])),1);
  console.log("ZIPPLE_QA_CASE_PARTIAL "+(kind==="objective"?"B5-006":"B5-008")+" ASSIGNMENT_VALIDATION_SCOPE_PASS");
 }
});
test("B4-034 private inbox read persistence and independent member state",async()=>{
 const {org,site,ok}=await fixture();const staff=await actor(org,site,"staff"),other=await actor(org,site,"staff");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 const record=await ok("workspace_write",write("work_create",{kind:"incident",title:"QA notification privée",detail:"Notification assignée",category:"service",priority:"urgent",assignee_id:staff.member,due_at:"2027-05-05T12:00:00Z"}));
 const event=(await staff.ok("workspace_snapshot",{page:"notifications"})).rows.find(x=>x.event_key.startsWith("work:"+record.id+":"));assert.ok(event);assert.equal(event.is_read,false);
 const mark=write("inbox_read",{event_key:event.event_key});assert.equal((await other.b("workspace_write",mark)).status,403);
 assert.equal((await staff.ok("workspace_write",mark)).confirmed,true);assert.equal((await staff.ok("workspace_write",mark)).confirmed,true);
 assert.equal((await staff.ok("workspace_snapshot",{page:"notifications"})).rows.find(x=>x.event_key===event.event_key).is_read,true);
 assert.equal((await ok("workspace_snapshot",{page:"notifications"})).rows.find(x=>x.event_key===event.event_key).is_read,false);
 assert.equal(Number(await scalar("select count(*) from zp_inbox_reads where site_id=$1 and event_key=$2",[site,event.event_key])),1);
 console.log("ZIPPLE_QA_CASE_PARTIAL B4-034 PRIVATE_READ_PERSISTENCE_PASS");
});


test("B5-004 absence request approval persists exactly once",async()=>{
 const {org,site,ok}=await fixture();const employee=await actor(org,site,"staff"),manager=await actor(org,site,"manager");
 const request={operation:"submit",request_id:id(),payload:{kind:"absence",member_id:employee.member,from_day:"2027-06-01",to_day:"2027-06-02",amount_xaf:null,reason:"Congé vérifié QA"}};
 const row=await employee.ok("hr_write",request);assert.equal((await employee.ok("hr_write",request)).id,row.id);
 const decision={operation:"decide",request_id:id(),payload:{id:row.id,decision:"approved",reason:"Planning vérifié QA"}};
 assert.equal((await employee.b("hr_write",decision)).status,403);assert.equal((await manager.ok("hr_write",decision)).id,row.id);
 assert.equal((await manager.ok("hr_write",decision)).id,row.id);
 const read=(await employee.ok("hr_snapshot")).rows.find(x=>x.id===row.id);assert.equal(read.state,"approved");assert.equal(read.reason,request.payload.reason);
 assert.equal(Number(await scalar("select count(*) from zp_hr_requests where id=$1 and site_id=$2 and member_id=$3",[row.id,site,employee.member])),1);
 assert.equal(Number(await scalar("select count(*) from zp_hr_decisions where request_id=$1 and decision='approved'",[row.id])),1);
 console.log("ZIPPLE_QA_CASE_PARTIAL B5-004 HR_APPROVAL_PERSISTENCE_PASS");
});


test("B4-032 guided ticket human claim, scope and thread closure",async()=>{
 const {org,site,ok}=await fixture();const staff=await actor(org,site,"staff"),other=await actor(org,site,"staff"),manager=await actor(org,site,"manager");
 const write=(operation,payload,request_id=id())=>({operation,payload,request_id});
 const req=write("work_create",{kind:"ticket",title:"Synchronisation",detail:"Guide consulté : Synchronisation — erreur de confirmation",category:"technical",priority:"normal"});
 const ticket=await staff.ok("workspace_write",req);assert.equal((await staff.ok("workspace_write",req)).id,ticket.id);
 const claim=write("work_claim",{work_id:ticket.id});assert.equal((await other.b("workspace_write",claim)).status,403);
 assert.equal((await manager.ok("workspace_write",claim)).id,ticket.id);assert.equal((await manager.ok("workspace_write",claim)).id,ticket.id);
 assert.notEqual((await ok("workspace_snapshot",{page:"tickets"})).rows.find(x=>x.id===ticket.id).assignee_id,null);
 await manager.ok("workspace_write",write("work_reply",{work_id:ticket.id,body:"Demande prise en charge"}));
 await staff.ok("workspace_write",write("work_reply",{work_id:ticket.id,body:"Confirmation reçue"}));
 await manager.ok("workspace_write",write("work_state",{work_id:ticket.id,expected_state:"in_progress",state:"done"}));
 const row=(await staff.ok("workspace_snapshot",{page:"tickets"})).rows.find(x=>x.id===ticket.id);assert.equal(row.state,"done");assert.equal(row.assignee_id,manager.member);assert.equal(row.messages.length,2);assert.equal((await other.ok("workspace_snapshot",{page:"tickets"})).rows.some(x=>x.id===ticket.id),false);
 console.log("ZIPPLE_QA_CASE_PARTIAL B4-032 SITE_HUMAN_HANDOFF_PASS");
});
