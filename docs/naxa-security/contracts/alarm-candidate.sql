-- Source alarm events and independent human triage; never actuates or clears a physical alarm.
begin;
create table public.sec_alarm_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,device_id uuid not null,gateway_id uuid not null,
 observed_at timestamptz not null,source_state text not null check(source_state in ('intrusion','sabotage','fault','restored')),
 triage_state text not null default 'new' check(triage_state in ('new','acknowledged','escalated','reviewed')),
 created_at timestamptz not null default now(),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 foreign key(organization_id,site_id,gateway_id) references public.sec_devices(organization_id,site_id,id)
);
create table public.sec_alarm_reviews(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,event_id uuid not null references public.sec_alarm_events(id),actor_id uuid not null references auth.users(id),
 operation text not null check(operation in ('ack','escalate','review')),reason text not null check(length(trim(reason)) between 1 and 500),receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_alarm_events enable row level security;
alter table public.sec_alarm_reviews enable row level security;
revoke all on public.sec_alarm_events,public.sec_alarm_reviews from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_alarm_events,public.sec_alarm_reviews to authenticated;
create policy alarm_read on public.sec_alarm_events for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create policy alarm_review_read on public.sec_alarm_reviews for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (actor_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create index alarm_scope on public.sec_alarm_events(organization_id,site_id,observed_at desc);
create function sec_private.notify_alarm(p_org uuid,p_site uuid,p_event uuid,p_type text) returns void language sql security definer set search_path=pg_catalog as $f$
 insert into public.sec_activity_notifications(organization_id,site_id,user_id,source,source_id,event_type)
 select p_org,p_site,m.user_id,'alarm',p_event,p_type from public.sec_memberships m join public.sec_site_memberships sm using(organization_id,user_id)
 join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id
 where m.organization_id=p_org and sm.site_id=p_site and m.active and sm.active and s.active and o.active and m.role in ('owner','manager') on conflict do nothing
$f$;
revoke all on function sec_private.notify_alarm(uuid,uuid,uuid,text) from public,anon,authenticated,sec_gateway_ingest;
create function sec_private.ingest_alarm(p_gateway uuid,p_org uuid,p_site uuid,p_device uuid,p_event uuid,p_observed timestamptz,p_state text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v public.sec_alarm_events%rowtype;
begin
 if p_event is null or p_observed is null or p_observed>now() or p_observed<now()-interval '24 hours' or p_state is null or p_state not in ('intrusion','sabotage','fault','restored') then raise exception 'invalid event' using errcode='22023';end if;
 if not exists(select 1 from sec_private.gateway_bindings b join public.sec_devices g on g.id=b.gateway_id and g.organization_id=b.organization_id and g.site_id=b.site_id join public.sec_devices d on d.id=b.device_id and d.organization_id=b.organization_id and d.site_id=b.site_id join public.sec_sites s on s.id=b.site_id and s.organization_id=b.organization_id join public.sec_organizations o on o.id=s.organization_id where b.gateway_id=p_gateway and b.organization_id=p_org and b.site_id=p_site and b.device_id=p_device and b.enabled and g.kind='gateway' and d.kind in ('access','camera','gateway') and s.active and o.active) then raise exception 'source denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,305));
 select * into v from public.sec_alarm_events where id=p_event;
 if found then
  if v.organization_id<>p_org or v.site_id<>p_site or v.device_id<>p_device or v.gateway_id<>p_gateway or v.source_state<>p_state or v.observed_at<>p_observed then raise exception 'event conflict' using errcode='23505';end if;
 else
  insert into public.sec_alarm_events(id,organization_id,site_id,device_id,gateway_id,observed_at,source_state) values(p_event,p_org,p_site,p_device,p_gateway,p_observed,p_state) returning * into v;
  if p_observed>=now()-interval '120 seconds' then perform sec_private.notify_alarm(p_org,p_site,p_event,p_state);end if;
 end if;
 return jsonb_build_object('event_id',v.id,'gateway_id',v.gateway_id,'device_id',v.device_id,'organization_id',v.organization_id,'site_id',v.site_id,'source_state',v.source_state,'state','recorded','physical_action',false);
end $f$;
revoke all on function sec_private.ingest_alarm(uuid,uuid,uuid,uuid,uuid,timestamptz,text) from public,anon,authenticated;
grant execute on function sec_private.ingest_alarm(uuid,uuid,uuid,uuid,uuid,timestamptz,text) to sec_gateway_ingest;
create function sec_private.alarm_action(p_org uuid,p_site uuid,p_event uuid,p_alarm uuid,p_op text,p_reason text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;v public.sec_alarm_events%rowtype;old public.sec_alarm_reviews%rowtype;next_state text;out jsonb;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') or (p_op in ('escalate','review') and r not in ('owner','manager')) then raise exception 'denied' using errcode='42501';end if;
 if p_event is null or p_alarm is null or p_op is null or p_op not in ('ack','escalate','review') or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'invalid action' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,306));
 select * into old from public.sec_alarm_reviews where id=p_event;
 if found then
  if old.organization_id<>p_org or old.site_id<>p_site or old.actor_id<>auth.uid() or old.event_id<>p_alarm or old.operation<>p_op or old.reason<>trim(p_reason) then raise exception 'event conflict' using errcode='23505';end if;
  return old.receipt;
 end if;
 select * into v from public.sec_alarm_events where id=p_alarm and organization_id=p_org and site_id=p_site for update;
 if not found then raise exception 'alarm denied' using errcode='42501';end if;
 if p_op='ack' and v.triage_state='new' then next_state:='acknowledged';
 elsif p_op='escalate' and v.triage_state in ('new','acknowledged') then next_state:='escalated';
 elsif p_op='review' and v.triage_state in ('acknowledged','escalated') then next_state:='reviewed';
 else raise exception 'invalid transition' using errcode='22023';end if;
 update public.sec_alarm_events set triage_state=next_state where id=v.id;
 out:=jsonb_build_object('event_id',p_event,'alarm_id',v.id,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'triage_state',next_state,'source_state',v.source_state,'physical_action',false);
 insert into public.sec_alarm_reviews values(p_event,p_org,p_site,v.id,auth.uid(),p_op,trim(p_reason),out,now());
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'alarm_'||p_op,v.id);
 if p_op='escalate' then perform sec_private.notify_alarm(p_org,p_site,v.id,'escalated');end if;
 return out;
end $f$;
revoke all on function sec_private.alarm_action(uuid,uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function sec_private.alarm_action(uuid,uuid,uuid,uuid,text,text) to authenticated;
create function public.sec_alarm_action(p_org uuid,p_site uuid,p_event uuid,p_alarm uuid,p_op text,p_reason text) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.alarm_action(p_org,p_site,p_event,p_alarm,p_op,p_reason)$r$;
revoke all on function public.sec_alarm_action(uuid,uuid,uuid,uuid,text,text) from public,anon;
grant execute on function public.sec_alarm_action(uuid,uuid,uuid,uuid,text,text) to authenticated;
commit;
