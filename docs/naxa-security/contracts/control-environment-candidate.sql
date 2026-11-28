-- Manager-configured environmental warning thresholds and scoped live supervision snapshot.
-- No command is sent to a device; independent fire detection is not modified.
begin;
create function sec_private.environment_policy(p_org uuid,p_site uuid,p_device uuid default null,p_metric text default null,p_limit double precision default null,p_remove boolean default false) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $f$
declare v jsonb;op text;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 if p_remove is null then raise exception 'invalid action' using errcode='22023';end if;
 if p_device is null then
  if p_metric is not null or p_limit is not null or p_remove then raise exception 'invalid list' using errcode='22023';end if;
 else
  if p_metric is null or p_metric not in ('temperature','humidity','water','co','gas') or (p_remove and p_limit is not null) or (not p_remove and (p_limit is null or p_limit not between -1000000 and 1000000 or (p_metric<>'temperature' and p_limit<0) or (p_metric='humidity' and p_limit>100))) then raise exception 'invalid threshold' using errcode='22023';end if;
  if not exists(select 1 from public.sec_devices where id=p_device and organization_id=p_org and site_id=p_site and kind='environment') then raise exception 'sensor denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_device::text||':'||p_metric,283));
  if p_remove then delete from sec_private.telemetry_thresholds where organization_id=p_org and site_id=p_site and device_id=p_device and metric=p_metric;op:='environment_threshold_remove';
  else insert into sec_private.telemetry_thresholds(organization_id,site_id,device_id,metric,upper_limit) values(p_org,p_site,p_device,p_metric,p_limit) on conflict(organization_id,site_id,device_id,metric) do update set upper_limit=excluded.upper_limit;op:='environment_threshold_set';end if;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),op,p_device);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('device_id',device_id,'metric',metric,'upper_limit',upper_limit) order by device_id,metric),'[]'::jsonb) into v from sec_private.telemetry_thresholds where organization_id=p_org and site_id=p_site;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'thresholds',v,'physical_action',false);
end $f$;
revoke all on function sec_private.environment_policy(uuid,uuid,uuid,text,double precision,boolean) from public,anon,authenticated;
grant execute on function sec_private.environment_policy(uuid,uuid,uuid,text,double precision,boolean) to authenticated;
create function public.sec_environment_policy(p_org uuid,p_site uuid,p_device uuid default null,p_metric text default null,p_limit double precision default null,p_remove boolean default false) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.environment_policy(p_org,p_site,p_device,p_metric,p_limit,p_remove)$r$;
revoke all on function public.sec_environment_policy(uuid,uuid,uuid,text,double precision,boolean) from public,anon;
grant execute on function public.sec_environment_policy(uuid,uuid,uuid,text,double precision,boolean) to authenticated;
create function public.sec_control_snapshot(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog as $f$
declare v jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 select jsonb_build_object('organization_id',p_org,'site_id',p_site,'generated_at',now(),'devices_total',count(*),
 'devices_recent',count(*) filter(where d.observed_at between now()-interval '120 seconds' and now()),
 'devices_stale_or_unknown',count(*) filter(where d.observed_at is null or d.observed_at<now()-interval '120 seconds' or d.observed_at>now()),
 'devices_fault_or_offline',count(*) filter(where x.status in ('fault','offline') and x.observed_at between now()-interval '120 seconds' and now()),
 'incidents_open',(select count(*) from public.sec_incidents where organization_id=p_org and site_id=p_site and state<>'closed'),
 'critical_open',(select count(*) from public.sec_incidents where organization_id=p_org and site_id=p_site and state<>'closed' and priority='P1'),
 'warnings_recent',(select count(*) from public.sec_observation_alerts where organization_id=p_org and site_id=p_site and observed_at between now()-interval '120 seconds' and now()),
 'fire_sources_active',(select count(*) from (select distinct on(device_id) source_state,observed_at from public.sec_fire_events where organization_id=p_org and site_id=p_site order by device_id,observed_at desc,id desc) f where f.source_state in ('alarm','prealarm','evacuation','fault')),
 'patrols_overdue',(select count(*) from public.sec_patrols where organization_id=p_org and site_id=p_site and state in ('planned','running') and ends_at<now()),
 'safety_open',(select count(*) from public.sec_internal_safety where organization_id=p_org and site_id=p_site and state<>'closed'),
 'physical_action',false) into v
 from public.sec_devices d left join lateral(select status,observed_at from public.sec_device_observations x where x.organization_id=p_org and x.site_id=p_site and x.device_id=d.id order by observed_at desc,id desc limit 1)x on true where d.organization_id=p_org and d.site_id=p_site;
 return v;
end $f$;
revoke all on function public.sec_control_snapshot(uuid,uuid) from public,anon;
grant execute on function public.sec_control_snapshot(uuid,uuid) to authenticated;
commit;
