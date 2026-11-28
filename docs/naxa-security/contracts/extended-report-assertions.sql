begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000241'),('00000000-0000-0000-0000-000000000242');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000241','QA report extension');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000241','00000000-0000-0000-0000-000000000241','manager',true),('10000000-0000-0000-0000-000000000241','00000000-0000-0000-0000-000000000242','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000241','10000000-0000-0000-0000-000000000241','QA'),('20000000-0000-0000-0000-000000000242','10000000-0000-0000-0000-000000000241','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000241','00000000-0000-0000-0000-000000000241',true),('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000242','00000000-0000-0000-0000-000000000242',true);
insert into public.sec_payment_receipts(organization_id,site_id,channel,reference,amount_fcfa,provider_confirmed_at) values ('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000241','bank','qa-report-241',5000,now()-interval '1 hour'),('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000242','bank','qa-report-242',9000,now()-interval '1 hour'),('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000241','bank','qa-report-old',7000,now()-interval '2 days');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000241',true);
do $q$declare j jsonb;begin
 j:=public.sec_site_report('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000241',now()-interval '1 day',now());
 if (j->'confirmed_payments'->>'count')::int<>1 or (j->'confirmed_payments'->>'amount_fcfa')::int<>5000 or (j->'maintenance'->>'reviewed_cost_fcfa')::int<>0 then raise exception 'report totals or period incorrect';end if;
 j:=public.sec_org_report('10000000-0000-0000-0000-000000000241',now()-interval '1 day',now());
 if (j->>'authorized_site_count')::int<>1 or (j->'totals'->>'confirmed_payments_fcfa')::int<>5000 or (j->'totals'->>'attendance_reviewed')::int is distinct from 0 or (j->'totals'->>'register_partners')::int is distinct from 0 or (j->'totals'->>'personal_notifications')::int is distinct from 0 then raise exception 'report cross site';end if;
 begin perform public.sec_site_report('10000000-0000-0000-0000-000000000241','20000000-0000-0000-0000-000000000242',now()-interval '1 day',now());raise exception 'unauthorized report';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
