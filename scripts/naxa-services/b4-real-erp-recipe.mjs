import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
export async function runB4({fixture,login,json,success,base,anon,admin,pass}) {
 const f=await fixture('B4-REAL','multi_site_network'), a=await login(f), b=await login({...f,device:{...f.device,installation_id:randomUUID()}});
 const org=f.org.id,site=f.site.id,seq=new Map(),url=base+'/rest/v1/rpc/ns_apply_sync_event';
 function event(session,action,id,payload,scope=site){const n=(seq.get(session.device_id)||0)+1;seq.set(session.device_id,n);return {p_org_id:org,p_site_id:scope,p_workstation_id:null,p_device_id:session.device_id,p_event_id:randomUUID(),p_device_sequence:n,p_aggregate_type:action.split('.')[0],p_aggregate_id:id,p_action_code:action,p_payload:{...payload,org_id:org,site_id:scope}};}
 const send=(session,e)=>json(url,e,session.access_token,anon);
 async function applied(session,e){const r=await send(session,e);assert.equal(r.status,200,JSON.stringify(r.data));assert.equal(r.data.status,'applied');return r.data;}
 async function denied(session,e){const r=await send(session,e);assert.ok(r.status>=400,JSON.stringify(r.data));}
 const rows=(table,query)=>success(base+'/rest/v1/'+table+'?'+query,undefined,admin,admin,'GET');
 const document=(id,kind,amount=1000,paid=0,status='open')=>({record_id:id,record_type:kind,reference:'B4-'+id,title:'B4 recette',counterparty:'Client recette',amount_xaf:amount,paid_xaf:paid,status,metadata_json:{}});
 const transition=(id,kind,from,to,version,delta={})=>({record_id:id,record_type:kind,from_status:from,to_status:to,expected_version:version,reason:'Recette B4',metadata_json_delta:delta,transitioned_at:new Date().toISOString()});
 const invoice=randomUUID();
 await applied(a,event(a,'invoice.created',invoice,document(invoice,'invoice')));
 await denied(a,event(a,'invoice.status_changed',invoice,transition(invoice,'invoice','open','paid',1)));
 const part=event(a,'invoice.status_changed',invoice,transition(invoice,'invoice','open','partial',1,{paid_xaf:400}));
 const receipt=await applied(a,part);assert.equal(receipt.result.paid_xaf,400);
 assert.equal((await applied(a,part)).idempotent,true);
 await denied(b,event(b,'invoice.status_changed',invoice,transition(invoice,'invoice','open','paid',1,{paid_xaf:1000})));
 await denied(a,event(a,'invoice.status_changed',invoice,transition(invoice,'invoice','partial','paid',2,{paid_xaf:1200})));
 await denied(a,event(a,'invoice.status_changed',invoice,transition(invoice,'invoice','partial','cancelled',2)));
 await applied(b,event(b,'invoice.status_changed',invoice,transition(invoice,'invoice','partial','paid',2,{paid_xaf:1000})));
 const [record]=await rows('ns_management_records','id=eq.'+invoice+'&select=paid_xaf,amount_xaf,status,revision');assert.equal(record.paid_xaf,1000);assert.equal(record.amount_xaf,1000);assert.equal(record.status,'paid');assert.equal(record.revision,3);
 assert.equal((await rows('ns_management_record_events','record_id=eq.'+invoice+'&select=id')).length,3);
 for(const kind of ['refund_due','customer_receivable']){const id=randomUUID();await applied(a,event(a,kind+'.created',id,document(id,kind,800,200,'partial')));await applied(b,event(b,kind+'.status_changed',id,transition(id,kind,'partial','paid',1,{paid_xaf:800})));assert.equal((await rows('ns_management_records','id=eq.'+id+'&select=paid_xaf'))[0].paid_xaf,800);}
 for(const kind of ['quote','credit_note']){const id=randomUUID();await denied(a,event(a,kind+'.created',id,document(id,kind,1000,1000,'paid')));await applied(a,event(a,kind+'.created',id,document(id,kind)));await applied(b,event(b,kind+'.status_changed',id,transition(id,kind,'open','approved',1)));await denied(a,event(a,kind+'.status_changed',id,transition(id,kind,'approved','paid',2,{paid_xaf:1000})));}
 pass('B4 finance: five document types, cumulative balance, exact retry, concurrent stale revision, overpayment and cancellation denied');
 const charge=randomUUID(),due='2027-01-10T00:00:00.000Z';
 await applied(a,event(a,'recurring_charge.saved',charge,{charge_id:charge,name:'Loyer recette',category:'rent',amount_xaf:1000,recurrence:'monthly',next_due_at:due,active:true}));
 const pay=(session,amount,date)=>event(session,'recurring_charge.payment_recorded',charge,{charge_id:charge,payment_id:randomUUID(),amount_xaf:amount,reference_due_at:date,payment_method:'manual',payment_reference:'B4'});
 const half=pay(a,400,due);await applied(a,half);assert.equal((await applied(a,half)).idempotent,true);
 await denied(b,pay(b,700,due));await applied(b,pay(b,600,due));await denied(a,pay(a,100,due));await denied(a,pay(a,100,null));
 const [chargeRow]=await rows('ns_recurring_charges','id=eq.'+charge+'&select=next_due_at');assert.equal(new Date(chargeRow.next_due_at).toISOString(),'2027-02-10T00:00:00.000Z');
 const payments=await rows('ns_charge_payments','charge_id=eq.'+charge+'&select=amount_xaf');assert.equal(payments.length,2);assert.equal(payments.reduce((s,x)=>s+x.amount_xaf,0),1000);
 pass('B4 charges: partial/full payment, idempotency, cycle advancement, old/missing due date rejected');
 const appointment=(id)=>({appointment_id:id,customer_reference_or_name:'Client B4',service_reference_or_name:'Service B4',assigned_member_id:f.member.id,starts_at:'2027-03-04T09:00:00Z',ends_at:'2027-03-04T10:00:00Z',deposit_xaf:0,status:'booked'});
 const ap1=randomUUID(),ap2=randomUUID(),concurrent=await Promise.all([send(a,event(a,'appointment.created',ap1,appointment(ap1))),send(b,event(b,'appointment.created',ap2,appointment(ap2)))]);
 assert.equal(concurrent.filter(r=>r.status===200&&r.data.status==='applied').length,1,JSON.stringify(concurrent));assert.equal(concurrent.filter(r=>r.status>=400).length,1);
 pass('B4 appointments: simultaneous reservation of one provider and interval, one acceptance only');

 const fields={
 coiffure:{style:'coupe',technique:'Recette'},couture:{garment:'Vêtement recette',measurements:'Mesures recette'},
 beaute:{treatment:'soin_visage',protocol:'Recette'},parfumerie:{product:'Parfum recette',format:'30ml'},
 reparation:{device:'Appareil recette',fault:'Panne recette'},menuiserie:{piece:'Meuble recette',dimensions:'Mesures recette'},
 garage:{vehicle:'Véhicule recette',fault:'Panne recette'},nettoyage:{site:'Site recette',tasks:'Tâches recette'},
 domicile:{address:'Adresse recette',service:'Prestation recette'},impression:{format:'A6',quantity:'1'},
 photo_evenementiel:{event:'Événement recette',date:'2028-02-29',deliverables:'Livrables recette'},
 autre:{service:'Service recette',specifications:'Recette'}
 };
 const paths={"coiffure":["received","approved","in_progress","quality_check","ready","delivered","closed"],"beaute":["received","approved","in_progress","quality_check","ready","delivered","closed"],"couture":["received","measurement","fitting","ready","delivered","closed"],"parfumerie":["received","quote_pending","approved","in_progress","quality_check","ready","delivered","closed"],"reparation":["received","diagnostic","quote_pending","approved","in_progress","quality_check","ready","delivered","closed"],"garage":["received","diagnostic","quote_pending","approved","in_progress","quality_check","ready","delivered","closed"],"menuiserie":["received","diagnostic","quote_pending","approved","fabrication","quality_check","ready","delivered","closed"],"nettoyage":["received","approved","planning","on_site","in_progress","quality_check","ready","delivered","closed"],"domicile":["received","approved","planning","on_site","in_progress","quality_check","ready","delivered","closed"],"impression":["received","proof_ready","production","quality_check","ready","delivered","closed"],"photo_evenementiel":["received","planning","shooting","post_production","quality_check","ready","delivered","closed"],"autre":["received","approved","in_progress","quality_check","ready","delivered","closed"]};
 for(const [profile,stages] of Object.entries(paths)){
   const kind=['coiffure','beaute','nettoyage','domicile'].includes(profile)?'service_order':['garage','reparation'].includes(profile)?'repair_order':'work_order';
   const id=randomUUID(), payload={...document(id,kind,1000,0,'received'),metadata_json:{activity_profile:profile,fields:fields[profile]}};
   const invalidId=randomUUID();await denied(a,event(a,kind+'.created',invalidId,{...payload,record_id:invalidId,metadata_json:{activity_profile:profile,fields:{}}}));
   await applied(a,event(a,kind+'.created',id,payload));
   await denied(a,event(a,kind+'.status_changed',id,transition(id,kind,'received','closed',1)));
   for(let v=1;v<stages.length;v++)await applied(a,event(a,kind+'.status_changed',id,transition(id,kind,stages[v-1],stages[v],v)));
   const [r]=await rows('ns_management_records','id=eq.'+id+'&select=status,revision,metadata_json');
   assert.equal(r.status,'closed',profile);assert.equal(r.revision,stages.length,profile);assert.deepEqual(r.metadata_json.fields,fields[profile],profile);
   assert.equal((await rows('ns_management_record_events','record_id=eq.'+id+'&select=id')).length,stages.length,profile);
   pass('B4 profile '+profile+' full lifecycle, durable fields, invalid stage refused');
 }
 const pressing=randomUUID(),pp={order_id:pressing,ticket_number:'B4-'+pressing,customer_name:'Client recette',items_summary:'1 chemise',total_xaf:1000,deposit_xaf:0,promised_at:'2027-03-10T12:00:00Z'};
 await applied(a,event(a,'pressing_order.created',pressing,pp));
 for(const [i,from,to] of [[1,'received','in_progress'],[2,'in_progress','ready'],[3,'ready','picked_up']]) await applied(a,event(a,'pressing_order.status_changed:'+to,pressing,{order_id:pressing,from_status:from,expected_version:i,reason:'Recette pressing'}));
 pass('B4 profile pressing: receipt through collection');


 const customer=randomUUID();
 await applied(a,event(a,'customer.created',customer,{customer_id:customer,display_name:'Client fidélité B4',contact_consent:false}));
 const program=randomUUID();
 await applied(a,event(a,'loyalty_program.updated',program,{program_id:program,activity_profile:'autre',program_code:'visits',name:'Deux visites',metric_code:'visits',unit_amount_xaf:1,target_value:2,reward_description:'Récompense recette',window_days:0,active:true},null));
 const activity=(session)=>{const id=randomUUID();return event(session,'loyalty_activity.recorded',id,{activity_event_id:id,program_id:program,customer_id:customer,amount_xaf:1000});};
 const v1=activity(a);await applied(a,v1);assert.equal((await applied(a,v1)).idempotent,true);
 const earned=await applied(b,activity(b));assert.equal(earned.result.rewards_earned,1);assert.equal(earned.result.reward_events.length,1);
 const reward=earned.result.reward_events[0].event_id;
 const redeem=event(a,'loyalty_reward.redeemed',reward,{reward_event_id:reward,program_id:program,customer_id:customer,wave_number:1});
 await applied(a,redeem);assert.equal((await applied(a,redeem)).idempotent,true);
 await denied(b,event(b,'loyalty_reward.redeemed',reward,{reward_event_id:reward,program_id:program,customer_id:customer,wave_number:1}));
 const [rw]=await rows('ns_loyalty_events','id=eq.'+reward+'&select=reward_status');assert.equal(rw.reward_status,'redeemed');
 pass('B4 loyalty: real customer visits on two devices, one reward, one redemption and retry');
 const [dest]=await success(base+'/rest/v1/ns_sites',{org_id:org,code:'B4DEST',name:'Destination recette'});
 const stock=randomUUID(),rawSku='b4-'+stock,sku=rawSku.toUpperCase();
 const itemReceipt=await applied(a,event(a,'inventory_item.created',stock,{inventory_item_id:stock,sku:rawSku,name:'Article transfert',unit:'piece',reorder_level:1}));
 assert.equal(itemReceipt.result.sku,sku,'server canonical SKU');
 const [createdItem]=await rows('ns_inventory_items','id=eq.'+stock+'&select=sku,unit,site_id');assert.equal(createdItem.sku,sku);assert.equal(createdItem.unit,'piece');assert.equal(createdItem.site_id,site);
 const mv=randomUUID();
 await applied(a,event(a,'inventory_movement.created',mv,{movement_id:mv,inventory_item_id:stock,movement_type:'in',quantity_delta:10,reason:'Stock initial B4'}));
 const transfer=randomUUID(),tp={transfer_id:transfer,source_site_id:site,destination_site_id:dest.id,inventory_item_id:stock,sku_snapshot:sku,unit:'piece',quantity:4,reference:'B4-TRANSFER',requested_at:new Date().toISOString()};
 const wrong=randomUUID();const invalidSku=await send(a,event(a,'inventory_transfer.requested',wrong,{...tp,transfer_id:wrong,reference:'B4-WRONG-SKU',sku_snapshot:sku+'-WRONG'}));assert.ok(invalidSku.status>=400);assert.match(JSON.stringify(invalidSku.data),/NAXA_INVENTORY_TRANSFER_ITEM_MISMATCH/);
 await applied(a,event(a,'inventory_transfer.requested',transfer,tp));
 const excess=randomUUID();await denied(a,event(a,'inventory_transfer.requested',excess,{...tp,transfer_id:excess,reference:'B4-EXCESS',quantity:7}));
 const approval={...transition(transfer,'inventory_transfer','open','approved',1),source_site_id:site,destination_site_id:dest.id};
 await applied(b,event(b,'inventory_transfer.status_changed',transfer,approval));
 const received=event(a,'inventory_transfer.received_at_destination',transfer,{...tp,expected_version:2,reason:'Réception B4',received_at:new Date().toISOString()},dest.id);
 await denied(a,event(a,'inventory_transfer.received_at_destination',transfer,{...tp,expected_version:2,reason:'Mauvais site',received_at:new Date().toISOString()},site));
 await applied(a,received);assert.equal((await applied(a,received)).idempotent,true);
 const items=await rows('ns_inventory_items','org_id=eq.'+org+'&sku=eq.'+sku+'&select=site_id,quantity');
 assert.equal(items.length,2);assert.equal(Number(items.find(r=>r.site_id===site).quantity),6);assert.equal(Number(items.find(r=>r.site_id===dest.id).quantity),4);
 const [tr]=await rows('ns_inventory_transfers','id=eq.'+transfer+'&select=status,revision');assert.equal(tr.status,'received');assert.equal(tr.revision,3);
 pass('B4 stock transfer: reservation prevents excess, approved reception at destination, conserved quantities and exact retry');
 const counted=(session,expected,delta)=>{const id=randomUUID();return event(session,'inventory_movement.created',id,{movement_id:id,inventory_item_id:stock,movement_type:'adjustment',expected_quantity:expected,quantity_delta:delta,reason:'Comptage B4 physique'});};
 const correction=counted(a,6,-1);await applied(a,correction);assert.equal((await applied(a,correction)).idempotent,true);
 await denied(b,counted(b,6,-2));const [countedItem]=await rows('ns_inventory_items','id=eq.'+stock+'&select=quantity');assert.equal(Number(countedItem.quantity),5);
 pass('B4 inventory count: atomic comparison, exact retry and stale second-device count denied');
 const staffIds=[];
 for(const kind of ['staff_commission','staff_advance','staff_bonus']){
  const id=randomUUID();staffIds.push(id);await applied(a,event(a,kind+'.created',id,document(id,kind,1200,0,'pending_review')));
  await denied(a,event(a,kind+'.status_changed',id,transition(id,kind,'pending_review','paid',1)));
  const approve=event(b,kind+'.status_changed',id,transition(id,kind,'pending_review','approved',1));await applied(b,approve);assert.equal((await applied(b,approve)).idempotent,true);
  await denied(a,event(a,kind+'.status_changed',id,transition(id,kind,'pending_review','rejected',1)));
  await applied(a,event(a,kind+'.status_changed',id,transition(id,kind,'approved','paid',2)));
  const [p]=await rows('ns_management_records','id=eq.'+id+'&select=status,paid_xaf,revision');assert.equal(p.status,'paid');assert.equal(Number(p.paid_xaf),1200);assert.equal(p.revision,3);
 }
 pass('B4 variable compensation: commission, advance and bonus review, stale decision denied, declared settlement');
 const goal=randomUUID();await applied(a,event(a,'business_goal.created',goal,{...document(goal,'business_goal',25000),counterparty:'daily',metadata_json:{period:'daily',period_start:'2026-11-27',period_end:'2026-11-27',baseline:'approved_at_creation'}}));
 await denied(b,event(b,'business_goal.status_changed',goal,transition(goal,'business_goal','open','approved',1,{period_start:'2026-11-28'})));
 const [baseGoal]=await rows('ns_management_records','id=eq.'+goal+'&select=amount_xaf,metadata_json,revision');assert.equal(baseGoal.amount_xaf,25000);assert.equal(baseGoal.metadata_json.period_start,'2026-11-27');assert.equal(baseGoal.revision,1);
 pass('B4 objective: confirmed baseline immutable under attempted mutation');
 // Same-tenant cashier can operate the site, but cannot see or change variable remuneration.
 const email='b4-cashier-'+randomUUID()+'@example.test',password='Qa7!'+randomUUID(),loginId='NS-'+randomUUID().replaceAll('-','').slice(0,10).toUpperCase();
 const user=await success(base+'/auth/v1/admin/users',{email,password,email_confirm:true,app_metadata:{app_code:'naxa-services'}});
 const [account]=await success(base+'/rest/v1/ns_accounts',{auth_user_id:user.id,login_id:loginId,auth_alias:email,password_change_required:false});
 const [member]=await success(base+'/rest/v1/ns_members',{org_id:org,account_id:account.id,display_name:'Caissier B4',role_code:'cashier'});
 await success(base+'/rest/v1/ns_member_scopes',{org_id:org,member_id:member.id,scope_type:'site',scope_id:site,site_id:site,can_read:true,can_operate:true,can_manage:false});
 const cashier=await login({...f,login:loginId,password,device:{...f.device,installation_id:randomUUID()}});
 const validCustomer=randomUUID();await applied(cashier,event(cashier,'customer.created',validCustomer,{customer_id:validCustomer,display_name:'Client du caissier B4',contact_consent:false}));
 const forbidden=randomUUID();await denied(cashier,event(cashier,'staff_commission.created',forbidden,document(forbidden,'staff_commission',100,0,'pending_review')));
 await denied(cashier,event(cashier,'staff_commission.status_changed',staffIds[0],transition(staffIds[0],'staff_commission','paid','approved',3)));
 await denied(cashier,counted(cashier,5,-1));
 const forbiddenGoal=randomUUID();await denied(cashier,event(cashier,'business_goal.created',forbiddenGoal,document(forbiddenGoal,'business_goal',5000)));
 const direct=await success(base+'/rest/v1/ns_management_records?id=in.('+staffIds.join(',')+')&select=id',undefined,cashier.access_token,anon,'GET');assert.deepEqual(direct,[]);
 const history=await success(base+'/rest/v1/ns_management_record_events?record_id=in.('+staffIds.join(',')+')&select=id',undefined,cashier.access_token,anon,'GET');assert.deepEqual(history,[]);
 const sync=await success(base+'/rest/v1/rpc/ns_pull_sync_changes',{p_org_id:org,p_device_id:cashier.device_id,p_after_cursor:0,p_limit:200},cashier.access_token,anon);
 assert.ok(sync.changes.some(x=>x.aggregate_id===invoice));assert.ok(!sync.changes.some(x=>staffIds.includes(x.aggregate_id)));
 pass('B4 roles: operating cashier may create customer but cannot count stock, set targets or read/approve remuneration via REST or peer sync');



 const peer=await success(base+'/rest/v1/rpc/ns_pull_sync_changes',{p_org_id:org,p_device_id:a.device_id,p_after_cursor:0,p_limit:200},a.access_token,anon);
 assert.ok(Array.isArray(peer.changes));assert.ok(peer.changes.some(x=>x.aggregate_id===invoice&&x.action_code==='invoice.status_changed'));
 pass('B4 peer sync: second device settlement visible through authenticated pull');
}
