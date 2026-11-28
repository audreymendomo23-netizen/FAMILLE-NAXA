begin;
-- An explicitly free trial, never a payment. Service-only entry point, authenticated internal identity; no verified external contact claimed.
create table grillad_private.signup_trials(
 user_id uuid primary key references auth.users(id) on delete restrict,
 email_hash text not null unique check(email_hash~'^[0-9a-f]{64}$'),
 org uuid not null unique references famille_core.organizations(id),
 site uuid not null references famille_core.locations(id),
 subscription uuid not null unique references famille_core.subscriptions(id),
 contact_phone text not null unique, terms_version text not null,
 starts_at timestamptz not null, ends_at timestamptz not null,
 check(ends_at=starts_at+interval '72 hours')
);
alter table grillad_private.signup_trials enable row level security;
revoke all on grillad_private.signup_trials from public,anon,authenticated;
create function grillad_private.self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;pl uuid;o uuid;s uuid;m uuid;sub uuid;t timestamptz:=now();h text;old grillad_private.signup_trials%rowtype;
begin
 if p_user is null or p_session is null or p_email is null or p_terms is distinct from 'grillad-2026-11-28-v1' or p_phone is null or p_phone!~'^\+[1-9][0-9]{7,14}$' or length(coalesce(btrim(p_name),'')) not between 2 and 80 or length(coalesce(btrim(p_org),'')) not between 2 and 160 or length(coalesce(btrim(p_site),'')) not between 2 and 160 or concat(p_name,p_org,p_site)~'[[:cntrl:]]' then raise exception 'GRILLAD_SIGNUP_INPUT' using errcode='22023';end if;
 if not exists(select 1 from auth.users u where u.id=p_user and lower(u.email)=lower(p_email) and ((p_email ~ '^grillad-[0-9a-f]{48}@accounts[.]grillad[.]invalid and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
-- Service-only lookup; never authorize by matching a declared phone or real email.
create function grillad_private.federated_identity(p_email text,p_subject uuid) returns jsonb
language sql stable security definer set search_path=pg_catalog as $fn$
 select jsonb_build_object('user_id',u.id,'has_access',exists(select 1 from famille_private.account_app_access a where a.user_id=u.id and a.app_code='grillad'))
 from auth.users u where u.email=p_email and p_email ~ '^grillad-naxa-[0-9a-f]{48}@accounts[.]grillad[.]invalid
 and (to_jsonb(u)->'raw_app_meta_data'->>'grillad_internal')='true') or (p_email ~ '^grillad-naxa-[0-9a-f]{48}@accounts[.]grillad[.]invalid and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
commit;
 and (to_jsonb(u)->'raw_app_meta_data'->>'grillad_federated')='true' and (to_jsonb(u)->'raw_app_meta_data'->>'naxa_subject') ~ '^[0-9a-f-]{36} and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
commit;
)) and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
commit;

 and u.raw_app_meta_data->>'grillad_federated'='true' and u.raw_app_meta_data->>'naxa_subject'=p_subject::text
 and coalesce(to_jsonb(u)->>'is_anonymous','false')='false'
$fn$;
create function public.grillad_federated_identity(p_email text,p_subject uuid) returns jsonb
language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.federated_identity(p_email,p_subject)$fn$;
revoke all on function grillad_private.federated_identity(text,uuid),public.grillad_federated_identity(text,uuid) from public,anon,authenticated;
grant execute on function grillad_private.federated_identity(text,uuid),public.grillad_federated_identity(text,uuid) to service_role;
commit;
 and (to_jsonb(u)->'raw_app_meta_data'->>'grillad_internal')='true') or (p_email ~ '^grillad-naxa-[0-9a-f]{48}@accounts[.]grillad[.]invalid and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
commit;
 and (to_jsonb(u)->'raw_app_meta_data'->>'grillad_federated')='true' and (to_jsonb(u)->'raw_app_meta_data'->>'naxa_subject') ~ '^[0-9a-f-]{36} and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
commit;
)) and coalesce(to_jsonb(u)->>'is_anonymous','false')='false') or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 h:=encode(sha256(convert_to('grillad-trial:'||lower(p_email),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial:'||h,0));
 perform pg_advisory_xact_lock(hashtextextended('grillad-trial-contact:'||p_phone,0));
 select * into old from grillad_private.signup_trials where user_id=p_user;
 if found then return jsonb_build_object('org',old.org,'site',old.site,'trial_ends_at',old.ends_at);end if;
 if exists(select 1 from grillad_private.signup_trials where email_hash=h or contact_phone=p_phone) then raise exception 'GRILLAD_TRIAL_USED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id into pl from famille_core.plans where app_id=a and code='grillad_premium_month' and status='active';
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a) or exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='42501';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org),'retail','active',p_user) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',t);
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,joined_at) values(p_user,o,a,'active',t) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_user);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_user);
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_user);
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) values(o,a,pl,'active',t,t+interval '72 hours') returning id into sub;
 insert into grillad_private.signup_trials values(p_user,h,o,s,sub,p_phone,p_terms,t,t+interval '72 hours');
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(p_user,btrim(p_name),1);
 return jsonb_build_object('org',o,'site',s,'trial_ends_at',t+interval '72 hours');
end $fn$;
create function public.grillad_self_trial(p_user uuid,p_session uuid,p_email text,p_name text,p_phone text,p_org text,p_site text,p_terms text) returns jsonb
language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.self_trial(p_user,p_session,p_email,p_name,p_phone,p_org,p_site,p_terms)$fn$;
revoke all on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.self_trial(uuid,uuid,text,text,text,text,text,text),public.grillad_self_trial(uuid,uuid,text,text,text,text,text,text) to service_role;
commit;
