\set ON_ERROR_STOP on
begin;

-- Capture canonical app IDs as the database owner before switching to authenticated.
select id::text as kiosko_app_id from famille_core.applications where code='kiosko' \gset
select id::text as campus237_app_id from famille_core.applications where code='campus237' \gset
select set_config('famille_test.kiosko_app_id', :'kiosko_app_id', false);
select set_config('famille_test.campus237_app_id', :'campus237_app_id', false);

insert into auth.users(id,email) values
 ('97000000-0000-0000-0000-000000000001','central-admin@x.invalid'),
 ('97000000-0000-0000-0000-000000000002','kiosko-user@x.invalid'),
 ('97000000-0000-0000-0000-000000000003','campus-user@x.invalid'),
 ('97000000-0000-0000-0000-000000000004','unassigned-user@x.invalid'),
 ('97000000-0000-0000-0000-000000000005','second-admin@x.invalid')
on conflict(id) do nothing;
insert into famille_core.family_admins(user_id,status)
 values('97000000-0000-0000-0000-000000000001','active')
on conflict(user_id) do update set status='active',revoked_at=null;
do $admin_uniqueness$ begin
  begin
    insert into famille_core.family_admins(user_id,status)
    values('97000000-0000-0000-0000-000000000005','active');
    raise exception 'a second active central administrator was accepted';
  exception when unique_violation then null;
  end;
end $admin_uniqueness$;

insert into famille_core.client_app_access(user_id,app_id,status)
 select '97000000-0000-0000-0000-000000000002',id,'granted'
 from famille_core.applications where code='kiosko'
on conflict(user_id,app_id) do nothing;
insert into famille_core.client_app_access(user_id,app_id,status)
 select '97000000-0000-0000-0000-000000000003',id,'granted'
 from famille_core.applications where code='campus237'
on conflict(user_id,app_id) do nothing;

-- A duplicate platform assignment for one ordinary identity must be rejected.
do $$
begin
  begin
    insert into famille_core.client_app_access(user_id,app_id,status)
    select '97000000-0000-0000-0000-000000000002',id,'granted'
    from famille_core.applications where code='campus237';
    raise exception 'one identity was allowed to access two platforms';
  exception when unique_violation then null;
  end;
end $$;

create table if not exists famille_test.admin_metadata_scope(
  app_id uuid not null,
  marker text not null
);
alter table famille_test.admin_metadata_scope enable row level security;
drop policy if exists admin_metadata_scope_read on famille_test.admin_metadata_scope;
create policy admin_metadata_scope_read on famille_test.admin_metadata_scope
 for select to authenticated using(famille_core.is_admin());
grant usage on schema famille_test to authenticated;
grant select on famille_test.admin_metadata_scope to authenticated;
insert into famille_test.admin_metadata_scope(app_id,marker)
 select id,code from famille_core.applications;

create table if not exists famille_test.central_admin_transaction_scope(
  organization_id uuid not null,
  app_id uuid not null,
  location_id uuid not null,
  amount_fcfa bigint not null
);
alter table famille_test.central_admin_transaction_scope enable row level security;
drop policy if exists central_admin_transaction_scope_read on famille_test.central_admin_transaction_scope;
create policy central_admin_transaction_scope_read on famille_test.central_admin_transaction_scope
 for select to authenticated using(
   famille_core.can_read_transaction_details(organization_id,app_id,location_id)
 );
grant select on famille_test.central_admin_transaction_scope to authenticated;
insert into famille_test.central_admin_transaction_scope(organization_id,app_id,location_id,amount_fcfa)
 select '98000000-0000-0000-0000-000000000001',id,'98000000-0000-0000-0000-000000000002',125000
 from famille_core.applications where code='kiosko';

insert into famille_core.organizations(id,legal_name,organization_type,created_by)
 values('98000000-0000-0000-0000-000000000001','Audit Probe','test','97000000-0000-0000-0000-000000000001')
 on conflict(id) do nothing;

create table if not exists famille_test.admin_mutation_audit_probe(
 id uuid primary key default gen_random_uuid(), app_id uuid, organization_id uuid, marker text
);
 drop trigger if exists admin_mutation_audit_probe_trigger on famille_test.admin_mutation_audit_probe;
create trigger admin_mutation_audit_probe_trigger after insert or update or delete
 on famille_test.admin_mutation_audit_probe for each row
 execute function famille_core.audit_central_admin_mutation();
grant insert on famille_test.admin_mutation_audit_probe to authenticated;

-- Every central-admin-manageable metadata table must carry the audit trigger.
do $audit_coverage$
declare t text;
begin
  foreach t in array array[
    'applications','organizations','organization_apps','locations','memberships',
    'role_catalog','role_assignments','client_app_access','devices','app_installations',
    'subscriptions','plans','app_versions','payment_parser_rules'
  ] loop
    if not exists (
      select 1 from pg_trigger
      where tgrelid=to_regclass('famille_core.' || t)
        and tgname='audit_central_admin_' || t
        and not tgisinternal
    ) then
      raise exception 'missing central-admin audit trigger on famille_core.%',t;
    end if;
  end loop;
end
$audit_coverage$;

set role authenticated;
select set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"97000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{}}',true);
do $$
declare n bigint;
begin
 if not famille_core.is_admin() then raise exception 'central admin not recognized without app claim'; end if;
 select count(*) into n from famille_test.admin_metadata_scope;
 if n<>10 then raise exception 'central admin metadata scope expected 10 apps, got %',n; end if;
 select count(*) into n from famille_test.central_admin_transaction_scope;
 if n<>0 then raise exception 'central admin must not read transaction details'; end if;
 if exists(select 1 from famille_core.identities) then
   raise exception 'central admin must not read personal identity profile rows';
 end if;
 insert into famille_test.admin_mutation_audit_probe(app_id,organization_id,marker)
 select id,'98000000-0000-0000-0000-000000000001','central-admin-write'
 from famille_core.applications where code='kiosko';
 if not exists(select 1 from famille_core.audit_events where actor_id='97000000-0000-0000-0000-000000000001' and entity_type='admin_mutation_audit_probe' and action_code='insert') then
   raise exception 'central admin mutation was not audited';
 end if;
end $$;

-- Normal identities are independent and app-scoped.
select set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','97000000-0000-0000-0000-000000000002','role','authenticated','app_metadata',jsonb_build_object('active_app_id', :'kiosko_app_id'))::text,true);
do $$
begin
 if famille_core.is_admin() then raise exception 'ordinary Kiosko user became central admin'; end if;
 if famille_core.current_app_id() is distinct from current_setting('famille_test.kiosko_app_id')::uuid then raise exception 'Kiosko identity has wrong app context'; end if;
 if not famille_core.has_current_app_access() then raise exception 'Kiosko assigned app access missing: uid %, claim %',auth.uid(),famille_core.current_app_id(); end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',auth.uid()::text,'role','authenticated','app_metadata',jsonb_build_object('active_app_id', current_setting('famille_test.campus237_app_id')))::text,true);
 if famille_core.has_current_app_access() then raise exception 'Kiosko identity crossed into Campus237'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',auth.uid()::text,'role','authenticated','app_metadata',jsonb_build_object('active_app_id', current_setting('famille_test.kiosko_app_id')))::text,true);
end $$;

select set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','97000000-0000-0000-0000-000000000003','role','authenticated','app_metadata',jsonb_build_object('active_app_id', :'campus237_app_id'))::text,true);
do $$
begin
 if famille_core.is_admin() then raise exception 'ordinary Campus237 user became central admin'; end if;
 if famille_core.current_app_id() is distinct from current_setting('famille_test.campus237_app_id')::uuid then raise exception 'Campus237 identity has wrong app context'; end if;
 if not famille_core.has_current_app_access() then raise exception 'Campus237 assigned app access missing'; end if;
end $$;

select set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','97000000-0000-0000-0000-000000000004','role','authenticated','app_metadata',jsonb_build_object('active_app_id', :'kiosko_app_id'))::text,true);
do $unassigned_access$ begin
 if famille_core.has_current_app_access() then raise exception 'unassigned account received platform access'; end if;
end $unassigned_access$;

reset role;
do $audit_test$ begin
  begin
    update famille_core.audit_events set action_code='tampered'
    where actor_id='97000000-0000-0000-0000-000000000001'
      and entity_type='admin_mutation_audit_probe';
    raise exception 'audit event mutation unexpectedly succeeded';
  exception when sqlstate '55000' then null;
  end;
end $audit_test$;
rollback;
