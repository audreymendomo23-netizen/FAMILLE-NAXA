-- Reviewed attendance report for a scheduled shift; never a payroll instruction.
begin;
create table public.sec_presence_exceptions(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,shift_id uuid not null references public.sec_shifts(id),
 worker_id uuid not null references auth.users(id),kind text not null check(kind in ('arrival','departure','pause_start','pause_end','absence')),
 observed_at timestamptz,reason text not null check(length(trim(reason)) between 1 and 500 and reason !~ '[[:cntrl:]]'),
 state text not null default 'pending_review' check(state in ('pending_review','approved','rejected')),created_at timestamptz not null default now(),
 reviewer_id uuid references auth.users(id),review_reason text,reviewed_at timestamptz,
 check((kind='absence')=(observed_at is null)),check(reviewer_id is null or reviewer_id<>worker_id),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_presence_exceptions enable row level security;
revoke all on public.sec_presence_exceptions from public,anon,authenticated;
grant select on public.sec_presence_exceptions to authenticated;
create policy presence_exception_read on public.sec_presence_exceptions for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (worker_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create index presence_exception_shift on public.sec_presence_exceptions(organization_id,site_id,shift_id,state);
create function public.sec_presence_report(p_org uuid,p_site uuid,p_shift uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog as $f$
declare r text;sh public.sec_shifts%rowtype;x record;phase text:='waiting';last_at timestamptz;arrived timestamptz;departed timestamptz;work_seconds bigint:=0;pause_seconds bigint:=0;anomalies integer:=0;pending integer:=0;rejected integer:=0;reviewed integer:=0;ok boolean;attendance_status text;absence_approved boolean:=false;manual_count integer:=0;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 select * into sh from public.sec_shifts where id=p_shift and organization_id=p_org and site_id=p_site and (r in ('owner','manager') or agent_id=auth.uid());
 if not found then raise exception 'shift denied' using errcode='42501';end if;
 if sh.state='cancelled' then return jsonb_build_object('organization_id',p_org,'site_id',p_site,'shift_id',p_shift,'state','cancelled','attendance_status','cancelled','complete',false,'physical_presence_certified',false);end if;
 select exists(select 1 from public.sec_presence_exceptions where shift_id=p_shift and organization_id=p_org and site_id=p_site and kind='absence' and state='approved') into absence_approved;
 select count(*) into pending from public.sec_presence_exceptions where shift_id=p_shift and organization_id=p_org and site_id=p_site and kind='absence' and state='pending_review';
 for x in select * from (
 select id,action,state,observed_at,false as manual from public.sec_attendance_drafts where organization_id=p_org and site_id=p_site and reporter_id=sh.agent_id and observed_at between sh.starts_at and sh.ends_at
 union all select id,kind,case state when 'approved' then 'reviewed' else state end,observed_at,true from public.sec_presence_exceptions where organization_id=p_org and site_id=p_site and shift_id=p_shift and kind<>'absence'
 ) q order by observed_at,id loop
  if x.state='pending_review' then pending:=pending+1;continue;elsif x.state='rejected' then rejected:=rejected+1;continue;end if;
  reviewed:=reviewed+1;if x.manual then manual_count:=manual_count+1;end if;
  if last_at is not null and x.observed_at<=last_at then anomalies:=anomalies+1;continue;end if;
  if phase='waiting' and x.action='arrival' then arrived:=x.observed_at;phase:='working';
  elsif phase='working' and x.action='pause_start' then work_seconds:=work_seconds+floor(extract(epoch from x.observed_at-last_at))::bigint;phase:='paused';
  elsif phase='paused' and x.action='pause_end' then pause_seconds:=pause_seconds+floor(extract(epoch from x.observed_at-last_at))::bigint;phase:='working';
  elsif phase='working' and x.action='departure' then work_seconds:=work_seconds+floor(extract(epoch from x.observed_at-last_at))::bigint;departed:=x.observed_at;phase:='finished';
  else anomalies:=anomalies+1;continue;end if;
  last_at:=x.observed_at;
 end loop;
 if absence_approved and reviewed>0 then anomalies:=anomalies+1;end if;
 ok:=not absence_approved and phase='finished' and anomalies=0 and pending=0 and sh.state in ('accepted','completed');
 attendance_status:=case
 when sh.state='planned' then 'not_accepted'
 when ok then 'reviewed_complete'
 when absence_approved and reviewed=0 and pending=0 and anomalies=0 then 'absence_reviewed'
 when pending>0 or anomalies>0 then 'review_required'
 when now()<sh.starts_at then 'scheduled'
 when now()<=sh.ends_at then 'in_progress_unconfirmed'
 when reviewed=0 and rejected=0 then 'missing_evidence'
 else 'incomplete_evidence' end;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'shift_id',p_shift,'state',sh.state,'attendance_status',attendance_status,'complete',ok,'phase',phase,
 'scheduled_start',sh.starts_at,'scheduled_end',sh.ends_at,'arrived_at',arrived,'departed_at',departed,'pending',pending,'rejected',rejected,'reviewed',reviewed,'anomalies',anomalies,'manual_approved_events',manual_count,'absence_approved',absence_approved,
 'worked_seconds',case when ok then work_seconds end,'pause_seconds',case when ok then pause_seconds end,
 'late_seconds',case when arrived is not null then floor(extract(epoch from arrived-sh.starts_at))::bigint end,
 'early_departure_seconds',case when departed is not null then floor(extract(epoch from sh.ends_at-departed))::bigint end,
 'physical_presence_certified',false);
end $f$;
revoke all on function public.sec_presence_report(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_presence_report(uuid,uuid,uuid) to authenticated;
commit;
