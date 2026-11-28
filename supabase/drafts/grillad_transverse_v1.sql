-- Candidate GRILLAD only: reuse the shared Famille support ticket registry; no separate Auth.
begin;
create function grillad_private.support_list(p_org uuid,p_site uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare a uuid;v jsonb;
begin
 perform grillad_private.scope(p_org,p_site);
 select id into a from famille_core.applications where code='grillad';
 select coalesce(jsonb_agg(to_jsonb(t) order by t.updated_at desc),'[]'::jsonb) into v
 from (select id,subject,status,created_at,updated_at from famille_core.support_tickets where app_id=a and organization_id=p_org and user_id=auth.uid() and deleted_at is null order by updated_at desc limit 50)t;
 return v;
end $fn$;
create function grillad_private.support_open(p_org uuid,p_site uuid,p_event uuid,p_subject text,p_description text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;u uuid:=auth.uid();t famille_core.support_tickets%rowtype;s text:=btrim(p_subject);d text:=btrim(p_description);
begin
 perform grillad_private.scope(p_org,p_site);
 if p_event is null or s is null or length(s) not between 3 and 120 or d is null or length(d) not between 10 and 2000 or s ~ '[[:cntrl:]]' then raise exception 'GRILLAD_SUPPORT_INPUT' using errcode='22023';end if;
 select id into a from famille_core.applications where code='grillad';
 perform pg_advisory_xact_lock(hashtextextended('grillad-support:'||u::text,0));
 select * into t from famille_core.support_tickets where id=p_event;
 if found then
  if t.user_id<>u or t.app_id<>a or t.organization_id is distinct from p_org or t.subject<>s or t.description<>d or t.deleted_at is not null then raise exception 'GRILLAD_SUPPORT_REPLAY' using errcode='42501';end if;
 else
  if (select count(*) from famille_core.support_tickets where user_id=u and app_id=a and created_at>now()-interval '1 hour')>=5 then raise exception 'GRILLAD_SUPPORT_LIMIT' using errcode='22023';end if;
  insert into famille_core.support_tickets(id,user_id,app_id,organization_id,subject,description) values(p_event,u,a,p_org,s,d) returning * into t;
 end if;
 return jsonb_build_object('id',t.id,'status',t.status,'subject',t.subject);
end $fn$;
-- Central identity only. No membership-based platform_admin fallback; no business detail or ticket text.
create function grillad_private.central_overview() returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare a uuid;sid uuid;allowed boolean:=false;u uuid:=auth.uid();
begin
 if u is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' or coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid;exception when invalid_text_representation then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end;
 if sid is null or not exists(select 1 from auth.sessions where id=sid and user_id=u) or to_regclass('famille_core.family_admins') is null then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end if;
 execute 'select exists(select 1 from famille_core.family_admins where user_id=$1 and status=''active'' and revoked_at is null)' into allowed using u;
 if not allowed then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad';
 return jsonb_build_object('app','grillad','organizations',(select count(*) from famille_core.organization_apps where app_id=a and status='active'),'active_subscriptions',(select count(*) from famille_core.subscriptions where app_id=a and status='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now())),'open_support',(select count(*) from famille_core.support_tickets where app_id=a and status in ('open','in_progress','waiting_user') and deleted_at is null));
end $fn$;
create function public.grillad_support_list(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.support_list(p_org,p_site)$fn$;
create function public.grillad_support_open(p_org uuid,p_site uuid,p_event uuid,p_subject text,p_description text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.support_open(p_org,p_site,p_event,p_subject,p_description)$fn$;
create function public.grillad_central_overview() returns jsonb language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.central_overview()$fn$;
revoke all on function grillad_private.support_list(uuid,uuid),grillad_private.support_open(uuid,uuid,uuid,text,text),grillad_private.central_overview(),public.grillad_support_list(uuid,uuid),public.grillad_support_open(uuid,uuid,uuid,text,text),public.grillad_central_overview() from public,anon,authenticated;
grant execute on function grillad_private.support_list(uuid,uuid),grillad_private.support_open(uuid,uuid,uuid,text,text),grillad_private.central_overview(),public.grillad_support_list(uuid,uuid),public.grillad_support_open(uuid,uuid,uuid,text,text),public.grillad_central_overview() to authenticated;
-- Reuse the existing central identity check and existing billing records.
create function public.grillad_central_clients() returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare a uuid;v jsonb;
begin
 perform grillad_private.central_overview();
 select id into a from famille_core.applications where code='grillad';
 select coalesce(jsonb_agg(to_jsonb(q) order by q.name,q.org),'[]'::jsonb) into v from
 (select o.id as org,o.legal_name as name,oa.status,
  (select coalesce(jsonb_agg(jsonb_build_object('status',s.status,'plan',p.code,'ends_at',s.ends_at) order by s.created_at desc),'[]'::jsonb)
    from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id
    where s.organization_id=o.id and s.app_id=a) subscriptions
 from famille_core.organization_apps oa join famille_core.organizations o on o.id=oa.organization_id
 where oa.app_id=a and o.deleted_at is null order by o.legal_name,o.id limit 100)q;
 return v;
end $fn$;
create function public.grillad_central_client_state(p_org uuid,p_expected text,p_next text,p_reason text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;v text;why text:=btrim(p_reason);
begin
 perform grillad_private.central_overview();
 if p_org is null or why is null or length(why) not between 10 and 300 or not ((p_expected='active' and p_next='suspended') or (p_expected='suspended' and p_next='active')) then raise exception 'GRILLAD_CENTRAL_INPUT' using errcode='22023';end if;
 select id into a from famille_core.applications where code='grillad';
 select status into v from famille_core.organization_apps where organization_id=p_org and app_id=a for update;
 if v is distinct from p_expected then raise exception 'GRILLAD_CENTRAL_STATE' using errcode='22023';end if;
 if p_next='active' and not exists(select 1 from famille_core.organizations where id=p_org and status='active' and deleted_at is null) then raise exception 'GRILLAD_CENTRAL_STATE' using errcode='22023';end if;
 update famille_core.organization_apps set status=p_next where organization_id=p_org and app_id=a;
 insert into famille_core.audit_events(app_id,organization_id,actor_id,action_code,entity_type,entity_id,metadata)
 values(a,p_org,auth.uid(),'grillad.client_state','organization_app',p_org::text,jsonb_build_object('from',p_expected,'to',p_next,'reason',why));
 return jsonb_build_object('org',p_org,'status',p_next);
end $fn$;
-- Organization-level referral, generated on server; no rewards or entitlement mutation.
create table grillad_private.referral_codes(org uuid primary key references famille_core.organizations(id),code text not null unique default upper(replace(gen_random_uuid()::text,'-','')),created_at timestamptz not null default now());
create table grillad_private.referral_links(referred_org uuid primary key references famille_core.organizations(id),referrer_org uuid not null references grillad_private.referral_codes(org),created_at timestamptz not null default now(),check(referred_org<>referrer_org));
alter table grillad_private.referral_codes enable row level security;
alter table grillad_private.referral_links enable row level security;
revoke all on grillad_private.referral_codes,grillad_private.referral_links from public,anon,authenticated;
create function public.grillad_referral(p_org uuid,p_site uuid,p_action text,p_code text default null) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare c text;r uuid;v uuid;result jsonb;
begin
 if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_REFERRAL_DENIED' using errcode='42501';end if;
 if p_action not in ('list','generate','attach') or p_action is null then raise exception 'GRILLAD_REFERRAL_INPUT' using errcode='22023';end if;
 if p_action='generate' then insert into grillad_private.referral_codes(org) values(p_org) on conflict(org) do nothing;
 elsif p_action='attach' then
  if p_code is null or upper(btrim(p_code))!~'^[0-9A-F]{32} then raise exception 'GRILLAD_REFERRAL_INPUT' using errcode='22023';end if;
  -- Serialize attachment to reject reciprocal and indirect loops.
  perform pg_advisory_xact_lock(hashtextextended('grillad-referral-graph',0));
  select org into r from grillad_private.referral_codes where code=upper(btrim(p_code));
  if r is null or r=p_org or exists(with recursive ancestors(org) as (select r union select l.referrer_org from grillad_private.referral_links l join ancestors x on l.referred_org=x.org) select 1 from ancestors where org=p_org) then raise exception 'GRILLAD_REFERRAL_DENIED' using errcode='42501';end if;
  insert into grillad_private.referral_links(referred_org,referrer_org) values(p_org,r) on conflict(referred_org) do nothing;
  select referrer_org into v from grillad_private.referral_links where referred_org=p_org;
  if v is distinct from r then raise exception 'GRILLAD_REFERRAL_ALREADY_LINKED' using errcode='22023';end if;
 end if;
 select code into c from grillad_private.referral_codes where org=p_org;
 select jsonb_build_object('code',c,'linked',exists(select 1 from grillad_private.referral_links where referred_org=p_org),'referrals',(select count(*) from grillad_private.referral_links where referrer_org=p_org),'reward_status','pending_policy') into result;
 return result;
end $fn$;
revoke all on function public.grillad_central_clients(),public.grillad_central_client_state(uuid,text,text,text),public.grillad_referral(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.grillad_central_clients(),public.grillad_central_client_state(uuid,text,text,text),public.grillad_referral(uuid,uuid,text,text) to authenticated;

commit;
