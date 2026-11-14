\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('91000000-0000-0000-0000-000000000001','multi-app@x.invalid')
on conflict(id) do nothing;
insert into famille_core.identities(user_id,display_name)
 values('91000000-0000-0000-0000-000000000001','Multi App')
on conflict(user_id) do nothing;

insert into famille_core.organizations(id,legal_name,organization_type,created_by)
 values('92000000-0000-0000-0000-000000000001','Multi App Org','retail','91000000-0000-0000-0000-000000000001')
on conflict(id) do nothing;

insert into famille_core.organization_apps(organization_id,app_id,status)
 select '92000000-0000-0000-0000-000000000001',id,'active'
 from famille_core.applications where code in ('kiosko','campus237')
on conflict do nothing;

insert into famille_core.locations(id,organization_id,code,name)
 values('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','MAIN','Main location')
on conflict(id) do nothing;

insert into famille_core.memberships(id,user_id,organization_id,app_id,status,joined_at)
 select x.mid,'91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',a.id,'active',now()
 from (values
  ('94000000-0000-0000-0000-000000000001'::uuid,'kiosko'::text),
  ('94000000-0000-0000-0000-000000000002'::uuid,'campus237'::text)
 ) x(mid,code) join famille_core.applications a on a.code=x.code
on conflict(user_id,organization_id,app_id) do nothing;

insert into famille_core.role_assignments(id,membership_id,app_id,organization_id,role_code,status)
 select x.aid,m.id,m.app_id,m.organization_id,'owner','active'
 from (values
  ('95000000-0000-0000-0000-000000000001'::uuid,'94000000-0000-0000-0000-000000000001'::uuid),
  ('95000000-0000-0000-0000-000000000002'::uuid,'94000000-0000-0000-0000-000000000002'::uuid)
 ) x(aid,mid) join famille_core.memberships m on m.id=x.mid
on conflict(id) do nothing;

insert into famille_core.plans(app_id,code,name,amount_fcfa,billing_period)
 select id,'test-plan','Test plan',1000,'monthly' from famille_core.applications
 where code in ('kiosko','campus237') on conflict(app_id,code) do nothing;
insert into famille_core.subscriptions(id,organization_id,app_id,plan_id,status,starts_at,ends_at)
 select case a.code when 'kiosko' then '96000000-0000-0000-0000-000000000001'::uuid else '96000000-0000-0000-0000-000000000002'::uuid end,
 '92000000-0000-0000-0000-000000000001',a.id,p.id,'active',now()-interval '1 day',now()+interval '30 days'
 from famille_core.applications a join famille_core.plans p on p.app_id=a.id and p.code='test-plan'
 where a.code in ('kiosko','campus237') on conflict(id) do nothing;

update famille_core.applications set status='active' where code in ('kiosko','campus237');

create table if not exists famille_test.tx_app_scope(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null,
 app_id uuid not null,
 location_id uuid not null,
 amount_fcfa bigint not null
);
alter table famille_test.tx_app_scope enable row level security;
drop policy if exists tx_app_scope_select on famille_test.tx_app_scope;
create policy tx_app_scope_select on famille_test.tx_app_scope for select to authenticated
 using(famille_core.can_read_transaction_details(organization_id,app_id,location_id));
grant usage on schema famille_test to authenticated;
grant select on famille_test.tx_app_scope to authenticated;

insert into famille_test.tx_app_scope(organization_id,app_id,location_id,amount_fcfa)
 select '92000000-0000-0000-0000-000000000001',a.id,'93000000-0000-0000-0000-000000000001',100
 from famille_core.applications a where a.code in ('kiosko','campus237');

set role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','91000000-0000-0000-0000-000000000001','role','authenticated','app_metadata',jsonb_build_object('active_app_id',(select id::text from famille_core.applications where code='kiosko')))::text,true);
do $$
declare v_app uuid; n bigint;
begin
 select id into v_app from famille_core.applications where code='kiosko';
 if famille_core.current_app_id() is distinct from v_app then raise exception 'Kiosko app claim not resolved'; end if;
 select count(*) into n from famille_test.tx_app_scope;
 if n<>1 then raise exception 'Kiosko context expected 1 transaction row, got %',n; end if;
 if famille_core.can_read_transaction_details('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='campus237'),'93000000-0000-0000-0000-000000000001') then
   raise exception 'Kiosko token must not authorize Campus237 helper';
 end if;
 select count(*) into n from famille_core.organization_apps;
 if n<>1 then raise exception 'Kiosko context expected one organization app, got %',n; end if;
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub','91000000-0000-0000-0000-000000000001','role','authenticated','app_metadata',jsonb_build_object('active_app_id',(select id::text from famille_core.applications where code='campus237')))::text,true);
do $$
declare v_app uuid; n bigint;
begin
 select id into v_app from famille_core.applications where code='campus237';
 if famille_core.current_app_id() is distinct from v_app then raise exception 'Campus237 app claim not resolved'; end if;
 select count(*) into n from famille_test.tx_app_scope;
 if n<>1 then raise exception 'Campus237 context expected 1 transaction row, got %',n; end if;
 if famille_core.can_read_transaction_details('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko'),'93000000-0000-0000-0000-000000000001') then
   raise exception 'Campus237 token must not authorize Kiosko helper';
 end if;
end $$;

select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{}}',true);
do $$ begin
 if famille_core.current_app_id() is not null then raise exception 'Missing app claim must fail closed'; end if;
 if famille_core.is_admin() then raise exception 'Missing app claim cannot grant admin'; end if;
 if exists(select 1 from famille_core.outlet_ids()) then raise exception 'Missing app claim exposed outlet ids'; end if;
 if famille_core.has_organization_access('92000000-0000-0000-0000-000000000001') then raise exception 'Missing app claim exposed organization'; end if;
 if famille_core.subscription_allows_workspace('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko')) then raise exception 'Missing app claim authorized subscription workspace'; end if;
 if famille_core.can_access_outlet('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko'),'93000000-0000-0000-0000-000000000001') then raise exception 'Missing app claim authorized outlet'; end if;
 if famille_core.can_read_transaction_details('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko'),'93000000-0000-0000-0000-000000000001') then raise exception 'Missing app claim authorized transaction read'; end if;
 if famille_core.can_write_transactions('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko'),'93000000-0000-0000-0000-000000000001') then raise exception 'Missing app claim authorized transaction write'; end if;
 if famille_core.can_read_financial_aggregates('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko')) then raise exception 'Missing app claim authorized aggregates'; end if;
 if famille_core.can_manage_billing('92000000-0000-0000-0000-000000000001',(select id from famille_core.applications where code='kiosko')) then raise exception 'Missing app claim authorized billing'; end if;
 if famille_core.can_manage_billing_for_intent('96000000-0000-0000-0000-000000000001') then raise exception 'Missing app claim authorized payment intent'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"active_app_id":"not-a-uuid"}}',true);
do $$ begin
 if famille_core.current_app_id() is not null then raise exception 'Malformed app claim must fail closed'; end if;
 if famille_core.is_admin() then raise exception 'Malformed app claim cannot grant admin'; end if;
end $$;
reset role;
rollback;
