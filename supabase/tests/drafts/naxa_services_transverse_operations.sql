-- Isolated test after v24/v25 fixtures.
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241'; s uuid:='30000000-0000-4000-8000-000000000241'; e uuid; r jsonb; event_id uuid:='84000000-0000-4000-8000-000000000241'; begin
 r:=public.ns_settled_commission_queue(o,s);
 if jsonb_array_length(r)<>1 then raise exception 'QA_QUEUE'; end if;
 e:=(r->0->>'id')::uuid;
 r:=public.ns_review_settled_commission(o,s,e,event_id,'approve','QA approved after payment');
 if r->>'status'<>'approved' then raise exception 'QA_APPROVAL'; end if;
 if (public.ns_review_settled_commission(o,s,e,event_id,'approve','QA approved after payment')->>'replayed')::boolean is not true then raise exception 'QA_REPLAY'; end if;
 begin perform public.ns_review_settled_commission(o,s,e,event_id,'reject','QA changed decision');raise exception 'QA_MUTATED';exception when others then if sqlerrm not like '%NS_COMMISSION_REVIEW_CONFLICT%' then raise;end if;end;
 begin perform public.ns_review_settled_commission(o,s,e,gen_random_uuid(),'reverse_refund','QA not refunded');raise exception 'QA_NO_REFUND';exception when others then if sqlerrm not like '%NS_COMMISSION_REFUND_PROOF_REQUIRED%' then raise;end if;end;
 r:=public.ns_cross_activity_operations(o,s);
 if r->>'site_id'<>s::text or (r->'appointments'->>'open')::integer<>0 then raise exception 'QA_COCKPIT';end if;
end $qa$;
reset role;
update public.ns_sales set status='refunded' where id='83000000-0000-4000-8000-000000000241';
update public.ns_payments set status='refunded' where sale_id='83000000-0000-4000-8000-000000000241';
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241'; s uuid:='30000000-0000-4000-8000-000000000241'; e uuid; r jsonb; begin
 e:=(public.ns_settled_commission_queue(o,s)->0->>'id')::uuid;
 r:=public.ns_review_settled_commission(o,s,e,'84000000-0000-4000-8000-000000000242','reverse_refund','QA full confirmed refund');
 if r->>'status'<>'reversed' then raise exception 'QA_REVERSAL';end if;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_commission_adjustments where amount_delta_xaf=-500 and org_id='20000000-0000-4000-8000-000000000241')<>1 then raise exception 'QA_ADJUSTMENT';end if;
 if has_function_privilege('anon','public.ns_cross_activity_operations(uuid,uuid)','EXECUTE') or has_function_privilege('anon','public.ns_review_settled_commission(uuid,uuid,uuid,uuid,text,text)','EXECUTE') then raise exception 'QA_ANON';end if;
end $qa$;
select 'PASS: transverse operational cockpit, commission approval, exact replay and confirmed full refund adjustment' as result;
