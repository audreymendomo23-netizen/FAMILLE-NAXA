-- Isolated, after v24-26 fixtures.
insert into public.ns_appointments(id,org_id,site_id,customer_id,service_id,assigned_member_id,starts_at,ends_at,status)
select ('82000000-0000-4000-8000-00000000024'||i)::uuid,'20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','81000000-0000-4000-8000-000000000241',case i when 2 then '60000000-0000-4000-8000-000000000242'::uuid else '60000000-0000-4000-8000-000000000241'::uuid end,'2026-11-27 10:00+01','2026-11-27 11:00+01','completed' from generate_series(2,3)i;
insert into public.ns_appointment_status_events(id,org_id,site_id,appointment_id,to_status,actor_member_id,occurred_at)
select gen_random_uuid(),org_id,site_id,id,'completed',assigned_member_id,'2026-11-27 11:00+01' from public.ns_appointments where id in ('82000000-0000-4000-8000-000000000242','82000000-0000-4000-8000-000000000243');
insert into public.ns_sales(id,org_id,site_id,customer_id,sale_number,subtotal_xaf,total_xaf,created_by) values('83000000-0000-4000-8000-000000000242','20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','80000000-0000-4000-8000-000000000241','QA-MULTILINE',10000,10000,'60000000-0000-4000-8000-000000000241');
insert into public.ns_sale_lines(id,org_id,site_id,sale_id,item_type,description,quantity,unit_price_xaf,idempotency_key)
select ('85000000-0000-4000-8000-00000000024'||i)::uuid,'20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000242','service','QA service',1,case i when 2 then 4000 else 6000 end,gen_random_uuid() from generate_series(2,3)i;
insert into public.ns_payments(org_id,site_id,sale_id,payment_method,amount_xaf,status,confirmed_at,idempotency_key) values('20000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241','83000000-0000-4000-8000-000000000242','mobile_money',10000,'confirmed','2026-11-27 12:00+01',gen_random_uuid());
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241';s uuid:='30000000-0000-4000-8000-000000000241';v uuid:='83000000-0000-4000-8000-000000000242';b uuid:='86000000-0000-4000-8000-000000000242';r jsonb;alloc jsonb:='[{"line_id":"85000000-0000-4000-8000-000000000242","appointment_id":"82000000-0000-4000-8000-000000000242"},{"line_id":"85000000-0000-4000-8000-000000000243","appointment_id":"82000000-0000-4000-8000-000000000243"}]';begin
 begin perform public.ns_prepare_multiline_commissions(o,s,v,b,jsonb_build_array(alloc->0,alloc->0));raise exception 'QA_DUPLICATE';exception when others then if sqlerrm not like '%NS_MULTILINE_DUPLICATE%' then raise;end if;end;
 r:=public.ns_prepare_multiline_commissions(o,s,v,b,alloc);
 if r->>'status'<>'prepared' or jsonb_array_length(r->'lines')<>2 or r is distinct from public.ns_prepare_multiline_commissions(o,s,v,b,jsonb_build_array(alloc->1,alloc->0)) then raise exception 'QA_BATCH_REPLAY';end if;
 if (public.ns_review_settled_commission(o,s,(r->'lines'->0->>'entry_id')::uuid,gen_random_uuid(),'approve','QA allocated line')->>'status')<>'approved' then raise exception 'QA_LINE_APPROVAL';end if;
 begin perform public.ns_prepare_settled_commission(o,s,'82000000-0000-4000-8000-000000000242',v);raise exception 'QA_DOUBLE';exception when others then if sqlerrm not like '%NS_COMMISSION_SETTLEMENT_CONFLICT%' then raise;end if;end;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_commission_entries where sale_id='83000000-0000-4000-8000-000000000242')<>2 or (select sum(base_amount_xaf) from public.ns_commission_entries where sale_id='83000000-0000-4000-8000-000000000242')<>10000 then raise exception 'QA_ALLOCATION_TOTAL';end if;
end $qa$;
select 'PASS: explicit multiline commission allocation, two executors, exact replay, scoped approval and no duplicate' as result;
