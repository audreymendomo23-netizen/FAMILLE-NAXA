-- Isolated gateway integration contract. Trusted ingestion role; never grant it to browser/app users.
begin;
create role sec_gateway_ingest nologin;
grant usage on schema sec_private to sec_gateway_ingest;
create table sec_private.gateway_bindings(
 gateway_id uuid not null,organization_id uuid not null,site_id uuid not null,device_id uuid not null,enabled boolean not null default true,
 primary key(gateway_id,device_id),
 foreign key(organization_id,site_id,gateway_id) references public.sec_devices(organization_id,site_id,id),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id)
);
create table sec_private.telemetry_thresholds(
 organization_id uuid not null,site_id uuid not null,device_id uuid not null,metric text not null check(metric in ('temperature','humidity','water','co','gas')),
 upper_limit double precision not null check(upper_limit between -1000000 and 1000000),
 primary key(organization_id,site_id,device_id,metric),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 check(metric<>'humidity' or upper_limit between 0 and 100),check(metric='temperature' or upper_limit>=0)
);
create table sec_private.gateway_receipts(
 event_id uuid primary key,gateway_id uuid not null,organization_id uuid not null,site_id uuid not null,device_id uuid not null,payload jsonb not null,receipt jsonb not null
);
revoke all on sec_private.gateway_bindings,sec_private.telemetry_thresholds,sec_private.gateway_receipts from public,anon,authenticated,sec_gateway_ingest;
create table public.sec_observation_alerts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,device_id uuid not null,
 event_id uuid not null references public.sec_device_observations(source_event_id),kind text not null check(kind in ('device_fault','device_offline','threshold_exceeded')),
 observed_at timestamptz not null,created_at timestamptz not null default now(),
 unique(event_id,kind),foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id)
);
alter table public.sec_observation_alerts enable row level security;
revoke all on public.sec_observation_alerts from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_observation_alerts to authenticated;
create policy sec_observation_alert_read on public.sec_observation_alerts for select to authenticated using(exists(select 1 from public.sec_sites s where s.id=sec_observation_alerts.site_id and s.organization_id=sec_observation_alerts.organization_id));
create function sec_private.ingest_observation(p_gateway uuid,p_org uuid,p_site uuid,p_device uuid,p_event uuid,p_observed timestamptz,p_status text,p_metric text,p_value double precision) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $ingest$
declare b sec_private.gateway_bindings%rowtype;old sec_private.gateway_receipts%rowtype;payload jsonb;receipt jsonb;lim double precision;warnings integer:=0;obs uuid;
begin
 -- No user JWT, no client writes. Gateway authentication/secret management belongs to the trusted transport.
 if p_event is null or p_observed is null or p_observed>now() or p_observed<now()-interval '24 hours' or p_status is null or p_status not in ('online','offline','fault')
 or (p_metric is null)<>(p_value is null)
 or (p_metric is not null and (p_metric not in ('temperature','humidity','water','co','gas') or p_value not between -1000000 and 1000000 or (p_metric<>'temperature' and p_value<0) or (p_metric='humidity' and p_value>100))) then raise exception 'invalid telemetry' using errcode='22023';end if;
 select x.* into b from sec_private.gateway_bindings x join public.sec_devices g on g.id=x.gateway_id and g.organization_id=x.organization_id and g.site_id=x.site_id join public.sec_sites s on s.id=x.site_id and s.organization_id=x.organization_id join public.sec_organizations o on o.id=s.organization_id
 where x.gateway_id=p_gateway and x.organization_id=p_org and x.site_id=p_site and x.device_id=p_device and x.enabled and g.kind='gateway' and s.active and o.active;
 if not found then raise exception 'gateway/device denied' using errcode='42501';end if;
 payload:=jsonb_build_object('observed_at',p_observed,'status',p_status,'metric',p_metric,'value',p_value);
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,1));
 select * into old from sec_private.gateway_receipts where event_id=p_event;
 if found then
  if old.gateway_id<>p_gateway or old.organization_id<>p_org or old.site_id<>p_site or old.device_id<>p_device or old.payload<>payload then raise exception 'event conflict' using errcode='23505';end if;return old.receipt;
 end if;
 insert into public.sec_device_observations(organization_id,site_id,device_id,observed_at,status,metric,value,source_event_id) values(p_org,p_site,p_device,p_observed,p_status,p_metric,p_value,p_event) returning id into obs;
 update public.sec_devices set observed_at=p_observed where id=p_device and organization_id=p_org and site_id=p_site and (observed_at is null or observed_at<p_observed);
 -- Warning records are not emergency alarms. Old batches remain historical, never fresh alerts.
 if p_observed>=now()-interval '120 seconds' then
  if p_status in ('offline','fault') then
   insert into public.sec_observation_alerts(organization_id,site_id,device_id,event_id,kind,observed_at) values(p_org,p_site,p_device,p_event,case when p_status='fault' then 'device_fault' else 'device_offline' end,p_observed);warnings:=warnings+1;
  end if;
  if p_metric is not null then
   select upper_limit into lim from sec_private.telemetry_thresholds where organization_id=p_org and site_id=p_site and device_id=p_device and metric=p_metric;
   if found and p_value>lim then insert into public.sec_observation_alerts(organization_id,site_id,device_id,event_id,kind,observed_at) values(p_org,p_site,p_device,p_event,'threshold_exceeded',p_observed);warnings:=warnings+1;end if;
  end if;
 end if;
 receipt:=jsonb_build_object('event_id',p_event,'gateway_id',p_gateway,'organization_id',p_org,'site_id',p_site,'device_id',p_device,'observation_id',obs,'state','recorded','warnings',warnings,'physical_action',false);
 insert into sec_private.gateway_receipts values(p_event,p_gateway,p_org,p_site,p_device,payload,receipt);
 return receipt;
end $ingest$;
revoke all on function sec_private.ingest_observation(uuid,uuid,uuid,uuid,uuid,timestamptz,text,text,double precision) from public,anon,authenticated;
grant execute on function sec_private.ingest_observation(uuid,uuid,uuid,uuid,uuid,timestamptz,text,text,double precision) to sec_gateway_ingest;
commit;
