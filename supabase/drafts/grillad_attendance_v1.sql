-- Candidate: private attendance proof, no continuous tracking, no production activation.
begin;
create table grillad_private.attendance_policy(
 org uuid not null,site uuid not null,enabled boolean not null default false,
 latitude double precision not null check(latitude between -90 and 90),longitude double precision not null check(longitude between -180 and 180),
 radius_m integer not null check(radius_m between 1 and 10000),max_accuracy_m integer not null check(max_accuracy_m between 1 and 1000),
 max_age_seconds integer not null check(max_age_seconds between 30 and 300),photo_retention_days integer not null check(photo_retention_days between 1 and 365),
 primary key(org,site),foreign key(org,site) references grillad_private.enabled_sites(org,site)
);
create table grillad_private.attendance(
 id uuid primary key,org uuid not null,site uuid not null,actor uuid not null,
 kind text not null check(kind in ('arrival','departure','departure_without_arrival')),captured_at timestamptz not null,received_at timestamptz not null default now(),
 latitude double precision not null,longitude double precision not null,accuracy double precision not null,
 photo bytea,photo_hash text not null,photo_until timestamptz not null,paired_arrival uuid references grillad_private.attendance(id),
 foreign key(org,site) references grillad_private.enabled_sites(org,site),
 check((kind='departure')=(paired_arrival is not null))
);
-- Approved regularization is distinct from captured evidence; no synthetic GPS or photo.
create table grillad_private.attendance_corrections(
 id uuid primary key,org uuid not null,site uuid not null,departure uuid not null references grillad_private.attendance(id),
 requester uuid not null,proposed_seconds bigint not null check(proposed_seconds>=0),reason text not null check(length(reason) between 1 and 300),
 requested_at timestamptz not null default now(),status text not null default 'pending' check(status in ('pending','approved','rejected')),
 decided_by uuid,decided_at timestamptz,decision_reason text,decision_event uuid,
 foreign key(org,site) references grillad_private.enabled_sites(org,site),
 check((status='pending' and decided_by is null and decided_at is null and decision_reason is null and decision_event is null) or
 (status in ('approved','rejected') and decided_by is not null and decided_by<>requester and decided_at is not null and decision_reason is not null and decision_event is not null))
);
create unique index grillad_pending_attendance_correction on grillad_private.attendance_corrections(departure) where status in ('pending','approved');
alter table grillad_private.attendance_corrections enable row level security;
revoke all on grillad_private.attendance_corrections from public,anon,authenticated;
-- Manual close of a proved arrival; never creates a photographic/GPS departure.
create table grillad_private.missing_departures(
 id uuid primary key,org uuid not null,site uuid not null,arrival uuid not null references grillad_private.attendance(id),
 requester uuid not null,proposed_at timestamptz not null,seconds bigint not null check(seconds>0),reason text not null check(length(reason) between 1 and 300),requested_at timestamptz not null default now(),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),decided_by uuid,decided_at timestamptz,decision_reason text,
 foreign key(org,site) references grillad_private.enabled_sites(org,site),
 check((status='pending' and decided_by is null and decided_at is null and decision_reason is null) or (status<>'pending' and decided_by is not null and decided_by<>requester and decided_at is not null and decision_reason is not null)));
create unique index grillad_missing_departure_one on grillad_private.missing_departures(arrival) where status in ('pending','approved');
alter table grillad_private.missing_departures enable row level security;
revoke all on grillad_private.missing_departures from public,anon,authenticated;
create table grillad_private.missing_arrivals(
 id uuid primary key,org uuid not null,site uuid not null,departure uuid not null references grillad_private.attendance(id),
 requester uuid not null,proposed_at timestamptz not null,seconds bigint not null check(seconds>0),reason text not null check(length(reason) between 1 and 300),requested_at timestamptz not null default now(),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),decided_by uuid,decided_at timestamptz,decision_reason text,
 foreign key(org,site) references grillad_private.enabled_sites(org,site),
 check((status='pending' and decided_by is null and decided_at is null and decision_reason is null) or (status<>'pending' and decided_by is not null and decided_by<>requester and decided_at is not null and decision_reason is not null)));
create unique index grillad_missing_arrival_one on grillad_private.missing_arrivals(departure) where status in ('pending','approved');
alter table grillad_private.missing_arrivals enable row level security;
revoke all on grillad_private.missing_arrivals from public,anon,authenticated;
create unique index grillad_attendance_pair on grillad_private.attendance(paired_arrival) where paired_arrival is not null;
create index grillad_attendance_actor on grillad_private.attendance(org,actor,captured_at desc);
alter table grillad_private.attendance_policy enable row level security;
alter table grillad_private.attendance enable row level security;
revoke all on grillad_private.attendance_policy,grillad_private.attendance from public,anon,authenticated;
create function grillad_private.attendance_status(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;enabled boolean;out jsonb;corrections jsonb;missing jsonb;missing_arrival jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 select p.enabled into enabled from grillad_private.attendance_policy p where org=p_org and site=p_site;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.captured_at desc),'[]'::jsonb) into out from (
 select a.id,a.actor,a.kind,a.captured_at,a.received_at,a.paired_arrival,a.photo is not null and a.photo_until>now() as photo_available,
 (a.kind='arrival' and not exists(select 1 from grillad_private.attendance d where d.paired_arrival=a.id) and not exists(select 1 from grillad_private.missing_departures m where m.arrival=a.id and m.status='approved')) as open_arrival,
 case when a.kind='departure' then extract(epoch from a.captured_at-b.captured_at)::bigint else null end as duration_seconds,
 case when a.kind='departure' then coalesce(c.proposed_seconds,extract(epoch from a.captured_at-b.captured_at)::bigint) else null end as effective_duration_seconds
 from grillad_private.attendance a left join grillad_private.attendance b on b.id=a.paired_arrival left join grillad_private.attendance_corrections c on c.departure=a.id and c.org=a.org and c.site=a.site and c.status='approved'
 where a.org=p_org and a.site=p_site and (r in ('owner','manager') or a.actor=auth.uid()) order by a.captured_at desc limit 100) x;
 select coalesce(jsonb_agg(to_jsonb(c) order by c.requested_at desc),'[]'::jsonb) into corrections from (select id,departure,requester,proposed_seconds,reason,requested_at,status,decided_by,decided_at,decision_reason from grillad_private.attendance_corrections where org=p_org and site=p_site and (r in ('owner','manager') or requester=auth.uid()) order by requested_at desc limit 100)c;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.requested_at desc),'[]'::jsonb) into missing from (select id,arrival,requester,proposed_at,seconds,reason,requested_at,status,decided_by,decided_at,decision_reason from grillad_private.missing_departures where org=p_org and site=p_site and (r in ('owner','manager') or requester=auth.uid()) order by requested_at desc limit 100)m;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.requested_at desc),'[]'::jsonb) into missing_arrival from (select id,departure,requester,proposed_at,seconds,reason,requested_at,status,decided_by,decided_at,decision_reason from grillad_private.missing_arrivals where org=p_org and site=p_site and (r in ('owner','manager') or requester=auth.uid()) order by requested_at desc limit 100)m;
 return jsonb_build_object('enabled',coalesce(enabled,false),'history',out,'corrections',corrections,'missing_departures',missing,'missing_arrivals',missing_arrival);
end $$;
create function grillad_private.attendance_capture(p_org uuid,p_site uuid,p_event uuid,p_kind text,p_at timestamptz,p_lat double precision,p_lon double precision,p_accuracy double precision,p_photo text)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();policy grillad_private.attendance_policy%rowtype;old grillad_private.attendance%rowtype;arrival grillad_private.attendance%rowtype;bytes bytea;h text;distance double precision;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_event is null or p_kind is null or p_kind not in ('arrival','departure','departure_without_arrival') or p_at is null or p_lat is null or p_lon is null or p_accuracy is null or not(p_lat between -90 and 90) or not(p_lon between -180 and 180) or not(p_accuracy>0 and p_accuracy<=1000) or p_photo is null or length(p_photo)>480000 then raise exception 'GRILLAD_PROOF' using errcode='22023';end if;
 bytes:=decode(p_photo,'base64');if octet_length(bytes) not between 16 and 350000 or substring(bytes from 1 for 3)<>decode('ffd8ff','hex') or substring(bytes from octet_length(bytes)-1 for 2)<>decode('ffd9','hex') then raise exception 'GRILLAD_PHOTO' using errcode='22023';end if;
 h:=encode(sha256(bytes),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 r:=grillad_private.scope(p_org,p_site);
 perform pg_advisory_xact_lock(hashtextextended('grillad-attendance:'||p_org::text||':'||u::text,0));
 select * into old from grillad_private.attendance where id=p_event;
 if found then
  if old.org<>p_org or old.site<>p_site or old.actor<>u or old.kind<>p_kind or old.captured_at<>p_at or old.latitude<>p_lat or old.longitude<>p_lon or old.accuracy<>p_accuracy or old.photo_hash<>h then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023';end if;
  return jsonb_build_object('id',old.id,'confirmed',true,'kind',old.kind);
 end if;
 select * into policy from grillad_private.attendance_policy where org=p_org and site=p_site and enabled;
 if not found then raise exception 'GRILLAD_ATTENDANCE_DISABLED' using errcode='42501';end if;
 if p_at>now()+interval '10 seconds' or p_at<now()-make_interval(secs=>policy.max_age_seconds) or p_accuracy>policy.max_accuracy_m then raise exception 'GRILLAD_STALE_OR_IMPRECISE' using errcode='22023';end if;
 distance:=6371000*2*asin(least(1,sqrt(power(sin(radians(p_lat-policy.latitude)/2),2)+cos(radians(policy.latitude))*cos(radians(p_lat))*power(sin(radians(p_lon-policy.longitude)/2),2))));
 if distance+p_accuracy>policy.radius_m then raise exception 'GRILLAD_OUTSIDE_SITE' using errcode='22023';end if;
 if exists(select 1 from grillad_private.attendance where org=p_org and actor=u and photo_hash=h) then raise exception 'GRILLAD_PHOTO_REUSED' using errcode='22023';end if;
 select a.* into arrival from grillad_private.attendance a where a.org=p_org and a.actor=u and a.kind='arrival' and not exists(select 1 from grillad_private.attendance b where b.paired_arrival=a.id) and not exists(select 1 from grillad_private.missing_departures m where m.arrival=a.id and m.status='approved') order by a.captured_at desc limit 1;
 if p_kind='arrival' and (exists(select 1 from grillad_private.attendance d where d.org=p_org and d.actor=u and d.kind in ('departure','departure_without_arrival') and d.captured_at>=p_at) or exists(select 1 from grillad_private.missing_departures m where m.org=p_org and m.requester=u and m.status='approved' and m.proposed_at>=p_at)) then raise exception 'GRILLAD_OVERLAP' using errcode='22023';end if;
 if p_kind='arrival' and arrival.id is not null then raise exception 'GRILLAD_ALREADY_PRESENT' using errcode='22023';end if;
 if p_kind='departure_without_arrival' and (arrival.id is not null or exists(select 1 from grillad_private.attendance d where d.org=p_org and d.actor=u and d.captured_at>=p_at) or exists(select 1 from grillad_private.missing_departures m where m.org=p_org and m.requester=u and m.status='approved' and m.proposed_at>=p_at)) then raise exception 'GRILLAD_OVERLAP' using errcode='22023';end if;
 if p_kind='departure' and (arrival.id is null or arrival.site<>p_site or p_at<=arrival.captured_at) then raise exception 'GRILLAD_NO_ARRIVAL' using errcode='22023';end if;
 insert into grillad_private.attendance(id,org,site,actor,kind,captured_at,latitude,longitude,accuracy,photo,photo_hash,photo_until,paired_arrival)
 values(p_event,p_org,p_site,u,p_kind,p_at,p_lat,p_lon,p_accuracy,bytes,h,now()+make_interval(days=>policy.photo_retention_days),case when p_kind='departure' then arrival.id else null end);
 return jsonb_build_object('id',p_event,'confirmed',true,'kind',p_kind);
end $$;
-- No public direct table access, and no photos or coordinates in routine lists.
create table grillad_private.attendance_photo_access(id bigint generated always as identity primary key,org uuid not null,site uuid not null,proof_id uuid not null references grillad_private.attendance(id),viewer uuid not null,viewed_at timestamptz not null default now(),foreign key(org,site) references grillad_private.enabled_sites(org,site));
alter table grillad_private.attendance_photo_access enable row level security;
revoke all on grillad_private.attendance_photo_access from public,anon,authenticated;
create function grillad_private.attendance_photo(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;proof grillad_private.attendance%rowtype;
begin
 r:=grillad_private.scope(p_org,p_site);
 select * into proof from grillad_private.attendance where id=p_id and org=p_org and site=p_site and photo_until>now() and photo is not null and (r in ('owner','manager') or actor=auth.uid());
 if not found then raise exception 'GRILLAD_PROOF_DENIED' using errcode='42501';end if;
 insert into grillad_private.attendance_photo_access(org,site,proof_id,viewer) values(p_org,p_site,proof.id,auth.uid());
 return jsonb_build_object('id',proof.id,'jpeg',encode(proof.photo,'base64'));
end $$;
create function grillad_private.purge_attendance_photos() returns bigint language plpgsql security definer set search_path=pg_catalog as $$
declare n bigint;begin update grillad_private.attendance set photo=null where photo is not null and photo_until<=now();get diagnostics n=row_count;return n;end $$;
create function public.grillad_attendance_status(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.attendance_status(p_org,p_site)$$;
create function public.grillad_attendance_capture(p_org uuid,p_site uuid,p_event uuid,p_kind text,p_at timestamptz,p_lat double precision,p_lon double precision,p_accuracy double precision,p_photo text) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.attendance_capture(p_org,p_site,p_event,p_kind,p_at,p_lat,p_lon,p_accuracy,p_photo)$$;
-- Explicit audited photo access; caller scope is enforced before returning bytes.
create function public.grillad_attendance_photo(p_org uuid,p_site uuid,p_id uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.attendance_photo(p_org,p_site,p_id)$$;
revoke all on function public.grillad_attendance_photo(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.grillad_attendance_photo(uuid,uuid,uuid) to authenticated;
revoke all on function grillad_private.attendance_status(uuid,uuid),grillad_private.attendance_capture(uuid,uuid,uuid,text,timestamptz,double precision,double precision,double precision,text),grillad_private.attendance_photo(uuid,uuid,uuid),grillad_private.purge_attendance_photos() from public,anon,authenticated;
grant execute on function grillad_private.attendance_status(uuid,uuid),grillad_private.attendance_capture(uuid,uuid,uuid,text,timestamptz,double precision,double precision,double precision,text),grillad_private.attendance_photo(uuid,uuid,uuid) to authenticated;
revoke all on function public.grillad_attendance_status(uuid,uuid),public.grillad_attendance_capture(uuid,uuid,uuid,text,timestamptz,double precision,double precision,double precision,text) from public,anon,authenticated;
grant execute on function public.grillad_attendance_status(uuid,uuid),public.grillad_attendance_capture(uuid,uuid,uuid,text,timestamptz,double precision,double precision,double precision,text) to authenticated;
create function grillad_private.attendance_correct(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();dep grillad_private.attendance%rowtype;arr grillad_private.attendance%rowtype;c grillad_private.attendance_corrections%rowtype;seconds bigint;why text;decision text;
begin
 r:=grillad_private.scope(p_org,p_site);
 why:=btrim(p_payload->>'reason');if why is null or length(why) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
 if p_action='attendance_request' then
  select * into dep from grillad_private.attendance where id=(p_payload->>'departure')::uuid and org=p_org and site=p_site and kind='departure' and actor=u;
  if not found then raise exception 'GRILLAD_PROOF_DENIED' using errcode='42501';end if;
  select * into arr from grillad_private.attendance where id=dep.paired_arrival and org=p_org and site=p_site and actor=u and kind='arrival';
  if not found then raise exception 'GRILLAD_PROOF_DENIED' using errcode='42501';end if;
  seconds:=(p_payload->>'seconds')::bigint;
  -- Conservative candidate: only reduce a closed, confirmed interval; no missing-punch or extension fabricated.
  if seconds is null or seconds<0 or seconds>=extract(epoch from dep.captured_at-arr.captured_at)::bigint then raise exception 'GRILLAD_CORRECTION_DURATION' using errcode='22023';end if;
  if exists(select 1 from grillad_private.attendance_corrections where departure=dep.id and status in ('pending','approved')) then raise exception 'GRILLAD_CORRECTION_EXISTS' using errcode='22023';end if;
  insert into grillad_private.attendance_corrections(id,org,site,departure,requester,proposed_seconds,reason) values(p_event,p_org,p_site,dep.id,u,seconds,why);
  return jsonb_build_object('id',p_event,'status','pending','proposed_seconds',seconds);
 elsif p_action='attendance_decide' then
  if r not in ('owner','manager') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  decision:=p_payload->>'decision';if decision is null or decision not in ('approved','rejected') then raise exception 'GRILLAD_CORRECTION_DECISION' using errcode='22023';end if;
  select * into c from grillad_private.attendance_corrections where id=(p_payload->>'request')::uuid and org=p_org and site=p_site for update;
  if not found or c.requester=u then raise exception 'GRILLAD_CORRECTION_DENIED' using errcode='42501';end if;
  if c.status<>'pending' then raise exception 'GRILLAD_CORRECTION_CLOSED' using errcode='22023';end if;
  update grillad_private.attendance_corrections set status=decision,decided_by=u,decided_at=now(),decision_reason=why,decision_event=p_event where id=c.id;
  return jsonb_build_object('id',c.id,'status',decision,'proposed_seconds',c.proposed_seconds);
 else raise exception 'GRILLAD_ACTION' using errcode='22023';end if;
end $$;
-- Called only inside the already scoped, locked and idempotent business RPC.
revoke all on function grillad_private.attendance_correct(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;

create function grillad_private.missing_departure(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();a grillad_private.attendance%rowtype;m grillad_private.missing_departures%rowtype;duration bigint;why text;decision text;end_at timestamptz;
begin
 r:=grillad_private.scope(p_org,p_site);why:=btrim(p_payload->>'reason');
 if why is null or length(why) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
 if p_action='missing_departure_request' then
  perform pg_advisory_xact_lock(hashtextextended('grillad-attendance:'||p_org::text||':'||u::text,0));
  select * into a from grillad_private.attendance where id=(p_payload->>'arrival')::uuid and org=p_org and site=p_site and actor=u and kind='arrival';
  if not found then raise exception 'GRILLAD_PROOF_DENIED' using errcode='42501';end if;
  duration:=(p_payload->>'seconds')::bigint;
  if duration is null or duration<=0 or duration>extract(epoch from now()-a.captured_at) then raise exception 'GRILLAD_MANUAL_TIME' using errcode='22023';end if;
  end_at:=a.captured_at+make_interval(secs=>duration::double precision);
  if exists(select 1 from grillad_private.attendance where paired_arrival=a.id) or exists(select 1 from grillad_private.missing_departures where arrival=a.id and status in ('pending','approved')) then raise exception 'GRILLAD_ARRIVAL_ALREADY_CLOSED_OR_PENDING' using errcode='22023';end if;
  insert into grillad_private.missing_departures(id,org,site,arrival,requester,proposed_at,seconds,reason) values(p_event,p_org,p_site,a.id,u,end_at,duration,why);
  return jsonb_build_object('id',p_event,'status','pending','source','manual');
 elsif p_action='missing_departure_decide' then
  if r not in ('owner','manager') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  decision:=p_payload->>'decision';if decision is null or decision not in ('approved','rejected') then raise exception 'GRILLAD_DECISION' using errcode='22023';end if;
  select * into m from grillad_private.missing_departures where id=(p_payload->>'request')::uuid and org=p_org and site=p_site;
  if not found or m.requester=u then raise exception 'GRILLAD_CORRECTION_DENIED' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended('grillad-attendance:'||p_org::text||':'||m.requester::text,0));
  select * into m from grillad_private.missing_departures where id=m.id for update;
  if m.status<>'pending' then raise exception 'GRILLAD_CORRECTION_CLOSED' using errcode='22023';end if;
  if decision='approved' and exists(select 1 from grillad_private.attendance where paired_arrival=m.arrival) then raise exception 'GRILLAD_ARRIVAL_ALREADY_CLOSED' using errcode='22023';end if;
  update grillad_private.missing_departures set status=decision,decided_by=u,decided_at=now(),decision_reason=why where id=m.id;
  return jsonb_build_object('id',m.id,'status',decision,'source','manual');
 else raise exception 'GRILLAD_ACTION' using errcode='22023';end if;
end $$;
revoke all on function grillad_private.missing_departure(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;

-- The departure proof remains real; the missing arrival is a separately approved declaration.
create function grillad_private.missing_arrival(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();dep grillad_private.attendance%rowtype;m grillad_private.missing_arrivals%rowtype;duration bigint;why text;decision text;start_at timestamptz;subject uuid;
begin
 r:=grillad_private.scope(p_org,p_site);why:=btrim(p_payload->>'reason');
 if why is null or length(why) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
 if p_action='missing_arrival_request' then
  subject:=u;
  select * into dep from grillad_private.attendance where id=(p_payload->>'departure')::uuid and org=p_org and site=p_site and actor=u and kind='departure_without_arrival';
  if not found then raise exception 'GRILLAD_PROOF_DENIED' using errcode='42501';end if;
  duration:=(p_payload->>'seconds')::bigint;
  if duration is null or duration<=0 or duration>86400 then raise exception 'GRILLAD_MANUAL_TIME' using errcode='22023';end if;
  start_at:=dep.captured_at-make_interval(secs=>duration::double precision);
 elsif p_action='missing_arrival_decide' then
  if r not in ('owner','manager') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  decision:=p_payload->>'decision';if decision is null or decision not in ('approved','rejected') then raise exception 'GRILLAD_DECISION' using errcode='22023';end if;
  select * into m from grillad_private.missing_arrivals where id=(p_payload->>'request')::uuid and org=p_org and site=p_site;
  if not found or m.requester=u then raise exception 'GRILLAD_CORRECTION_DENIED' using errcode='42501';end if;
  subject:=m.requester;start_at:=m.proposed_at;
  select * into dep from grillad_private.attendance where id=m.departure and org=p_org and site=p_site and actor=subject and kind='departure_without_arrival';
  if not found then raise exception 'GRILLAD_PROOF_DENIED' using errcode='42501';end if;
 else raise exception 'GRILLAD_ACTION' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-attendance:'||p_org::text||':'||subject::text,0));
 if p_action='missing_arrival_request' or decision='approved' then
  -- Refuse any previously recorded boundary within the claimed interval and any intersecting manual close.
  if exists(select 1 from grillad_private.attendance a where a.org=p_org and a.actor=subject and a.id<>dep.id and a.captured_at>=start_at and a.captured_at<=dep.captured_at)
  or exists(select 1 from grillad_private.missing_departures md join grillad_private.attendance a on a.id=md.arrival where md.org=p_org and md.requester=subject and md.status='approved' and a.captured_at<dep.captured_at and md.proposed_at>start_at)
  or exists(select 1 from grillad_private.missing_arrivals ma join grillad_private.attendance a on a.id=ma.departure where ma.org=p_org and ma.requester=subject and ma.departure<>dep.id and ma.status in ('pending','approved') and ma.proposed_at<dep.captured_at and a.captured_at>start_at) then raise exception 'GRILLAD_OVERLAP' using errcode='22023';end if;
 end if;
 if p_action='missing_arrival_request' then
  if exists(select 1 from grillad_private.missing_arrivals where departure=dep.id and status in ('pending','approved')) then raise exception 'GRILLAD_CORRECTION_EXISTS' using errcode='22023';end if;
  insert into grillad_private.missing_arrivals(id,org,site,departure,requester,proposed_at,seconds,reason) values(p_event,p_org,p_site,dep.id,u,start_at,duration,why);
  return jsonb_build_object('id',p_event,'status','pending','source','manual_arrival');
 end if;
 update grillad_private.missing_arrivals set status=decision,decided_by=u,decided_at=now(),decision_reason=why where id=m.id and status='pending';
 if not found then raise exception 'GRILLAD_CORRECTION_CLOSED' using errcode='22023';end if;
 return jsonb_build_object('id',m.id,'status',decision,'source','manual_arrival');
end $$;
revoke all on function grillad_private.missing_arrival(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;

commit;
