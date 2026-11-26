-- Run only on FAMILLE-NAXA as authorized administrator.
-- First create a NEW dedicated, confirmed Auth user via the Auth Admin API/dashboard.
-- Replace UUID, alias, login and display names. Never include password or privileged API key.
begin;
do $bootstrap$
declare
  v_auth uuid := '00000000-0000-0000-0000-000000000000';
  v_alias text := 'ns-replace@example.invalid';
  v_login text := 'NS-REPLACE';
  v_org_name text := 'NAXA SERVICES - initial establishment';
  v_display text := 'Promoteur';
  v_org uuid; v_account uuid; v_member uuid; v_site uuid;
begin
  if v_auth = '00000000-0000-0000-0000-000000000000' or v_alias = 'ns-replace@example.invalid' or v_login = 'NS-REPLACE' then raise exception 'REPLACE_BOOTSTRAP_PLACEHOLDERS'; end if;
  if v_login !~ '^NS-[A-Z0-9]{4,12}$' or v_alias !~ '^ns-[a-z0-9-]+@[a-z0-9.-]+\.[a-z]{2,}$' or length(trim(v_org_name))=0 or length(trim(v_display))=0 then raise exception 'INVALID_BOOTSTRAP_INPUT'; end if;
  lock table public.ns_accounts, public.ns_organizations in share row exclusive mode;
  if exists(select 1 from public.ns_accounts) or exists(select 1 from public.ns_organizations) then raise exception 'FIRST_BOOTSTRAP_ONLY'; end if;
  if not exists(select 1 from auth.users where id=v_auth and email=v_alias and email_confirmed_at is not null and coalesce(raw_app_meta_data->>'app_code','naxa-services')='naxa-services') then raise exception 'DEDICATED_CONFIRMED_AUTH_USER_REQUIRED'; end if;
  insert into public.ns_organizations(display_name,business_mode) values(v_org_name,'solo') returning id into v_org;
  insert into public.ns_accounts(auth_user_id,login_id,auth_alias,password_change_required) values(v_auth,v_login,v_alias,true) returning id into v_account;
  insert into public.ns_members(org_id,account_id,display_name,role_code) values(v_org,v_account,v_display,'promoter') returning id into v_member;
  insert into public.ns_sites(org_id,code,name) values(v_org,'SITE01','Site principal') returning id into v_site;
  insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,can_read,can_operate,can_manage) values(v_org,v_member,'organization',v_org,true,true,true);
  insert into public.ns_audit_events(org_id,site_id,actor_auth_user_id,actor_member_id,action_code,object_type,object_id,reason,metadata_redacted)
    values(v_org,v_site,v_auth,v_member,'organization.bootstrap','organization',v_org,'Provisionnement initial hors inscription publique','{"app_code":"naxa-services","source":"operator"}'::jsonb);
end $bootstrap$;
commit;
