-- Combined candidate test on disposable DB. No permanent writes.
begin;
-- Candidate: manager policy and immutable proof, isolated until clients and sync are qualified.
create table public.ns_attendance_policies (
 org_id uuid not null, site_id uuid not null, event_type text not null check(event_type in ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out')),
 require_gps boolean not null default false, require_selfie boolean not null default false,
 revision bigint not null default 1, updated_at timestamptz not null default now(), updated_by uuid not null,
 primary key(org_id,site_id,event_type), foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(updated_by,org_id) references public.ns_members(id,org_id));
alter table public.ns_attendance_policies enable row level security;
revoke all on public.ns_attendance_policies from public,anon,authenticated;
grant select,insert,update on public.ns_attendance_policies to authenticated;
create policy ns_attendance_policy_read on public.ns_attendance_policies for select to authenticated using(public.ns_can_access_site(org_id,site_id));
create policy ns_attendance_policy_create on public.ns_attendance_policies for insert to authenticated with check(public.ns_can_manage_site(org_id,site_id) and updated_by=public.ns_current_member_id(org_id));
create policy ns_attendance_policy_update on public.ns_attendance_policies for update to authenticated using(public.ns_can_manage_site(org_id,site_id)) with check(public.ns_can_manage_site(org_id,site_id) and updated_by=public.ns_current_member_id(org_id));
create function public.ns_attendance_policy_version() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' then
  if (new.org_id,new.site_id,new.event_type) is distinct from (old.org_id,old.site_id,old.event_type) then raise exception 'NS_ATTENDANCE_POLICY_IMMUTABLE_KEY'; end if;
  new.revision:=old.revision+1;
 else new.revision:=1; end if;
 new.updated_at:=clock_timestamp(); return new;
end $$;
revoke all on function public.ns_attendance_policy_version() from public,anon,authenticated;
do $acl$ begin
 if has_function_privilege('anon','public.ns_attendance_policy_version()','EXECUTE') or has_function_privilege('authenticated','public.ns_attendance_policy_version()','EXECUTE') then raise exception 'NS_ATTENDANCE_INTERNAL_TRIGGER_EXPOSED'; end if;
end $acl$;
create trigger ns_attendance_policy_version before insert or update on public.ns_attendance_policies for each row execute function public.ns_attendance_policy_version();
create table public.ns_attendance_evidence (
 event_id uuid primary key references public.ns_staff_time_events(id) deferrable initially deferred,
 org_id uuid not null, site_id uuid not null, member_id uuid not null, event_type text not null,
 policy_revision bigint not null, required_gps boolean not null, required_selfie boolean not null,
 latitude double precision, longitude double precision, accuracy_m double precision, gps_captured_at timestamptz,
 selfie_path text unique, selfie_captured_at timestamptz, received_at timestamptz not null default clock_timestamp(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id), foreign key(member_id,org_id) references public.ns_members(id,org_id),
 check ((latitude is null and longitude is null and accuracy_m is null and gps_captured_at is null) or (latitude is not null and longitude is not null and accuracy_m is not null and gps_captured_at is not null and latitude between -90 and 90 and longitude between -180 and 180 and accuracy_m > 0 and accuracy_m <= 500)),
 check ((selfie_path is null)=(selfie_captured_at is null)), check(not required_gps or latitude is not null), check(not required_selfie or selfie_path is not null));
alter table public.ns_attendance_evidence enable row level security;
revoke all on public.ns_attendance_evidence from public,anon,authenticated;
grant select on public.ns_attendance_evidence to authenticated;
create policy ns_attendance_evidence_read on public.ns_attendance_evidence for select to authenticated using(public.ns_can_access_site(org_id,site_id) and (member_id=public.ns_current_member_id(org_id) or public.ns_can_manage_site(org_id,site_id)));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ns-attendance-selfies','ns-attendance-selfies',false,2097152,array['image/jpeg']);
create function public.ns_attendance_selfie_upload_allowed(p_name text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.ns_members m join public.ns_sites s on s.org_id=m.org_id where m.id=public.ns_current_member_id(m.org_id) and public.ns_can_operate_site(m.org_id,s.id)
 and p_name ~ ('^'||m.org_id::text||'/'||s.id::text||'/'||m.id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$')
 and not exists(select 1 from public.ns_attendance_evidence e where e.selfie_path=p_name))
$$;
create function public.ns_attendance_selfie_read_allowed(p_name text) returns boolean language sql stable security invoker set search_path='' as $$ select exists(select 1 from public.ns_attendance_evidence e where e.selfie_path=p_name) $$;
revoke all on function public.ns_attendance_selfie_upload_allowed(text),public.ns_attendance_selfie_read_allowed(text) from public,anon,authenticated;
grant execute on function public.ns_attendance_selfie_upload_allowed(text),public.ns_attendance_selfie_read_allowed(text) to authenticated;
create policy ns_attendance_selfie_insert on storage.objects for insert to authenticated with check(bucket_id='ns-attendance-selfies' and public.ns_attendance_selfie_upload_allowed(name));
create policy ns_attendance_selfie_read on storage.objects for select to authenticated using(bucket_id='ns-attendance-selfies' and public.ns_attendance_selfie_read_allowed(name));
create policy ns_attendance_selfie_insert_guard on storage.objects as restrictive for insert to authenticated with check(bucket_id<>'ns-attendance-selfies' or public.ns_attendance_selfie_upload_allowed(name));
create policy ns_attendance_selfie_read_guard on storage.objects as restrictive for select to authenticated using(bucket_id<>'ns-attendance-selfies' or public.ns_attendance_selfie_read_allowed(name));
create policy ns_attendance_selfie_update_guard on storage.objects as restrictive for update to authenticated using(bucket_id<>'ns-attendance-selfies') with check(bucket_id<>'ns-attendance-selfies');
create policy ns_attendance_selfie_delete_guard on storage.objects as restrictive for delete to authenticated using(bucket_id<>'ns-attendance-selfies');
create policy ns_attendance_selfie_anon_guard on storage.objects as restrictive for all to anon using(bucket_id<>'ns-attendance-selfies') with check(bucket_id<>'ns-attendance-selfies');
create function public.ns_attendance_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare p public.ns_attendance_policies%rowtype; e public.ns_attendance_evidence%rowtype;
begin
 if new.actor_member_id is distinct from new.staff_member_id or new.actor_member_id is distinct from public.ns_current_member_id(new.org_id) then raise exception 'NS_ATTENDANCE_SELF_ONLY'; end if;
 select * into p from public.ns_attendance_policies where org_id=new.org_id and site_id=new.site_id and event_type=new.event_type;
 select * into e from public.ns_attendance_evidence where event_id=new.id;
 if coalesce(p.require_gps,false) or coalesce(p.require_selfie,false) or e.event_id is not null then
  if e.event_id is null or (e.org_id,e.site_id,e.member_id,e.event_type,e.policy_revision,e.required_gps,e.required_selfie) is distinct from (new.org_id,new.site_id,new.staff_member_id,new.event_type,coalesce(p.revision,0),coalesce(p.require_gps,false),coalesce(p.require_selfie,false)) then raise exception 'NS_ATTENDANCE_EVIDENCE_REQUIRED'; end if;
 end if; return new;
end $$;
revoke all on function public.ns_attendance_guard() from public,anon,authenticated;
create trigger ns_attendance_guard before insert on public.ns_staff_time_events for each row execute function public.ns_attendance_guard();
drop policy ns_staff_time_events_select on public.ns_staff_time_events;
create policy ns_staff_time_events_select on public.ns_staff_time_events for select to authenticated using(public.ns_can_access_site(org_id,site_id) and (staff_member_id=public.ns_current_member_id(org_id) or public.ns_can_manage_site(org_id,site_id)));
create function public.ns_record_staff_time_with_evidence(p_event_id uuid,p_org_id uuid,p_site_id uuid,p_workstation_id uuid,p_event_type text,p_occurred_at timestamptz,p_policy_revision bigint,p_latitude double precision,p_longitude double precision,p_accuracy_m double precision,p_gps_captured_at timestamptz,p_selfie_captured_at timestamptz)
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
revoke all on function public.ns_record_staff_time_with_evidence(uuid,uuid,uuid,uuid,text,timestamptz,bigint,double precision,double precision,double precision,timestamptz,timestamptz) from public,anon,authenticated;
grant execute on function public.ns_record_staff_time_with_evidence(uuid,uuid,uuid,uuid,text,timestamptz,bigint,double precision,double precision,double precision,timestamptz,timestamptz) to authenticated;


insert into auth.users(id) values ('10000000-0000-4000-8000-000000000091'),('10000000-0000-4000-8000-000000000092');
insert into public.ns_organizations(id,display_name,business_mode) values ('20000000-0000-4000-8000-000000000091','QA Attendance','multi_site_network');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000091','10000000-0000-4000-8000-000000000091','NS-QA91','qa91@example.invalid',false),('50000000-0000-4000-8000-000000000092','10000000-0000-4000-8000-000000000092','NS-QA92','qa92@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000091','QA Manager','site_manager'),('60000000-0000-4000-8000-000000000092','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000092','QA Staff','cashier');
insert into public.ns_sites(id,org_id,code,name) values ('30000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','QA91','QA Site');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000091','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,true),('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000092','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,false);
insert into public.ns_devices(account_id,installation_id,platform,label,session_id) values ('50000000-0000-4000-8000-000000000091','qa-91','web','QA','qa-91-session'),('50000000-0000-4000-8000-000000000092','qa-92','web','QA','qa-92-session');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
insert into public.ns_attendance_policies(org_id,site_id,event_type,require_gps,require_selfie,updated_by) values ('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091','staff_clock_in',true,false,'60000000-0000-4000-8000-000000000091'),('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091','staff_clock_out',false,true,'60000000-0000-4000-8000-000000000091');
reset role;
do $$ begin begin
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'60000000-0000-4000-8000-000000000092','QA Staff','staff_clock_in',now());
 raise exception 'QA IMPERSONATION ACCEPTED';
 exception when others then if sqlerrm not like '%NS_ATTENDANCE_SELF_ONLY%' then raise; end if; end; end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
do $$ begin begin
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000092','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'60000000-0000-4000-8000-000000000092','QA Staff','staff_clock_in',now());
 raise exception 'QA LEGACY BYPASS';
 exception when others then if sqlerrm not like '%NS_ATTENDANCE_EVIDENCE_REQUIRED%' then raise; end if; end; end $$;
set local role authenticated;
do $$ declare c integer; org uuid:='20000000-0000-4000-8000-000000000091'; site uuid:='30000000-0000-4000-8000-000000000091'; member uuid:='60000000-0000-4000-8000-000000000092'; eid uuid:='70000000-0000-4000-8000-000000000092'; outid uuid:='70000000-0000-4000-8000-000000000093'; t timestamptz:=now(); v jsonb;
begin
 update public.ns_attendance_policies set require_gps=false,updated_by=member where org_id=org and site_id=site and event_type='staff_clock_in';
 get diagnostics c=row_count; if c<>0 then raise exception 'QA STAFF CHANGED POLICY'; end if;
 begin perform public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,null,null,null,null,null); raise exception 'QA MISSING GPS ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_GPS_REQUIRED%' then raise; end if; end;
 begin perform public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,0,4.1,9.7,15,t,null); raise exception 'QA OLD POLICY ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_POLICY_CHANGED%' then raise; end if; end;
 begin perform public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,120,9.7,15,t,null); raise exception 'QA INVALID GPS ACCEPTED'; exception when check_violation then null; end;
 v:=public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,4.1,9.7,15,t,null);
 if v->>'recorded' is distinct from 'true' then raise exception 'QA GPS NOT RECORDED'; end if;
 if not exists(select 1 from public.ns_attendance_evidence where event_id=eid and required_gps and latitude=4.1) then raise exception 'QA GPS NOT STORED'; end if;
 v:=public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,4.1,9.7,15,t,null);
 if v->>'duplicate' is distinct from 'true' then raise exception 'QA RETRY NOT IDEMPOTENT'; end if;
 begin perform public.ns_record_staff_time_with_evidence(outid,org,site,null,'staff_clock_out',t,1,null,null,null,null,null); raise exception 'QA MISSING SELFIE ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_SELFIE_REQUIRED%' then raise; end if; end;
 begin perform public.ns_record_staff_time_with_evidence(outid,org,site,null,'staff_clock_out',t,1,null,null,null,null,t); raise exception 'QA MISSING OBJECT ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_SELFIE_MISSING%' then raise; end if; end;
end $$;
reset role;
set constraints all immediate;

-- Candidate follow-on: four canonical operations use the existing atomic sync.
create function public.ns_record_attendance_sync(p_org uuid,p_site uuid,p_event_type text,p_payload jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare e jsonb:=p_payload->'attendance_evidence';
begin
 if (p_payload->>'staff_member_id')::uuid is distinct from public.ns_current_member_id(p_org) then raise exception 'NS_ATTENDANCE_SELF_ONLY'; end if;
 if e is null then
  return public.ns_record_staff_time_event((p_payload->>'time_event_id')::uuid,p_org,p_site,nullif(p_payload->>'workstation_id','')::uuid,(p_payload->>'staff_member_id')::uuid,p_payload->>'staff_name_snapshot',p_event_type,(p_payload->>'occurred_at')::timestamptz);
 end if;
 if jsonb_typeof(e)<>'object' then raise exception 'NS_ATTENDANCE_EVIDENCE_INVALID'; end if;
 return public.ns_record_staff_time_with_evidence((p_payload->>'time_event_id')::uuid,p_org,p_site,nullif(p_payload->>'workstation_id','')::uuid,p_event_type,(p_payload->>'occurred_at')::timestamptz,(e->>'policy_revision')::bigint,(e->>'latitude')::double precision,(e->>'longitude')::double precision,(e->>'accuracy_m')::double precision,(e->>'gps_captured_at')::timestamptz,(e->>'selfie_captured_at')::timestamptz);
end $$;
revoke all on function public.ns_record_attendance_sync(uuid,uuid,text,jsonb) from public,anon,authenticated;
do $patch$ declare d text; old text; event text; projection text:='public.ns_sync_redact_payload(p_payload || jsonb_build_object(''actor_member_id'', v_member_id, ''server_result'', coalesce(v_result, ''{}''::jsonb)))';
begin
 select pg_get_functiondef('public.ns_apply_sync_event(uuid,uuid,uuid,uuid,uuid,bigint,text,text,text,jsonb)'::regprocedure) into d;
 foreach event in array array['staff_clock_in','staff_break_start','staff_break_end','staff_clock_out'] loop
 old:=format($fmt$v_result := public.ns_record_staff_time_event(
        (p_payload->>'time_event_id')::uuid,p_org_id,p_site_id,
        nullif(p_payload->>'workstation_id','')::uuid,(p_payload->>'staff_member_id')::uuid,
        p_payload->>'staff_name_snapshot',%L,(p_payload->>'occurred_at')::timestamptz
      );$fmt$,event);
 if strpos(d,old)=0 then raise exception 'NS_ATTENDANCE_SYNC_PATCH_DRIFT: %',event; end if;
 d:=replace(d,old,format('v_result := public.ns_record_attendance_sync(p_org_id,p_site_id,%L,p_payload);',event));
 end loop;
 if strpos(d,projection)=0 then raise exception 'NS_ATTENDANCE_PROJECTION_PATCH_DRIFT'; end if;
 d:=replace(d,projection,$projection$case when p_action_code in ('staff_clock_in.recorded','staff_break_start.recorded','staff_break_end.recorded','staff_clock_out.recorded') then jsonb_build_object('time_event_id',p_payload->>'time_event_id','staff_member_id',v_member_id,'staff_name_snapshot',p_payload->>'staff_name_snapshot','occurred_at',p_payload->>'occurred_at','workstation_id',p_payload->>'workstation_id','org_id',p_org_id,'site_id',p_site_id,'actor_member_id',v_member_id,'server_result',v_result) else $projection$||projection||' end');
 execute d;
 select pg_get_functiondef('public.ns_pull_sync_changes(uuid,uuid,bigint,integer)'::regprocedure) into d;
 old:='and c.source_device_id <> p_device_id';
 if strpos(d,old)=0 then raise exception 'NS_ATTENDANCE_PULL_PATCH_DRIFT'; end if;
 d:=replace(d,old,old||$filter$
    and (c.action_code not in ('staff_clock_in.recorded','staff_break_start.recorded','staff_break_end.recorded','staff_clock_out.recorded')
      or c.projection_json->>'staff_member_id'=v_member_id::text
      or public.ns_can_manage_site(p_org_id,c.site_id))$filter$);
 execute d;
end $patch$;
revoke execute on function public.ns_record_staff_time_with_evidence(uuid,uuid,uuid,uuid,text,timestamptz,bigint,double precision,double precision,double precision,timestamptz,timestamptz) from authenticated;

-- Canonical sync with device id resolved before assuming the authenticated role.
set constraints all deferred;
select set_config('qa.attendance_device',(select id::text from public.ns_devices where session_id='qa-92-session'),true);
set local role authenticated;
do $$ declare o uuid:='20000000-0000-4000-8000-000000000091'; s uuid:='30000000-0000-4000-8000-000000000091'; m uuid:='60000000-0000-4000-8000-000000000092'; d uuid:=current_setting('qa.attendance_device')::uuid; e uuid:='70000000-0000-4000-8000-000000000094'; v jsonb; t timestamptz:=now();
begin
 v:=public.ns_apply_sync_event(o,s,null,d,e,1,'staff_break_start',e::text,'staff_break_start.recorded',jsonb_build_object('org_id',o,'site_id',s,'time_event_id',e,'staff_member_id',m,'staff_name_snapshot','QA Staff','occurred_at',t,'attendance_evidence',jsonb_build_object('policy_revision',0,'latitude',4.1,'longitude',9.7,'accuracy_m',15,'gps_captured_at',t)));
 if v->>'status' is distinct from 'applied' then raise exception 'QA SYNC NOT APPLIED'; end if;
 if not exists(select 1 from public.ns_attendance_evidence where event_id=e and latitude=4.1) then raise exception 'QA SYNC GPS NOT RECORDED'; end if;
end $$;
reset role;
set constraints all immediate;
do $$ begin
 if exists(select 1 from public.ns_sync_changes where aggregate_id='70000000-0000-4000-8000-000000000094' and (projection_json ? 'attendance_evidence' or projection_json ? 'latitude' or projection_json ? 'selfie_path')) then raise exception 'QA PROOF LEAK TO SYNC'; end if;
 if not exists(select 1 from public.ns_sync_changes where aggregate_id='70000000-0000-4000-8000-000000000094') then raise exception 'QA SYNC PROJECTION MISSING'; end if;
end $$;

rollback;
select 'PASS: 11 candidate assertions plus atomic sync, private projection and receipt' as result;
