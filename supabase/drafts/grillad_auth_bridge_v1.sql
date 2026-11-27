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
create function public.grillad_purge_attendance_photos() returns bigint language sql security invoker set search_path=pg_catalog as $select grillad_private.purge_attendance_photos()$;
revoke all on function public.grillad_purge_attendance_photos() from public,anon,authenticated;
grant execute on function public.grillad_purge_attendance_photos(),grillad_private.purge_attendance_photos() to service_role;
commit;
