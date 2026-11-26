-- ZIPPLE N1 draft ONLY. Apply on an isolated database before any production approval.
begin;
create table public.zp_organizations(id uuid primary key, name text not null, active boolean not null default true);
create table public.zp_members(id uuid primary key, org_id uuid not null references public.zp_organizations(id), auth_user_id uuid not null unique references auth.users(id), login_id text not null unique, auth_alias text not null unique, role_code text not null check(role_code in ('promoteur','manager','staff')), active boolean not null default true, reset_pending boolean not null default false, credential_epoch integer not null default 0, unique(id,org_id));
create table public.zp_sites(id uuid primary key, org_id uuid not null references public.zp_organizations(id), name text not null, active boolean not null default true, unique(id,org_id));
create table public.zp_site_scopes(member_id uuid not null, org_id uuid not null, site_id uuid not null, primary key(member_id,site_id), foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id));
create table public.zp_sessions(id uuid primary key default gen_random_uuid(), member_id uuid not null references public.zp_members(id), access_hash text unique not null, refresh_hash text unique, access_until timestamptz not null, refresh_until timestamptz, revoked boolean not null default false);
create table public.zp_rate_windows(bucket text primary key, window_start timestamptz not null, attempts int not null);
create table public.zp_recovery_requests(id uuid primary key default gen_random_uuid(), member_id uuid not null references public.zp_members(id), created_at timestamptz not null default now(), state text not null default 'pending' check(state in ('pending','processing','failed','resolved','dismissed')), operator_id uuid references auth.users(id), attempt_id uuid, reason text);
create table public.zp_n1_receipts(member_id uuid not null, org_id uuid not null, site_id uuid not null, event_id text not null, digest text not null, primary key(member_id,org_id,site_id,event_id), foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id));
create table public.zp_recovery_operators(auth_user_id uuid primary key references auth.users(id), active boolean not null default true);
create table public.zp_recovery_audit(id uuid primary key default gen_random_uuid(), request_id uuid not null references public.zp_recovery_requests(id), operator_id uuid not null references auth.users(id), action text not null check(action in ('begin','failed','resolved')), created_at timestamptz not null default now());
-- Private gateway boundary: no direct access by anon/authenticated.
do $$ declare t text; begin
 foreach t in array array['zp_organizations','zp_members','zp_sites','zp_site_scopes','zp_sessions','zp_rate_windows','zp_recovery_requests','zp_recovery_operators','zp_recovery_audit','zp_n1_receipts'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select,insert,update,delete on public.%I to service_role',t);
 end loop;
end $$;
create function public.zp_rate_limit(p_bucket text) returns boolean language sql security invoker set search_path=pg_catalog,public as $$
 insert into public.zp_rate_windows as w(bucket,window_start,attempts) values(p_bucket,now(),1)
 on conflict(bucket) do update set window_start=case when w.window_start<=now()-interval '15 minutes' then now() else w.window_start end,
 attempts=case when w.window_start<=now()-interval '15 minutes' then 1 else least(w.attempts+1,1000000) end returning attempts<=8
$$;
create function public.zp_identity(p_member uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('app_id','ZIPPLE','member_id',m.id,'organization_id',m.org_id,'organization_name',o.name,'role',m.role_code,'active',true,'session_active',true,'active_sites',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'active',true) order by s.id) from public.zp_site_scopes sc join public.zp_sites s on s.id=sc.site_id and s.org_id=sc.org_id where sc.member_id=m.id and sc.org_id=m.org_id and s.active),'[]'::jsonb),'scopes',coalesce((select jsonb_agg(jsonb_build_object('scope_type','site','site_id',s.id)) from public.zp_site_scopes sc join public.zp_sites s on s.id=sc.site_id and s.org_id=sc.org_id where sc.member_id=m.id and sc.org_id=m.org_id and s.active),'[]'::jsonb))
 from public.zp_members m join public.zp_organizations o on o.id=m.org_id where m.id=p_member and m.active and not m.reset_pending and o.active and exists(select 1 from public.zp_site_scopes sc join public.zp_sites s on s.id=sc.site_id and s.org_id=sc.org_id where sc.member_id=m.id and sc.org_id=m.org_id and s.active)
$$;
create function public.zp_issue(p_member uuid,p_auth_user uuid,p_epoch integer,p_access text,p_refresh text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
 declare identity jsonb; deadline timestamptz:=now()+interval '15 minutes'; begin
 perform 1 from public.zp_members where id=p_member and auth_user_id=p_auth_user and active and not reset_pending and credential_epoch=p_epoch for update; if not found then raise exception 'DENIED'; end if;
 identity:=public.zp_identity(p_member); if identity is null then raise exception 'DENIED'; end if;
 insert into public.zp_sessions(member_id,access_hash,refresh_hash,access_until,refresh_until) values(p_member,p_access,p_refresh,deadline,case when p_refresh is not null then now()+interval '30 days' end);
 return identity||jsonb_build_object('expires_at',floor(extract(epoch from deadline)*1000)::bigint);
end $$;
create function public.zp_rotate(p_previous text,p_access text,p_refresh text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
 declare member uuid; deadline timestamptz:=now()+interval '15 minutes'; identity jsonb; begin
 update public.zp_sessions set access_hash=p_access,refresh_hash=p_refresh,access_until=deadline where refresh_hash=p_previous and not revoked and refresh_until>now() returning member_id into member;
 if member is null then raise exception 'DENIED'; end if;
 identity:=public.zp_identity(member); if identity is null then raise exception 'DENIED'; end if;
 return identity||jsonb_build_object('expires_at',floor(extract(epoch from deadline)*1000)::bigint);
end $$;
create function public.zp_revoke(p_access text) returns boolean language sql security invoker set search_path=pg_catalog,public as $$
 with changed as(update public.zp_sessions set revoked=true,refresh_hash=null where access_hash=p_access and not revoked returning id) select exists(select 1 from changed)
$$;
create function public.zp_recovery(p_login text) returns void language sql security invoker set search_path=pg_catalog,public as $$
 insert into public.zp_recovery_requests(member_id) select id from public.zp_members where login_id=p_login and active
$$;
-- N1 probe only: never acknowledge an actual business operation without applying it.
create function public.zp_probe_receipt(p_access text,p_org uuid,p_member uuid,p_site uuid,p_event text,p_digest text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
 declare stored text; begin
 if not exists(select 1 from public.zp_sessions a join public.zp_members m on m.id=a.member_id join public.zp_organizations o on o.id=m.org_id join public.zp_site_scopes sc on sc.member_id=m.id and sc.org_id=m.org_id join public.zp_sites s on s.id=sc.site_id and s.org_id=sc.org_id where a.access_hash=p_access and not a.revoked and a.access_until>now() and m.active and not m.reset_pending and o.active and s.active and m.id=p_member and m.org_id=p_org and s.id=p_site) then raise exception 'DENIED'; end if;
 insert into public.zp_n1_receipts values(p_member,p_org,p_site,p_event,p_digest) on conflict do nothing;
 select digest into stored from public.zp_n1_receipts where member_id=p_member and org_id=p_org and site_id=p_site and event_id=p_event;
 return case when stored=p_digest then 'acknowledged' else 'conflict' end;
end $$;

create function public.zp_admin_recovery_list(p_operator uuid) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $
 begin
 if not exists(select 1 from public.zp_recovery_operators where auth_user_id=p_operator and active) then raise exception 'DENIED'; end if;
 return coalesce((select jsonb_agg(to_jsonb(q)) from (select r.id,r.member_id,m.login_id,m.org_id,r.state,r.created_at from public.zp_recovery_requests r join public.zp_members m on m.id=r.member_id where r.state in ('pending','processing','failed') order by r.created_at limit 100) q),'[]'::jsonb);
 end $;
create function public.zp_admin_recovery_begin(p_operator uuid,p_request uuid,p_reason text,p_attempt uuid) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $
 declare target uuid; auth_id uuid; begin
 if not exists(select 1 from public.zp_recovery_operators where auth_user_id=p_operator and active) or length(trim(p_reason))<10 or length(p_reason)>500 then raise exception 'DENIED'; end if;
 select member_id into target from public.zp_recovery_requests where id=p_request and state in ('pending','failed') for update;
 if target is null then raise exception 'DENIED'; end if;
 select auth_user_id into auth_id from public.zp_members where id=target and active for update;
 if auth_id is null or auth_id=p_operator or exists(select 1 from public.zp_recovery_requests where member_id=target and state='processing') then raise exception 'DENIED'; end if;
 update public.zp_members set reset_pending=true,credential_epoch=credential_epoch+1 where id=target;
 update public.zp_sessions set revoked=true,refresh_hash=null where member_id=target;
 update public.zp_recovery_requests set state='processing',operator_id=p_operator,attempt_id=p_attempt,reason=p_reason where id=p_request;
 insert into public.zp_recovery_audit(request_id,operator_id,action) values(p_request,p_operator,'begin');
 return auth_id;
 end $;
create function public.zp_admin_recovery_finish(p_operator uuid,p_request uuid,p_attempt uuid,p_success boolean) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $
 declare target uuid; begin
 if not exists(select 1 from public.zp_recovery_operators where auth_user_id=p_operator and active) then raise exception 'DENIED'; end if;
 select member_id into target from public.zp_recovery_requests where id=p_request and state='processing' and operator_id=p_operator and attempt_id=p_attempt for update;
 if target is null then raise exception 'DENIED'; end if;
 if p_success then
  update public.zp_members set reset_pending=false where id=target;
  update public.zp_recovery_requests set state='resolved' where id=p_request;
  update public.zp_recovery_requests set state='dismissed' where member_id=target and id<>p_request and state in ('pending','failed');
 else update public.zp_recovery_requests set state='failed' where id=p_request; end if;
 insert into public.zp_recovery_audit(request_id,operator_id,action) values(p_request,p_operator,case when p_success then 'resolved' else 'failed' end);
 return true;
 end $;

do $ declare f record; begin for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_rate_limit','zp_identity','zp_issue','zp_rotate','zp_revoke','zp_recovery','zp_probe_receipt','zp_admin_recovery_list','zp_admin_recovery_begin','zp_admin_recovery_finish') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
