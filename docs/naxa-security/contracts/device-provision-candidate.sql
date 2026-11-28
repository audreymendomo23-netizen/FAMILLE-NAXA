-- Administrative device registration and gateway link lifecycle; no automatic device discovery or secret issuance.
begin;
create table sec_private.device_profiles(
 device_id uuid primary key references public.sec_devices(id),organization_id uuid not null,site_id uuid not null,
 manufacturer text not null check(length(trim(manufacturer)) between 1 and 80),model text not null check(length(trim(model)) between 1 and 120),firmware text not null check(length(trim(firmware)) between 1 and 80),
 reference text not null check(reference ~ '^[A-Za-z0-9._-]{1,80}$'),registered_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(organization_id,site_id,reference),foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id)
);
revoke all on sec_private.device_profiles from public,anon,authenticated,sec_gateway_ingest;
create table sec_private.provision_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,actor_id uuid not null references auth.users(id),operation text not null,detail_hash text not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
revoke all on sec_private.provision_events from public,anon,authenticated,sec_gateway_ingest;
create function sec_private.device_provision(p_org uuid,p_site uuid,p_event uuid,p_op text,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;h text;v sec_private.provision_events%rowtype;d uuid;g uuid;k text;label text;manufacturer text;model text;firmware text;reference text;receipt jsonb;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'')<>'owner' then raise exception 'owner required' using errcode='42501';end if;
 if p_event is null or p_op is null or p_op not in ('register','bind','revoke') or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>2048 then raise exception 'invalid request' using errcode='22023';end if;
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,361));
 select * into v from sec_private.provision_events where id=p_event;
 if found then
  if v.organization_id<>p_org or v.site_id<>p_site or v.actor_id<>auth.uid() or v.operation<>p_op or v.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;
  return v.receipt;
 end if;
 if p_op='register' then
  if p_detail-'label'-'kind'-'manufacturer'-'model'-'firmware'-'reference'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  k:=p_detail->>'kind';label:=trim(coalesce(p_detail->>'label',''));manufacturer:=trim(coalesce(p_detail->>'manufacturer',''));model:=trim(coalesce(p_detail->>'model',''));firmware:=trim(coalesce(p_detail->>'firmware',''));reference:=coalesce(p_detail->>'reference','');
  if k is null or k not in ('camera','gateway','smoke','fire','audio','tracker','access','environment') or length(label) not between 1 and 120 or length(manufacturer) not between 1 and 80 or length(model) not between 1 and 120 or length(firmware) not between 1 and 80 or reference !~ '^[A-Za-z0-9._-]{1,80}$' then raise exception 'invalid device profile' using errcode='22023';end if;
  d:=p_event;
  insert into public.sec_devices(id,organization_id,site_id,label,kind) values(d,p_org,p_site,label,k);
  insert into sec_private.device_profiles values(d,p_org,p_site,manufacturer,model,firmware,reference,auth.uid(),now());
  receipt:=jsonb_build_object('device_id',d,'state','registered','kind',k,'compatibility_verified',false);
 else
  if p_detail-'gateway_id'-'device_id'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  d:=(p_detail->>'device_id')::uuid;g:=(p_detail->>'gateway_id')::uuid;
  if d is null or g is null or d=g or not exists(select 1 from public.sec_devices where id=g and organization_id=p_org and site_id=p_site and kind='gateway') or not exists(select 1 from public.sec_devices where id=d and organization_id=p_org and site_id=p_site and kind<>'gateway') then raise exception 'binding denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(d::text,362));
  if p_op='bind' then
   -- Prevent an implicit second trusted source; explicit revocation is required before moving a device.
   if exists(select 1 from sec_private.gateway_bindings where organization_id=p_org and site_id=p_site and device_id=d and gateway_id<>g and enabled) then raise exception 'active gateway exists' using errcode='23505';end if;
   insert into sec_private.gateway_bindings(gateway_id,organization_id,site_id,device_id,enabled) values(g,p_org,p_site,d,true) on conflict(gateway_id,device_id) do update set enabled=true;
  else
   update sec_private.gateway_bindings set enabled=false where gateway_id=g and organization_id=p_org and site_id=p_site and device_id=d;
   if not found then raise exception 'binding denied' using errcode='42501';end if;
  end if;
  receipt:=jsonb_build_object('device_id',d,'gateway_id',g,'state',case when p_op='bind' then 'bound' else 'revoked' end);
 end if;
 receipt:=receipt||jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'physical_action',false,'transport_configured',false);
 insert into sec_private.provision_events(id,organization_id,site_id,actor_id,operation,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),p_op,h,receipt);
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'device_'||p_op,d);
 return receipt;
end $f$;
revoke all on function sec_private.device_provision(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function sec_private.device_provision(uuid,uuid,uuid,text,jsonb) to authenticated;
create function public.sec_device_provision(p_org uuid,p_site uuid,p_event uuid,p_op text,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.device_provision(p_org,p_site,p_event,p_op,p_detail)$r$;
revoke all on function public.sec_device_provision(uuid,uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.sec_device_provision(uuid,uuid,uuid,text,jsonb) to authenticated;
create function sec_private.device_inventory(p_org uuid,p_site uuid,p_after uuid default null) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $f$
declare r text;data jsonb;next_cursor uuid;n integer;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager') then raise exception 'denied' using errcode='42501';end if;
 with batch as (select d.id,d.label,d.kind,d.observed_at,p.manufacturer,p.model,p.firmware,p.reference,false as compatibility_verified,
 (select coalesce(jsonb_agg(jsonb_build_object('gateway_id',b.gateway_id,'enabled',b.enabled) order by b.gateway_id),'[]'::jsonb) from sec_private.gateway_bindings b where b.organization_id=p_org and b.site_id=p_site and b.device_id=d.id) as bindings
 from public.sec_devices d left join sec_private.device_profiles p on p.device_id=d.id and p.organization_id=d.organization_id and p.site_id=d.site_id
 where d.organization_id=p_org and d.site_id=p_site and (p_after is null or d.id>p_after) order by d.id limit 101),
 page as (select * from batch order by id limit 100)
 select coalesce((select jsonb_agg(to_jsonb(x) order by x.id) from page x),'[]'::jsonb),(select count(*) from batch),(select id from page order by id desc limit 1) into data,n,next_cursor;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'can_provision',r='owner','devices',data,'next',case when n>100 then next_cursor end,'physical_action',false);
end $f$;
revoke all on function sec_private.device_inventory(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.device_inventory(uuid,uuid,uuid) to authenticated;
create function public.sec_device_inventory(p_org uuid,p_site uuid,p_after uuid default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.device_inventory(p_org,p_site,p_after)$r$;
revoke all on function public.sec_device_inventory(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_device_inventory(uuid,uuid,uuid) to authenticated;
commit;
