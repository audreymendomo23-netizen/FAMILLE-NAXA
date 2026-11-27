-- Runs after v28 fixtures, isolated.
insert into public.ns_appointments(id,org_id,site_id,customer_id,service_id,assigned_member_id,starts_at,ends_at,status) values('82000000-0000-4000-8000-000000000244','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','81000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000242','2026-11-27 10:00+01','2026-11-27 11:00+01','booked');
insert into public.ns_sales(id,org_id,site_id,customer_id,sale_number,subtotal_xaf,total_xaf,created_by) values('83000000-0000-4000-8000-000000000244','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','QA-DEFERRED',7000,7000,'60000000-0000-4000-8000-000000000241');
insert into public.ns_sale_lines(id,org_id,site_id,sale_id,item_type,description,quantity,unit_price_xaf,idempotency_key) values('85000000-0000-4000-8000-000000000244','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000244','service','QA service',1,7000,gen_random_uuid());
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241';s uuid:='30000000-0000-4000-8000-000000000241';v uuid:='83000000-0000-4000-8000-000000000244';b uuid:='86000000-0000-4000-8000-000000000244';r jsonb;alloc jsonb:='[{"line_id":"85000000-0000-4000-8000-000000000244","appointment_id":"82000000-0000-4000-8000-000000000244"}]';begin
 r:=public.ns_register_commission_plan(o,s,v,b,alloc);
 if r->>'state'<>'waiting' or r is distinct from public.ns_register_commission_plan(o,s,v,b,alloc) then raise exception 'QA_PLAN_REPLAY';end if;
 if public.ns_process_commission_plan(o,s,b)->>'state'<>'waiting' then raise exception 'QA_PREMATURE';end if;
end $qa$;
reset role;
update public.ns_appointments set status='completed' where id='82000000-0000-4000-8000-000000000244';
insert into public.ns_appointment_status_events(id,org_id,site_id,appointment_id,to_status,actor_member_id,occurred_at) select gen_random_uuid(),org_id,site_id,id,'completed',assigned_member_id,'2026-11-27 11:00+01' from public.ns_appointments where id='82000000-0000-4000-8000-000000000244';
insert into public.ns_payments(org_id,site_id,sale_id,payment_method,amount_xaf,status,confirmed_at,idempotency_key) values('20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000244','mobile_money',7000,'confirmed','2026-11-27 12:00+01',gen_random_uuid());
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241';s uuid:='30000000-0000-4000-8000-000000000241';b uuid:='86000000-0000-4000-8000-000000000244';r jsonb;begin
 r:=public.ns_process_commission_plan(o,s,b);
 if r->>'state'<>'processed' or r->'receipt'->>'status'<>'pending_approval' or r is distinct from public.ns_process_commission_plan(o,s,b) then raise exception 'QA_PLAN_PROCESS';end if;
 if jsonb_array_length(public.ns_list_commission_plans(o,s))<>1 then raise exception 'QA_PLAN_LIST';end if;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_commission_entries where sale_id='83000000-0000-4000-8000-000000000244' and status='pending_approval')<>1 then raise exception 'QA_PLAN_LEDGER';end if;
 if has_function_privilege('anon','public.ns_process_commission_plan(uuid,uuid,uuid)','EXECUTE') then raise exception 'QA_PLAN_ANON';end if;
end $qa$;
select 'PASS: deferred explicit commission plan, unpaid wait, completion and payment recheck, one pending entry and exact replay' as result;
