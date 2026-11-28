begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000331'),('00000000-0000-0000-0000-000000000332');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000331','QA billing');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000331','00000000-0000-0000-0000-000000000331','owner',true),('10000000-0000-0000-0000-000000000331','00000000-0000-0000-0000-000000000332','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000331','10000000-0000-0000-0000-000000000331','A'),('20000000-0000-0000-0000-000000000332','10000000-0000-0000-0000-000000000331','B');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000331','00000000-0000-0000-0000-000000000331',true),('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000332','00000000-0000-0000-0000-000000000331',true),('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000331','00000000-0000-0000-0000-000000000332',true);
insert into public.sec_payment_receipts(organization_id,site_id,channel,reference,amount_fcfa,provider_confirmed_at) values ('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000331','bank','qa-billing-first',5000,now()),('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000332','bank','qa-billing-second',20000,now());
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000331',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000331','00000000-0000-0000-0000-000000000331','30000000-0000-0000-0000-000000000331','payment','{"reference":"qa-billing-first","amount_fcfa":5000,"channel":"bank"}'),('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000332','00000000-0000-0000-0000-000000000331','30000000-0000-0000-0000-000000000332','payment','{"reference":"qa-billing-second","amount_fcfa":20000,"channel":"bank"}');
do $q$declare o uuid:='10000000-0000-0000-0000-000000000331';s uuid:='20000000-0000-0000-0000-000000000331';t uuid:='20000000-0000-0000-0000-000000000332';a jsonb;b jsonb;v jsonb;begin
 v:=public.sec_billing_status(o,s);if v->>'status'<>'not_subscribed' then raise exception 'unpaid status';end if;
 a:=public.sec_service_action(o,s,gen_random_uuid(),'subscription','30000000-0000-0000-0000-000000000331','{"plan":"Essentiel","period":"monthly"}');
 b:=public.sec_service_action(o,t,gen_random_uuid(),'subscription','30000000-0000-0000-0000-000000000332','{"plan":"Business","period":"monthly"}');
 if a->>'ends_at'<>b->>'starts_at' then raise exception 'period overlap';end if;
 v:=public.sec_billing_status(o,s);if v->>'status'<>'active' or v->>'current_plan'<>'Essentiel' or v->>'next_plan'<>'Business' or jsonb_array_length(v->'history')<>2 then raise exception 'billing status';end if;
 v:=public.sec_billing_status(o,t);if v->>'status'<>'site_not_covered' or v->>'covered'<>'false' then raise exception 'essential site scope';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000332',true);
do $q$declare v jsonb;begin
 v:=public.sec_billing_status('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000331');if v->>'can_allocate'<>'false' or jsonb_array_length(v->'history')<>0 then raise exception 'operator financial disclosure';end if;
 begin perform public.sec_billing_status('10000000-0000-0000-0000-000000000331','20000000-0000-0000-0000-000000000332');raise exception 'other site';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
