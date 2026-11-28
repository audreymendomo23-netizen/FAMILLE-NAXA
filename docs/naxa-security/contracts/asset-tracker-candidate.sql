-- Asset-only GPS tracking. No staff/personal continuous tracking, no physical actuation.
begin;
create table sec_private.tracker_assets(
 organization_id uuid not null,site_id uuid not null,device_id uuid not null,asset_label text not null check(length(trim(asset_label)) between 1 and 120),
 enabled boolean not null,updated_by uuid not null references auth.users(id),updated_at timestamptz not null default now(),
 primary key(organization_id,site_id,device_id),foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id)
);
revoke all on sec_private.tracker_assets from public,anon,authenticated,sec_gateway_ingest;
create table public.sec_asset_positions(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,device_id uuid not null,gateway_id uuid not null,
 observed_at timestamptz not null,latitude double precision not null check(latitude between -90 and 90),longitude double precision not null check(longitude between -180 and 180),
 accuracy_m double precision not null check(accuracy_m>0 and accuracy_m<=5000),created_at timestamptz not null default now(),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 foreign key(organization_id,site_id,gateway_id) references public.sec_devices(organization_id,site_id,id)
);
alter table public.sec_asset_positions enable row level security;
revoke all on public.sec_asset_positions from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_asset_positions to authenticated;
create policy asset_position_read on public.sec_asset_positions for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager'));
create index asset_position_scope on public.sec_asset_positions(organization_id,site_id,device_id,observed_at desc,id);
create function sec_private.tracker_manage(p_org uuid,p_site uuid,p_device uuid default null,p_label text default null,p_enabled boolean default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare rows jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 if p_device is null then
  if p_label is not null or p_enabled is not null then raise exception 'invalid list' using errcode='22023';end if;
 else
  if p_label is null or length(trim(p_label)) not between 1 and 120 or p_enabled is null then raise exception 'invalid asset' using errcode='22023';end if;
  if not exists(select 1 from public.sec_devices where organization_id=p_org and site_id=p_site and id=p_device and kind='tracker') then raise exception 'tracker denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_device::text,340));
  insert into sec_private.tracker_assets(organization_id,site_id,device_id,asset_label,enabled,updated_by) values(p_org,p_site,p_device,trim(p_label),p_enabled,auth.uid())
  on conflict(organization_id,site_id,device_id) do update set asset_label=excluded.asset_label,enabled=excluded.enabled,updated_by=excluded.updated_by,updated_at=clock_timestamp();
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'tracker_config',p_device);
 end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.asset_label,x.device_id),'[]'::jsonb) into rows from
 (select t.device_id,t.asset_label,t.enabled,t.updated_at from sec_private.tracker_assets t where t.organization_id=p_org and t.site_id=p_site order by t.asset_label,t.device_id limit 100)x;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'trackers',rows,'asset_only',true);
end $f$;
revoke all on function sec_private.tracker_manage(uuid,uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function sec_private.tracker_manage(uuid,uuid,uuid,text,boolean) to authenticated;
create function public.sec_tracker_manage(p_org uuid,p_site uuid,p_device uuid default null,p_label text default null,p_enabled boolean default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.tracker_manage(p_org,p_site,p_device,p_label,p_enabled)$r$;
revoke all on function public.sec_tracker_manage(uuid,uuid,uuid,text,boolean) from public,anon;
grant execute on function public.sec_tracker_manage(uuid,uuid,uuid,text,boolean) to authenticated;
create function sec_private.ingest_asset_position(p_gateway uuid,p_org uuid,p_site uuid,p_device uuid,p_event uuid,p_observed timestamptz,p_lat double precision,p_lon double precision,p_accuracy double precision) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v public.sec_asset_positions%rowtype;
begin
 if p_event is null or p_observed is null or p_observed>now() or p_observed<now()-interval '24 hours' or p_lat is null or p_lat not between -90 and 90 or p_lon is null or p_lon not between -180 and 180 or p_accuracy is null or p_accuracy<=0 or p_accuracy>5000 then raise exception 'invalid position' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_device::text,340));
 if not exists(select 1 from sec_private.tracker_assets t join sec_private.gateway_bindings b on b.organization_id=t.organization_id and b.site_id=t.site_id and b.device_id=t.device_id
 join public.sec_devices g on g.id=b.gateway_id and g.organization_id=b.organization_id and g.site_id=b.site_id
 join public.sec_devices d on d.id=b.device_id and d.organization_id=b.organization_id and d.site_id=b.site_id
 join public.sec_sites s on s.id=b.site_id and s.organization_id=b.organization_id join public.sec_organizations o on o.id=s.organization_id
 where t.organization_id=p_org and t.site_id=p_site and t.device_id=p_device and t.enabled and b.enabled and b.gateway_id=p_gateway and g.kind='gateway' and d.kind='tracker' and s.active and o.active) then raise exception 'tracker denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,341));
 select * into v from public.sec_asset_positions where id=p_event;
 if found then
  if v.organization_id<>p_org or v.site_id<>p_site or v.device_id<>p_device or v.gateway_id<>p_gateway or v.observed_at<>p_observed or v.latitude<>p_lat or v.longitude<>p_lon or v.accuracy_m<>p_accuracy then raise exception 'event conflict' using errcode='23505';end if;
 else
  insert into public.sec_asset_positions(id,organization_id,site_id,device_id,gateway_id,observed_at,latitude,longitude,accuracy_m) values(p_event,p_org,p_site,p_device,p_gateway,p_observed,p_lat,p_lon,p_accuracy) returning * into v;
  update public.sec_devices set observed_at=p_observed where organization_id=p_org and site_id=p_site and id=p_device and (observed_at is null or observed_at<p_observed);
 end if;
 return jsonb_build_object('event_id',v.id,'organization_id',v.organization_id,'site_id',v.site_id,'gateway_id',v.gateway_id,'device_id',v.device_id,'state','recorded','physical_action',false);
end $f$;
revoke all on function sec_private.ingest_asset_position(uuid,uuid,uuid,uuid,uuid,timestamptz,double precision,double precision,double precision) from public,anon,authenticated;
grant execute on function sec_private.ingest_asset_position(uuid,uuid,uuid,uuid,uuid,timestamptz,double precision,double precision,double precision) to sec_gateway_ingest;
create function public.sec_tracker_history(p_org uuid,p_site uuid,p_device uuid,p_before timestamptz default null,p_before_id uuid default null) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog as $f$
declare rows jsonb;next_cursor jsonb;last_id uuid;last_time timestamptz;total integer;zones jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 if p_device is null or (p_before is null)<>(p_before_id is null) then raise exception 'invalid cursor' using errcode='22023';end if;
 if not exists(select 1 from public.sec_devices where organization_id=p_org and site_id=p_site and id=p_device and kind='tracker') then raise exception 'tracker denied' using errcode='42501';end if;
 with batch as (select id,observed_at,latitude,longitude,accuracy_m from public.sec_asset_positions where organization_id=p_org and site_id=p_site and device_id=p_device and (p_before is null or (observed_at,id)<(p_before,p_before_id)) order by observed_at desc,id desc limit 101),
 page as (select * from batch order by observed_at desc,id desc limit 100)
 select coalesce((select jsonb_agg(to_jsonb(p) order by p.observed_at desc,p.id desc) from page p),'[]'::jsonb),(select count(*) from batch),(select id from page order by observed_at,id limit 1),(select observed_at from page order by observed_at,id limit 1)
 into rows,total,last_id,last_time;
 if total>100 then next_cursor:=jsonb_build_object('before',last_time,'before_id',last_id);end if;
 -- Geofence comparison uses the freshest known source position, with an accuracy band.
 select coalesce(jsonb_agg(jsonb_build_object('zone_id',z.id,'label',z.label,'distance_m',round(d.distance_m::numeric,1),'assessment',case when p.observed_at<now()-interval '120 seconds' then 'stale' when d.distance_m+p.accuracy_m<=z.radius_m then 'inside' when d.distance_m-p.accuracy_m>z.radius_m then 'outside' else 'uncertain' end) order by z.id),'[]'::jsonb) into zones
 from (select latitude,longitude,accuracy_m,observed_at from public.sec_asset_positions where organization_id=p_org and site_id=p_site and device_id=p_device order by observed_at desc,id desc limit 1)p
 join public.sec_geofences z on z.organization_id=p_org and z.site_id=p_site
 cross join lateral(select 12742000*asin(sqrt(least(1.0,greatest(0.0,power(sin(radians(p.latitude-z.latitude)/2),2)+cos(radians(p.latitude))*cos(radians(z.latitude))*power(sin(radians(p.longitude-z.longitude)/2),2))))) as distance_m)d;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'device_id',p_device,'generated_at',now(),'rows',rows,'next',next_cursor,'zones',zones,'position_authenticated',false);
end $f$;
revoke all on function public.sec_tracker_history(uuid,uuid,uuid,timestamptz,uuid) from public,anon;
grant execute on function public.sec_tracker_history(uuid,uuid,uuid,timestamptz,uuid) to authenticated;
commit;
