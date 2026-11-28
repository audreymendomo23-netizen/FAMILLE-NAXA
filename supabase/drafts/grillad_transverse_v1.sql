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
declare c text;r uuid;v uuid;result jsonb;paid integer;
begin
 if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_REFERRAL_DENIED' using errcode='42501';end if;
 if p_action not in ('list','generate','attach') or p_action is null then raise exception 'GRILLAD_REFERRAL_INPUT' using errcode='22023';end if;
 if p_action='generate' then insert into grillad_private.referral_codes(org) values(p_org) on conflict(org) do nothing;
 elsif p_action='attach' then
  if p_code is null or upper(btrim(p_code))!~'^[0-9A-F]{32}$' then raise exception 'GRILLAD_REFERRAL_INPUT' using errcode='22023';end if;
  -- Serialize attachment to reject reciprocal and indirect loops.
  perform pg_advisory_xact_lock(hashtextextended('grillad-referral-graph',0));
  select org into r from grillad_private.referral_codes where code=upper(btrim(p_code));
  if r is null or r=p_org or exists(with recursive ancestors(org) as (select r union select l.referrer_org from grillad_private.referral_links l join ancestors x on l.referred_org=x.org) select 1 from ancestors where org=p_org) then raise exception 'GRILLAD_REFERRAL_DENIED' using errcode='42501';end if;
  insert into grillad_private.referral_links(referred_org,referrer_org) values(p_org,r) on conflict(referred_org) do nothing;
  select referrer_org into v from grillad_private.referral_links where referred_org=p_org;
  if v is distinct from r then raise exception 'GRILLAD_REFERRAL_ALREADY_LINKED' using errcode='22023';end if;
 end if;
 select code into c from grillad_private.referral_codes where org=p_org;
 -- Count only confirmed independent matched subscription payments for GRILLAD, after referral attachment.
 select count(*) into paid from grillad_private.referral_links l where l.referrer_org=p_org and exists(
  select 1 from famille_core.subscriptions s join famille_core.applications a on a.id=s.app_id and a.code='grillad'
  join famille_core.payment_intents i on i.subscription_id=s.id and i.status='matched'
  join famille_core.payment_matches m on m.payment_intent_id=i.id and m.status='confirmed' and m.amount_fcfa=i.expected_amount_fcfa
  join grillad_private.renewal_payment_links rl on rl.intent_id=i.id
  join grillad_private.central_requests q on q.id=rl.request_id and q.org=l.referred_org and q.kind='renewal' and q.status='processed'
  where s.organization_id=l.referred_org and m.verified_at>=l.created_at);
 select jsonb_build_object('code',c,'linked',exists(select 1 from grillad_private.referral_links where referred_org=p_org),'referrals',(select count(*) from grillad_private.referral_links where referrer_org=p_org),'paid_referrals',paid,'reward_status','pending_policy') into result;
 return result;
end $fn$;
revoke all on function public.grillad_central_clients(),public.grillad_central_client_state(uuid,text,text,text),public.grillad_referral(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.grillad_central_clients(),public.grillad_central_client_state(uuid,text,text,text),public.grillad_referral(uuid,uuid,text,text) to authenticated;

-- Extend the existing shared ticket registry, not a second customer identity.
create table grillad_private.support_messages(
 id uuid primary key,ticket uuid not null references famille_core.support_tickets(id),
 author uuid not null references auth.users(id),author_kind text not null check(author_kind in ('customer','agent')),
 body text not null check(length(body) between 1 and 2000),created_at timestamptz not null default now());
create index grillad_support_messages_ticket on grillad_private.support_messages(ticket,created_at,id);
create table grillad_private.support_assignments(ticket uuid primary key references famille_core.support_tickets(id),agent uuid not null references auth.users(id),assigned_at timestamptz not null default now());
create table grillad_private.support_agent_access(agent uuid primary key references auth.users(id),enabled boolean not null default false);
alter table grillad_private.support_messages enable row level security;
alter table grillad_private.support_assignments enable row level security;
alter table grillad_private.support_agent_access enable row level security;
revoke all on grillad_private.support_messages,grillad_private.support_assignments,grillad_private.support_agent_access from public,anon,authenticated;
-- Existing NAXA agents only, explicit GRILLAD opt-in, live session, no new agent identity.
create function grillad_private.agent_allowed(p_permission text) returns boolean
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare u uuid:=auth.uid();sid uuid;ok boolean:=false;
begin
 if u is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' or coalesce(auth.jwt()->>'aal','')<>'aal2' or to_regclass('public.support_agents') is null or to_regclass('public.support_agent_permissions') is null then return false;end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid;exception when invalid_text_representation then return false;end;
 if sid is null or not exists(select 1 from auth.sessions where id=sid and user_id=u) or not exists(select 1 from grillad_private.support_agent_access where agent=u and enabled) then return false;end if;
 execute 'select exists(select 1 from public.support_agents a join public.support_agent_permissions p on p.agent_user_id=a.user_id where a.user_id=$1 and a.status=''active'' and p.permission_code=$2 and p.revoked_at is null)' into ok using u,p_permission;
 return ok;
end $fn$;
create function public.grillad_support_thread(p_org uuid,p_site uuid,p_ticket uuid,p_event uuid default null,p_body text default null) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;t famille_core.support_tickets%rowtype;m grillad_private.support_messages%rowtype;v jsonb;msg text:=btrim(p_body);
begin
 perform grillad_private.scope(p_org,p_site);
 select id into a from famille_core.applications where code='grillad';
 select * into t from famille_core.support_tickets where id=p_ticket and app_id=a and organization_id=p_org and user_id=auth.uid() and deleted_at is null for update;
 if not found then raise exception 'GRILLAD_SUPPORT_DENIED' using errcode='42501';end if;
 if p_event is not null then
  if msg is null or length(msg) not between 1 and 2000 or t.status in ('resolved','closed') then raise exception 'GRILLAD_SUPPORT_INPUT' using errcode='22023';end if;
  select * into m from grillad_private.support_messages where id=p_event;
  if found then if m.ticket<>p_ticket or m.author<>auth.uid() or m.body<>msg or m.author_kind<>'customer' then raise exception 'GRILLAD_SUPPORT_REPLAY' using errcode='42501';end if;
  else
   if (select count(*) from grillad_private.support_messages where author=auth.uid() and created_at>now()-interval '1 minute')>=12 then raise exception 'GRILLAD_SUPPORT_LIMIT' using errcode='22023';end if;
   insert into grillad_private.support_messages(id,ticket,author,author_kind,body) values(p_event,p_ticket,auth.uid(),'customer',msg);
   update famille_core.support_tickets set updated_at=now(),status=case when status='waiting_user' then 'in_progress' else status end where id=p_ticket;
  end if;
 end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at,q.id),'[]'::jsonb) into v from (select id,author_kind,body,created_at from grillad_private.support_messages where ticket=p_ticket order by created_at desc,id desc limit 100)q;
 return jsonb_build_object('ticket',p_ticket,'description',t.description,'messages',v);
end $fn$;
create function public.grillad_agent_queue() returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare a uuid;v jsonb;
begin
 if not grillad_private.agent_allowed('queue_view') or not grillad_private.agent_allowed('ticket_view_assigned') then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad';
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at),'[]'::jsonb) into v from
 (select t.id,t.subject,t.status,t.created_at,(s.agent=auth.uid()) as mine from famille_core.support_tickets t left join grillad_private.support_assignments s on s.ticket=t.id where t.app_id=a and t.deleted_at is null and t.status not in ('resolved','closed') and (s.agent is null or s.agent=auth.uid()) order by t.created_at limit 50)q;
 return v;
end $fn$;
create function public.grillad_agent_thread(p_ticket uuid,p_action text,p_event uuid default null,p_body text default null) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;t famille_core.support_tickets%rowtype;m grillad_private.support_messages%rowtype;v jsonb;msg text:=btrim(p_body);
begin
 if auth.uid() is null then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-agent:'||auth.uid()::text,0));
 if not grillad_private.agent_allowed('ticket_view_assigned') or p_action is null or p_action not in ('claim','read','reply') then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad';
 select * into t from famille_core.support_tickets where id=p_ticket and app_id=a and deleted_at is null and status not in ('resolved','closed') for update;
 if not found then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
 if p_action='claim' then
  if not grillad_private.agent_allowed('queue_view') then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
  insert into grillad_private.support_assignments(ticket,agent) values(p_ticket,auth.uid()) on conflict(ticket) do nothing;
 end if;
 if not exists(select 1 from grillad_private.support_assignments where ticket=p_ticket and agent=auth.uid()) then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
 if p_action='reply' then
  if not grillad_private.agent_allowed('ticket_reply') or p_event is null or msg is null or length(msg) not between 1 and 2000 then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
  select * into m from grillad_private.support_messages where id=p_event;
  if found then if m.ticket<>p_ticket or m.author<>auth.uid() or m.body<>msg or m.author_kind<>'agent' then raise exception 'GRILLAD_SUPPORT_REPLAY' using errcode='42501';end if;
  else insert into grillad_private.support_messages(id,ticket,author,author_kind,body) values(p_event,p_ticket,auth.uid(),'agent',msg);
   update famille_core.support_tickets set status='waiting_user',updated_at=now() where id=p_ticket;
  end if;
 elsif p_action='claim' and t.status='open' then update famille_core.support_tickets set status='in_progress',updated_at=now() where id=p_ticket;end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at,q.id),'[]'::jsonb) into v from (select id,author_kind,body,created_at from grillad_private.support_messages where ticket=p_ticket order by created_at desc,id desc limit 100)q;
 return jsonb_build_object('ticket',p_ticket,'description',t.description,'messages',v);
end $fn$;
revoke all on function grillad_private.agent_allowed(text),public.grillad_support_thread(uuid,uuid,uuid,uuid,text),public.grillad_agent_queue(),public.grillad_agent_thread(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.grillad_support_thread(uuid,uuid,uuid,uuid,text),public.grillad_agent_queue(),public.grillad_agent_thread(uuid,text,uuid,text) to authenticated;

create function public.grillad_central_agent_access(p_agent uuid,p_enabled boolean,p_reason text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;valid boolean:=false;why text:=btrim(p_reason);
begin
 perform grillad_private.central_overview();
 if p_agent is null or p_enabled is null or why is null or length(why) not between 10 and 300 or p_agent=auth.uid() then raise exception 'GRILLAD_AGENT_INPUT' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-agent:'||p_agent::text,0));
 if p_enabled then
  if to_regclass('public.support_agents') is null or to_regclass('public.support_agent_permissions') is null then raise exception 'GRILLAD_AGENT_UNAVAILABLE' using errcode='42501';end if;
  execute 'select exists(select 1 from public.support_agents a where a.user_id=$1 and a.status=''active'' and (select count(distinct p.permission_code) from public.support_agent_permissions p where p.agent_user_id=a.user_id and p.revoked_at is null and p.permission_code in (''queue_view'',''ticket_view_assigned'',''ticket_reply''))=3)' into valid using p_agent;
  if not valid then raise exception 'GRILLAD_AGENT_DENIED' using errcode='42501';end if;
 end if;
 insert into grillad_private.support_agent_access(agent,enabled) values(p_agent,p_enabled) on conflict(agent) do update set enabled=excluded.enabled;
 -- Release only GRILLAD assignments if access is revoked; conversation remains intact.
 if not p_enabled then delete from grillad_private.support_assignments where agent=p_agent;end if;
 select id into a from famille_core.applications where code='grillad';
 insert into famille_core.audit_events(app_id,actor_id,action_code,entity_type,entity_id,metadata) values(a,auth.uid(),'grillad.agent_access','support_agent',p_agent::text,jsonb_build_object('enabled',p_enabled,'reason',why));
 return jsonb_build_object('agent',p_agent,'enabled',p_enabled);
end $fn$;
revoke all on function public.grillad_central_agent_access(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.grillad_central_agent_access(uuid,boolean,text) to authenticated;

-- Owner-controlled backup preference and bounded, explicit business export.
-- No OAuth credential, PIN, profile photo, camera or authentication material exported.
create table grillad_private.backup_preferences(
 org uuid not null,site uuid not null,actor uuid not null references auth.users(id),
 frequency text not null check(frequency in ('off','daily','weekly','monthly')),
 local_minute integer not null check(local_minute between 0 and 1439),
 weekday integer not null check(weekday between 1 and 7),monthday integer not null check(monthday between 1 and 28),
 updated_at timestamptz not null default now(),primary key(org,site,actor),
 foreign key(org,site) references grillad_private.enabled_sites(org,site));
alter table grillad_private.backup_preferences enable row level security;
revoke all on grillad_private.backup_preferences from public,anon,authenticated;
create function public.grillad_backup_preferences(p_org uuid,p_site uuid,p_frequency text default null,p_minute integer default null,p_weekday integer default null,p_monthday integer default null) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare v grillad_private.backup_preferences%rowtype;cloud jsonb;
begin
 if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_BACKUP_DENIED' using errcode='42501';end if;
 if p_frequency is not null then
  if p_frequency not in ('off','daily','weekly','monthly') or p_minute is null or p_minute not between 0 and 1439 or p_weekday is null or p_weekday not between 1 and 7 or p_monthday is null or p_monthday not between 1 and 28 then raise exception 'GRILLAD_BACKUP_INPUT' using errcode='22023';end if;
  insert into grillad_private.backup_preferences(org,site,actor,frequency,local_minute,weekday,monthday) values(p_org,p_site,auth.uid(),p_frequency,p_minute,p_weekday,p_monthday)
  on conflict(org,site,actor) do update set frequency=excluded.frequency,local_minute=excluded.local_minute,weekday=excluded.weekday,monthday=excluded.monthday,updated_at=now();
 end if;
 select * into v from grillad_private.backup_preferences where org=p_org and site=p_site and actor=auth.uid();
 select jsonb_build_object('status',last_status,'last_success',last_success) into cloud from grillad_private.drive_connections where org=p_org and site=p_site and actor=auth.uid();
 return jsonb_build_object('frequency',coalesce(v.frequency,'off'),'minute',coalesce(v.local_minute,360),'weekday',coalesce(v.weekday,1),'monthday',coalesce(v.monthday,1),'timezone','Africa/Douala','destination','google_drive','cloud_status',coalesce(cloud->>'status','not_connected'),'last_success',cloud->'last_success');
end $fn$;
create function grillad_private.backup_data(p_org uuid,p_site uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare v jsonb:='{}'::jsonb; t text; a jsonb; n bigint;
begin
 foreach t in array array['items','cash','cash_recounts','preparations','stock_adjustments','sales','cash_receipts','expenses','purchases','targets','dimension_targets','service_policy','service_revisions','daily_summary'] loop
  execute format('select count(*) from grillad_private.%I where org=$1 and site=$2',t) into n using p_org,p_site;
  if n>10000 then raise exception 'GRILLAD_BACKUP_TOO_LARGE' using errcode='22023';end if;
  execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from grillad_private.%I x where org=$1 and site=$2',t) into a using p_org,p_site;
  v:=v||jsonb_build_object(t,a);
  if octet_length(v::text)>3000000 then raise exception 'GRILLAD_BACKUP_TOO_LARGE' using errcode='22023';end if;
 end loop;
 return jsonb_build_object('format','grillad-business-export-v1','org',p_org,'site',p_site,'generated_at',now(),'coverage','selected_business_tables_only','tables',v);
end $fn$;

create function public.grillad_backup_export(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $fn$
begin
 if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_BACKUP_DENIED' using errcode='42501';end if;
 return grillad_private.backup_data(p_org,p_site);
end $fn$;
revoke all on function grillad_private.backup_data(uuid,uuid) from public,anon,authenticated;
create table grillad_private.drive_connections(
 org uuid not null,site uuid not null,actor uuid not null references auth.users(id),
 sealed text not null,last_success timestamptz,last_slot text,requested uuid,lease uuid,leased_at timestamptz,last_status text not null default 'connected',
 primary key(org,site,actor),foreign key(org,site) references grillad_private.enabled_sites(org,site));
create table grillad_private.drive_states(hash text primary key,org uuid not null,site uuid not null,actor uuid not null references auth.users(id),sealed text not null,expires_at timestamptz not null default now()+interval '10 minutes',foreign key(org,site) references grillad_private.enabled_sites(org,site));
alter table grillad_private.drive_connections enable row level security;
alter table grillad_private.drive_states enable row level security;
revoke all on grillad_private.drive_connections,grillad_private.drive_states from public,anon,authenticated;
create function grillad_private.drive_owner(o uuid,s uuid,u uuid) returns boolean language sql stable security definer set search_path=pg_catalog as $fn$
select exists(select 1 from famille_core.applications a
 join famille_core.organization_apps oa on oa.app_id=a.id and oa.organization_id=o and oa.status='active'
 join famille_core.organizations g on g.id=o and g.status='active' and g.deleted_at is null
 join famille_core.locations l on l.id=s and l.organization_id=o and l.status='active'
 join grillad_private.enabled_sites e on e.org=o and e.site=s and e.enabled
 join famille_core.memberships m on m.app_id=a.id and m.organization_id=o and m.user_id=u and m.status='active'
 join famille_core.role_assignments r on r.membership_id=m.id and r.app_id=a.id and r.organization_id=o and r.role_code='owner' and r.location_id is null and r.status='active' and r.starts_at<=now() and (r.expires_at is null or r.expires_at>now())
 join famille_core.client_app_access c on c.user_id=u and c.app_id=a.id and c.status='granted'
 join famille_core.subscriptions b on b.app_id=a.id and b.organization_id=o
 join famille_core.plans p on p.id=b.plan_id and p.app_id=a.id and p.status='active'
 where a.code='grillad' and a.status='active' and ((b.status='active' and (b.starts_at is null or b.starts_at<=now()) and (b.ends_at is null or b.ends_at>=now())) or (b.status='past_due' and b.grace_until>=now()))
 and ((p.code='grillad_access_month' and p.amount_fcfa=2000 and p.billing_period='monthly') or (p.code='grillad_access_year' and p.amount_fcfa=24000 and p.billing_period='yearly') or (p.code='grillad_premium_month' and p.amount_fcfa=6000 and p.billing_period='monthly') or (p.code='grillad_premium_year' and p.amount_fcfa=60000 and p.billing_period='yearly'))
 and (p.code not like 'grillad_access_%' or (select count(*) from grillad_private.enabled_sites where org=o and enabled)=1));
$fn$;
create function public.grillad_drive_begin(p_org uuid,p_site uuid,p_hash text,p_sealed text) returns boolean language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if grillad_private.scope(p_org,p_site)<>'owner' or not grillad_private.drive_owner(p_org,p_site,auth.uid()) then raise exception 'DRIVE_DENIED' using errcode='42501';end if;
 if p_hash is null or length(p_hash)<>64 or p_sealed is null or length(p_sealed)>4096 then raise exception 'DRIVE_INPUT' using errcode='22023';end if;
 delete from grillad_private.drive_states where expires_at<now() or (org=p_org and site=p_site and actor=auth.uid());
 insert into grillad_private.drive_states(hash,org,site,actor,sealed) values(p_hash,p_org,p_site,auth.uid(),p_sealed);
 return true;
end $fn$;
create function public.grillad_drive_consume(p_hash text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $fn$
declare d grillad_private.drive_states%rowtype;
begin
 delete from grillad_private.drive_states where hash=p_hash and expires_at>now() returning * into d;
 if not found or not grillad_private.drive_owner(d.org,d.site,d.actor) then raise exception 'DRIVE_STATE' using errcode='42501';end if;
 return jsonb_build_object('org',d.org,'site',d.site,'actor',d.actor,'sealed',d.sealed);
end $fn$;
create function public.grillad_drive_connect(p_org uuid,p_site uuid,p_actor uuid,p_sealed text) returns boolean language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if not grillad_private.drive_owner(p_org,p_site,p_actor) or p_sealed is null or length(p_sealed)>8192 then raise exception 'DRIVE_DENIED' using errcode='42501';end if;
 insert into grillad_private.drive_connections(org,site,actor,sealed) values(p_org,p_site,p_actor,p_sealed)
 on conflict(org,site,actor) do update set sealed=excluded.sealed,lease=null,leased_at=null,last_status='connected';
 return true;
end $fn$;
create function public.grillad_drive_control(p_org uuid,p_site uuid,p_action text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $fn$
declare d grillad_private.drive_connections%rowtype;
begin
 if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'DRIVE_DENIED' using errcode='42501';end if;
 if p_action='disconnect' then delete from grillad_private.drive_states where org=p_org and site=p_site and actor=auth.uid();delete from grillad_private.drive_connections where org=p_org and site=p_site and actor=auth.uid();
 elsif p_action='now' then update grillad_private.drive_connections set requested=coalesce(requested,gen_random_uuid()) where org=p_org and site=p_site and actor=auth.uid();
 if not found then raise exception 'DRIVE_NOT_CONNECTED' using errcode='22023';end if;
 elsif p_action is distinct from 'status' then raise exception 'DRIVE_INPUT' using errcode='22023';end if;
 select * into d from grillad_private.drive_connections where org=p_org and site=p_site and actor=auth.uid();
 return jsonb_build_object('connected',d.actor is not null,'last_success',d.last_success,'status',coalesce(d.last_status,'not_connected'),'queued',d.requested is not null);
end $fn$;
create function public.grillad_drive_claim() returns jsonb language plpgsql security definer set search_path=pg_catalog as $fn$
declare d grillad_private.drive_connections%rowtype;p grillad_private.backup_preferences%rowtype;local_ts timestamp:=now() at time zone 'Africa/Douala';slot text;candidate record;
begin
 for candidate in select c.org,c.site,c.actor from grillad_private.drive_connections c left join grillad_private.backup_preferences bp on bp.org=c.org and bp.site=c.site and bp.actor=c.actor
 where (c.leased_at is null or c.leased_at<now()-interval '15 minutes')
 and (c.requested is not null or (bp.frequency<>'off' and extract(hour from local_ts)*60+extract(minute from local_ts)>=bp.local_minute and
 ((bp.frequency='daily' and c.last_slot is distinct from 'daily-'||local_ts::date::text)
 or (bp.frequency='weekly' and extract(isodow from local_ts)=bp.weekday and c.last_slot is distinct from 'weekly-'||local_ts::date::text)
 or (bp.frequency='monthly' and extract(day from local_ts)=bp.monthday and c.last_slot is distinct from 'monthly-'||to_char(local_ts,'YYYY-MM')))))
 and grillad_private.drive_owner(c.org,c.site,c.actor)
 order by c.leased_at nulls first,c.last_success nulls first,c.org,c.site,c.actor limit 100 loop
  select * into d from grillad_private.drive_connections where org=candidate.org and site=candidate.site and actor=candidate.actor for update skip locked;
  if not found or (d.leased_at is not null and d.leased_at>=now()-interval '15 minutes') or not grillad_private.drive_owner(d.org,d.site,d.actor) then continue;end if;
  select * into p from grillad_private.backup_preferences where org=d.org and site=d.site and actor=d.actor;
  slot:=null;
  if d.requested is not null then slot:='manual-'||d.requested::text;
  elsif p.frequency is not null and p.frequency<>'off' and extract(hour from local_ts)*60+extract(minute from local_ts)>=p.local_minute then
   if p.frequency='daily' then slot:='daily-'||local_ts::date::text;
   elsif p.frequency='weekly' and extract(isodow from local_ts)=p.weekday then slot:='weekly-'||local_ts::date::text;
   elsif p.frequency='monthly' and extract(day from local_ts)=p.monthday then slot:='monthly-'||to_char(local_ts,'YYYY-MM');end if;
  end if;
  if slot is null or slot=d.last_slot then continue;end if;
  update grillad_private.drive_connections set lease=gen_random_uuid(),leased_at=now(),last_status='running' where org=d.org and site=d.site and actor=d.actor returning * into d;
  return jsonb_build_object('org',d.org,'site',d.site,'actor',d.actor,'sealed',d.sealed,'lease',d.lease,'slot',slot);
 end loop;
 return null;
end $fn$;
create function public.grillad_drive_payload(p_org uuid,p_site uuid,p_actor uuid,p_lease uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $fn$
begin
 if not grillad_private.drive_owner(p_org,p_site,p_actor) or not exists(select 1 from grillad_private.drive_connections where org=p_org and site=p_site and actor=p_actor and lease=p_lease and leased_at>now()-interval '15 minutes') then raise exception 'DRIVE_DENIED' using errcode='42501';end if;
 return grillad_private.backup_data(p_org,p_site);
end $fn$;
create function public.grillad_drive_finish(p_org uuid,p_site uuid,p_actor uuid,p_lease uuid,p_slot text,p_ok boolean) returns boolean language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 update grillad_private.drive_connections set last_status=case when p_ok then 'uploaded' else 'failed' end,last_success=case when p_ok then now() else last_success end,last_slot=case when p_ok and p_slot not like 'manual-%' then p_slot else last_slot end,requested=case when p_ok and p_slot='manual-'||requested::text then null else requested end,lease=null,leased_at=case when p_ok then null else now() end
 where org=p_org and site=p_site and actor=p_actor and lease=p_lease;
 return found;
end $fn$;
revoke all on function grillad_private.drive_owner(uuid,uuid,uuid),public.grillad_drive_begin(uuid,uuid,text,text),public.grillad_drive_consume(text),public.grillad_drive_connect(uuid,uuid,uuid,text),public.grillad_drive_control(uuid,uuid,text),public.grillad_drive_claim(),public.grillad_drive_payload(uuid,uuid,uuid,uuid),public.grillad_drive_finish(uuid,uuid,uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.grillad_drive_begin(uuid,uuid,text,text),public.grillad_drive_control(uuid,uuid,text) to authenticated;
grant execute on function public.grillad_drive_consume(text),public.grillad_drive_connect(uuid,uuid,uuid,text),public.grillad_drive_claim(),public.grillad_drive_payload(uuid,uuid,uuid,uuid),public.grillad_drive_finish(uuid,uuid,uuid,uuid,text,boolean) to service_role;

revoke all on function public.grillad_backup_preferences(uuid,uuid,text,integer,integer,integer),public.grillad_backup_export(uuid,uuid) from public,anon,authenticated;
grant execute on function public.grillad_backup_preferences(uuid,uuid,text,integer,integer,integer),public.grillad_backup_export(uuid,uuid) to authenticated;

commit;
