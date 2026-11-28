-- Disposable candidate. A pass authorizes a manual registry check, never a lock or barrier.
begin;
create table public.sec_visit_passes(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,register_id uuid not null references public.sec_service_register(id),
 created_by uuid not null references auth.users(id),issued_at timestamptz not null default now(),expires_at timestamptz not null,
 used_at timestamptz,revoked_at timestamptz,check(expires_at>issued_at),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table sec_private.visit_pass_hashes(pass_id uuid primary key references public.sec_visit_passes(id),digest text not null unique check(digest ~ '^[a-f0-9]{64}$'));
revoke all on sec_private.visit_pass_hashes from public,anon,authenticated;
alter table public.sec_visit_passes enable row level security;
revoke all on public.sec_visit_passes from public,anon,authenticated;
grant select on public.sec_visit_passes to authenticated;
create policy visit_pass_read on public.sec_visit_passes for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager'));
create function sec_private.visit_pass(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;v public.sec_visit_passes%rowtype;reg public.sec_service_register%rowtype;prior public.sec_service_action_log%rowtype;h text;token text;expiry timestamptz;out jsonb;passage_id uuid;last_direction text;reg_id uuid;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') or p_event is null or p_target is null or p_op is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>1024 then raise exception 'denied' using errcode='42501';end if;
 if p_op in ('issue','revoke') and r not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,11));
 select * into prior from public.sec_service_action_log where id=p_event;
 if found then
  if prior.actor_id<>auth.uid() or prior.organization_id<>p_org or prior.site_id<>p_site or prior.operation<>'visit_'||p_op or prior.target_id<>p_target or prior.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;return prior.receipt;
 end if;
 if p_op='issue' then
  if p_detail-'token'-'minutes'<>'{}'::jsonb or jsonb_typeof(p_detail->'minutes') is distinct from 'number' or (p_detail->>'minutes') !~ '^[0-9]+$' then raise exception 'invalid pass' using errcode='22023';end if;
  token:=p_detail->>'token';
  if token is null or token !~ '^[a-f0-9]{64}$' or (p_detail->>'minutes')::integer not between 1 and 120 then raise exception 'invalid pass' using errcode='22023';end if;
  select * into reg from public.sec_service_register where id=p_target and organization_id=p_org and site_id=p_site and kind in ('visitor','vehicle') for update;
  if not found or reg.cancelled_at is not null then raise exception 'register denied' using errcode='42501';end if;
  expiry:=least(now()+make_interval(mins=>(p_detail->>'minutes')::integer),reg.recorded_at+make_interval(mins=>(reg.details->>'duration_minutes')::integer));
  if expiry<=now() then raise exception 'expired visit' using errcode='22023';end if;
  if exists(select 1 from public.sec_visit_passes where register_id=reg.id and used_at is null and revoked_at is null and expires_at>now()) then raise exception 'active pass exists' using errcode='23505';end if;
  insert into public.sec_visit_passes(id,organization_id,site_id,register_id,created_by,expires_at) values(p_event,p_org,p_site,reg.id,auth.uid(),expiry) returning * into v;
  insert into sec_private.visit_pass_hashes values(v.id,encode(sha256(convert_to(token,'UTF8')),'hex'));
 elsif p_op in ('consume','consume_entry') then
  if p_detail-'token'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  token:=p_detail->>'token';
  if token is null or token !~ '^[a-f0-9]{64}$' then raise exception 'invalid pass' using errcode='22023';end if;
  -- Lock the register first, like field passage and issuance; serialize the two workflows.
  select register_id into reg_id from public.sec_visit_passes where id=p_target and organization_id=p_org and site_id=p_site;
  if not found then raise exception 'pass not available' using errcode='42501';end if;
  select * into reg from public.sec_service_register where id=reg_id and organization_id=p_org and site_id=p_site for update;
  if not found or reg.cancelled_at is not null then raise exception 'pass not available' using errcode='42501';end if;
  select * into v from public.sec_visit_passes where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found or v.revoked_at is not null or v.used_at is not null or v.expires_at<=now() or not exists(select 1 from sec_private.visit_pass_hashes where pass_id=v.id and digest=encode(sha256(convert_to(token,'UTF8')),'hex')) then raise exception 'pass not available' using errcode='42501';end if;
  if p_op='consume_entry' then
   select direction into last_direction from public.sec_passage_logs where register_id=reg.id order by sequence desc limit 1;
   if last_direction='entry' or now()>reg.recorded_at+make_interval(mins=>(reg.details->>'duration_minutes')::integer) then raise exception 'entry unavailable' using errcode='22023';end if;
   insert into public.sec_passage_logs(organization_id,site_id,register_id,actor_id,direction) values(p_org,p_site,reg.id,auth.uid(),'entry') returning id into passage_id;
  end if;
  update public.sec_visit_passes set used_at=now() where id=v.id returning * into v;
 elsif p_op='revoke' then
  if p_detail<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  select * into v from public.sec_visit_passes where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found or v.used_at is not null then raise exception 'pass not available' using errcode='42501';end if;
  update public.sec_visit_passes set revoked_at=coalesce(revoked_at,now()) where id=v.id returning * into v;
 else raise exception 'unknown action' using errcode='22023';end if;
 out:=jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'pass_id',v.id,'register_id',v.register_id,'expires_at',v.expires_at,'state',case p_op when 'issue' then 'issued' when 'consume' then 'checked' when 'consume_entry' then 'entered' else 'revoked' end,'physical_access',false);
 if p_op='consume_entry' then out:=out||jsonb_build_object('passage_id',passage_id);end if;
 insert into public.sec_service_action_log(id,organization_id,site_id,actor_id,operation,target_id,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),'visit_'||p_op,p_target,h,out);
 return out;
end $f$;
revoke all on function sec_private.visit_pass(uuid,uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.visit_pass(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create function public.sec_visit_pass(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.visit_pass(p_org,p_site,p_event,p_op,p_target,p_detail)$r$;
revoke all on function public.sec_visit_pass(uuid,uuid,uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.sec_visit_pass(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
commit;
