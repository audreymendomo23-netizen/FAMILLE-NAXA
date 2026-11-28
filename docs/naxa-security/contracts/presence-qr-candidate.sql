-- One-time, worker-specific QR challenge plus fresh GPS declaration; independent manager review remains mandatory.
begin;
create table sec_private.presence_challenges(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,shift_id uuid not null references public.sec_shifts(id),worker_id uuid not null references auth.users(id),issuer_id uuid not null references auth.users(id),
 action text not null check(action in ('arrival','departure','pause_start','pause_end')),digest text not null unique check(digest ~ '^[a-f0-9]{64}$'),
 issued_at timestamptz not null default now(),expires_at timestamptz not null,used_event uuid unique,used_hash text,used_receipt jsonb,
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),check(worker_id<>issuer_id),check(expires_at>issued_at and expires_at<=issued_at+interval '120 seconds'),
 check((used_event is null and used_hash is null and used_receipt is null) or (used_event is not null and used_hash is not null and used_receipt is not null))
);
revoke all on sec_private.presence_challenges from public,anon,authenticated;
alter table public.sec_attendance_drafts add column qr_challenge_id uuid references sec_private.presence_challenges(id);
create unique index sec_attendance_qr_once on public.sec_attendance_drafts(qr_challenge_id) where qr_challenge_id is not null;
create function sec_private.presence_qr(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;sh public.sec_shifts%rowtype;v sec_private.presence_challenges%rowtype;token text;h text;op_action text;lat double precision;lon double precision;accuracy double precision;obs timestamptz;src text;mock boolean;draft uuid;result jsonb;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') or p_event is null or p_target is null or p_op is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>2048 then raise exception 'denied' using errcode='42501';end if;
 token:=p_detail->>'token';
 if token is null or token !~ '^[a-f0-9]{64}$' then raise exception 'invalid token' using errcode='22023';end if;
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,411));
 if p_op='issue' then
  if r not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
  if p_detail-'token'-'action'<>'{}'::jsonb then raise exception 'unknown fields' using errcode='22023';end if;
  op_action:=p_detail->>'action';
  if op_action is null or op_action not in ('arrival','departure','pause_start','pause_end') then raise exception 'invalid action' using errcode='22023';end if;
  select * into sh from public.sec_shifts where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found or sh.agent_id=auth.uid() then raise exception 'shift denied' using errcode='42501';end if;
  select * into v from sec_private.presence_challenges where id=p_event;
  if found then
   if v.organization_id<>p_org or v.site_id<>p_site or v.shift_id<>p_target or v.issuer_id<>auth.uid() or v.action<>op_action or v.digest<>encode(sha256(convert_to(token,'UTF8')),'hex') then raise exception 'event conflict' using errcode='23505';end if;
  else
   if sh.state<>'accepted' or (now()<sh.starts_at or now()>=sh.ends_at) or not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships m using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=sh.agent_id and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'shift unavailable' using errcode='42501';end if;
   if exists(select 1 from sec_private.presence_challenges where shift_id=sh.id and action=op_action and used_event is null and expires_at>now()) then raise exception 'active challenge exists' using errcode='23505';end if;
   insert into sec_private.presence_challenges(id,organization_id,site_id,shift_id,worker_id,issuer_id,action,digest,expires_at) values(p_event,p_org,p_site,sh.id,sh.agent_id,auth.uid(),op_action,encode(sha256(convert_to(token,'UTF8')),'hex'),least(now()+interval '120 seconds',sh.ends_at)) returning * into v;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'presence_qr_issue',v.id);
  end if;
  result:=jsonb_build_object('challenge_id',v.id,'shift_id',v.shift_id,'action',v.action,'expires_at',v.expires_at,'state','issued');
 elsif p_op='consume' then
  if p_detail-'token'-'lat'-'lon'-'accuracy_m'-'observed_at'-'source'-'mock_reported'<>'{}'::jsonb then raise exception 'unknown fields' using errcode='22023';end if;
  select * into v from sec_private.presence_challenges where id=p_target and organization_id=p_org and site_id=p_site and worker_id=auth.uid() for update;
  if not found or v.digest<>encode(sha256(convert_to(token,'UTF8')),'hex') then raise exception 'challenge denied' using errcode='42501';end if;
  if v.used_event is not null then
   if v.used_event=p_event and v.used_hash=h then return v.used_receipt;end if;
   raise exception 'challenge consumed' using errcode='42501';
  end if;
  if v.expires_at<=now() then raise exception 'challenge expired' using errcode='42501';end if;
  select * into sh from public.sec_shifts where id=v.shift_id and organization_id=p_org and site_id=p_site for update;
  if not found or sh.agent_id<>auth.uid() or sh.state<>'accepted' or now() not between sh.starts_at and sh.ends_at then raise exception 'shift unavailable' using errcode='42501';end if;
  if jsonb_typeof(p_detail->'lat') is distinct from 'number' or jsonb_typeof(p_detail->'lon') is distinct from 'number' or jsonb_typeof(p_detail->'accuracy_m') is distinct from 'number' or jsonb_typeof(p_detail->'observed_at') is distinct from 'string' then raise exception 'invalid GPS' using errcode='22023';end if;
  lat:=(p_detail->>'lat')::double precision;lon:=(p_detail->>'lon')::double precision;accuracy:=(p_detail->>'accuracy_m')::double precision;obs:=(p_detail->>'observed_at')::timestamptz;src:=p_detail->>'source';mock:=(p_detail->>'mock_reported')::boolean;
  if obs is null or lat is null or lon is null or accuracy is null or lat not between -90 and 90 or lon not between -180 and 180 or accuracy<=0 or accuracy>100 or obs not between greatest(now()-interval '120 seconds',sh.starts_at) and now() or not coalesce((src='browser' and mock is null) or (src='android' and mock is false),false) then raise exception 'invalid GPS declaration' using errcode='22023';end if;
  insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,source,mock_reported,qr_challenge_id)
  values(p_org,p_site,auth.uid(),p_event,v.action,lat,lon,accuracy,obs,src,mock,v.id) returning id into draft;
  result:=jsonb_build_object('challenge_id',v.id,'shift_id',v.shift_id,'action',v.action,'draft_id',draft,'state','pending_review','organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'event_id',p_event,'operation',p_op,'physical_presence_certified',false);
  update sec_private.presence_challenges set used_event=p_event,used_hash=h,used_receipt=result where id=v.id;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'presence_qr_consume',v.id);
  return result;
 else raise exception 'invalid operation' using errcode='22023';end if;
 return result||jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'event_id',p_event,'operation',p_op,'physical_presence_certified',false);
end $f$;
revoke all on function sec_private.presence_qr(uuid,uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.presence_qr(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create function public.sec_presence_qr(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.presence_qr(p_org,p_site,p_event,p_op,p_target,p_detail)$r$;
revoke all on function public.sec_presence_qr(uuid,uuid,uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.sec_presence_qr(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
commit;
