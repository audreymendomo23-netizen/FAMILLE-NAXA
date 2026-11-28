-- ERP shift scheduling and maintenance execution in disposable PostgreSQL.
begin;
create table public.sec_shifts(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,agent_id uuid not null references auth.users(id),created_by uuid not null references auth.users(id),
 label text not null check(length(trim(label)) between 1 and 120),starts_at timestamptz not null,ends_at timestamptz not null,
 state text not null default 'planned' check(state in ('planned','accepted','completed','cancelled')),created_at timestamptz not null default now(),
 check(ends_at>starts_at and ends_at-starts_at<=interval '24 hours'),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create index sec_shifts_agent on public.sec_shifts(organization_id,agent_id,starts_at,ends_at);
create table public.sec_maintenance_details(
 order_id uuid primary key references public.sec_work_orders(id),organization_id uuid not null,site_id uuid not null,device_id uuid not null,
 technician_id uuid not null references auth.users(id),scheduled_at timestamptz not null,diagnosis text,completed_at timestamptz,
 cost_fcfa bigint check(cost_fcfa between 0 and 100000000),reviewer_id uuid references auth.users(id),reviewed_at timestamptz,
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id)
);
create table public.sec_erp_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,actor_id uuid not null references auth.users(id),operation text not null,target_id uuid,detail_hash text not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_shifts enable row level security;
revoke all on public.sec_shifts from public,anon,authenticated;
grant select on public.sec_shifts to authenticated;
alter table public.sec_maintenance_details enable row level security;
revoke all on public.sec_maintenance_details from public,anon,authenticated;
grant select on public.sec_maintenance_details to authenticated;
alter table public.sec_erp_events enable row level security;
revoke all on public.sec_erp_events from public,anon,authenticated;
grant select on public.sec_erp_events to authenticated;
create policy sec_shift_read on public.sec_shifts for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (agent_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create policy sec_maintenance_detail_read on public.sec_maintenance_details for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (technician_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create policy sec_erp_event_read on public.sec_erp_events for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (actor_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create function sec_private.erp_action(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;old public.sec_erp_events%rowtype;h text;out jsonb;sh public.sec_shifts%rowtype;w public.sec_work_orders%rowtype;m public.sec_maintenance_details%rowtype;agent uuid;dev uuid;st timestamptz;en timestamptz;label_value text;diag text;amount bigint;next_state text;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') or p_event is null or p_op is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>4096 then raise exception 'denied' using errcode='42501';end if;
 if p_op in ('shift_create','shift_cancel','maintenance_assign','maintenance_review') and r not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');perform pg_advisory_xact_lock(hashtextextended(p_event::text,9));
 select * into old from public.sec_erp_events where id=p_event;
 if found then
  if old.organization_id<>p_org or old.site_id<>p_site or old.actor_id<>auth.uid() or old.operation<>p_op or old.target_id is distinct from p_target or old.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;return old.receipt;
 end if;
 if p_op='shift_create' then
  if p_target is not null or p_detail-'agent_id'-'label'-'starts_at'-'ends_at'<>'{}'::jsonb then raise exception 'invalid shift' using errcode='22023';end if;
  agent:=(p_detail->>'agent_id')::uuid;st:=(p_detail->>'starts_at')::timestamptz;en:=(p_detail->>'ends_at')::timestamptz;label_value:=trim(coalesce(p_detail->>'label',''));
  if st is null or en is null or st<now()-interval '1 minute' or en<=st or en-st>interval '24 hours' or length(label_value) not between 1 and 120 then raise exception 'invalid schedule' using errcode='22023';end if;
  if not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships x using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=agent and sm.active and x.active and x.role in ('owner','manager','operator')) then raise exception 'agent denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||agent::text,10));
  if exists(select 1 from public.sec_shifts where organization_id=p_org and agent_id=agent and state<>'cancelled' and starts_at<en and ends_at>st) then raise exception 'shift overlap' using errcode='23505';end if;
  insert into public.sec_shifts(id,organization_id,site_id,agent_id,created_by,label,starts_at,ends_at) values(p_event,p_org,p_site,agent,auth.uid(),label_value,st,en);
  out:=jsonb_build_object('target_id',p_event,'state','planned');
 elsif p_op in ('shift_accept','shift_complete','shift_cancel') then
  if p_detail<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  select * into sh from public.sec_shifts where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found then raise exception 'shift denied' using errcode='42501';end if;
  if p_op='shift_accept' and sh.agent_id=auth.uid() and sh.state='planned' and now()<sh.ends_at then next_state:='accepted';
  elsif p_op='shift_complete' and sh.agent_id=auth.uid() and sh.state='accepted' and now()>=sh.ends_at then next_state:='completed';
  elsif p_op='shift_cancel' and sh.state in ('planned','accepted') then next_state:='cancelled';
  else raise exception 'invalid shift transition' using errcode='22023';end if;
  update public.sec_shifts set state=next_state where id=sh.id;out:=jsonb_build_object('target_id',sh.id,'state',next_state,'attendance_certified',false);
 elsif p_op in ('maintenance_assign','maintenance_start','maintenance_complete','maintenance_review') then
  select * into w from public.sec_work_orders where id=p_target and organization_id=p_org and site_id=p_site for update;
  if not found then raise exception 'order denied' using errcode='42501';end if;
  select * into m from public.sec_maintenance_details where order_id=w.id for update;
  if p_op='maintenance_assign' then
   if w.state<>'requested' or m.order_id is not null or p_detail-'device_id'-'technician_id'-'scheduled_at'<>'{}'::jsonb then raise exception 'invalid assignment' using errcode='22023';end if;
   dev:=(p_detail->>'device_id')::uuid;agent:=(p_detail->>'technician_id')::uuid;st:=(p_detail->>'scheduled_at')::timestamptz;
   if st is null or st<now()-interval '1 minute' or not exists(select 1 from public.sec_devices where id=dev and organization_id=p_org and site_id=p_site) or not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships x using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=agent and sm.active and x.active and x.role in ('owner','manager','operator')) then raise exception 'assignment denied' using errcode='42501';end if;
   insert into public.sec_maintenance_details(order_id,organization_id,site_id,device_id,technician_id,scheduled_at) values(w.id,p_org,p_site,dev,agent,st);
   update public.sec_work_orders set state='assigned' where id=w.id;next_state:='assigned';
  elsif p_op='maintenance_start' and w.state='assigned' and m.technician_id=auth.uid() and p_detail='{}'::jsonb then
   update public.sec_work_orders set state='in_progress' where id=w.id;next_state:='in_progress';
  elsif p_op='maintenance_complete' and w.state='in_progress' and m.technician_id=auth.uid() and m.completed_at is null and p_detail-'diagnosis'-'cost_fcfa'='{}'::jsonb then
   diag:=trim(coalesce(p_detail->>'diagnosis',''));if length(diag) not between 1 and 1000 or jsonb_typeof(p_detail->'cost_fcfa') is distinct from 'number' or (p_detail->>'cost_fcfa') !~ '^[0-9]+$' then raise exception 'invalid completion' using errcode='22023';end if;
   amount:=(p_detail->>'cost_fcfa')::bigint;
   if amount not between 0 and 100000000 then raise exception 'invalid cost' using errcode='22023';end if;
   update public.sec_maintenance_details set diagnosis=diag,cost_fcfa=amount,completed_at=now() where order_id=w.id;next_state:='pending_review';
  elsif p_op='maintenance_review' and w.state='in_progress' and m.completed_at is not null and m.reviewer_id is null and m.technician_id<>auth.uid() and p_detail='{}'::jsonb then
   update public.sec_maintenance_details set reviewer_id=auth.uid(),reviewed_at=now() where order_id=w.id;
   update public.sec_work_orders set state='completed' where id=w.id;next_state:='completed';
  else raise exception 'invalid maintenance transition' using errcode='22023';end if;
  out:=jsonb_build_object('target_id',w.id,'state',next_state,'device_certified',false);
 else raise exception 'unknown operation' using errcode='22023';end if;
 out:=out||jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op);
 insert into public.sec_erp_events(id,organization_id,site_id,actor_id,operation,target_id,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),p_op,p_target,h,out);return out;
end $f$;
revoke all on function sec_private.erp_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.erp_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
create function public.sec_erp_action(p_org uuid,p_site uuid,p_event uuid,p_op text,p_target uuid,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.erp_action(p_org,p_site,p_event,p_op,p_target,p_detail)$r$;
revoke all on function public.sec_erp_action(uuid,uuid,uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.sec_erp_action(uuid,uuid,uuid,text,uuid,jsonb) to authenticated;
-- Prevent the older transition path from bypassing the detailed technician workflow once attached.
create function sec_private.guard_maintenance_review() returns trigger language plpgsql set search_path=pg_catalog as $g$
declare d public.sec_maintenance_details%rowtype;
begin
 if new.state is distinct from old.state and new.state in ('assigned','in_progress','completed') then
  select * into d from public.sec_maintenance_details where order_id=new.id and organization_id=new.organization_id and site_id=new.site_id;
  if not found then raise exception 'detailed assignment required' using errcode='22023';end if;
  if new.state='in_progress' and d.technician_id is distinct from auth.uid() then raise exception 'technician required' using errcode='42501';end if;
  if new.state='completed' and (d.completed_at is null or d.reviewed_at is null or d.reviewer_id is distinct from auth.uid()) then raise exception 'review required' using errcode='22023';end if;
 end if;
 return new;
end $g$;
create trigger sec_maintenance_review_guard before update on public.sec_work_orders for each row execute function sec_private.guard_maintenance_review();
commit;
