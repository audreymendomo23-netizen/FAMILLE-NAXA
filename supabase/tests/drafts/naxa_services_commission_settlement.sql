-- Runs after v24 fixtures and v25 definition, within disposable rollback.
insert into public.ns_customers(id,org_id,site_id,display_name) values('80000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','QA customer');
insert into public.ns_services(id,org_id,site_id,code,activity,name,price_xaf) values('81000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','QA','service','QA service',10000);
insert into public.ns_appointments(id,org_id,site_id,customer_id,service_id,assigned_member_id,starts_at,ends_at,status) values('82000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','81000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000242','2026-11-27 10:00+01','2026-11-27 11:00+01','completed');
insert into public.ns_appointment_status_events(id,org_id,site_id,appointment_id,to_status,actor_member_id,occurred_at) values(gen_random_uuid(),'20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','82000000-0000-4000-8000-000000000241','completed','60000000-0000-4000-8000-000000000242','2026-11-27 11:00+01');
insert into public.ns_sales(id,org_id,site_id,customer_id,sale_number,subtotal_xaf,total_xaf,created_by) values('83000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','QA-COM-SETTLE',10000,10000,'60000000-0000-4000-8000-000000000241');
insert into public.ns_sale_lines(org_id,site_id,sale_id,item_type,description,quantity,unit_price_xaf,idempotency_key) values('20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000241','service','QA service',1,10000,gen_random_uuid());
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000241',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000241","session_id":"qa-com241-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241'; s uuid:='30000000-0000-4000-8000-000000000241'; a uuid:='82000000-0000-4000-8000-000000000241'; v uuid:='83000000-0000-4000-8000-000000000241'; begin
 if public.ns_prepare_settled_commission(o,s,a,v)->>'status'<>'disabled' then raise exception 'QA_DISABLED'; end if;
 perform public.ns_set_automatic_commission_settings(o,true,2);
 if public.ns_prepare_settled_commission(o,s,a,v)->>'status'<>'awaiting_completed_and_confirmed' then raise exception 'QA_UNPAID'; end if;
end $qa$;
reset role;
insert into public.ns_payments(org_id,site_id,sale_id,payment_method,amount_xaf,status,confirmed_at,idempotency_key) values('20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000241','mobile_money',10000,'confirmed','2026-11-27 12:00+01',gen_random_uuid());
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241'; s uuid:='30000000-0000-4000-8000-000000000241'; a uuid:='82000000-0000-4000-8000-000000000241'; v uuid:='83000000-0000-4000-8000-000000000241'; r jsonb; r2 jsonb; begin
 r:=public.ns_prepare_settled_commission(o,s,a,v);r2:=public.ns_prepare_settled_commission(o,s,a,v);
 if r->>'status'<>'pending_approval' or (r->>'commission_xaf')::bigint<>500 or r2->>'status'<>'existing' or r->>'entry_id'<>r2->>'entry_id' then raise exception 'QA_SETTLEMENT'; end if;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_commission_entries where appointment_id='82000000-0000-4000-8000-000000000241' and status='pending_approval')<>1 then raise exception 'QA_LEDGER'; end if;
 if has_function_privilege('anon','public.ns_prepare_settled_commission(uuid,uuid,uuid,uuid)','EXECUTE') then raise exception 'QA_ANON'; end if;
end $qa$;
select 'PASS: explicit single-service settlement, disabled and unpaid blocked, confirmed amount pending approval, exact retry' as result;
