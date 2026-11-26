begin;
-- v15 candidate: private temporary proof staging; durable sync contains only the reference.
create table public.ns_attendance_staged_proof(
 event_id uuid primary key,org_id uuid not null,site_id uuid not null,member_id uuid not null,workstation_id uuid,
 event_type text not null check(event_type in ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out')),
 occurred_at timestamptz not null,policy_revision bigint not null,latitude double precision,longitude double precision,
 accuracy_m double precision,gps_captured_at timestamptz,selfie_captured_at timestamptz,
 expires_at timestamptz not null default (clock_timestamp()+interval '5 minutes'),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 check((latitude is null and longitude is null and accuracy_m is null and gps_captured_at is null) or
 (latitude is not null and longitude is not null and accuracy_m is not null and gps_captured_at is not null and latitude between -90 and 90 and longitude between -180 and 180 and accuracy_m>0 and accuracy_m<=500)));
alter table public.ns_attendance_staged_proof enable row level security;
revoke all on public.ns_attendance_staged_proof from public,anon,authenticated;
create function public.ns_stage_attendance_proof(p_event_id uuid,p_org uuid,p_site uuid,p_post uuid,p_event text,p_occurred timestamptz,p_revision bigint,p_latitude double precision,p_longitude double precision,p_accuracy double precision,p_gps_at timestamptz,p_selfie_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare m uuid:=public.ns_current_member_id(p_org); p public.ns_attendance_policies%rowtype; s public.ns_attendance_staged_proof%rowtype; path text;
begin
 if m is null or not public.ns_can_operate_site(p_org,p_site) or not exists(select 1 from public.ns_organizations where id=p_org and business_mode in ('single_site_multi_workstation','multi_site_network')) or p_event_id is null or p_event is null or p_event not in ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out') then raise exception 'NS_PROOF_FORBIDDEN';end if;
 if p_post is not null and not public.ns_can_operate_workstation(p_org,p_site,p_post) then raise exception 'NS_PROOF_FORBIDDEN';end if;
 if p_occurred is null or p_occurred>clock_timestamp()+interval '1 minute' or p_occurred<clock_timestamp()-interval '5 minutes' then raise exception 'NS_PROOF_TIME_INVALID';end if;
 select * into p from public.ns_attendance_policies where org_id=p_org and site_id=p_site and event_type=p_event;
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
revoke all on function public.ns_stage_attendance_proof(uuid,uuid,uuid,uuid,text,timestamptz,bigint,double precision,double precision,double precision,timestamptz,timestamptz) from public,anon,authenticated;
grant execute on function public.ns_stage_attendance_proof(uuid,uuid,uuid,uuid,text,timestamptz,bigint,double precision,double precision,double precision,timestamptz,timestamptz) to authenticated;
create or replace function public.ns_record_attendance_sync(p_org uuid,p_site uuid,p_event_type text,p_payload jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $f$
declare s public.ns_attendance_staged_proof%rowtype; m uuid:=public.ns_current_member_id(p_org); eid uuid:=(p_payload->>'time_event_id')::uuid; v jsonb;
begin
 if (p_payload->>'staff_member_id')::uuid is distinct from m then raise exception 'NS_ATTENDANCE_SELF_ONLY';end if;
 if p_payload ? 'attendance_evidence' or p_payload ? 'latitude' or p_payload ? 'longitude' or p_payload ? 'selfie_path' then raise exception 'NS_RAW_PROOF_FORBIDDEN';end if;
 if not (p_payload ? 'attendance_proof_ref') then
  return public.ns_record_staff_time_event(eid,p_org,p_site,nullif(p_payload->>'workstation_id','')::uuid,m,p_payload->>'staff_name_snapshot',p_event_type,(p_payload->>'occurred_at')::timestamptz);
 end if;
 if (p_payload->>'attendance_proof_ref')::uuid is distinct from eid then raise exception 'NS_PROOF_CONFLICT';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(eid::text,0));
 select * into s from public.ns_attendance_staged_proof where event_id=eid for update;
 if not found or s.expires_at<clock_timestamp() or (s.org_id,s.site_id,s.member_id,s.workstation_id,s.event_type,s.occurred_at) is distinct from (p_org,p_site,m,nullif(p_payload->>'workstation_id','')::uuid,p_event_type,(p_payload->>'occurred_at')::timestamptz) then raise exception 'NS_PROOF_EXPIRED_OR_FORBIDDEN';end if;
 v:=public.ns_record_staff_time_with_evidence(eid,p_org,p_site,s.workstation_id,p_event_type,s.occurred_at,s.policy_revision,s.latitude,s.longitude,s.accuracy_m,s.gps_captured_at,s.selfie_captured_at);
 delete from public.ns_attendance_staged_proof where event_id=eid;
 return v;
end $f$;
-- Policy history and fail-closed UI changes use compare-and-set.
create table public.ns_attendance_policy_history(
 org_id uuid not null,site_id uuid not null,event_type text not null,revision bigint not null,
 require_gps boolean not null,require_selfie boolean not null,changed_by uuid not null,changed_at timestamptz not null,
 primary key(org_id,site_id,event_type,revision));
alter table public.ns_attendance_policy_history enable row level security;
revoke all on public.ns_attendance_policy_history from public,anon,authenticated;
grant select on public.ns_attendance_policy_history to authenticated;
create policy ns_attendance_history_read on public.ns_attendance_policy_history for select to authenticated using(public.ns_can_manage_site(org_id,site_id));
create function public.ns_attendance_history_trigger() returns trigger language plpgsql security definer set search_path='' as $f$
begin insert into public.ns_attendance_policy_history values(new.org_id,new.site_id,new.event_type,new.revision,new.require_gps,new.require_selfie,new.updated_by,new.updated_at);return new;end $f$;
revoke all on function public.ns_attendance_history_trigger() from public,anon,authenticated;
create trigger ns_attendance_history after insert or update on public.ns_attendance_policies for each row execute function public.ns_attendance_history_trigger();
create function public.ns_set_attendance_policy(p_org uuid,p_site uuid,p_event text,p_revision bigint,p_gps boolean,p_selfie boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m uuid:=public.ns_current_member_id(p_org); p public.ns_attendance_policies%rowtype;
begin
 if m is null or not public.ns_can_manage_site(p_org,p_site) or not exists(select 1 from public.ns_organizations where id=p_org and business_mode in ('single_site_multi_workstation','multi_site_network')) or p_event is null or p_event not in ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out') or p_gps is null or p_selfie is null then raise exception 'NS_POLICY_FORBIDDEN';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org::text||':'||p_site::text||':'||p_event,0));
 select * into p from public.ns_attendance_policies where org_id=p_org and site_id=p_site and event_type=p_event;
 if p_revision is distinct from coalesce(p.revision,0) then raise exception 'NS_ATTENDANCE_POLICY_CHANGED';end if;
 insert into public.ns_attendance_policies(org_id,site_id,event_type,require_gps,require_selfie,updated_by) values(p_org,p_site,p_event,p_gps,p_selfie,m)
 on conflict(org_id,site_id,event_type) do update set require_gps=excluded.require_gps,require_selfie=excluded.require_selfie,updated_by=excluded.updated_by returning * into p;
 return jsonb_build_object('revision',p.revision,'require_gps',p.require_gps,'require_selfie',p.require_selfie);
end $f$;
revoke all on function public.ns_set_attendance_policy(uuid,uuid,text,bigint,boolean,boolean) from public,anon,authenticated;
grant execute on function public.ns_set_attendance_policy(uuid,uuid,text,bigint,boolean,boolean) to authenticated;
revoke insert,update on public.ns_attendance_policies from authenticated;
-- Cleanup of expired staging and unlinked Storage objects is a separate server worker gate.

rollback;
