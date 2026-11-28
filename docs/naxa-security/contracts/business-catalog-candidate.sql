-- Operational catalog: linked customers, contracts, teams, assets, parts, partners and access profiles.
-- No physical access authorization or automatic device operation is implied.
begin;
create table public.sec_business_catalog(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,kind text not null check(kind in ('customer','contract','team','asset','part','partner','access_profile')),
 label text not null check(length(trim(label)) between 1 and 120),reference text not null check(reference ~ '^[A-Za-z0-9._-]{1,80}$'),
 parent_id uuid references public.sec_business_catalog(id),member_id uuid references auth.users(id),device_id uuid,
 valid_from date,valid_until date,amount_fcfa bigint check(amount_fcfa between 0 and 1000000000),
 quantity bigint not null default 0 check(quantity between 0 and 100000000),minimum bigint not null default 0 check(minimum between 0 and 100000000),
 state text not null default 'active' check(state in ('active','archived')),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(organization_id,site_id,kind,reference),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 check(valid_until is null or valid_from is not null and valid_until>=valid_from),
 check((kind='contract')=(parent_id is not null)),check((kind='team')=(member_id is not null)),
 check((kind='asset')=(device_id is not null)),check(kind='part' or (quantity=0 and minimum=0)),
 check(kind in ('contract','asset','partner') or (valid_from is null and valid_until is null)),
 check(kind='contract' or amount_fcfa is null)
);
create unique index sec_catalog_device on public.sec_business_catalog(organization_id,site_id,device_id) where kind='asset' and state='active';
create table public.sec_business_catalog_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,actor_id uuid not null references auth.users(id),
 operation text not null,target_id uuid not null references public.sec_business_catalog(id),delta bigint,detail_hash text not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_business_catalog enable row level security;
alter table public.sec_business_catalog_events enable row level security;
revoke all on public.sec_business_catalog,public.sec_business_catalog_events from public,anon,authenticated;
grant select on public.sec_business_catalog,public.sec_business_catalog_events to authenticated;
create policy catalog_read on public.sec_business_catalog for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager'));
create policy catalog_event_read on public.sec_business_catalog_events for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager'));
create function sec_private.catalog_action(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare k text;row public.sec_business_catalog%rowtype;old public.sec_business_catalog_events%rowtype;h text;v jsonb;delta bigint;parent uuid;member uuid;device uuid;d1 date;d2 date;money bigint;minimum_value bigint;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 if p_event is null or p_op is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>4096 then raise exception 'invalid request' using errcode='22023';end if;
 h:=encode(sha256(convert_to(jsonb_build_array(p_target,p_detail)::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,271));
 select * into old from public.sec_business_catalog_events where id=p_event;
 if found then
  if old.organization_id<>p_org or old.site_id<>p_site or old.actor_id<>auth.uid() or old.operation<>p_op or old.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;
  return old.receipt;
 end if;
 -- Serialize catalog dependency changes and inventory movements per site.
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,272));
 if p_op='create' then
  k:=p_detail->>'kind';
  if p_target is not null or k is null or k not in ('customer','contract','team','asset','part','partner','access_profile') or p_detail-'kind'-'label'-'reference'-'parent_id'-'member_id'-'device_id'-'valid_from'-'valid_until'-'amount_fcfa'-'minimum'<>'{}'::jsonb then raise exception 'invalid catalog' using errcode='22023';end if;
  parent:=(p_detail->>'parent_id')::uuid;member:=(p_detail->>'member_id')::uuid;device:=(p_detail->>'device_id')::uuid;d1:=(p_detail->>'valid_from')::date;d2:=(p_detail->>'valid_until')::date;money:=(p_detail->>'amount_fcfa')::bigint;minimum_value:=coalesce((p_detail->>'minimum')::bigint,0);
  if k='contract' and (d1 is null or d2 is null or money is null or not exists(select 1 from public.sec_business_catalog c where c.id=parent and c.organization_id=p_org and c.site_id=p_site and c.kind='customer' and c.state='active')) then raise exception 'contract customer or dates invalid' using errcode='22023';end if;
  if k='team' and not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships m using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=member and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'member denied' using errcode='42501';end if;
  if k='partner' and (d1 is null or d2 is null) then raise exception 'partner authorization dates required' using errcode='22023';end if;
  insert into public.sec_business_catalog(id,organization_id,site_id,kind,label,reference,parent_id,member_id,device_id,valid_from,valid_until,amount_fcfa,minimum,created_by)
  values(p_event,p_org,p_site,k,trim(p_detail->>'label'),p_detail->>'reference',parent,member,device,d1,d2,money,minimum_value,auth.uid()) returning * into row;
 elsif p_op in ('archive','stock_move') then
  select * into row from public.sec_business_catalog where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found then raise exception 'target denied' using errcode='42501';end if;
  if row.state<>'active' then raise exception 'inactive target' using errcode='22023';end if;
  if p_op='archive' then
   if p_detail<>'{}'::jsonb or (row.kind='part' and row.quantity<>0) or exists(select 1 from public.sec_business_catalog where parent_id=row.id and state='active') then raise exception 'active dependencies or stock' using errcode='22023';end if;
   update public.sec_business_catalog set state='archived' where id=row.id returning * into row;
  else
   if row.kind<>'part' or p_detail-'delta'-'reason'<>'{}'::jsonb or jsonb_typeof(p_detail->'delta') is distinct from 'number' or (p_detail->>'delta') !~ '^-?[0-9]+$' or length(trim(coalesce(p_detail->>'reason',''))) not between 1 and 200 then raise exception 'invalid stock movement' using errcode='22023';end if;
   delta:=(p_detail->>'delta')::bigint;
   if delta=0 or delta not between -100000000 and 100000000 or row.quantity+delta not between 0 and 100000000 then raise exception 'stock unavailable' using errcode='22023';end if;
   update public.sec_business_catalog set quantity=quantity+delta where id=row.id returning * into row;
  end if;
 else raise exception 'unknown operation' using errcode='22023';end if;
 v:=jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'target_id',row.id,'kind',row.kind,'state',row.state,'quantity',row.quantity,'below_minimum',row.kind='part' and row.quantity<=row.minimum,'physical_access',false);
 insert into public.sec_business_catalog_events(id,organization_id,site_id,actor_id,operation,target_id,delta,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),p_op,row.id,delta,h,v);return v;
end $f$;
revoke all on function sec_private.catalog_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.catalog_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create function public.sec_catalog_action(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.catalog_action(p_org,p_site,p_event,p_op,p_target,p_detail)$r$;
revoke all on function public.sec_catalog_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.sec_catalog_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create or replace view public.sec_audit_timeline with(security_invoker=true) as
 select 'field'::text as source,id,organization_id,site_id,actor_id,operation,coalesce(result->>'state','recorded') as state,created_at,target_id as object_id,'field_rpc'::text as origin,id as correlation_id from public.sec_field_events
 union all select 'service',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at,target_id,'service_rpc',id from public.sec_service_action_log
 union all select 'erp',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at,target_id,'erp_rpc',id from public.sec_erp_events
 union all select 'support',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at,case_id,'support_rpc',id from public.sec_support_events
 union all select 'fire_ack',event_id,organization_id,site_id,actor_id,'acknowledge','recorded',created_at,event_id,'fire_rpc',event_id from public.sec_fire_acknowledgments
 union all select 'admin',id,organization_id,site_id,actor_id,'site_membership',case when enabled then 'enabled' else 'revoked' end,created_at,target_id,'admin_rpc',id from public.sec_site_admin_log
 union all select 'access',id,organization_id,site_id,actor_id,operation,outcome,created_at,object_id,'access_rpc',id from public.sec_access_audit
 union all select 'catalog',id,organization_id,site_id,actor_id,operation,receipt->>'state',created_at,target_id,'catalog_rpc',id from public.sec_business_catalog_events;
commit;
