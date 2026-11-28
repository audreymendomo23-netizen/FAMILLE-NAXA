-- Isolated operational lifecycle. No device actuation, no emergency dispatch.
begin;
create function sec_private.field_role(p_org uuid,p_site uuid) returns text language sql stable security definer set search_path=pg_catalog as $role$
 select m.role from public.sec_memberships m
 join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id
 join public.sec_sites s on s.organization_id=sm.organization_id and s.id=sm.site_id
 join public.sec_organizations o on o.id=s.organization_id
 where m.user_id=auth.uid() and m.organization_id=p_org and sm.site_id=p_site and m.active and sm.active and s.active and o.active
$role$;
revoke all on function sec_private.field_role(uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.field_role(uuid,uuid) to authenticated;
alter table public.sec_attendance_drafts drop constraint sec_attendance_drafts_state_check;
alter table public.sec_attendance_drafts add constraint sec_attendance_review_state check(state in ('pending_review','reviewed','rejected'));
create table public.sec_patrols(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 agent_id uuid not null references auth.users(id),created_by uuid not null references auth.users(id),
 label text not null check(length(trim(label)) between 1 and 120),starts_at timestamptz,ends_at timestamptz,check((starts_at is null and ends_at is null) or (starts_at is not null and ends_at is not null and ends_at>starts_at and ends_at-starts_at<=interval '24 hours')),checkpoints text[] not null check(cardinality(checkpoints) between 1 and 30),
 state text not null default 'planned' check(state in ('planned','running','submitted','reviewed','cancelled')),
 created_at timestamptz not null default now(),started_at timestamptz,submitted_at timestamptz,reviewed_at timestamptz,reviewed_by uuid references auth.users(id),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_patrol_checks(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 patrol_id uuid not null references public.sec_patrols(id),checkpoint_index integer not null check(checkpoint_index between 1 and 30),
 agent_id uuid not null references auth.users(id),note text not null check(length(trim(note)) between 1 and 500),
 created_at timestamptz not null default now(),unique(patrol_id,checkpoint_index),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_service_register add column cancelled_at timestamptz,add column cancelled_by uuid references auth.users(id),add constraint sec_register_cancel_pair check((cancelled_at is null)=(cancelled_by is null));
create table public.sec_passage_logs(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 register_id uuid not null references public.sec_service_register(id),actor_id uuid not null references auth.users(id),
 direction text not null check(direction in ('entry','exit')),sequence bigint generated always as identity,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_internal_safety(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 reporter_id uuid not null references auth.users(id),detail text not null check(length(trim(detail)) between 1 and 500),
 state text not null default 'reported' check(state in ('reported','acknowledged','closed')),
 created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_field_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,actor_id uuid not null references auth.users(id),
 operation text not null,target_id uuid,detail jsonb not null,result jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_patrols enable row level security;
revoke all on public.sec_patrols from public,anon,authenticated;
grant select on public.sec_patrols to authenticated;
alter table public.sec_patrol_checks enable row level security;
revoke all on public.sec_patrol_checks from public,anon,authenticated;
grant select on public.sec_patrol_checks to authenticated;
alter table public.sec_passage_logs enable row level security;
revoke all on public.sec_passage_logs from public,anon,authenticated;
grant select on public.sec_passage_logs to authenticated;
alter table public.sec_internal_safety enable row level security;
revoke all on public.sec_internal_safety from public,anon,authenticated;
grant select on public.sec_internal_safety to authenticated;
alter table public.sec_field_events enable row level security;
revoke all on public.sec_field_events from public,anon,authenticated;
grant select on public.sec_field_events to authenticated;
create policy sec_patrol_read on public.sec_patrols for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (agent_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create policy sec_patrol_check_read on public.sec_patrol_checks for select to authenticated using(exists(select 1 from public.sec_patrols p where p.id=patrol_id and p.organization_id=sec_patrol_checks.organization_id and p.site_id=sec_patrol_checks.site_id));
create policy sec_passage_read on public.sec_passage_logs for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create policy sec_safety_read on public.sec_internal_safety for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (reporter_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create policy sec_field_event_read on public.sec_field_events for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (actor_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
-- Managers can review attendance for their own active site; raw position is never exposed to viewers.
create policy sec_attendance_manager on public.sec_attendance_drafts for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager'));
-- Narrow field commands with server-side state transitions, lock, idempotent receipts and audit.
create function sec_private.field_action(p_org uuid,p_site uuid,p_event uuid,p_operation text,p_target uuid,p_detail jsonb) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $action$
declare role_name text; prior public.sec_field_events%rowtype; receipt jsonb; current_state text; next_state text; reason text; target uuid; agent uuid; points text[]; idx integer; p public.sec_patrols%rowtype; reg public.sec_service_register%rowtype; last_direction text; who uuid; record_id uuid; st timestamptz; en timestamptz;
begin
 role_name:=sec_private.field_role(p_org,p_site);
 if role_name is null or role_name not in ('owner','manager','operator') or auth.uid() is null or p_event is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>4096 then raise exception 'field denied' using errcode='42501';end if;
 -- Serialize same actor event ID even across concurrent requests.
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,0));
 select * into prior from public.sec_field_events where id=p_event;
 if found then
  if prior.actor_id<>auth.uid() or prior.organization_id<>p_org or prior.site_id<>p_site or prior.operation<>p_operation or prior.target_id is distinct from p_target or prior.detail<>p_detail then raise exception 'event conflict' using errcode='23505';end if;
  return prior.result;
 end if;
 reason:=trim(coalesce(p_detail->>'reason',''));
 if p_operation not in ('patrol_create') and (length(reason) not between 1 and 500 or reason ~ '[[:cntrl:]]') then raise exception 'reason required' using errcode='22023';end if;
 if p_operation in ('incident','work','attendance','patrol_create','patrol_review','patrol_cancel','patrol_replace','safety_ack','safety_close') and role_name not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 if p_operation in ('incident','work','attendance') then
  if p_detail - 'reason' - 'next' <> '{}'::jsonb then raise exception 'unknown field' using errcode='22023';end if;
  next_state:=p_detail->>'next';
  if p_operation='incident' then
   select state into current_state from public.sec_incidents where id=p_target and organization_id=p_org and site_id=p_site and priority<>'P1' for update;
   if not found then raise exception 'incident unavailable' using errcode='42501';end if;
   if not coalesce((current_state,next_state) in (('new','review'),('review','confirmed'),('confirmed','assigned'),('assigned','in_progress'),('in_progress','resolved'),('resolved','closed'),('closed','reopened'),('reopened','review')),false) then raise exception 'invalid transition' using errcode='22023';end if;
   update public.sec_incidents set state=next_state where id=p_target;
  elsif p_operation='work' then
   select state into current_state from public.sec_work_orders where id=p_target and organization_id=p_org and site_id=p_site for update;
   if not found then raise exception 'work unavailable' using errcode='42501';end if;
   if not coalesce((current_state,next_state) in (('requested','assigned'),('requested','cancelled'),('assigned','in_progress'),('assigned','cancelled'),('in_progress','completed')),false) then raise exception 'invalid transition' using errcode='22023';end if;
   update public.sec_work_orders set state=next_state where id=p_target;
  else
   select state,reporter_id into current_state,who from public.sec_attendance_drafts where id=p_target and organization_id=p_org and site_id=p_site for update;
   if not found or who=auth.uid() then raise exception 'attendance review denied' using errcode='42501';end if;
   if current_state<>'pending_review' or next_state is null or next_state not in ('reviewed','rejected') then raise exception 'invalid review' using errcode='22023';end if;
   update public.sec_attendance_drafts set state=next_state where id=p_target;
  end if;
  receipt:=jsonb_build_object('target_id',p_target,'state',next_state);
 elsif p_operation='patrol_create' then
  if p_target is not null or p_detail-'label'-'agent_id'-'checkpoints'-'starts_at'-'ends_at'<>'{}'::jsonb or jsonb_typeof(p_detail->'checkpoints') is distinct from 'array' then raise exception 'invalid patrol' using errcode='22023';end if;
  agent:=(p_detail->>'agent_id')::uuid;
  if not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships m using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=agent and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'agent unavailable' using errcode='42501';end if;
  select array_agg(trim(value)) into points from jsonb_array_elements_text(p_detail->'checkpoints');
  if coalesce(cardinality(points),0) not between 1 and 30 or exists(select 1 from unnest(points) t(v) where length(v) not between 1 and 120 or v ~ '[[:cntrl:]]') or (select count(distinct v) from unnest(points) t(v))<>cardinality(points) then raise exception 'invalid checkpoints' using errcode='22023';end if;
  st:=(p_detail->>'starts_at')::timestamptz;en:=(p_detail->>'ends_at')::timestamptz;
  if (st is null)<>(en is null) or (st is not null and (st<now()-interval '1 minute' or en<=st or en-st>interval '24 hours')) then raise exception 'invalid patrol window' using errcode='22023';end if;
  insert into public.sec_patrols(organization_id,site_id,agent_id,created_by,label,checkpoints,starts_at,ends_at) values(p_org,p_site,agent,auth.uid(),trim(p_detail->>'label'),points,st,en) returning id into target;
  receipt:=jsonb_build_object('target_id',target,'state','planned');
 elsif p_operation='patrol_replace' then
  if p_detail-'reason'-'agent_id'<>'{}'::jsonb then raise exception 'invalid replacement' using errcode='22023';end if;
  select * into p from public.sec_patrols where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found then raise exception 'patrol denied' using errcode='42501';end if;
  agent:=(p_detail->>'agent_id')::uuid;
  if p.state<>'planned' or (p.ends_at is not null and p.ends_at<=now()) or agent=p.agent_id or not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships m using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=agent and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'invalid replacement' using errcode='22023';end if;
  update public.sec_patrols set agent_id=agent where id=p.id;
  receipt:=jsonb_build_object('target_id',p.id,'state','planned','previous_agent_id',p.agent_id,'agent_id',agent);
 elsif p_operation='patrol_anomaly' then
  if p_detail-'reason'<>'{}'::jsonb then raise exception 'invalid anomaly' using errcode='22023';end if;
  select * into p from public.sec_patrols where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found or (role_name='operator' and p.agent_id<>auth.uid()) then raise exception 'patrol denied' using errcode='42501';end if;
  if p.state not in ('planned','running','submitted') then raise exception 'patrol closed' using errcode='22023';end if;
  receipt:=jsonb_build_object('target_id',p.id,'state',p.state,'anomaly_recorded',true);
 elsif p_operation in ('patrol_start','patrol_check','patrol_submit','patrol_review','patrol_cancel') then
  if p_detail-'reason'-(case when p_operation='patrol_check' then 'index' else 'reason' end)<>'{}'::jsonb then raise exception 'unknown field' using errcode='22023';end if;
  select * into p from public.sec_patrols where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found then raise exception 'patrol denied' using errcode='42501';end if;
  if p_operation in ('patrol_start','patrol_check','patrol_submit') and p.agent_id<>auth.uid() then raise exception 'agent required' using errcode='42501';end if;
  if p_operation='patrol_start' and p.state='planned' and (p.starts_at is null or now()>=p.starts_at and now()<p.ends_at) then next_state:='running';
  elsif p_operation='patrol_check' and p.state='running' then
   idx:=(p_detail->>'index')::integer;
   if idx is null or idx<1 or idx>cardinality(p.checkpoints) or idx<>(select count(*)+1 from public.sec_patrol_checks where patrol_id=p.id) then raise exception 'checkpoint order' using errcode='22023';end if;
   insert into public.sec_patrol_checks(organization_id,site_id,patrol_id,checkpoint_index,agent_id,note) values(p_org,p_site,p.id,idx,auth.uid(),reason);
   next_state:='running';
  elsif p_operation='patrol_submit' and p.state='running' and (select count(*) from public.sec_patrol_checks where patrol_id=p.id)=cardinality(p.checkpoints) then next_state:='submitted';
  elsif p_operation='patrol_review' and p.state='submitted' and p.agent_id<>auth.uid() then next_state:='reviewed';
  elsif p_operation='patrol_cancel' and p.state in ('planned','running','submitted') then next_state:='cancelled';
  else raise exception 'invalid patrol transition' using errcode='22023';end if;
  update public.sec_patrols set state=next_state,started_at=case when p_operation='patrol_start' then now() else started_at end,submitted_at=case when p_operation='patrol_submit' then now() else submitted_at end,reviewed_at=case when p_operation='patrol_review' then now() else reviewed_at end,reviewed_by=case when p_operation='patrol_review' then auth.uid() else reviewed_by end where id=p.id;
  receipt:=jsonb_build_object('target_id',p.id,'state',next_state,'manual_checkpoints_only',true,'late',p.ends_at is not null and now()>p.ends_at);
 elsif p_operation='passage' then
  if p_detail-'reason'-'direction'<>'{}'::jsonb then raise exception 'unknown field' using errcode='22023';end if;
  select * into reg from public.sec_service_register where id=p_target and organization_id=p_org and site_id=p_site and kind in ('visitor','vehicle') for update;
  if not found then raise exception 'register unavailable' using errcode='42501';end if;
  next_state:=p_detail->>'direction';
  select direction into last_direction from public.sec_passage_logs where register_id=reg.id order by sequence desc limit 1;
  if next_state is null or next_state not in ('entry','exit') or (next_state='entry' and last_direction is not distinct from 'entry') or (next_state='exit' and last_direction is distinct from 'entry') then raise exception 'invalid passage sequence' using errcode='22023';end if;
  if next_state='entry' and (reg.cancelled_at is not null or now()>reg.recorded_at+make_interval(mins=>(reg.details->>'duration_minutes')::integer)) then raise exception 'visit period expired' using errcode='22023';end if;
  insert into public.sec_passage_logs(organization_id,site_id,register_id,actor_id,direction) values(p_org,p_site,reg.id,auth.uid(),next_state) returning id into record_id;
  receipt:=jsonb_build_object('target_id',reg.id,'state',next_state,'record_id',record_id,'physical_access',false);
 elsif p_operation='safety_report' then
  if p_target is not null or p_detail-'reason'<>'{}'::jsonb then raise exception 'invalid safety report' using errcode='22023';end if;
  insert into public.sec_internal_safety(organization_id,site_id,reporter_id,detail) values(p_org,p_site,auth.uid(),reason) returning id into target;
  receipt:=jsonb_build_object('target_id',target,'state','reported','external_dispatch',false);
 elsif p_operation in ('safety_ack','safety_close') then
  if p_detail-'reason'<>'{}'::jsonb then raise exception 'unknown field' using errcode='22023';end if;
  select state,reporter_id into current_state,who from public.sec_internal_safety where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found or who=auth.uid() then raise exception 'review denied' using errcode='42501';end if;
  if p_operation='safety_ack' and current_state='reported' then next_state:='acknowledged';
  elsif p_operation='safety_close' and current_state='acknowledged' then next_state:='closed';
  else raise exception 'invalid safety transition' using errcode='22023';end if;
  update public.sec_internal_safety set state=next_state where id=p_target;
  receipt:=jsonb_build_object('target_id',p_target,'state',next_state,'external_dispatch',false);
 else raise exception 'unsupported operation' using errcode='22023';end if;
 receipt:=receipt||jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_operation);
 insert into public.sec_field_events(id,organization_id,site_id,actor_id,operation,target_id,detail,result) values(p_event,p_org,p_site,auth.uid(),p_operation,p_target,p_detail,receipt);
 return receipt;
end $action$;
revoke all on function sec_private.field_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.field_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create function public.sec_field_action(p_org uuid,p_site uuid,p_event uuid,p_operation text,p_target uuid,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.field_action(p_org,p_site,p_event,p_operation,p_target,p_detail)$rpc$;
revoke all on function public.sec_field_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.sec_field_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
commit;
