-- Detailed case lifecycle and scoped reporting, disposable SQL candidate.
begin;
alter table public.sec_incidents drop constraint sec_incidents_state_check;
alter table public.sec_incidents add constraint sec_incidents_state_check check(state in ('new','review','confirmed','assigned','in_progress','waiting_information','waiting_third_party','resolved','closed','reopened'));
alter table public.sec_incidents add column assignee_id uuid references auth.users(id);
alter table public.sec_incidents add column closure_reason text;
alter table public.sec_incidents add column resolved_at timestamptz;
create table public.sec_incident_notes(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,incident_id uuid not null references public.sec_incidents(id),
 actor_id uuid not null references auth.users(id),kind text not null check(kind in ('transition','assignment','comment','evidence')),
 note text not null check(length(trim(note)) between 1 and 500),evidence_id uuid references public.sec_evidence_files(id),
 old_state text,new_state text,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_incident_notes enable row level security;
revoke all on public.sec_incident_notes from public,anon,authenticated;
grant select on public.sec_incident_notes to authenticated;
create policy sec_case_note_read on public.sec_incident_notes for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (sec_private.field_role(organization_id,site_id)='operator' and exists(select 1 from public.sec_incidents i where i.id=incident_id and i.organization_id=sec_incident_notes.organization_id and i.site_id=sec_incident_notes.site_id and (i.reporter_id=auth.uid() or i.assignee_id=auth.uid()))));
-- New schema cannot close or assign without the additional facts. Old historical rows are not rewritten.
create function sec_private.guard_case_update() returns trigger language plpgsql set search_path=pg_catalog as $g$
begin
 if new.state is distinct from old.state then
  if new.state in ('assigned','in_progress','waiting_information','waiting_third_party','resolved','closed') and new.assignee_id is null then raise exception 'assignee required' using errcode='22023';end if;
  if new.state='resolved' and new.resolved_at is null then raise exception 'resolution timestamp required' using errcode='22023';end if;
  if new.state='closed' and (new.closure_reason is null or length(trim(new.closure_reason))<1 or new.resolved_at is null) then raise exception 'closure record required' using errcode='22023';end if;
 end if;
 return new;
end $g$;
create trigger guard_case_update before update on public.sec_incidents for each row execute function sec_private.guard_case_update();
create function sec_private.case_action(p_org uuid,p_site uuid,p_case uuid,p_event uuid,p_op text,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;i public.sec_incidents%rowtype;n public.sec_incident_notes%rowtype;msg text;dest text;target uuid;evidence uuid;prev public.sec_service_action_log%rowtype;h text;out jsonb;actor_allowed boolean;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') or p_event is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>2048 then raise exception 'denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,8));
 select * into i from public.sec_incidents where id=p_case and organization_id=p_org and site_id=p_site for update;
 if not found then raise exception 'case denied' using errcode='42501';end if;
 actor_allowed:=r in ('owner','manager') or coalesce(i.reporter_id=auth.uid() or i.assignee_id=auth.uid(),false);
 if not actor_allowed then raise exception 'case denied' using errcode='42501';end if;
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');
 select * into prev from public.sec_service_action_log where id=p_event;
 if found then
  if prev.organization_id<>p_org or prev.site_id<>p_site or prev.actor_id<>auth.uid() or prev.operation<>'case_'||p_op or prev.target_id<>p_case or prev.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;return prev.receipt;
 end if;
 msg:=trim(coalesce(p_detail->>'note',''));if length(msg) not between 1 and 500 or msg ~ '[[:cntrl:]]' then raise exception 'note required' using errcode='22023';end if;
 dest:=i.state;
 if p_op='assignment' then
  if r not in ('owner','manager') or i.state not in ('confirmed','assigned','in_progress','waiting_information','waiting_third_party') or p_detail-'note'-'assignee_id'<>'{}'::jsonb then raise exception 'assignment denied' using errcode='42501';end if;
  target:=(p_detail->>'assignee_id')::uuid;
  if not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships m using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=target and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'assignee denied' using errcode='42501';end if;
  if i.state='confirmed' then dest:='assigned';end if;
  update public.sec_incidents set assignee_id=target,state=dest where id=i.id;
 elsif p_op='transition' then
  if p_detail-'note'-'next'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  dest:=p_detail->>'next';
  if not coalesce((i.state,dest) in (('new','review'),('review','confirmed'),('assigned','in_progress'),('in_progress','waiting_information'),('in_progress','waiting_third_party'),('waiting_information','in_progress'),('waiting_third_party','in_progress'),('in_progress','resolved'),('resolved','closed'),('closed','reopened'),('reopened','review')),false) then raise exception 'invalid transition' using errcode='22023';end if;
  if r not in ('owner','manager') and (i.assignee_id is distinct from auth.uid() or dest not in ('in_progress','waiting_information','waiting_third_party','resolved')) then raise exception 'manager required' using errcode='42501';end if;
  -- Critical source remains read-only in this candidate: no action may suppress the alarm.
  if i.priority='P1' then raise exception 'critical case requires separate qualified procedure' using errcode='42501';end if;
  update public.sec_incidents set state=dest,resolved_at=case when dest='resolved' then now() when dest='reopened' then null else resolved_at end,closure_reason=case when dest='closed' then msg when dest='reopened' then null else closure_reason end where id=i.id;
 elsif p_op='evidence' then
  if p_detail-'note'-'evidence_id'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  evidence:=(p_detail->>'evidence_id')::uuid;
  if not exists(select 1 from public.sec_evidence_files f where f.id=evidence and f.organization_id=p_org and f.site_id=p_site and f.owner_id=auth.uid()) then raise exception 'evidence denied' using errcode='42501';end if;
 elsif p_op='comment' then
  if p_detail-'note'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
 else raise exception 'unknown operation' using errcode='22023';end if;
 insert into public.sec_incident_notes(id,organization_id,site_id,incident_id,actor_id,kind,note,evidence_id,old_state,new_state) values(p_event,p_org,p_site,p_case,auth.uid(),p_op,msg,evidence,i.state,dest);
 out:=jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'case_id',p_case,'operation',p_op,'state',dest);
 insert into public.sec_service_action_log(id,organization_id,site_id,actor_id,operation,target_id,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),'case_'||p_op,p_case,h,out);
 return out;
end $f$;
revoke all on function sec_private.case_action(uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function sec_private.case_action(uuid,uuid,uuid,uuid,text,jsonb) to authenticated;
create function public.sec_case_action(p_org uuid,p_site uuid,p_case uuid,p_event uuid,p_op text,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.case_action(p_org,p_site,p_case,p_event,p_op,p_detail)$r$;
revoke all on function public.sec_case_action(uuid,uuid,uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.sec_case_action(uuid,uuid,uuid,uuid,text,jsonb) to authenticated;
-- Server-side aggregates: no artificial 100-record truncation. Only authorized sites, manager/owner, bounded date range.
create function public.sec_site_report(p_org uuid,p_site uuid,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql security invoker set search_path=pg_catalog as $r$
declare out jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'report denied' using errcode='42501';end if;
 if p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '366 days' or p_end>now()+interval '1 minute' then raise exception 'invalid period' using errcode='22023';end if;
 select jsonb_build_object('organization_id',p_org,'site_id',p_site,'start',p_start,'end',p_end,'generated_at',now(),
 'incidents',(select jsonb_build_object('total',count(*),'open',count(*) filter(where state<>'closed'),'critical',count(*) filter(where priority='P1'),'closed',count(*) filter(where state='closed')) from public.sec_incidents where organization_id=p_org and site_id=p_site and occurred_at>=p_start and occurred_at<p_end),
 'attendance',(select jsonb_build_object('total',count(*),'reviewed',count(*) filter(where state='reviewed'),'rejected',count(*) filter(where state='rejected'),'pending',count(*) filter(where state='pending_review')) from public.sec_attendance_drafts where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'patrols',(select jsonb_build_object('total',count(*),'reviewed',count(*) filter(where state='reviewed'),'running',count(*) filter(where state='running')) from public.sec_patrols where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'work',(select jsonb_build_object('total',count(*),'completed',count(*) filter(where state='completed'),'open',count(*) filter(where state not in ('completed','cancelled'))) from public.sec_work_orders where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'passages',(select jsonb_build_object('entries',count(*) filter(where direction='entry'),'exits',count(*) filter(where direction='exit')) from public.sec_passage_logs where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'warnings',(select count(*) from public.sec_observation_alerts where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'fire_source_events',(select count(*) from public.sec_fire_events where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'devices',(select jsonb_build_object('total',count(*),'recent_contact',count(*) filter(where observed_at between now()-interval '120 seconds' and now()),'unknown_contact',count(*) filter(where observed_at is null or observed_at<now()-interval '120 seconds' or observed_at>now())) from public.sec_devices where organization_id=p_org and site_id=p_site),
 'audit_events',(select count(*) from public.sec_field_events where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end)
 ) into out;
 return out;
end $r$;
revoke all on function public.sec_site_report(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.sec_site_report(uuid,uuid,timestamptz,timestamptz) to authenticated;
-- Multi-site reporting over authorized sites only. No access granted by the aggregate.
create function public.sec_org_report(p_org uuid,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql security invoker set search_path=pg_catalog as $r$
declare reports jsonb; totals jsonb; sites_count integer;
begin
 if p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '366 days' or p_end>now()+interval '1 minute' then raise exception 'invalid period' using errcode='22023';end if;
 select coalesce(jsonb_agg(public.sec_site_report(p_org,s.id,p_start,p_end)||jsonb_build_object('site_name',s.name) order by s.id),'[]'::jsonb) into reports
 from public.sec_sites s where s.organization_id=p_org and sec_private.field_role(p_org,s.id) in ('owner','manager');
 sites_count:=jsonb_array_length(reports);
 if sites_count=0 then raise exception 'report denied' using errcode='42501';end if;
 select jsonb_build_object('incidents_total',sum((x->'incidents'->>'total')::bigint),'incidents_open',sum((x->'incidents'->>'open')::bigint),'incidents_closed',sum((x->'incidents'->>'closed')::bigint),'attendance_total',sum((x->'attendance'->>'total')::bigint),'patrols_total',sum((x->'patrols'->>'total')::bigint),'work_open',sum((x->'work'->>'open')::bigint),'devices_total',sum((x->'devices'->>'total')::bigint),'warnings',sum((x->>'warnings')::bigint),'fire_source_events',sum((x->>'fire_source_events')::bigint)) into totals from jsonb_array_elements(reports) q(x);
 return jsonb_build_object('organization_id',p_org,'start',p_start,'end',p_end,'generated_at',now(),'authorized_site_count',sites_count,'totals',totals,'sites',reports);
end $r$;
revoke all on function public.sec_org_report(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.sec_org_report(uuid,timestamptz,timestamptz) to authenticated;
commit;
