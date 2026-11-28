-- Read-only fire-source events and scoped, declared-position geofence assessment. No emergency actuation.
begin;
create table public.sec_fire_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,device_id uuid not null,gateway_id uuid not null,
 observed_at timestamptz not null,source_state text not null check(source_state in ('fault','prealarm','alarm','evacuation','restored')),
 created_at timestamptz not null default now(),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 foreign key(organization_id,site_id,gateway_id) references public.sec_devices(organization_id,site_id,id)
);
create table public.sec_fire_acknowledgments(
 event_id uuid not null references public.sec_fire_events(id),organization_id uuid not null,site_id uuid not null,
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default now(),
 primary key(event_id,actor_id),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_geofences(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,label text not null check(length(trim(label)) between 1 and 120),
 latitude double precision not null check(latitude between -90 and 90),longitude double precision not null check(longitude between -180 and 180),
 radius_m double precision not null check(radius_m between 20 and 5000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_fire_events enable row level security;
revoke all on public.sec_fire_events from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_fire_events to authenticated;
alter table public.sec_fire_acknowledgments enable row level security;
revoke all on public.sec_fire_acknowledgments from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_fire_acknowledgments to authenticated;
alter table public.sec_geofences enable row level security;
revoke all on public.sec_geofences from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_geofences to authenticated;
create policy fire_read on public.sec_fire_events for select to authenticated using(sec_private.field_role(organization_id,site_id) is not null);
create policy fire_ack_read on public.sec_fire_acknowledgments for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (actor_id=auth.uid() and sec_private.field_role(organization_id,site_id) is not null));
create policy geofence_read on public.sec_geofences for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create function sec_private.ingest_fire(p_gateway uuid,p_org uuid,p_site uuid,p_device uuid,p_event uuid,p_observed timestamptz,p_state text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $fire$
declare f public.sec_fire_events%rowtype;
begin
 if p_event is null or p_observed is null or p_observed>now() or p_observed<now()-interval '24 hours' or p_state is null or p_state not in ('fault','prealarm','alarm','evacuation','restored') then raise exception 'invalid source event' using errcode='22023';end if;
 if not exists(select 1 from sec_private.gateway_bindings b join public.sec_devices g on g.id=b.gateway_id and g.organization_id=b.organization_id and g.site_id=b.site_id join public.sec_devices d on d.id=b.device_id and d.organization_id=b.organization_id and d.site_id=b.site_id join public.sec_sites s on s.id=b.site_id and s.organization_id=b.organization_id join public.sec_organizations o on o.id=b.organization_id where b.gateway_id=p_gateway and b.organization_id=p_org and b.site_id=p_site and b.device_id=p_device and b.enabled and g.kind='gateway' and d.kind in ('smoke','fire') and s.active and o.active) then raise exception 'source denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,4));
 select * into f from public.sec_fire_events where id=p_event;
 if found then
  if f.organization_id<>p_org or f.site_id<>p_site or f.device_id<>p_device or f.gateway_id<>p_gateway or f.source_state<>p_state or f.observed_at<>p_observed then raise exception 'event conflict' using errcode='23505';end if;
 else
  insert into public.sec_fire_events(id,organization_id,site_id,device_id,gateway_id,observed_at,source_state) values(p_event,p_org,p_site,p_device,p_gateway,p_observed,p_state) returning * into f;
 end if;
 return jsonb_build_object('event_id',f.id,'organization_id',f.organization_id,'site_id',f.site_id,'source_state',f.source_state,'physical_action',false);
end $fire$;
revoke all on function sec_private.ingest_fire(uuid,uuid,uuid,uuid,uuid,timestamptz,text) from public,anon,authenticated;
grant execute on function sec_private.ingest_fire(uuid,uuid,uuid,uuid,uuid,timestamptz,text) to sec_gateway_ingest;
create function sec_private.ack_fire(p_org uuid,p_site uuid,p_event uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $ack$
declare f public.sec_fire_events%rowtype; t timestamptz;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'ack denied' using errcode='42501';end if;
 select * into f from public.sec_fire_events where id=p_event and organization_id=p_org and site_id=p_site;
 if not found then raise exception 'event denied' using errcode='42501';end if;
 insert into public.sec_fire_acknowledgments(event_id,organization_id,site_id,actor_id) values(p_event,p_org,p_site,auth.uid()) on conflict(event_id,actor_id) do nothing;
 select created_at into t from public.sec_fire_acknowledgments where event_id=p_event and actor_id=auth.uid();
 return jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'acknowledged_at',t,'source_state',f.source_state,'physical_action',false);
end $ack$;
create function sec_private.create_geofence(p_org uuid,p_site uuid,p_id uuid,p_label text,p_lat double precision,p_lon double precision,p_radius double precision) returns jsonb language plpgsql security definer set search_path=pg_catalog as $zone$
declare z public.sec_geofences%rowtype;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'zone denied' using errcode='42501';end if;
 if p_id is null or p_label is null or length(trim(p_label)) not between 1 and 120 or p_lat is null or p_lat not between -90 and 90 or p_lon is null or p_lon not between -180 and 180 or p_radius is null or p_radius not between 20 and 5000 then raise exception 'invalid zone' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,5));
 select * into z from public.sec_geofences where id=p_id;
 if found then
  if z.organization_id<>p_org or z.site_id<>p_site or z.created_by<>auth.uid() or z.label<>trim(p_label) or z.latitude<>p_lat or z.longitude<>p_lon or z.radius_m<>p_radius then raise exception 'zone conflict' using errcode='23505';end if;
 else insert into public.sec_geofences(id,organization_id,site_id,label,latitude,longitude,radius_m,created_by) values(p_id,p_org,p_site,trim(p_label),p_lat,p_lon,p_radius,auth.uid()) returning * into z;end if;
 return to_jsonb(z);
end $zone$;
-- Haversine with accuracy band; never certifies that the declared position is authentic.
create view public.sec_geofence_assessments with(security_invoker=true) as
 select a.id,a.organization_id,a.site_id,a.reporter_id,a.observed_at,z.id as zone_id,z.label,
 round(d.distance_m::numeric,1) as distance_m,
 case when d.distance_m+a.accuracy_m<=z.radius_m then 'declared_inside'
 when d.distance_m-a.accuracy_m>z.radius_m then 'declared_outside' else 'uncertain' end as assessment,
 false as position_authenticated
 from public.sec_attendance_drafts a join public.sec_geofences z on z.organization_id=a.organization_id and z.site_id=a.site_id
 cross join lateral(select 12742000*asin(sqrt(least(1.0,greatest(0.0,power(sin(radians(a.lat-z.latitude)/2),2)+cos(radians(a.lat))*cos(radians(z.latitude))*power(sin(radians(a.lon-z.longitude)/2),2))))) as distance_m)d;
revoke all on public.sec_geofence_assessments from public,anon,authenticated;
grant select on public.sec_geofence_assessments to authenticated;
revoke all on function sec_private.ack_fire(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.ack_fire(uuid,uuid,uuid) to authenticated;
create function public.sec_ack_fire(p_org uuid,p_site uuid,p_event uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.ack_fire(p_org,p_site,p_event)$rpc$;
revoke all on function public.sec_ack_fire(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_ack_fire(uuid,uuid,uuid) to authenticated;
revoke all on function sec_private.create_geofence(uuid,uuid,uuid,text,double precision,double precision,double precision) from public,anon,authenticated;
grant execute on function sec_private.create_geofence(uuid,uuid,uuid,text,double precision,double precision,double precision) to authenticated;
create function public.sec_create_geofence(p_org uuid,p_site uuid,p_id uuid,p_label text,p_lat double precision,p_lon double precision,p_radius double precision) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.create_geofence(p_org,p_site,p_id,p_label,p_lat,p_lon,p_radius)$rpc$;
revoke all on function public.sec_create_geofence(uuid,uuid,uuid,text,double precision,double precision,double precision) from public,anon;
grant execute on function public.sec_create_geofence(uuid,uuid,uuid,text,double precision,double precision,double precision) to authenticated;
commit;
