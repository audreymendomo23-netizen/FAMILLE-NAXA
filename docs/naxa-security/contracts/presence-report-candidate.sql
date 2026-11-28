-- Reviewed attendance report for a scheduled shift; never a payroll instruction.
begin;
create function public.sec_presence_report(p_org uuid,p_site uuid,p_shift uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog as $f$
declare r text;sh public.sec_shifts%rowtype;x record;phase text:='waiting';last_at timestamptz;arrived timestamptz;departed timestamptz;work_seconds bigint:=0;pause_seconds bigint:=0;anomalies integer:=0;pending integer:=0;rejected integer:=0;reviewed integer:=0;ok boolean;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 select * into sh from public.sec_shifts where id=p_shift and organization_id=p_org and site_id=p_site and (r in ('owner','manager') or agent_id=auth.uid());
 if not found then raise exception 'shift denied' using errcode='42501';end if;
 if sh.state='cancelled' then return jsonb_build_object('organization_id',p_org,'site_id',p_site,'shift_id',p_shift,'state','cancelled','complete',false,'physical_presence_certified',false);end if;
 for x in select action,state,observed_at from public.sec_attendance_drafts where organization_id=p_org and site_id=p_site and reporter_id=sh.agent_id and observed_at between sh.starts_at and sh.ends_at order by observed_at,id loop
  if x.state='pending_review' then pending:=pending+1;continue;elsif x.state='rejected' then rejected:=rejected+1;continue;end if;
  reviewed:=reviewed+1;
  if last_at is not null and x.observed_at<=last_at then anomalies:=anomalies+1;continue;end if;
  if phase='waiting' and x.action='arrival' then arrived:=x.observed_at;phase:='working';
  elsif phase='working' and x.action='pause_start' then work_seconds:=work_seconds+floor(extract(epoch from x.observed_at-last_at))::bigint;phase:='paused';
  elsif phase='paused' and x.action='pause_end' then pause_seconds:=pause_seconds+floor(extract(epoch from x.observed_at-last_at))::bigint;phase:='working';
  elsif phase='working' and x.action='departure' then work_seconds:=work_seconds+floor(extract(epoch from x.observed_at-last_at))::bigint;departed:=x.observed_at;phase:='finished';
  else anomalies:=anomalies+1;continue;end if;
  last_at:=x.observed_at;
 end loop;
 ok:=phase='finished' and anomalies=0 and pending=0 and sh.state in ('accepted','completed');
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'shift_id',p_shift,'state',sh.state,'complete',ok,'phase',phase,
 'scheduled_start',sh.starts_at,'scheduled_end',sh.ends_at,'arrived_at',arrived,'departed_at',departed,'pending',pending,'rejected',rejected,'reviewed',reviewed,'anomalies',anomalies,
 'worked_seconds',case when ok then work_seconds end,'pause_seconds',case when ok then pause_seconds end,
 'late_seconds',case when arrived is not null then floor(extract(epoch from arrived-sh.starts_at))::bigint end,
 'early_departure_seconds',case when departed is not null then floor(extract(epoch from sh.ends_at-departed))::bigint end,
 'physical_presence_certified',false);
end $f$;
revoke all on function public.sec_presence_report(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_presence_report(uuid,uuid,uuid) to authenticated;
commit;
