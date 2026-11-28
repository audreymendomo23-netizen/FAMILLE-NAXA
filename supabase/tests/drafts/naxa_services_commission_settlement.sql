-- Runs after v24 fixtures and v25 definition, within disposable rollback.
insert into public.ns_customers(id,org_id,site_id,display_name) values('80000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','QA customer');
insert into public.ns_services(id,org_id,site_id,code,activity,name,price_xaf) values('81000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','QA','service','QA service',10000);
insert into public.ns_appointments(id,org_id,site_id,customer_id,service_id,assigned_member_id,starts_at,ends_at,status) values('82000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','81000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000242','2026-11-27 10:00+01','2026-11-27 11:00+01','completed');
insert into public.ns_appointment_status_events(id,org_id,site_id,appointment_id,to_status,actor_member_id,occurred_at) values(gen_random_uuid(),'20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','82000000-0000-4000-8000-000000000241','completed','60000000-0000-4000-8000-000000000242','2026-11-27 11:00+01');
insert into public.ns_sales(id,org_id,site_id,customer_id,sale_number,subtotal_xaf,total_xaf,created_by) values('83000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','QA-COM-SETTLE',10000,10000,'60000000-0000-4000-8000-000000000241');
insert into public.ns_sale_lines(org_id,site_id,sale_id,item_type,description,quantity,unit_price_xaf,idempotency_key) values('20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000241','service','QA service',1,10000,gen_random_uuid());
-- Bind an actual activity to exercise all four dimensions of commission policy scope.
update public.ns_organizations set activity_profile='coiffure',activity_profile_selected_at=now(),activity_profile_selected_by='60000000-0000-4000-8000-000000000241' where id='20000000-0000-4000-8000-000000000241' and activity_profile is null;
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
-- Subtransaction deliberately rolled back so the original v25-v29 fixtures remain intact.
do $qa$
declare o uuid:='20000000-0000-4000-8000-000000000241'; s uuid:='30000000-0000-4000-8000-000000000241'; a uuid:='82000000-0000-4000-8000-000000000241'; v uuid:='83000000-0000-4000-8000-000000000241'; staff uuid:='60000000-0000-4000-8000-000000000242'; promoter uuid:='60000000-0000-4000-8000-000000000241'; svc uuid:='81000000-0000-4000-8000-000000000241'; d date:='2026-11-27'; p uuid:=gen_random_uuid(); r jsonb;
begin
 begin
  if not public.ns_retire_automatic_commission_policy(o,'70000000-0000-4000-8000-000000000242') then raise exception 'QA_SCOPE_RETIRE'; end if;
  if public.ns_prepare_settled_commission(o,s,a,v)->>'status'<>'no_applicable_policy' then raise exception 'QA_SCOPE_NO_RULE'; end if;
  perform public.ns_publish_automatic_commission_policy(gen_random_uuid(),o,s,promoter,svc,'coiffure','qa-scope-other',1,'fixed_xaf',null,900,d,null,'QA scope different member');
  if public.ns_prepare_settled_commission(o,s,a,v)->>'status'<>'no_applicable_policy' then raise exception 'QA_SCOPE_WRONG_MEMBER'; end if;
  begin
   perform public.ns_publish_automatic_commission_policy(gen_random_uuid(),o,s,staff,svc,'garage','qa-invalid-activity',1,'fixed_xaf',null,900,d,null,'QA scope wrong activity');
   raise exception 'QA_SCOPE_WRONG_ACTIVITY_ACCEPTED';
  exception when others then if sqlerrm not like '%NS_COMMISSION_POLICY_SCOPE%' then raise; end if; end;
  if public.ns_publish_automatic_commission_policy(p,o,s,staff,svc,'coiffure','qa-scope-match',1,'percent_bps',700,null,d,null,'QA scope match')<>p then raise exception 'QA_SCOPE_PUBLISH'; end if;
  begin
   perform public.ns_publish_automatic_commission_policy(gen_random_uuid(),o,s,null,svc,'coiffure','qa-overlap',1,'fixed_xaf',null,800,d,null,'QA scope overlap');
   raise exception 'QA_SCOPE_OVERLAP_ACCEPTED';
  exception when others then if sqlerrm not like '%NS_COMMISSION_POLICY_AMBIGUOUS%' then raise; end if; end;
  r:=public.ns_prepare_settled_commission(o,s,a,v);
  if r->>'status'<>'pending_approval' or (r->>'commission_xaf')::bigint<>700 then raise exception 'QA_SCOPE_MATCH'; end if;
  raise exception using errcode='PZ001',message='QA scope checks completed; rollback fixture';
 exception when sqlstate 'PZ001' then null;
 end;
end $qa$;
select 'PASS: commission scope site member service activity, no applicable policy, overlap rejection and exact scoped calculation' as result;
reset role;
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
