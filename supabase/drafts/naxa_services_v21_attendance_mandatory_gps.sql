begin;
-- v21: enforce shift boundaries even without policy or with legacy false. Breaks remain configurable.
create or replace function public.ns_attendance_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare p public.ns_attendance_policies%rowtype; e public.ns_attendance_evidence%rowtype;
begin
 if new.actor_member_id is distinct from new.staff_member_id or new.actor_member_id is distinct from public.ns_current_member_id(new.org_id) then raise exception 'NS_ATTENDANCE_SELF_ONLY'; end if;
 select * into p from public.ns_attendance_policies where org_id=new.org_id and site_id=new.site_id and event_type=new.event_type;
 if new.event_type in ('staff_clock_in','staff_clock_out') and exists(select 1 from public.ns_organizations where id=new.org_id and business_mode in ('single_site_multi_workstation','multi_site_network')) then p.require_gps:=true; end if;
 select * into e from public.ns_attendance_evidence where event_id=new.id;
 if coalesce(p.require_gps,false) or coalesce(p.require_selfie,false) or e.event_id is not null then
  if e.event_id is null or (e.org_id,e.site_id,e.member_id,e.event_type,e.policy_revision,e.required_gps,e.required_selfie) is distinct from (new.org_id,new.site_id,new.staff_member_id,new.event_type,coalesce(p.revision,0),coalesce(p.require_gps,false),coalesce(p.require_selfie,false)) then raise exception 'NS_ATTENDANCE_EVIDENCE_REQUIRED'; end if;
 end if; return new;
end $$;

create or replace function public.ns_record_staff_time_with_evidence(p_event_id uuid,p_org_id uuid,p_site_id uuid,p_workstation_id uuid,p_event_type text,p_occurred_at timestamptz,p_policy_revision bigint,p_latitude double precision,p_longitude double precision,p_accuracy_m double precision,p_gps_captured_at timestamptz,p_selfie_captured_at timestamptz)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare m uuid; n text; p public.ns_attendance_policies%rowtype; path text; existing public.ns_staff_time_events%rowtype;
begin
 m:=public.ns_current_member_id(p_org_id);
 if m is null or not public.ns_can_operate_site(p_org_id,p_site_id) then raise exception 'NS_ATTENDANCE_FORBIDDEN'; end if;
 select display_name into n from public.ns_members where id=m and org_id=p_org_id;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_event_id::text,0));
 select * into existing from public.ns_staff_time_events where id=p_event_id;
 if found then
  if (existing.org_id,existing.site_id,existing.staff_member_id,existing.event_type,existing.occurred_at,existing.workstation_id) is distinct from (p_org_id,p_site_id,m,p_event_type,p_occurred_at,p_workstation_id) then raise exception 'NS_ATTENDANCE_EVENT_CONFLICT'; end if;
  return jsonb_build_object('time_event_id',p_event_id,'recorded',true,'duplicate',true);
 end if;
 select * into p from public.ns_attendance_policies where org_id=p_org_id and site_id=p_site_id and event_type=p_event_type;
 if p_event_type in ('staff_clock_in','staff_clock_out') and exists(select 1 from public.ns_organizations where id=p_org_id and business_mode in ('single_site_multi_workstation','multi_site_network')) then p.require_gps:=true; end if;
 if p_policy_revision is distinct from coalesce(p.revision,0) then raise exception 'NS_ATTENDANCE_POLICY_CHANGED'; end if;
 if p_occurred_at is null or p_occurred_at > clock_timestamp()+interval '1 minute' or p_occurred_at < clock_timestamp()-interval '5 minutes' then raise exception 'NS_ATTENDANCE_TIME_INVALID'; end if;
 if coalesce(p.require_gps,false) and (p_latitude is null or p_longitude is null or p_accuracy_m is null or p_gps_captured_at is null) then raise exception 'NS_ATTENDANCE_GPS_REQUIRED'; end if;
 if p_gps_captured_at is not null and abs(extract(epoch from p_gps_captured_at-p_occurred_at))>120 then raise exception 'NS_ATTENDANCE_GPS_STALE'; end if;
 if coalesce(p.require_selfie,false) and p_selfie_captured_at is null then raise exception 'NS_ATTENDANCE_SELFIE_REQUIRED'; end if;
 if p_selfie_captured_at is not null then
  if abs(extract(epoch from p_selfie_captured_at-p_occurred_at))>120 then raise exception 'NS_ATTENDANCE_SELFIE_STALE'; end if;
  path:=p_org_id::text||'/'||p_site_id::text||'/'||m::text||'/'||p_event_id::text||'.jpg';
  if not exists(select 1 from storage.objects o where o.bucket_id='ns-attendance-selfies' and o.name=path and o.owner_id=auth.uid()::text and o.created_at>=p_occurred_at-interval '2 minutes' and o.metadata->>'mimetype'='image/jpeg') then raise exception 'NS_ATTENDANCE_SELFIE_MISSING'; end if;
 end if;
 insert into public.ns_attendance_evidence(event_id,org_id,site_id,member_id,event_type,policy_revision,required_gps,required_selfie,latitude,longitude,accuracy_m,gps_captured_at,selfie_path,selfie_captured_at)
 values(p_event_id,p_org_id,p_site_id,m,p_event_type,coalesce(p.revision,0),coalesce(p.require_gps,false),coalesce(p.require_selfie,false),p_latitude,p_longitude,p_accuracy_m,p_gps_captured_at,path,p_selfie_captured_at);
 return public.ns_record_staff_time_event(p_event_id,p_org_id,p_site_id,p_workstation_id,m,n,p_event_type,p_occurred_at);
end $$;

create or replace function public.ns_stage_attendance_proof(p_event_id uuid,p_org uuid,p_site uuid,p_post uuid,p_event text,p_occurred timestamptz,p_revision bigint,p_latitude double precision,p_longitude double precision,p_accuracy double precision,p_gps_at timestamptz,p_selfie_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare m uuid:=public.ns_current_member_id(p_org); p public.ns_attendance_policies%rowtype; s public.ns_attendance_staged_proof%rowtype; path text;
begin
 if m is null or not public.ns_can_operate_site(p_org,p_site) or not exists(select 1 from public.ns_organizations where id=p_org and business_mode in ('single_site_multi_workstation','multi_site_network')) or p_event_id is null or p_event is null or p_event not in ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out') then raise exception 'NS_PROOF_FORBIDDEN';end if;
 if p_post is not null and not public.ns_can_operate_workstation(p_org,p_site,p_post) then raise exception 'NS_PROOF_FORBIDDEN';end if;
 if p_occurred is null or p_occurred>clock_timestamp()+interval '1 minute' or p_occurred<clock_timestamp()-interval '5 minutes' then raise exception 'NS_PROOF_TIME_INVALID';end if;
 select * into p from public.ns_attendance_policies where org_id=p_org and site_id=p_site and event_type=p_event;
 if p_event in ('staff_clock_in','staff_clock_out') then p.require_gps:=true; end if;
 if p_revision is distinct from coalesce(p.revision,0) then raise exception 'NS_ATTENDANCE_POLICY_CHANGED';end if;
 if coalesce(p.require_gps,false) and (p_latitude is null or p_longitude is null or p_accuracy is null or p_gps_at is null) then raise exception 'NS_ATTENDANCE_GPS_REQUIRED';end if;
 if coalesce(p.require_selfie,false) and p_selfie_at is null then raise exception 'NS_ATTENDANCE_SELFIE_REQUIRED';end if;
 if (p_gps_at is not null and abs(extract(epoch from p_gps_at-p_occurred))>120) or (p_selfie_at is not null and abs(extract(epoch from p_selfie_at-p_occurred))>120) then raise exception 'NS_PROOF_STALE';end if;
 if p_selfie_at is not null then
  path:=p_org::text||'/'||p_site::text||'/'||m::text||'/'||p_event_id::text||'.jpg';
  if not exists(select 1 from storage.objects o where o.bucket_id='ns-attendance-selfies' and o.name=path and o.owner_id=auth.uid()::text and o.created_at>=p_occurred-interval '2 minutes' and o.metadata->>'mimetype'='image/jpeg') then raise exception 'NS_ATTENDANCE_SELFIE_MISSING';end if;
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_event_id::text,0));
 if exists(select 1 from public.ns_staff_time_events where id=p_event_id) then raise exception 'NS_PROOF_ALREADY_USED';end if;
 select * into s from public.ns_attendance_staged_proof where event_id=p_event_id;
 if found then
  if (s.org_id,s.site_id,s.member_id,s.workstation_id,s.event_type,s.occurred_at,s.policy_revision,s.latitude,s.longitude,s.accuracy_m,s.gps_captured_at,s.selfie_captured_at) is distinct from (p_org,p_site,m,p_post,p_event,p_occurred,p_revision,p_latitude,p_longitude,p_accuracy,p_gps_at,p_selfie_at) or s.expires_at<clock_timestamp() then raise exception 'NS_PROOF_CONFLICT';end if;
 else
  insert into public.ns_attendance_staged_proof(event_id,org_id,site_id,member_id,workstation_id,event_type,occurred_at,policy_revision,latitude,longitude,accuracy_m,gps_captured_at,selfie_captured_at,expires_at)
  values(p_event_id,p_org,p_site,m,p_post,p_event,p_occurred,p_revision,p_latitude,p_longitude,p_accuracy,p_gps_at,p_selfie_at,least(p_occurred+interval '5 minutes',clock_timestamp()+interval '5 minutes'));
 end if;
 return jsonb_build_object('proof_ref',p_event_id,'staged',true);
end $f$;

create or replace function public.ns_set_attendance_policy(p_org uuid,p_site uuid,p_event text,p_revision bigint,p_gps boolean,p_selfie boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m uuid:=public.ns_current_member_id(p_org); p public.ns_attendance_policies%rowtype;
begin
 if m is null or not public.ns_can_manage_site(p_org,p_site) or not exists(select 1 from public.ns_organizations where id=p_org and business_mode in ('single_site_multi_workstation','multi_site_network')) or p_event is null or p_event not in ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out') or p_gps is null or p_selfie is null then raise exception 'NS_POLICY_FORBIDDEN';end if;
 if p_event in ('staff_clock_in','staff_clock_out') and not p_gps then raise exception 'NS_ATTENDANCE_GPS_MANDATORY';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org::text||':'||p_site::text||':'||p_event,0));
 select * into p from public.ns_attendance_policies where org_id=p_org and site_id=p_site and event_type=p_event;
 if p_revision is distinct from coalesce(p.revision,0) then raise exception 'NS_ATTENDANCE_POLICY_CHANGED';end if;
 insert into public.ns_attendance_policies(org_id,site_id,event_type,require_gps,require_selfie,updated_by) values(p_org,p_site,p_event,p_gps,p_selfie,m)
 on conflict(org_id,site_id,event_type) do update set require_gps=excluded.require_gps,require_selfie=excluded.require_selfie,updated_by=excluded.updated_by returning * into p;
 return jsonb_build_object('revision',p.revision,'require_gps',p.require_gps,'require_selfie',p.require_selfie);
end $f$;
rollback;
