-- N0 isolated candidate fixture: PostgreSQL 17, NOT a production migration.
-- All identities and organizations below are synthetic; JWT context emulated only in CI.
begin;
create role zipple_n0_anon nologin;
create role zipple_n0_authenticated nologin;
create schema zipple_n0;
revoke all on schema zipple_n0 from public;
grant usage on schema zipple_n0 to zipple_n0_anon,zipple_n0_authenticated;
create table zipple_n0.memberships (
  user_id text not null, app_id text not null, org_id text not null,
  role_code text not null check(role_code in ('promoteur','manager','staff')),
  active boolean not null, primary key(user_id,app_id,org_id)
);
create table zipple_n0.subscriptions(
  app_id text not null, org_id text not null, plan text not null check(plan in ('ACCESS','PREMIUM')),
  active boolean not null, primary key(app_id,org_id)
);
create table zipple_n0.catalog(
  plan text not null, cadence text not null check(cadence in ('monthly','annual')),
  amount integer not null check(amount>0), service_months int not null, paid_months int not null,
  primary key(plan,cadence)
);
insert into zipple_n0.catalog values
('ACCESS','monthly',5000,1,1),
('ACCESS','annual',50000,12,10),
('PREMIUM','monthly',18000,1,1),
('PREMIUM','annual',180000,12,10);
create table zipple_n0.optional_grants(
 app_id text not null, org_id text not null, feature text not null check(feature in ('advanced_ai','video','advanced_reports','extra_capacity')),
 approved boolean not null, primary key(app_id,org_id,feature)
);
create table zipple_n0.business_records(app_id text not null,org_id text not null,site_id text not null,record_id text primary key);
create table zipple_n0.site_scopes(user_id text not null,app_id text not null,org_id text not null,site_id text not null,primary key(user_id,app_id,org_id,site_id));
insert into zipple_n0.memberships values
 ('owner-a','ZIPPLE','a','promoteur',true),('owner-b','ZIPPLE','b','promoteur',true),
 ('owner-c','ZIPPLE','c','promoteur',true),('staff-b','ZIPPLE','b','staff',true),
 ('revoked','ZIPPLE','b','promoteur',false),('other-app','NAXA_SERVICES','b','promoteur',true);
insert into zipple_n0.subscriptions values ('ZIPPLE','a','ACCESS',true),('ZIPPLE','b','PREMIUM',true),('ZIPPLE','c','PREMIUM',false),('NAXA_SERVICES','b','PREMIUM',true);
insert into zipple_n0.optional_grants values ('ZIPPLE','b','advanced_reports',true),('NAXA_SERVICES','b','advanced_ai',true);
insert into zipple_n0.business_records values ('ZIPPLE','a','a1','a1r'),('ZIPPLE','b','b1','b1r'),('ZIPPLE','b','b2','b2r'),('NAXA_SERVICES','b','b1','nsr');
insert into zipple_n0.site_scopes values ('staff-b','ZIPPLE','b','b1');
-- No client may change memberships, subscriptions, grants or catalogue.
alter table zipple_n0.memberships enable row level security;
alter table zipple_n0.subscriptions enable row level security;
alter table zipple_n0.catalog enable row level security;
alter table zipple_n0.optional_grants enable row level security;
alter table zipple_n0.business_records enable row level security;
alter table zipple_n0.site_scopes enable row level security;
grant select on all tables in schema zipple_n0 to zipple_n0_authenticated;
create policy own_member on zipple_n0.memberships for select to zipple_n0_authenticated using (app_id='ZIPPLE' and active and user_id=current_setting('request.jwt.claim.sub',true));
create policy own_subscription on zipple_n0.subscriptions for select to zipple_n0_authenticated using (app_id='ZIPPLE' and exists(select 1 from zipple_n0.memberships m where m.app_id=subscriptions.app_id and m.org_id=subscriptions.org_id));
create policy catalogue_read on zipple_n0.catalog for select to zipple_n0_authenticated using (true);
create policy own_grant on zipple_n0.optional_grants for select to zipple_n0_authenticated using (app_id='ZIPPLE' and approved and exists(select 1 from zipple_n0.memberships m where m.app_id=optional_grants.app_id and m.org_id=optional_grants.org_id));
create policy own_scope on zipple_n0.site_scopes for select to zipple_n0_authenticated using (app_id='ZIPPLE' and user_id=current_setting('request.jwt.claim.sub',true));
create policy own_records on zipple_n0.business_records for select to zipple_n0_authenticated using (
 app_id='ZIPPLE' and exists(select 1 from zipple_n0.subscriptions s where s.app_id=business_records.app_id and s.org_id=business_records.org_id and s.active)
 and exists(select 1 from zipple_n0.memberships m where m.app_id=business_records.app_id and m.org_id=business_records.org_id
 and (m.role_code='promoteur' or exists(select 1 from zipple_n0.site_scopes ss where ss.user_id=m.user_id and ss.app_id=m.app_id and ss.org_id=m.org_id and ss.site_id=business_records.site_id))));
create function zipple_n0.quote_for_org(p_org text,p_plan text,p_cadence text)
returns table(amount int, service_months int,paid_months int)
language sql stable security invoker set search_path=pg_catalog,zipple_n0 as $$
 select c.amount,c.service_months,c.paid_months from zipple_n0.catalog c
 where c.plan=p_plan and c.cadence=p_cadence and exists(select 1 from zipple_n0.memberships m where m.org_id=p_org and m.role_code='promoteur' and m.app_id='ZIPPLE')
$$;
create function zipple_n0.feature_allowed(p_org text,p_feature text)
returns boolean language sql stable security invoker set search_path=pg_catalog,zipple_n0 as $$
 select exists(select 1 from zipple_n0.memberships m join zipple_n0.subscriptions s on m.app_id=s.app_id and m.org_id=s.org_id
 where m.org_id=p_org and m.app_id='ZIPPLE' and s.active
 and ((p_feature in ('workspace','catalog','orders','cash','inventory','accounting_integrity','support','export','professional_referral') and m.role_code='promoteur')
 or (p_feature='multilevel_management' and s.plan='PREMIUM' and m.role_code='promoteur')
 or (m.role_code='promoteur' and p_feature in ('advanced_ai','video','advanced_reports','extra_capacity') and exists(select 1 from zipple_n0.optional_grants g where g.app_id=m.app_id and g.org_id=m.org_id and g.feature=p_feature and g.approved))))
$$;
revoke all on function zipple_n0.quote_for_org(text,text,text),zipple_n0.feature_allowed(text,text) from public;
grant execute on function zipple_n0.quote_for_org(text,text,text),zipple_n0.feature_allowed(text,text) to zipple_n0_authenticated;
commit;
