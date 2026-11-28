\set ON_ERROR_STOP on
begin;
-- Isolated auth fixture, no production identities.
alter table auth.users add column if not exists phone text;
alter table auth.users add column if not exists phone_confirmed_at timestamptz;
insert into auth.users(id,email,phone,phone_confirmed_at) values
 ('c1000000-0000-0000-0000-000000000001','grillad-owner@x.invalid','237699000011',now()),
 ('c1000000-0000-0000-0000-000000000002','grillad-operator@x.invalid','237699000012',now()),
 ('c1000000-0000-0000-0000-000000000003','grillad-seller@x.invalid','237699000013',now());
insert into auth.sessions(id,user_id) values('c1000000-0000-0000-0000-000000000011','c1000000-0000-0000-0000-000000000001'),('c1000000-0000-0000-0000-000000000013','c1000000-0000-0000-0000-000000000003');
set role service_role;
do $test$ declare e uuid:='c2000000-0000-0000-0000-000000000001';u uuid:='c1000000-0000-0000-0000-000000000001';op uuid:='c1000000-0000-0000-0000-000000000002';v jsonb;begin
 v:=public.grillad_central_provision(e,op,u,'+237699000011','Test grillad','Point test','grillad_premium_month');
 if v->>'status'<>'billing_only' or public.grillad_central_provision(e,op,u,'+237699000011','Test grillad','Point test','grillad_premium_month')<>v then raise exception 'provision replay';end if;
 perform set_config('grillad.test.org',v->>'org',true);perform set_config('grillad.test.site',v->>'site',true);
 if not public.grillad_auth_begin(repeat('c',64),false) or not public.grillad_auth_finish(repeat('c',64),u,'c1000000-0000-0000-0000-000000000011',gen_random_uuid(),'web') then raise exception 'billing login';end if;
 perform public.grillad_payment_prepare(e,'mtn_momo');
 begin perform public.grillad_payment_confirm(e,op,'TEST-GRILLAD-1',5999,now(),repeat('a',64));raise exception 'wrong payment';exception when invalid_parameter_value then null;end;
 if public.grillad_payment_confirm(e,op,'TEST-GRILLAD-1',6000,now(),repeat('a',64))->>'status'<>'processed' then raise exception 'payment activation';end if;
 if public.grillad_payment_confirm(e,op,'TEST-GRILLAD-1',6000,now(),repeat('a',64))->>'status'<>'processed' then raise exception 'payment replay';end if;

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
 begin perform public.grillad_offline_batch(o,s,gen_random_uuid(),d,null,l);raise exception 'same line IDs accepted in different batch';exception when invalid_parameter_value then null;end;
 if public.grillad_offline_cancel(o,s,e,d,null,l)->>'status'<>'committed' then raise exception 'cancel erased committed batch';end if;
 e:=gen_random_uuid();if public.grillad_offline_cancel(o,s,e,d-1,null,l)->>'status'<>'cancelled' then raise exception 'cancel uncertain batch';end if;
 begin perform public.grillad_offline_batch(o,s,e,d-1,null,l);raise exception 'cancelled batch replayed';exception when invalid_parameter_value then null;end;
 perform public.grillad_action(o,s,gen_random_uuid(),'open_cash','{"opening":1000}');
 e:=gen_random_uuid();perform public.grillad_action(o,s,e,'sell',jsonb_build_object('item',i,'qty',1,'price',1000,'received',1000,'method','mtn_momo'));
 v:=public.grillad_snapshot(o,s,d,d);if (v->'cash'->>'expected')::bigint<>1000 or (v->'finance'->>'mtn_declared')::bigint<>1000 or (v->'finance'->>'encaissements')::bigint<>0 then raise exception 'mobile polluted physical cash';end if;
 perform public.grillad_action(o,s,gen_random_uuid(),'reconcile_mobile',jsonb_build_object('receipt',e,'source','direct','amount',1000,'reference','FIXTURE-REF-1'));
 v:=public.grillad_snapshot(o,s,d,d);if (v->'finance'->>'mobile_pending')::bigint<>0 or (v->'cash'->>'expected')::bigint<>1000 then raise exception 'reconciliation changed cash';end if;
 perform public.grillad_action(o,s,'c2000000-0000-0000-0000-000000000002','employee_request','{"phone":"+237699000013","name":"Test vendeur","role":"seller"}');
end $test$;
reset role;
set role service_role;
do $test$ declare e uuid:='c2000000-0000-0000-0000-000000000002';op uuid:='c1000000-0000-0000-0000-000000000002';u uuid:='c1000000-0000-0000-0000-000000000003';v jsonb;begin
 v:=public.grillad_central_employee(e,op,u,encode(sha256(convert_to(repeat('b',40),'UTF8')),'hex'));if v->>'status'<>'pending' then raise exception 'employee invite';end if;
 perform public.grillad_invite_rotate(e,op,encode(sha256(convert_to(repeat('d',40),'UTF8')),'hex'));
end $test$;
reset role;
set role authenticated;
do $test$ begin
 begin perform public.grillad_employee_accept('c2000000-0000-0000-0000-000000000002',repeat('b',40));raise exception 'owner accepted employee invitation';exception when insufficient_privilege then null;end;
end $test$;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"c1000000-0000-0000-0000-000000000013"}',true);
do $test$ declare e uuid:='c2000000-0000-0000-0000-000000000002';v jsonb;begin
 begin perform public.grillad_employee_accept(e,repeat('z',40));raise exception 'wrong invitation accepted';exception when insufficient_privilege then null;end;
 begin perform public.grillad_employee_accept(e,repeat('b',40));raise exception 'old token accepted';exception when insufficient_privilege then null;end;
 v:=public.grillad_employee_accept(e,repeat('d',40));
 if v->>'status'<>'processed' or public.grillad_employee_accept(e,repeat('d',40))<>v then raise exception 'employee accept replay';end if;
end $test$;
reset role;
-- Partner fixtures only; exercise central proof and real relational source contract.
create table public.sec_organizations(id uuid primary key,active boolean not null);
create table public.sec_sites(id uuid primary key,organization_id uuid not null,active boolean not null);
create table public.sec_devices(id uuid primary key,organization_id uuid not null,site_id uuid not null,label text,kind text,observed_at timestamptz);
create table public.sec_incidents(id uuid primary key,organization_id uuid not null,site_id uuid not null,device_id uuid,occurred_at timestamptz);
insert into famille_core.organizations(id,legal_name,organization_type,status) values('c3000000-0000-0000-0000-000000000001','ZIPPLE test','retail','active'),('c3000000-0000-0000-0000-000000000002','SECURITY test','retail','active');
update famille_core.applications set status='active' where code in ('zipple','naxa_security');
insert into famille_core.organization_apps(organization_id,app_id,status) select case code when 'zipple' then 'c3000000-0000-0000-0000-000000000001'::uuid else 'c3000000-0000-0000-0000-000000000002'::uuid end,id,'active' from famille_core.applications where code in ('zipple','naxa_security');
insert into famille_core.locations(id,organization_id,name) values('c4000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','Snack test'),('c4000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000002','Cam test');
insert into famille_core.plans(app_id,code,name,amount_fcfa,billing_period) select id,'fixture-plan','Fixture',1,'monthly' from famille_core.applications where code in ('zipple','naxa_security');
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select o.organization_id,p.app_id,p.id,'active',now(),now()+interval '1 day' from famille_core.plans p join famille_core.organization_apps o on o.app_id=p.app_id where p.code='fixture-plan';

insert into public.sec_organizations values('c3000000-0000-0000-0000-000000000002',true);
insert into public.sec_sites values('c4000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000002',true);
insert into public.sec_devices values('c5000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000002','c4000000-0000-0000-0000-000000000002','Caméra test','camera',now());
insert into public.sec_incidents values('c5000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000002','c4000000-0000-0000-0000-000000000002','c5000000-0000-0000-0000-000000000001',now());
set role service_role;
do $test$ declare o uuid:=current_setting('grillad.test.org')::uuid;s uuid:=current_setting('grillad.test.site')::uuid;op uuid:='c1000000-0000-0000-0000-000000000002';zo uuid:='c3000000-0000-0000-0000-000000000001';zs uuid:='c4000000-0000-0000-0000-000000000001';so uuid:='c3000000-0000-0000-0000-000000000002';ss uuid:='c4000000-0000-0000-0000-000000000002';v jsonb;e uuid:=gen_random_uuid();begin
 begin perform public.grillad_partner_zipple(e,o,s,zo,zs,repeat('c',64),now()+interval '1 day');raise exception 'missing consent accepted';exception when insufficient_privilege then null;end;
 perform public.grillad_partner_approval('zipple',o,s,zo,zs,op,repeat('a',64),repeat('b',64));
 if not public.grillad_partner_zipple(e,o,s,zo,zs,repeat('c',64),now()+interval '1 day') then raise exception 'zipple link';end if;
 if public.grillad_connect_catalog(repeat('c',64))->>'merchant'<>'GRILLAD' then raise exception 'zipple catalog';end if;
 perform public.grillad_partner_approval('security',o,s,so,ss,op,repeat('d',64),repeat('e',64));
 if not public.grillad_security_bind(o,s,so,ss,so,ss) then raise exception 'security bind';end if;
 v:=public.grillad_security_project(o,s,so,ss);if (v->>'cameras')::int<>1 or (v->>'incidents')::int<>0 or (v->>'live_available')::boolean then raise exception 'security projection';end if;
 v:=public.grillad_security_project(o,s,so,ss);if (v->>'incidents')::int<>0 then raise exception 'security duplicate';end if;
end $test$;
reset role;
-- A second renewal request with an expired intent is a fixture, not a real debit.
insert into grillad_private.central_requests(id,org,site,actor,kind,details) values('c2000000-0000-0000-0000-000000000009',current_setting('grillad.test.org')::uuid,current_setting('grillad.test.site')::uuid,'c1000000-0000-0000-0000-000000000001','renewal','{"plan":"grillad_premium_month","amount":6000,"currency":"FCFA"}');
set role service_role;
select public.grillad_payment_prepare('c2000000-0000-0000-0000-000000000009','mtn_momo');
reset role;
update famille_core.payment_intents set expires_at=now()-interval '1 second' where id=(select intent_id from grillad_private.renewal_payment_links where request_id='c2000000-0000-0000-0000-000000000009');
set role service_role;
do $test$ declare v jsonb;e uuid:=gen_random_uuid();q uuid:='c2000000-0000-0000-0000-000000000009';op uuid:='c1000000-0000-0000-0000-000000000002';begin
 if public.grillad_payment_prepare(q,'bank')->>'status'<>'expired' or public.grillad_payment_prepare(q,'bank')->>'channel'<>'mtn_momo' then raise exception 'expired payment status';end if;
 v:=public.grillad_payment_reissue(e,q,op,'orange_money',repeat('f',64));
 if v->>'status'<>'reissued' or v->>'intent'=v->>'previous' or public.grillad_payment_reissue(e,q,op,'orange_money',repeat('f',64))<>v then raise exception 'payment reissue';end if;
 if public.grillad_payment_prepare(q,'bank')->>'channel'<>'orange_money' or public.grillad_payment_prepare(q,'bank')->>'status'<>'pending' then raise exception 'reissued payment status';end if;
 begin perform public.grillad_payment_reissue(gen_random_uuid(),q,op,'bank',repeat('e',64));raise exception 'unexpired intent reissued';exception when invalid_parameter_value then null;end;
 v:=public.grillad_security_tick(10);if (v->>'processed')::int<>1 or (v->>'failed')::int<>0 then raise exception 'security tick';end if;
end $test$;
reset role;
-- Reading an inactive donor must not expose old cached inventory.
update public.sec_sites set active=false where id='c4000000-0000-0000-0000-000000000002';
set role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"c1000000-0000-0000-0000-000000000011"}',true);
do $test$ declare v jsonb;begin
 v:=public.grillad_security_list(current_setting('grillad.test.org')::uuid,current_setting('grillad.test.site')::uuid);
 if (v->>'available')::boolean or jsonb_array_length(v->'cameras')<>0 or jsonb_array_length(v->'incidents')<>0 or v->>'reason'<>'SOURCE_INACTIVE' then raise exception 'inactive source leak';end if;
end $test$;
reset role;
-- NAXA-derived independent debit/credit proof, fixture only.
set role service_role;
select public.grillad_subscription_destination_set('orange_money','Fixture beneficiary','FIXTURE-DEST',true);
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"c1000000-0000-0000-0000-000000000011"}',true);
do $test$ declare q uuid:='c2000000-0000-0000-0000-000000000009';v jsonb;begin
 v:=public.grillad_payment_quote(current_setting('grillad.test.org')::uuid,current_setting('grillad.test.site')::uuid,q,'orange_money');
 if v->'destination'->>'reference'<>'FIXTURE-DEST' then raise exception 'destination not frozen';end if;
 v:=public.grillad_subscription_declare(current_setting('grillad.test.org')::uuid,current_setting('grillad.test.site')::uuid,q,'MANUAL-FIXTURE',6000,'699000011',now());
 if v->>'status'<>'manual_review' then raise exception 'manual declaration auto approved';end if;
end $test$;
reset role;
set role service_role;
do $test$ declare q uuid:='c2000000-0000-0000-0000-000000000009';v jsonb;begin
 v:=public.grillad_subscription_proof(q,1::smallint,'c1000000-0000-0000-0000-000000000001','DEBIT-FIXTURE',6000,'699000011','FIXTURE-DEST',now(),repeat('1',64));
 if v->>'status'<>'awaiting_independent_proof' then raise exception 'single proof auto approved';end if;
 v:=public.grillad_subscription_proof(q,2::smallint,'c1000000-0000-0000-0000-000000000002','CREDIT-FIXTURE',6000,'699000011','FIXTURE-DEST',now(),repeat('2',64));
 if v->>'status'<>'processed' then raise exception 'independent proofs not matched';end if;
end $test$;
reset role;
insert into grillad_private.central_requests(id,org,site,actor,kind,details) values('c2000000-0000-0000-0000-000000000010',current_setting('grillad.test.org')::uuid,current_setting('grillad.test.site')::uuid,'c1000000-0000-0000-0000-000000000001','renewal','{"plan":"grillad_premium_month","amount":6000,"currency":"FCFA"}');
set role authenticated;
do $test$ declare q uuid:='c2000000-0000-0000-0000-000000000010';o uuid:=current_setting('grillad.test.org')::uuid;s uuid:=current_setting('grillad.test.site')::uuid;begin
 perform public.grillad_payment_quote(o,s,q,'orange_money');
 begin perform public.grillad_subscription_declare(o,s,q,'credit.fixture',6000,'699000011',now());raise exception 'cross intent reference reused';exception when unique_violation then null;end;
end $test$;
reset role;
rollback;
