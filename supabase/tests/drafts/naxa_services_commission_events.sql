-- Runs after v28 fixtures, isolated.
insert into public.ns_appointments(id,org_id,site_id,customer_id,service_id,assigned_member_id,starts_at,ends_at,status) values('82000000-0000-4000-8000-000000000245','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','81000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000242','2026-11-27 10:00+01','2026-11-27 11:00+01','booked');
insert into public.ns_sales(id,org_id,site_id,customer_id,sale_number,subtotal_xaf,total_xaf,created_by) values('83000000-0000-4000-8000-000000000245','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','QA-EVENT',7000,7000,'60000000-0000-4000-8000-000000000241');
insert into public.ns_sale_lines(id,org_id,site_id,sale_id,item_type,description,quantity,unit_price_xaf,idempotency_key) values('85000000-0000-4000-8000-000000000245','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000245','service','QA service',1,7000,gen_random_uuid());
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241';s uuid:='30000000-0000-4000-8000-000000000241';v uuid:='83000000-0000-4000-8000-000000000245';b uuid:='86000000-0000-4000-8000-000000000245';r jsonb;alloc jsonb:='[{"line_id":"85000000-0000-4000-8000-000000000245","appointment_id":"82000000-0000-4000-8000-000000000245"}]';begin
 r:=public.ns_register_commission_plan(o,s,v,b,alloc);
 if r->>'state'<>'waiting' or r is distinct from public.ns_register_commission_plan(o,s,v,b,alloc) then raise exception 'QA_PLAN_REPLAY';end if;
 begin
  perform public.ns_prepare_settled_commission(o,s,'82000000-0000-4000-8000-000000000245',v);
  raise exception 'QA_EVENT_RESERVATION_BYPASS';
 exception when others then if sqlerrm not like '%NS_COMMISSION_SETTLEMENT_RESERVED%' then raise;end if;end;
 if has_function_privilege('authenticated','public.ns_process_next_commission_event()','EXECUTE') then raise exception 'QA_EVENT_CLIENT_GRANT';end if;
end $qa$;
reset role;
set local role service_role;
do $qa$ declare r jsonb;begin
 r:=public.ns_process_next_commission_event();
 if r->>'state'<>'waiting' then raise exception 'QA_EVENT_PREMATURE';end if;
end $qa$;
reset role;
update public.ns_appointments set status='completed' where id='82000000-0000-4000-8000-000000000245';
insert into public.ns_appointment_status_events(id,org_id,site_id,appointment_id,to_status,actor_member_id,occurred_at) select gen_random_uuid(),org_id,site_id,id,'completed',assigned_member_id,'2026-11-27 11:00+01' from public.ns_appointments where id='82000000-0000-4000-8000-000000000245';
insert into public.ns_payments(org_id,site_id,sale_id,payment_method,amount_xaf,status,confirmed_at,idempotency_key) values('20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000245','mobile_money',7000,'confirmed','2026-11-27 12:00+01',gen_random_uuid());
set local role service_role;
do $qa$ declare r jsonb; i int; processed boolean:=false;begin
 for i in 1..10 loop
  r:=public.ns_process_next_commission_event();
  if r->>'state'='processed' then processed:=true;end if;
  exit when r->>'state'='empty';
 end loop;
 if not processed or r->>'state'<>'empty' then raise exception 'QA_EVENT_DRAIN';end if;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_commission_entries where sale_id='83000000-0000-4000-8000-000000000245' and status='pending_approval')<>1 then raise exception 'QA_PLAN_LEDGER';end if;
 if has_function_privilege('anon','public.ns_process_commission_plan(uuid,uuid,uuid)','EXECUTE') then raise exception 'QA_PLAN_ANON';end if;
end $qa$;
select 'PASS: commission event worker, unpaid wait, completion and payment wakeup, one pending entry and idempotent drain' as result;
-- Runs after v28 fixtures, isolated.
insert into public.ns_appointments(id,org_id,site_id,customer_id,service_id,assigned_member_id,starts_at,ends_at,status) values('82000000-0000-4000-8000-000000000246','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','81000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000242','2026-11-27 10:00+01','2026-11-27 11:00+01','booked');
insert into public.ns_sales(id,org_id,site_id,customer_id,sale_number,subtotal_xaf,total_xaf,created_by) values('83000000-0000-4000-8000-000000000246','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','QA-REVOKED',7000,7000,'60000000-0000-4000-8000-000000000241');
insert into public.ns_sale_lines(id,org_id,site_id,sale_id,item_type,description,quantity,unit_price_xaf,idempotency_key) values('85000000-0000-4000-8000-000000000246','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000246','service','QA service',1,7000,gen_random_uuid());
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241';s uuid:='30000000-0000-4000-8000-000000000241';v uuid:='83000000-0000-4000-8000-000000000246';b uuid:='86000000-0000-4000-8000-000000000246';r jsonb;alloc jsonb:='[{"line_id":"85000000-0000-4000-8000-000000000246","appointment_id":"82000000-0000-4000-8000-000000000246"}]';begin
 r:=public.ns_register_commission_plan(o,s,v,b,alloc);
 if r->>'state'<>'waiting' or r is distinct from public.ns_register_commission_plan(o,s,v,b,alloc) then raise exception 'QA_PLAN_REPLAY';end if;
 begin
  perform public.ns_prepare_settled_commission(o,s,'82000000-0000-4000-8000-000000000246',v);
  raise exception 'QA_EVENT_RESERVATION_BYPASS';
 exception when others then if sqlerrm not like '%NS_COMMISSION_SETTLEMENT_RESERVED%' then raise;end if;end;
 if has_function_privilege('authenticated','public.ns_process_next_commission_event()','EXECUTE') then raise exception 'QA_EVENT_CLIENT_GRANT';end if;
end $qa$;
reset role;
update public.ns_members set status='suspended' where id='60000000-0000-4000-8000-000000000241';
set local role service_role;
do $qa$ declare r jsonb;begin
 r:=public.ns_process_next_commission_event();
 if r->>'state'<>'review_required' or r->>'id'<>'86000000-0000-4000-8000-000000000246' then raise exception 'QA_EVENT_REVOKED';end if;
end $qa$;
reset role;
update public.ns_members set status='active' where id='60000000-0000-4000-8000-000000000241';
do $qa$ begin
 if exists(select 1 from public.ns_commission_entries where sale_id='83000000-0000-4000-8000-000000000246') then raise exception 'QA_REVOKED_LEDGER';end if;
end $qa$;
select 'PASS: commission event reservation and revoked promoter block without ledger mutation' as result;
