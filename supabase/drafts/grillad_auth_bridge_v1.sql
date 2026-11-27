-- Candidate after 0004 account lifecycle + GRILLAD business and attendance.
-- Reuses family login guard, grants, device registry and bound session. No public service credential.
begin;
create function grillad_private.auth_begin(p_hash text,p_recovery boolean) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
begin
 if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then return false;end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-login:'||p_hash,0));
 delete from famille_private.login_guard where app_code='grillad' and login_hash=p_hash and locked_until<=now();
 if famille_private.login_is_locked(p_hash,'grillad') then return false;end if;
 perform famille_private.record_login_failure(p_hash,'grillad');
 if p_recovery then
  if not exists(select 1 from famille_private.recovery_requests where app_code='grillad' and login_hash=p_hash and status in ('pending','identity_check')) then
   insert into famille_private.recovery_requests(login_hash,app_code,channel) values(p_hash,'grillad','whatsapp');
  end if;
 end if;
 return true;
end $$;
create function grillad_private.auth_finish(p_hash text,p_user uuid,p_session uuid,p_installation uuid,p_platform text) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
declare d famille_private.account_devices%rowtype;tag_value text;
begin
 if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' or p_user is null or p_session is null or p_installation is null or p_platform not in ('android','web') then return false;end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-device:'||p_user::text,0));
 select tag into tag_value from auth.sessions where id=p_session and user_id=p_user for update;
 if not found or (tag_value is not null and tag_value<>'famille:grillad') then return false;end if;
 if not exists(select 1 from famille_private.account_app_access g where g.user_id=p_user and g.app_code='grillad' and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())) then return false;end if;
 select * into d from famille_private.account_devices where user_id=p_user and app_code='grillad' and installation_id=p_installation::text;
 if found and d.status<>'active' then return false;end if;
 -- Adapt the family's two-device protection per individual, not per shop.
 -- Never evict a different seller or automatically revoke an active device.
 if d.id is null and (select count(*) from famille_private.account_devices where user_id=p_user and app_code='grillad' and status='active')>=2 then return false;end if;
 if not famille_private.bind_auth_session(p_user,p_session,'grillad') then return false;end if;
 if d.id is null then
  insert into famille_private.account_devices(user_id,app_code,installation_id,auth_session_id,platform,device_label) values(p_user,'grillad',p_installation::text,p_session,p_platform,'GRILLAD');
 else update famille_private.account_devices set auth_session_id=p_session,last_seen_at=now(),platform=p_platform where id=d.id;
 end if;
 perform famille_private.clear_login_failures(p_hash,'grillad');
 insert into famille_private.account_audit_log(actor_id,subject_user_id,app_code,event_code,outcome) values(p_user,p_user,'grillad','device.registered','success');
 return true;
end $$;
-- Keep previously tested business scope, add lifecycle grant validation per org and site.
alter function grillad_private.scope(uuid,uuid) rename to business_scope_base;
create function grillad_private.scope(p_org uuid,p_site uuid) returns text language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;
begin
 r:=grillad_private.business_scope_base(p_org,p_site);
 if not exists(select 1 from famille_private.account_app_access g where g.user_id=auth.uid() and g.app_code='grillad' and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()) and g.organization_id=p_org and (g.location_id is null or g.location_id=p_site)) then raise exception 'GRILLAD_LIFECYCLE_GRANT' using errcode='42501';end if;
 return r;
end $$;
revoke all on function grillad_private.scope(uuid,uuid),grillad_private.business_scope_base(uuid,uuid),grillad_private.auth_begin(text,boolean),grillad_private.auth_finish(text,uuid,uuid,uuid,text) from public,anon,authenticated;
grant usage on schema grillad_private to service_role;
grant execute on function grillad_private.auth_begin(text,boolean),grillad_private.auth_finish(text,uuid,uuid,uuid,text) to service_role;
create function public.grillad_auth_begin(p_hash text,p_recovery boolean) returns boolean language sql security invoker set search_path=pg_catalog as $$select grillad_private.auth_begin(p_hash,p_recovery)$$;
create function public.grillad_auth_finish(p_hash text,p_user uuid,p_session uuid,p_installation uuid,p_platform text) returns boolean language sql security invoker set search_path=pg_catalog as $$select grillad_private.auth_finish(p_hash,p_user,p_session,p_installation,p_platform)$$;
revoke all on function public.grillad_auth_begin(text,boolean),public.grillad_auth_finish(text,uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.grillad_auth_begin(text,boolean),public.grillad_auth_finish(text,uuid,uuid,uuid,text) to service_role;
-- Scheduled retention wrapper: service-only, no photo bytes returned.
create function public.grillad_purge_attendance_photos() returns bigint language sql security invoker set search_path=pg_catalog as $$select grillad_private.purge_attendance_photos()$$;
revoke all on function public.grillad_purge_attendance_photos() from public,anon,authenticated;
grant execute on function public.grillad_purge_attendance_photos(),grillad_private.purge_attendance_photos() to service_role;
-- Owner may assign only an already active GRILLAD collaborator in the same organization.
-- No new auth user, no change to the central user lifecycle or other app.
create function grillad_private.set_team_assignment(p_org uuid,p_site uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare u uuid:=auth.uid();target_user uuid;app uuid;member uuid;desired text;why text;source_grant famille_private.account_app_access%rowtype;site_grant famille_private.account_app_access%rowtype;
begin
 if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 target_user:=(p_payload->>'user')::uuid;desired:=p_payload->>'role';why:=btrim(p_payload->>'reason');
 if target_user is null or target_user=u or desired is null or desired not in ('seller','manager','none') or why is null or length(why) not between 1 and 300 then raise exception 'GRILLAD_ASSIGNMENT' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-network:'||p_org::text,0));
 select id into app from famille_core.applications where code='grillad' and status='active';
 select m.id into member from famille_core.memberships m join famille_core.client_app_access a on a.user_id=m.user_id and a.app_id=m.app_id and a.status='granted' where m.user_id=target_user and m.organization_id=p_org and m.app_id=app and m.status='active';
 if member is null or exists(select 1 from famille_core.role_assignments r where r.membership_id=member and r.app_id=app and r.organization_id=p_org and r.role_code='owner' and r.status='active') then raise exception 'GRILLAD_COLLABORATOR_DENIED' using errcode='42501';end if;
 if desired<>'none' then
  select g.* into source_grant from famille_private.account_app_access g where g.user_id=target_user and g.app_code='grillad' and g.organization_id=p_org and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()) order by g.ends_at desc nulls first limit 1;
  if not found then raise exception 'GRILLAD_COLLABORATOR_DENIED' using errcode='42501';end if;
  select g.* into site_grant from famille_private.account_app_access g where g.user_id=target_user and g.app_code='grillad' and g.organization_id=p_org and g.location_id=p_site;
  if found and (site_grant.status<>'active' or site_grant.starts_at>now() or site_grant.ends_at<=now()) then raise exception 'GRILLAD_CENTRAL_GRANT_DENIED' using errcode='42501';end if;
  if not exists(select 1 from famille_private.account_app_access g where g.user_id=target_user and g.app_code='grillad' and g.organization_id=p_org and (g.location_id is null or g.location_id=p_site) and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())) then
   insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,location_id,role_code,starts_at,ends_at,granted_by) values(target_user,'grillad',source_grant.account_kind,p_org,p_site,desired,now(),source_grant.ends_at,u);
  end if;
 end if;
 update famille_core.role_assignments set status='revoked',revoked_by=u,revoked_at=now() where membership_id=member and app_id=app and organization_id=p_org and location_id=p_site and role_code in ('seller','manager') and status='active';
 if desired<>'none' then
  insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id,granted_by,expires_at) values(member,app,p_org,desired,p_site,u,source_grant.ends_at);
 end if;
 return jsonb_build_object('user',target_user,'site',p_site,'role',desired);
end $$;
revoke all on function grillad_private.set_team_assignment(uuid,uuid,jsonb) from public,anon,authenticated;

-- Suspension GRILLAD only. Keep historical rows, other applications and their locations unchanged.
create function grillad_private.set_site_enabled(p_org uuid,p_anchor uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare target uuid;desired boolean;why text;before_state boolean;
begin
 if grillad_private.scope(p_org,p_anchor)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 target:=(p_payload->>'site')::uuid;why:=btrim(p_payload->>'reason');
 if target is null or target=p_anchor or jsonb_typeof(p_payload->'enabled') is distinct from 'boolean' or why is null or length(why) not between 1 and 300 then raise exception 'GRILLAD_SITE_STATE' using errcode='22023';end if;
 desired:=(p_payload->>'enabled')::boolean;
 perform pg_advisory_xact_lock(hashtextextended('grillad-network:'||p_org::text,0));
 -- Do not wait for another site while holding an anchor and network lock.
 if not pg_try_advisory_xact_lock(hashtextextended(p_org::text||':'||target::text,0)) then raise exception 'GRILLAD_SITE_BUSY' using errcode='22023';end if;
 if not famille_core.can_access_outlet(p_org,famille_core.current_app_id(),target) or not exists(select 1 from famille_private.account_app_access g where g.user_id=auth.uid() and g.app_code='grillad' and g.organization_id=p_org and (g.location_id is null or g.location_id=target) and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())) then raise exception 'GRILLAD_SITE_DENIED' using errcode='42501';end if;
 select enabled into before_state from grillad_private.enabled_sites where org=p_org and site=target for update;
 if not found then raise exception 'GRILLAD_SITE_DENIED' using errcode='42501';end if;
 if desired and not before_state and not exists(select 1 from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id where s.organization_id=p_org and s.app_id=famille_core.current_app_id() and p.status='active' and ((s.status='active' and (s.starts_at is null or s.starts_at<=now()) and (s.ends_at is null or s.ends_at>=now())) or (s.status='past_due' and s.grace_until>=now())) and ((p.code='grillad_premium_month' and p.amount_fcfa=6000 and p.billing_period='monthly') or (p.code='grillad_premium_year' and p.amount_fcfa=60000 and p.billing_period='yearly'))) then raise exception 'GRILLAD_PREMIUM_REQUIRED' using errcode='42501';end if;
 if not desired and before_state then
  if exists(select 1 from grillad_private.cash c where c.org=p_org and c.site=target and c.closed_at is null)
  or exists(select 1 from grillad_private.attendance a where a.org=p_org and a.site=target and a.kind='arrival' and not exists(select 1 from grillad_private.attendance b where b.paired_arrival=a.id) and not exists(select 1 from grillad_private.missing_departures m where m.arrival=a.id and m.status='approved'))
  or exists(select 1 from grillad_private.attendance a where a.org=p_org and a.site=target and a.kind='departure_without_arrival' and not exists(select 1 from grillad_private.missing_arrivals m where m.departure=a.id and m.status in ('approved','rejected')))
  or exists(select 1 from grillad_private.connect_orders o where o.org=p_org and o.site=target and o.status in ('submitted','accepted','preparing','ready'))
  then raise exception 'GRILLAD_SITE_OPEN_OPERATIONS' using errcode='22023';end if;
 end if;
 update grillad_private.enabled_sites set enabled=desired where org=p_org and site=target;
 return jsonb_build_object('site',target,'enabled',desired,'previous',before_state);
end $$;
revoke all on function grillad_private.set_site_enabled(uuid,uuid,jsonb) from public,anon,authenticated;

-- Owner requests central onboarding or renewal; never grants access or confirms money locally.
create table grillad_private.central_requests(
 id uuid primary key,org uuid not null,site uuid not null,actor uuid not null,
 kind text not null check(kind in ('employee','renewal')), details jsonb not null,
 status text not null default 'pending' check(status in ('pending','cancelled','processed','rejected')),
 created_at timestamptz not null default now(),resolved_at timestamptz,resolution text,
 foreign key(org,site) references grillad_private.enabled_sites(org,site));
create unique index grillad_central_pending_employee on grillad_private.central_requests(org,site,(details->>'phone')) where kind='employee' and status='pending';
create unique index grillad_central_pending_renewal on grillad_private.central_requests(org) where kind='renewal' and status='pending';
alter table grillad_private.central_requests enable row level security;
revoke all on grillad_private.central_requests from public,anon,authenticated;
-- Narrow renewal scope for an expired subscription, never a business workspace.
create function grillad_private.renewal_workspace() returns jsonb language sql stable security definer set search_path=pg_catalog as $$
 select coalesce(jsonb_agg(to_jsonb(x) order by x.organization,x.site),'[]'::jsonb) from (
 select distinct on(e.org) e.org,e.site,l.name,o.legal_name organization,'owner'::text role
 from grillad_private.enabled_sites e join famille_core.locations l on l.id=e.site and l.organization_id=e.org
 join famille_core.organizations o on o.id=e.org and o.status='active'
 join famille_core.applications a on a.code='grillad' and a.id=famille_core.current_app_id() and a.status='active'
 join famille_core.memberships m on m.user_id=auth.uid() and m.organization_id=e.org and m.app_id=a.id and m.status='active'
 join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=a.id and ra.organization_id=e.org and ra.role_code='owner' and ra.location_id is null and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now())
 join famille_core.client_app_access ca on ca.user_id=m.user_id and ca.app_id=a.id and ca.status='granted'
 where e.enabled and coalesce(auth.jwt()->>'is_anonymous','false')<>'true'
 and famille_core.can_access_outlet(e.org,a.id,e.site)
 and exists(select 1 from famille_private.account_app_access g where g.user_id=auth.uid() and g.app_code='grillad' and g.organization_id=e.org and (g.location_id is null or g.location_id=e.site) and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()))
 and not famille_core.subscription_allows_workspace(e.org,a.id)
 and exists(select 1 from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id where s.organization_id=e.org and s.app_id=a.id and s.status in ('expired','past_due','active') and s.ends_at<now() and p.code in ('grillad_access_month','grillad_access_year','grillad_premium_month','grillad_premium_year'))
 and not exists(select 1 from famille_core.subscriptions s where s.organization_id=e.org and s.app_id=a.id and s.status='suspended')
 order by e.org,e.site)x
$$;
revoke all on function grillad_private.renewal_workspace() from public,anon,authenticated;
grant execute on function grillad_private.renewal_workspace() to authenticated;
create function public.grillad_renewal_workspace() returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.renewal_workspace()$$;
revoke all on function public.grillad_renewal_workspace() from public,anon,authenticated;
grant execute on function public.grillad_renewal_workspace() to authenticated;
create function grillad_private.renewal_guard(p_org uuid,p_site uuid) returns void language plpgsql stable security definer set search_path=pg_catalog as $$
begin
 if not exists(select 1 from jsonb_array_elements(grillad_private.renewal_workspace()) x where x->>'org'=p_org::text and x->>'site'=p_site::text) then raise exception 'GRILLAD_RENEWAL_DENIED' using errcode='42501';end if;
end $$;
revoke all on function grillad_private.renewal_guard(uuid,uuid) from public,anon,authenticated;
create function grillad_private.central_request(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb,p_billing_only boolean default false) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare u uuid:=auth.uid();k text;d jsonb;phone text;desired text;why text;price bigint;r grillad_private.central_requests%rowtype;
begin
 if p_billing_only then perform grillad_private.renewal_guard(p_org,p_site);if p_action not in ('renewal_request','central_request_cancel') then raise exception 'GRILLAD_RENEWAL_DENIED' using errcode='42501';end if;
 elsif grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-network:'||p_org::text,0));
 if p_action='central_request_cancel' then
  select * into r from grillad_private.central_requests where id=(p_payload->>'request')::uuid and org=p_org and (site=p_site or (p_billing_only and kind='renewal')) and (not p_billing_only or kind='renewal') for update;
  if not found then raise exception 'GRILLAD_REQUEST_DENIED' using errcode='42501';end if;
  why:=btrim(p_payload->>'reason');
  if r.status<>'pending' or why is null or length(why) not between 1 and 300 then raise exception 'GRILLAD_REQUEST_STATE' using errcode='22023';end if;
  update grillad_private.central_requests set status='cancelled',resolved_at=now(),resolution=why where id=r.id;
  return jsonb_build_object('id',r.id,'status','cancelled');
 elsif p_action='employee_request' then
  k:='employee';phone:=p_payload->>'phone';desired:=p_payload->>'role';why:=btrim(p_payload->>'name');
  if phone is null or phone !~ '^\+[1-9][0-9]{7,14}$' or desired is null or desired not in ('seller','manager') or why is null or length(why) not between 2 and 100 then raise exception 'GRILLAD_EMPLOYEE_INPUT' using errcode='22023';end if;
  d:=jsonb_build_object('phone',phone,'name',why,'role',desired);
 elsif p_action='renewal_request' then
  k:='renewal';desired:=p_payload->>'plan';
  price:=case desired when 'grillad_access_month' then 2000 when 'grillad_access_year' then 24000 when 'grillad_premium_month' then 6000 when 'grillad_premium_year' then 60000 else null end;
  if price is null or not exists(select 1 from famille_core.plans p join famille_core.applications a on a.id=p.app_id where a.code='grillad' and p.code=desired and p.status='active' and p.amount_fcfa=price) then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
  d:=jsonb_build_object('plan',desired,'amount',price,'currency','FCFA');
 else raise exception 'GRILLAD_ACTION' using errcode='22023';end if;
 if exists(select 1 from grillad_private.central_requests x where x.org=p_org and x.status='pending' and x.kind=k and (k='renewal' or (x.site=p_site and x.details->>'phone'=phone))) then raise exception 'GRILLAD_REQUEST_PENDING' using errcode='22023';end if;
 insert into grillad_private.central_requests(id,org,site,actor,kind,details) values(p_event,p_org,p_site,u,k,d);
 return jsonb_build_object('id',p_event,'status','pending','kind',k);
end $$;
revoke all on function grillad_private.central_request(uuid,uuid,uuid,text,jsonb,boolean) from public,anon,authenticated;
create function grillad_private.renewal_status(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
begin
 perform grillad_private.renewal_guard(p_org,p_site);
 return jsonb_build_object('central_requests',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'kind',x.kind,'status',x.status,'label',x.details->>'plan','amount',x.details->'amount','created_at',x.created_at) order by x.created_at desc),'[]'::jsonb) from (select * from grillad_private.central_requests where org=p_org and kind='renewal' order by created_at desc limit 50)x));
end $$;
create function grillad_private.renewal_action(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare old grillad_private.events%rowtype;result jsonb;u uuid:=auth.uid();
begin
 if p_event is null or p_action is null or p_action not in ('renewal_request','central_request_cancel') or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>8192 then raise exception 'GRILLAD_RENEWAL_INPUT' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 -- A completed billing request can be replayed after subscription renewal, but only by the currently authorized owner.
 begin perform grillad_private.renewal_guard(p_org,p_site);exception when insufficient_privilege then if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_RENEWAL_DENIED' using errcode='42501';end if;end;
 select * into old from grillad_private.events where org=p_org and site=p_site and id=p_event;
 if found then if old.actor<>u or old.action<>p_action or old.payload<>p_payload then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023';end if;return old.result;end if;
 perform grillad_private.renewal_guard(p_org,p_site);
 result:=grillad_private.central_request(p_org,p_site,p_event,p_action,p_payload,true);
 insert into grillad_private.events(org,site,id,actor,action,payload,result) values(p_org,p_site,p_event,u,p_action,p_payload,result);
 return result;
end $$;
create function public.grillad_renewal_status(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.renewal_status(p_org,p_site)$$;
create function public.grillad_renewal_action(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.renewal_action(p_org,p_site,p_event,p_action,p_payload)$$;
revoke all on function grillad_private.renewal_status(uuid,uuid),public.grillad_renewal_status(uuid,uuid),grillad_private.renewal_action(uuid,uuid,uuid,text,jsonb),public.grillad_renewal_action(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function grillad_private.renewal_status(uuid,uuid),public.grillad_renewal_status(uuid,uuid),grillad_private.renewal_action(uuid,uuid,uuid,text,jsonb),public.grillad_renewal_action(uuid,uuid,uuid,text,jsonb) to authenticated;
-- Central service integration contract. Only central service may read unmasked requests.
create function public.grillad_central_queue(p_limit integer) returns jsonb language plpgsql security invoker set search_path=pg_catalog as $$
begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception 'GRILLAD_LIMIT' using errcode='22023';end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb) from (select id,org,site,kind,details,created_at from grillad_private.central_requests where status='pending' order by created_at limit p_limit)x);
end $$;
revoke all on function public.grillad_central_queue(integer) from public,anon,authenticated;
grant select on grillad_private.central_requests to service_role;
grant execute on function public.grillad_central_queue(integer) to service_role;
-- A processed request requires a matching central fact, not an arbitrary reference.
create unique index grillad_central_processed_reference on grillad_private.central_requests(kind,resolution) where status='processed';
create function grillad_private.central_resolve(p_request uuid,p_status text,p_reference text) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
declare q grillad_private.central_requests%rowtype;ref_id uuid;
begin
 if p_status is null or p_status not in ('processed','rejected') or p_reference is null or length(btrim(p_reference)) not between 1 and 160 then raise exception 'GRILLAD_RESOLUTION' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request for update;
 if not found then return false;end if;
 if q.status=p_status and q.resolution=btrim(p_reference) then return true;end if;
 if q.status<>'pending' then return false;end if;
 if p_status='processed' then
  begin ref_id:=btrim(p_reference)::uuid;exception when invalid_text_representation then raise exception 'GRILLAD_CENTRAL_EVIDENCE' using errcode='22023';end;
  if q.kind='employee' then
   if not exists(select 1 from famille_private.account_invites i join auth.users u on u.id=i.user_id
    join famille_core.applications a on a.code='grillad' and a.status='active'
    join famille_core.memberships m on m.user_id=u.id and m.app_id=a.id and m.organization_id=q.org and m.status='active'
    join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=a.id and ra.organization_id=q.org and ra.location_id=q.site and ra.role_code=q.details->>'role' and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now())
    join famille_core.client_app_access ca on ca.user_id=u.id and ca.app_id=a.id and ca.status='granted'
    join famille_private.account_app_access g on g.user_id=u.id and g.app_code='grillad' and g.organization_id=q.org and g.location_id=q.site and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())
    where i.id=ref_id and i.request_id=q.id and i.app_code='grillad' and i.organization_id=q.org and i.location_id=q.site and i.role_code=q.details->>'role' and i.status='accepted' and i.accepted_by=u.id and i.accepted_at>=q.created_at and ltrim(to_jsonb(u)->>'phone','+')=ltrim(q.details->>'phone','+')) then raise exception 'GRILLAD_CENTRAL_EVIDENCE' using errcode='22023';end if;
  else
   if not exists(select 1 from famille_core.payment_matches pm join famille_core.payment_intents pi on pi.id=pm.payment_intent_id join famille_core.subscriptions s on s.id=pi.subscription_id
    join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id join famille_core.applications a on a.id=s.app_id and a.code='grillad'
    where pm.id=ref_id and pm.status='confirmed' and pm.verified_at>=q.created_at and pi.status='matched' and pi.created_at>=q.created_at and pi.currency='FCFA'
    and pi.expected_amount_fcfa=(q.details->>'amount')::bigint and pm.amount_fcfa=pi.expected_amount_fcfa and s.organization_id=q.org and s.status='active' and s.ends_at>now() and p.code=q.details->>'plan' and p.amount_fcfa=pi.expected_amount_fcfa) then raise exception 'GRILLAD_CENTRAL_EVIDENCE' using errcode='22023';end if;
  end if;
  if exists(select 1 from grillad_private.central_requests x where x.kind=q.kind and x.status='processed' and x.resolution=ref_id::text and x.id<>q.id) then raise exception 'GRILLAD_CENTRAL_EVIDENCE_USED' using errcode='22023';end if;
 end if;
 update grillad_private.central_requests set status=p_status,resolved_at=now(),resolution=case when p_status='processed' then ref_id::text else btrim(p_reference) end where id=p_request and status='pending';
 return found;
end $$;
revoke all on function grillad_private.central_resolve(uuid,text,text) from public,anon,authenticated;
grant execute on function grillad_private.central_resolve(uuid,text,text) to service_role;
create function public.grillad_central_resolve(p_request uuid,p_status text,p_reference text) returns boolean language sql security invoker set search_path=pg_catalog as $$select grillad_private.central_resolve(p_request,p_status,p_reference)$$;
revoke all on function public.grillad_central_resolve(uuid,text,text) from public,anon,authenticated;
grant execute on function public.grillad_central_resolve(uuid,text,text) to service_role;

-- Reconcile only existing, uniquely matched central evidence. This job never
-- creates accounts, invites, payments, subscriptions or grants.
create function grillad_private.central_reconcile(p_limit integer) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $
declare q record; n integer:=0; deferred integer:=0;
begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception 'GRILLAD_LIMIT' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-central-reconcile',0));
 for q in
  with evidence as (
   select c.id request_id,i.id proof_id,c.kind,c.created_at
   from grillad_private.central_requests c join famille_private.account_invites i on i.request_id=c.id
   join auth.users u on u.id=i.user_id
   join famille_core.applications a on a.code='grillad' and a.status='active'
   join famille_core.memberships m on m.user_id=u.id and m.app_id=a.id and m.organization_id=c.org and m.status='active'
   where c.status='pending' and c.kind='employee' and i.app_code='grillad' and i.organization_id=c.org and i.location_id=c.site
   and i.role_code=c.details->>'role' and i.status='accepted' and i.accepted_by=u.id and i.accepted_at>=c.created_at
   and ltrim(to_jsonb(u)->>'phone','+')=ltrim(c.details->>'phone','+')
   and exists(select 1 from famille_core.role_assignments ra where ra.membership_id=m.id and ra.app_id=a.id and ra.organization_id=c.org and ra.location_id=c.site and ra.role_code=c.details->>'role' and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now()))
   and exists(select 1 from famille_core.client_app_access ca where ca.user_id=u.id and ca.app_id=a.id and ca.status='granted')
   and exists(select 1 from famille_private.account_app_access g where g.user_id=u.id and g.app_code='grillad' and g.organization_id=c.org and g.location_id=c.site and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()))
   union
   select c.id,pm.id,c.kind,c.created_at
   from grillad_private.central_requests c
   join famille_core.subscriptions s on s.organization_id=c.org and s.status='active' and s.ends_at>now()
   join famille_core.applications a on a.id=s.app_id and a.code='grillad'
   join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id and p.code=c.details->>'plan'
   join famille_core.payment_intents pi on pi.subscription_id=s.id and pi.status='matched' and pi.created_at>=c.created_at and pi.currency='FCFA'
   join famille_core.payment_matches pm on pm.payment_intent_id=pi.id and pm.status='confirmed' and pm.verified_at>=c.created_at
   where c.status='pending' and c.kind='renewal' and pi.expected_amount_fcfa=(c.details->>'amount')::bigint and pm.amount_fcfa=pi.expected_amount_fcfa and p.amount_fcfa=pi.expected_amount_fcfa
  ), unused as (
   select e.* from evidence e where not exists(select 1 from grillad_private.central_requests x where x.kind=e.kind and x.status='processed' and x.resolution=e.proof_id::text)
  )
  select request_id,(array_agg(proof_id order by proof_id))[1] proof_id
  from unused group by request_id having count(distinct proof_id)=1 order by min(created_at),request_id limit p_limit
 loop
  begin
   if grillad_private.central_resolve(q.request_id,'processed',q.proof_id::text) then n:=n+1;else deferred:=deferred+1;end if;
  exception when invalid_parameter_value or unique_violation then deferred:=deferred+1;
  end;
 end loop;
 return jsonb_build_object('processed',n,'deferred',deferred);
end $;
revoke all on function grillad_private.central_reconcile(integer) from public,anon,authenticated;
grant execute on function grillad_private.central_reconcile(integer) to service_role;
create function public.grillad_central_reconcile(p_limit integer) returns jsonb language sql security invoker set search_path=pg_catalog as $select grillad_private.central_reconcile(p_limit)$;
revoke all on function public.grillad_central_reconcile(integer) from public,anon,authenticated;
grant execute on function public.grillad_central_reconcile(integer) to service_role;

commit;
