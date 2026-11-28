\set ON_ERROR_STOP on
begin;
-- Synthetic actors: owner plus three distinct sellers on one point.
insert into auth.users(id,email) select ('b1000000-0000-0000-0000-00000000000'||n)::uuid,'grillad-'||n||'@x.invalid' from generate_series(1,4) n;
insert into auth.sessions(id,user_id) select ('b1000000-0000-0000-0000-00000000001'||n)::uuid,id from auth.users cross join lateral (select right(id::text,1) n) q where id::text like 'b1000000%';
insert into famille_core.organizations(id,legal_name,organization_type,status) values('b2000000-0000-0000-0000-000000000001','Test','retail','active');
update famille_core.applications set status='active' where code='grillad';
insert into famille_core.organization_apps(organization_id,app_id,status) select 'b2000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.locations(id,organization_id,name) values ('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','Test');
insert into grillad_private.enabled_sites(org,site) values ('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001');
insert into famille_core.client_app_access(user_id,app_id,status) select u.id,a.id,'granted' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.id::text like 'b1000000%';
insert into famille_core.memberships(user_id,organization_id,app_id,status) select u.id,'b2000000-0000-0000-0000-000000000001',a.id,'active' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.id::text like 'b1000000%';
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select id,app_id,organization_id,case when user_id='b1000000-0000-0000-0000-000000000001' then 'owner' else 'seller' end,case when user_id='b1000000-0000-0000-0000-000000000001' then null else 'b3000000-0000-0000-0000-000000000001'::uuid end from famille_core.memberships;
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select 'b2000000-0000-0000-0000-000000000001',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad_access_month';
insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,location_id,role_code)
select m.user_id,'grillad','professional',m.organization_id,r.location_id,r.role_code from famille_core.memberships m join famille_core.role_assignments r on r.membership_id=m.id;
set role service_role;
do $$
declare n int;u uuid;s uuid;installation uuid;h text;
begin
 for n in 1..4 loop
  u:=('b1000000-0000-0000-0000-00000000000'||n)::uuid;s:=('b1000000-0000-0000-0000-00000000001'||n)::uuid;installation:=('b4000000-0000-0000-0000-00000000000'||n)::uuid;h:=repeat(n::text,64);
  if not public.grillad_auth_begin(h,false) or not public.grillad_auth_finish(h,u,s,installation,'android') then raise exception 'login %',n;end if;
 end loop;
 for n in 1..5 loop if not public.grillad_auth_begin(repeat('a',64),false) then raise exception 'early throttle';end if;end loop;
 if public.grillad_auth_begin(repeat('a',64),false) then raise exception 'expected throttle';end if;
end $$;
reset role;
do $$begin if (select count(*) from famille_private.account_devices where app_code='grillad' and status='active')<>4 then raise exception 'cross seller eviction';end if;end $$;
-- Profile isolation, revisions and replay on two distinct bound users.
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);

-- The positive paths are deliberately synthetic and transactional. No hosted credentials.
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';v jsonb;
begin
 v:=public.grillad_backup_export(o,s);if v->>'format' is distinct from 'grillad-business-export-v2' or v->>'org' is distinct from o::text or v->>'site' is distinct from s::text then raise exception 'backup envelope';end if;
 if jsonb_typeof(v->'tables'->'sales') is distinct from 'array' or (v->'tables')?'drive_connections' then raise exception 'backup scope';end if;
 if not public.grillad_drive_begin(o,s,repeat('a',64),'sealed-fixture') then raise exception 'drive state';end if;
 perform public.grillad_backup_preferences(o,s,'off',360,1,1);
 begin perform public.grillad_drive_claim();raise exception 'claim exposed';exception when insufficient_privilege then null;end;
 begin perform public.grillad_central_overview();raise exception 'central exposed';exception when insufficient_privilege then null;end;
end $test$;
reset role;
set role service_role;
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';u uuid:='b1000000-0000-0000-0000-000000000001';v jsonb;
begin
 v:=public.grillad_drive_consume(repeat('a',64));if v->>'actor' is distinct from u::text then raise exception 'state binding';end if;
 begin perform public.grillad_drive_consume(repeat('a',64));raise exception 'state replay';exception when insufficient_privilege then null;end;
 if not public.grillad_drive_connect(o,s,u,'sealed-fixture') then raise exception 'drive connect';end if;
 if public.grillad_drive_claim() is not null then raise exception 'disabled cadence';end if;
end $test$;
reset role;
set role authenticated;
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';begin
 if public.grillad_drive_control(o,s,'now')->>'queued' is distinct from 'true' then raise exception 'queue request';end if;
end $test$;
reset role;
set role service_role;
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';u uuid:='b1000000-0000-0000-0000-000000000001';v jsonb;l uuid;
begin
 v:=public.grillad_drive_claim();l:=(v->>'lease')::uuid;
 if v->>'actor' is distinct from u::text or l is null then raise exception 'missing claim';end if;
 if public.grillad_drive_claim() is not null then raise exception 'duplicate claim';end if;
 begin perform public.grillad_drive_payload(o,s,u,gen_random_uuid());raise exception 'foreign lease';exception when insufficient_privilege then null;end;
 if public.grillad_drive_payload(o,s,u,l)->>'site' is distinct from s::text then raise exception 'payload';end if;
 if not public.grillad_drive_finish(o,s,u,l,v->>'slot',true) or public.grillad_drive_finish(o,s,u,l,v->>'slot',true) then raise exception 'finish replay';end if;
 if public.grillad_drive_claim() is not null then raise exception 'manual replay';end if;
end $test$;
reset role;
set role authenticated;
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';v jsonb;begin
 v:=public.grillad_drive_control(o,s,'status');if v->>'status' is distinct from 'uploaded' or v->>'last_success' is null then raise exception 'missing confirmation';end if;
 perform public.grillad_drive_control(o,s,'disconnect');
 if public.grillad_drive_control(o,s,'status')->>'connected' is distinct from 'false' then raise exception 'disconnect';end if;
end $test$;
reset role;
-- Canonical admin identity from the existing governance contract, fixture only.
create table if not exists famille_core.family_admins(user_id uuid primary key references auth.users(id),status text not null,revoked_at timestamptz);
insert into famille_core.family_admins(user_id,status) values('b1000000-0000-0000-0000-000000000004','active');
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000014","aal":"aal2","app_metadata":{}}',true);
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';begin
 if public.grillad_central_overview()->>'app' is distinct from 'grillad' then raise exception 'central identity';end if;
 if jsonb_array_length(public.grillad_central_clients())<>1 then raise exception 'central directory';end if;
 if public.grillad_central_client_state(o,'active','suspended','Synthetic central test')->>'status' is distinct from 'suspended' then raise exception 'central suspend';end if;
 if public.grillad_central_client_state(o,'suspended','active','Synthetic central test')->>'status' is distinct from 'active' then raise exception 'central resume';end if;
end $test$;
reset role;
-- Recover an actual sale and stock history from the portable snapshot, in this isolated transaction.
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';i uuid:=gen_random_uuid();begin
 perform public.grillad_action(o,s,i,'add_item','{"name":"Poulet restauration","family":"Poulet","price":1000,"cost":400}');
 perform public.grillad_action(o,s,gen_random_uuid(),'prepare',jsonb_build_object('item',i,'qty',5));
 perform public.grillad_action(o,s,gen_random_uuid(),'open_cash','{"opening":100}');
 perform public.grillad_action(o,s,gen_random_uuid(),'sell',jsonb_build_object('item',i,'qty',2,'price',1000,'received',2000));
end $test$;
reset role;
\ir ../../scripts/grillad/replay-business-archive.sql
do $test$ declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';archive jsonb;after_restore jsonb;counts jsonb;begin
 insert into grillad_private.attendance_policy(org,site,enabled,latitude,longitude,radius_m,max_accuracy_m,max_age_seconds,photo_retention_days) values(o,s,true,4.05,9.7,100,50,120,30);
 insert into grillad_private.attendance(id,org,site,actor,kind,captured_at,latitude,longitude,accuracy,photo,photo_hash,photo_until) values('b8000000-0000-0000-0000-000000000001',o,s,'b1000000-0000-0000-0000-000000000001','arrival',now(),4.05,9.7,5,decode('0102','hex'),repeat('a',64),now()+interval '1 day');
 archive:=grillad_private.backup_data(o,s);
 if archive->'tables'->'attendance'->0->'photo' is distinct from 'null'::jsonb then raise exception 'photo included';end if;
 if jsonb_array_length(archive->'tables'->'sales')<>1 then raise exception 'restore fixture missing sale';end if;
 begin perform pg_temp.grillad_replay_business(archive,o,s);raise exception 'nonempty target accepted';exception when invalid_parameter_value then null;end;
 begin perform pg_temp.grillad_replay_business(archive,o,gen_random_uuid());raise exception 'foreign archive accepted';exception when invalid_parameter_value then null;end;
 -- Synthetic rollback-only loss simulation. Never execute against a live database.
 delete from grillad_private.attendance where org=o and site=s;
 delete from grillad_private.attendance_policy where org=o and site=s;
 delete from grillad_private.cash_receipts where org=o and site=s;
 delete from grillad_private.sales where org=o and site=s;
 delete from grillad_private.preparations where org=o and site=s;
 delete from grillad_private.cash where org=o and site=s;
 delete from grillad_private.items where org=o and site=s;
 counts:=pg_temp.grillad_replay_business(archive,o,s);
 after_restore:=grillad_private.backup_data(o,s);
 if counts->>'sales' is distinct from '1' or after_restore->'tables' is distinct from archive->'tables' then raise exception 'restore data differs';end if;
end $test$;


-- Positive support call lifecycle with the existing canonical identity, agent contract and independent customer.
create table if not exists public.support_agents(user_id uuid primary key references auth.users(id),status text not null);
create table if not exists public.support_agent_permissions(agent_user_id uuid references auth.users(id),permission_code text,revoked_at timestamptz,primary key(agent_user_id,permission_code));
insert into public.support_agents values('b1000000-0000-0000-0000-000000000003','active');
insert into public.support_agent_permissions(agent_user_id,permission_code) select 'b1000000-0000-0000-0000-000000000003',x from unnest(array['queue_view','ticket_view_assigned','ticket_reply']) x;
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000014","aal":"aal2","app_metadata":{}}',true);
select public.grillad_central_agent_access('b1000000-0000-0000-0000-000000000003',true,'Synthetic support qualification');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
select public.grillad_support_open('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001','Test appel','Test assistance audio et écran');
do $test$ begin if public.grillad_customer_call('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001','request',null,true)->>'status' is distinct from 'queued' then raise exception 'call request';end if;end $test$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000013","aal":"aal2","app_metadata":{}}',true);
do $test$ declare t uuid:='b7000000-0000-0000-0000-000000000001';begin
 begin perform public.grillad_agent_call(t,'accept');raise exception 'unassigned agent accepted';exception when insufficient_privilege then null;end;
 perform public.grillad_agent_thread(t,'claim');
 if public.grillad_agent_call(t,'accept')->>'status' is distinct from 'accepted' then raise exception 'call accept';end if;
end $test$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
select public.grillad_customer_call('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001','offer','v=0 fixture');
select public.grillad_customer_call('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001','stop_screen');
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000013","aal":"aal2","app_metadata":{}}',true);
do $test$ declare t uuid:='b7000000-0000-0000-0000-000000000001';v jsonb;begin
 v:=public.grillad_agent_call(t,'read');if v->>'offer' is distinct from 'v=0 fixture' or v->>'screen_stopped' is distinct from 'true' then raise exception 'offer or consent';end if;
 perform public.grillad_agent_call(t,'answer','v=0 answer');
 perform public.grillad_agent_call(t,'end');
 if public.grillad_agent_call(t,'read')->>'status' is distinct from 'idle' then raise exception 'call close';end if;
end $test$;
reset role;

rollback;
