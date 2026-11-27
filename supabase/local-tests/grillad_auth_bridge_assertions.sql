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
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin
 if jsonb_array_length(public.grillad_workspace())<>1 then raise exception 'bound session failed';end if;
 begin perform public.grillad_auth_begin(repeat('b',64),false);raise exception 'service-only auth bridge leaked';exception when insufficient_privilege then null;end;
end $$;
reset role;
update famille_private.account_devices set status='revoked',revoked_at=now() where user_id='b1000000-0000-0000-0000-000000000002';
set role authenticated;
do $$begin
 begin perform public.grillad_workspace();raise exception 'revocation failed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
