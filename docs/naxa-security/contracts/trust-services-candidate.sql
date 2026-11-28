-- Candidate: administration, allocated receipts, personal evidence, preference recovery and integration management.
begin;
create table public.sec_site_admin_log(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 actor_id uuid not null references auth.users(id),target_id uuid not null references auth.users(id),
 enabled boolean not null,reason text not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_subscriptions(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 receipt_id uuid not null unique references public.sec_payment_receipts(id),request_id uuid not null unique references public.sec_module_requests(request_id),
 plan text not null check(plan in ('Essentiel','Business','Professional')),period text not null check(period in ('monthly','annual')),
 starts_at timestamptz not null,ends_at timestamptz not null check(ends_at>starts_at),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_evidence_files(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,owner_id uuid not null references auth.users(id),
 reference text not null check(reference ~ '^[A-Za-z0-9._-]{1,80}$'),
 digest text not null check(digest ~ '^[a-f0-9]{64}$'),size_bytes int not null check(size_bytes between 1 and 262144),
 created_at timestamptz not null default now(),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table sec_private.evidence_content(id uuid primary key references public.sec_evidence_files(id),content bytea not null check(octet_length(content) between 1 and 262144));
create table public.sec_preference_snapshots(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,user_id uuid not null references auth.users(id),
 digest text not null,preferences jsonb not null check(jsonb_typeof(preferences)='object'),created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_service_action_log(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,actor_id uuid not null references auth.users(id),
 operation text not null,target_id uuid,detail_hash text not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_site_admin_log enable row level security;
revoke all on public.sec_site_admin_log from public,anon,authenticated;
grant select on public.sec_site_admin_log to authenticated;
alter table public.sec_subscriptions enable row level security;
revoke all on public.sec_subscriptions from public,anon,authenticated;
grant select on public.sec_subscriptions to authenticated;
alter table public.sec_evidence_files enable row level security;
revoke all on public.sec_evidence_files from public,anon,authenticated;
grant select on public.sec_evidence_files to authenticated;
alter table public.sec_preference_snapshots enable row level security;
revoke all on public.sec_preference_snapshots from public,anon,authenticated;
grant select on public.sec_preference_snapshots to authenticated;
alter table public.sec_service_action_log enable row level security;
revoke all on public.sec_service_action_log from public,anon,authenticated;
grant select on public.sec_service_action_log to authenticated;
revoke all on sec_private.evidence_content from public,anon,authenticated;
create policy sec_admin_log_read on public.sec_site_admin_log for select to authenticated using(sec_private.field_role(organization_id,site_id)='owner');
create policy sec_subscription_read on public.sec_subscriptions for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager'));
create policy sec_evidence_self on public.sec_evidence_files for select to authenticated using(owner_id=auth.uid() and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create policy sec_snapshot_self on public.sec_preference_snapshots for select to authenticated using(user_id=auth.uid() and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create policy sec_service_log_self on public.sec_service_action_log for select to authenticated using(actor_id=auth.uid() and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
-- No direct exposure of secrets or private content. Existing members only, never change organization roles.
create function sec_private.site_members(p_org uuid,p_site uuid) returns jsonb language sql stable security definer set search_path=pg_catalog as $q$
 select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'site_active',coalesce(sm.active,false)) order by m.user_id),'[]'::jsonb)
 from public.sec_memberships m left join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id and sm.site_id=p_site
 where m.organization_id=p_org and m.active and sec_private.field_role(p_org,p_site)='owner'
$q$;
create function sec_private.integration_list(p_org uuid,p_site uuid) returns jsonb language sql stable security definer set search_path=pg_catalog as $q$
 select coalesce(jsonb_agg(jsonb_build_object('gateway_id',b.gateway_id,'device_id',b.device_id,'enabled',b.enabled) order by b.gateway_id,b.device_id),'[]'::jsonb)
 from sec_private.gateway_bindings b where b.organization_id=p_org and b.site_id=p_site and sec_private.field_role(p_org,p_site) in ('owner','manager')
$q$;
create function sec_private.service_action(p_org uuid,p_site uuid,p_event uuid,p_operation text,p_target uuid,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $action$
declare r text; prev public.sec_service_action_log%rowtype; h text; out jsonb; q public.sec_module_requests%rowtype; p public.sec_payment_receipts%rowtype; plan_name text; period_name text; price bigint; b bytea; digest_value text; snapshot public.sec_preference_snapshots%rowtype; prefs jsonb; starts timestamptz; ends timestamptz; target_role text; device uuid;
begin
 r:=sec_private.field_role(p_org,p_site);
 if r is null or r not in ('owner','manager','operator') or p_event is null or p_operation is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>360000 then raise exception 'denied' using errcode='42501';end if;
 if p_operation in ('site_member','subscription','integration_revoke') and r<>'owner' then raise exception 'owner required' using errcode='42501';end if;
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,2));
 select * into prev from public.sec_service_action_log where id=p_event;
 if found then
  if prev.organization_id<>p_org or prev.site_id<>p_site or prev.actor_id<>auth.uid() or prev.operation<>p_operation or prev.target_id is distinct from p_target or prev.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;
  return prev.receipt;
 end if;
 case p_operation
 when 'site_member' then
  if p_detail-'enabled'-'reason'<>'{}'::jsonb or jsonb_typeof(p_detail->'enabled') is distinct from 'boolean' or length(trim(coalesce(p_detail->>'reason',''))) not between 1 and 500 or p_target=auth.uid() then raise exception 'invalid assignment' using errcode='22023';end if;
  select role into target_role from public.sec_memberships where organization_id=p_org and user_id=p_target and active for update;
  if not found or target_role='owner' then raise exception 'target denied' using errcode='42501';end if;
  insert into public.sec_site_memberships(organization_id,site_id,user_id,active) values(p_org,p_site,p_target,(p_detail->>'enabled')::boolean)
  on conflict(organization_id,site_id,user_id) do update set active=excluded.active;
  insert into public.sec_site_admin_log(organization_id,site_id,actor_id,target_id,enabled,reason) values(p_org,p_site,auth.uid(),p_target,(p_detail->>'enabled')::boolean,trim(p_detail->>'reason'));
  out:=jsonb_build_object('target_id',p_target,'state',case when (p_detail->>'enabled')::boolean then 'assigned' else 'revoked' end);
 when 'subscription' then
  if p_detail-'plan'-'period'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  plan_name:=p_detail->>'plan';period_name:=p_detail->>'period';
  price:=case plan_name when 'Essentiel' then case period_name when 'monthly' then 5000 when 'annual' then 60000 end when 'Business' then case period_name when 'monthly' then 20000 when 'annual' then 200000 end when 'Professional' then case period_name when 'monthly' then 50000 when 'annual' then 500000 end end;
  if price is null then raise exception 'invalid plan' using errcode='22023';end if;
  select * into q from public.sec_module_requests where request_id=p_target and organization_id=p_org and site_id=p_site and reporter_id=auth.uid() and kind='payment' for update;
  if not found then raise exception 'request denied' using errcode='42501';end if;
  select * into p from public.sec_payment_receipts where organization_id=p_org and site_id=p_site and channel=q.payload->>'channel' and reference=q.payload->>'reference' and amount_fcfa=price and amount_fcfa=(q.payload->>'amount_fcfa')::bigint and provider_confirmed_at<=now() for update;
  if not found then raise exception 'unmatched receipt' using errcode='22023';end if;
  -- One paid timeline per organization; never charge each Business/Professional site separately.
  perform pg_advisory_xact_lock(hashtextextended(p_org::text,3));
  select greatest(now(),coalesce(max(ends_at),now())) into starts from public.sec_subscriptions where organization_id=p_org;
  -- Keep previously paid periods immutable; a different plan starts only at the next boundary.
  ends:=starts+case period_name when 'monthly' then interval '1 month' else interval '1 year' end;
  insert into public.sec_subscriptions(id,organization_id,site_id,receipt_id,request_id,plan,period,starts_at,ends_at) values(p_event,p_org,p_site,p.id,q.request_id,plan_name,period_name,starts,ends);
  out:=jsonb_build_object('target_id',p_target,'state','allocated','plan',plan_name,'starts_at',starts,'ends_at',ends);
 when 'evidence_store' then
  if p_target is not null or p_detail-'reference'-'digest'-'base64'<>'{}'::jsonb or coalesce(p_detail->>'reference','') !~ '^[A-Za-z0-9._-]{1,80}$' or coalesce(p_detail->>'digest','') !~ '^[a-f0-9]{64}$' or coalesce(p_detail->>'base64','') !~ '^[A-Za-z0-9+/]+={0,2}$' then raise exception 'invalid evidence' using errcode='22023';end if;
  b:=decode(p_detail->>'base64','base64');digest_value:=encode(sha256(b),'hex');
  if octet_length(b) not between 1 and 262144 or digest_value<>p_detail->>'digest' then raise exception 'digest mismatch' using errcode='22023';end if;
  insert into public.sec_evidence_files(id,organization_id,site_id,owner_id,reference,digest,size_bytes) values(p_event,p_org,p_site,auth.uid(),p_detail->>'reference',digest_value,octet_length(b));
  insert into sec_private.evidence_content values(p_event,b);
  out:=jsonb_build_object('target_id',p_event,'state','stored','digest',digest_value);
 when 'snapshot_create' then
  if p_target is not null or p_detail<>'{}'::jsonb then raise exception 'invalid snapshot' using errcode='22023';end if;
  select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) into prefs from public.sec_preferences where organization_id=p_org and site_id=p_site and user_id=auth.uid();
  digest_value:=encode(sha256(convert_to(prefs::text,'UTF8')),'hex');
  insert into public.sec_preference_snapshots(id,organization_id,site_id,user_id,digest,preferences) values(p_event,p_org,p_site,auth.uid(),digest_value,prefs);
  out:=jsonb_build_object('target_id',p_event,'state','saved','digest',digest_value);
 when 'snapshot_restore' then
  if p_detail<>'{"confirm":true}'::jsonb then raise exception 'confirmation required' using errcode='22023';end if;
  select * into snapshot from public.sec_preference_snapshots where id=p_target and organization_id=p_org and site_id=p_site and user_id=auth.uid();
  if not found then raise exception 'snapshot denied' using errcode='42501';end if;
  if snapshot.digest<>encode(sha256(convert_to(snapshot.preferences::text,'UTF8')),'hex') then raise exception 'digest mismatch' using errcode='22023';end if;
  delete from public.sec_preferences where organization_id=p_org and site_id=p_site and user_id=auth.uid();
  insert into public.sec_preferences(organization_id,site_id,user_id,key,value) select p_org,p_site,auth.uid(),key,value from jsonb_each_text(snapshot.preferences);
  out:=jsonb_build_object('target_id',p_target,'state','preferences_restored','digest',snapshot.digest);
 when 'integration_revoke' then
  if p_detail-'device_id'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  device:=(p_detail->>'device_id')::uuid;
  update sec_private.gateway_bindings set enabled=false where gateway_id=p_target and device_id=device and organization_id=p_org and site_id=p_site;
  if not found then raise exception 'binding denied' using errcode='42501';end if;
  out:=jsonb_build_object('target_id',p_target,'state','revoked','device_id',device);
 else raise exception 'unknown action' using errcode='22023';
 end case;
 out:=out||jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_operation);
 insert into public.sec_service_action_log(id,organization_id,site_id,actor_id,operation,target_id,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),p_operation,p_target,h,out);
 return out;
end $action$;
create function sec_private.evidence_download(p_org uuid,p_site uuid,p_id uuid) returns jsonb language sql stable security definer set search_path=pg_catalog as $q$
 select jsonb_build_object('id',f.id,'digest',f.digest,'base64',replace(encode(c.content,'base64'),E'\n',''))
 from public.sec_evidence_files f join sec_private.evidence_content c using(id)
 where f.id=p_id and f.organization_id=p_org and f.site_id=p_site and f.owner_id=auth.uid() and sec_private.field_role(p_org,p_site) in ('owner','manager','operator')
$q$;
revoke all on function sec_private.site_members(uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.site_members(uuid,uuid) to authenticated;
create function public.sec_site_members(p_org uuid,p_site uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.site_members(p_org,p_site)$rpc$;
revoke all on function public.sec_site_members(uuid,uuid) from public,anon;
grant execute on function public.sec_site_members(uuid,uuid) to authenticated;
revoke all on function sec_private.integration_list(uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.integration_list(uuid,uuid) to authenticated;
create function public.sec_integration_list(p_org uuid,p_site uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.integration_list(p_org,p_site)$rpc$;
revoke all on function public.sec_integration_list(uuid,uuid) from public,anon;
grant execute on function public.sec_integration_list(uuid,uuid) to authenticated;
revoke all on function sec_private.service_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.service_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create function public.sec_service_action(p_org uuid,p_site uuid,p_event uuid,p_operation text,p_target uuid,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.service_action(p_org,p_site,p_event,p_operation,p_target,p_detail)$rpc$;
revoke all on function public.sec_service_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.sec_service_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
revoke all on function sec_private.evidence_download(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.evidence_download(uuid,uuid,uuid) to authenticated;
create function public.sec_evidence_download(p_org uuid,p_site uuid,p_id uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.evidence_download(p_org,p_site,p_id)$rpc$;
revoke all on function public.sec_evidence_download(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_evidence_download(uuid,uuid,uuid) to authenticated;
commit;
