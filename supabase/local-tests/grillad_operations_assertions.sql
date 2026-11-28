\set ON_ERROR_STOP on
begin;
-- Isolated auth fixture, no production identities.
alter table auth.users add column if not exists phone text;
alter table auth.users add column if not exists phone_confirmed_at timestamptz;
insert into auth.users(id,email,phone,phone_confirmed_at) values
 ('c1000000-0000-0000-0000-000000000001','grillad-owner@x.invalid','237699000011',now()),
 ('c1000000-0000-0000-0000-000000000002','grillad-operator@x.invalid','237699000012',now()),
 ('c1000000-0000-0000-0000-000000000003','grillad-seller@x.invalid','237699000013',now());
insert into auth.sessions(id,user_id) values('c1000000-0000-0000-0000-000000000011','c1000000-0000-0000-0000-000000000001');
set role service_role;
do $test$ declare e uuid:='c2000000-0000-0000-0000-000000000001';u uuid:='c1000000-0000-0000-0000-000000000001';op uuid:='c1000000-0000-0000-0000-000000000002';v jsonb;begin
 v:=public.grillad_central_provision(e,op,u,'+237699000011','Test grillad','Point test','grillad_premium_month');
 if v->>'status'<>'billing_only' or public.grillad_central_provision(e,op,u,'+237699000011','Test grillad','Point test','grillad_premium_month')<>v then raise exception 'provision replay';end if;
 perform set_config('grillad.test.org',v->>'org',true);perform set_config('grillad.test.site',v->>'site',true);
 perform public.grillad_payment_prepare(e,'mtn_momo');
 begin perform public.grillad_payment_confirm(e,op,'TEST-GRILLAD-1',5999,now(),repeat('a',64));raise exception 'wrong payment';exception when invalid_parameter_value then null;end;
 if public.grillad_payment_confirm(e,op,'TEST-GRILLAD-1',6000,now(),repeat('a',64))->>'status'<>'processed' then raise exception 'payment activation';end if;
 if public.grillad_payment_confirm(e,op,'TEST-GRILLAD-1',6000,now(),repeat('a',64))->>'status'<>'processed' then raise exception 'payment replay';end if;
 if not public.grillad_auth_begin(repeat('c',64),false) or not public.grillad_auth_finish(repeat('c',64),u,'c1000000-0000-0000-0000-000000000011',gen_random_uuid(),'web') then raise exception 'provisioned login';end if;
end $test$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"c1000000-0000-0000-0000-000000000011"}',true);
do $test$ declare o uuid:=current_setting('grillad.test.org')::uuid;s uuid:=current_setting('grillad.test.site')::uuid;i uuid:=gen_random_uuid();e uuid:=gen_random_uuid();l jsonb;v jsonb;d date:=(now() at time zone 'Africa/Douala')::date;
begin
 if jsonb_array_length(public.grillad_workspace())<>1 then raise exception 'workspace after payment';end if;
 begin perform public.grillad_payment_prepare(gen_random_uuid(),'mtn_momo');raise exception 'client payment admin';exception when insufficient_privilege then null;end;
 perform public.grillad_action(o,s,i,'add_item','{"name":"Poulet test","family":"Poulet","price":1000,"cost":400}');
 l:=jsonb_build_array(jsonb_build_object('event',gen_random_uuid(),'operation','prepare','payload',jsonb_build_object('item',i,'qty',2)),jsonb_build_object('event',gen_random_uuid(),'operation','prepare','payload',jsonb_build_object('item',i,'qty',3)));
 v:=public.grillad_offline_batch(o,s,e,d,null,l);
 if (v->>'count')::int<>2 or public.grillad_offline_batch(o,s,e,d,null,l)<>v then raise exception 'offline replay';end if;
 begin perform public.grillad_offline_batch(o,s,gen_random_uuid(),d-1,null,l);raise exception 'old batch accepted';exception when invalid_parameter_value then null;end;
 perform public.grillad_action(o,s,'c2000000-0000-0000-0000-000000000002','employee_request','{"phone":"+237699000013","name":"Test vendeur","role":"seller"}');
end $test$;
reset role;
set role service_role;
do $test$ declare e uuid:='c2000000-0000-0000-0000-000000000002';op uuid:='c1000000-0000-0000-0000-000000000002';u uuid:='c1000000-0000-0000-0000-000000000003';v jsonb;begin
 v:=public.grillad_central_employee(e,op,u,repeat('b',64));if v->>'status'<>'processed' or public.grillad_central_employee(e,op,u,repeat('b',64))<>v then raise exception 'employee replay';end if;
end $test$;
reset role;
rollback;
