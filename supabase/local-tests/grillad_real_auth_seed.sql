\set ON_ERROR_STOP on
begin;
-- Local test data only. Auth users originate from real GoTrue admin API, not inserted manually.
do $test$ begin if (select count(*) from auth.users where phone in ('237600000001','237600000002','237600000003') and phone_confirmed_at is not null)<>3 then raise exception 'fixture auth accounts missing';end if;end $test$;
insert into famille_core.organizations(id,legal_name,organization_type,status) values('d2000000-0000-0000-0000-000000000001','GRILLAD CI','retail','active');
update famille_core.applications set status='active' where code='grillad';
insert into famille_core.organization_apps(organization_id,app_id,status) select 'd2000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.locations(id,organization_id,name) values ('d3000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','A - recette'),('d3000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','B - recette');
insert into grillad_private.enabled_sites(org,site) values ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001'),('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000002');
insert into famille_core.client_app_access(user_id,app_id,status) select u.id,a.id,'granted' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.phone in ('237600000001','237600000002','237600000003');
insert into famille_core.memberships(user_id,organization_id,app_id,status) select u.id,'d2000000-0000-0000-0000-000000000001',a.id,'active' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.phone in ('237600000001','237600000002','237600000003');
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select m.id,m.app_id,m.organization_id,case when u.phone='237600000001' then 'owner' when u.phone='237600000003' then 'manager' else 'seller' end,case when u.phone='237600000001' then null else 'd3000000-0000-0000-0000-000000000001'::uuid end from famille_core.memberships m join auth.users u on u.id=m.user_id where u.phone in ('237600000001','237600000002','237600000003');
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select 'd2000000-0000-0000-0000-000000000001',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad_premium_month';
insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,location_id,role_code) select m.user_id,'grillad','professional',m.organization_id,r.location_id,r.role_code from famille_core.memberships m join famille_core.role_assignments r on r.membership_id=m.id;
commit;
