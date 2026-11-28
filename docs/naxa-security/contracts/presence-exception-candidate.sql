-- Explicit manual exception: no fabricated GPS, no automatic approval, no payroll effect.
begin;
create function sec_private.presence_exception(p_org uuid,p_site uuid,p_op text,p_id uuid default null,p_shift uuid default null,p_detail jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;sh public.sec_shifts%rowtype;v public.sec_presence_exceptions%rowtype;k text;why text;obs timestamptz;decision text;result jsonb;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') or p_op is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>2048 then raise exception 'denied' using errcode='42501';end if;
 if p_op='list' and p_id is null and p_shift is not null and p_detail='{}'::jsonb then
  select * into sh from public.sec_shifts where id=p_shift and organization_id=p_org and site_id=p_site and (r in ('owner','manager') or agent_id=auth.uid());
  if not found then raise exception 'shift denied' using errcode='42501';end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id),'[]'::jsonb) into result from (select * from public.sec_presence_exceptions where organization_id=p_org and site_id=p_site and shift_id=p_shift order by created_at desc,id limit 100)x;
 elsif p_op='submit' and p_id is not null and p_shift is not null then
  if p_detail-'kind'-'observed_at'-'reason'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  k:=p_detail->>'kind';why:=trim(coalesce(p_detail->>'reason',''));obs:=(p_detail->>'observed_at')::timestamptz;
  if k is null or k not in ('arrival','departure','pause_start','pause_end','absence') or length(why) not between 1 and 500 or why ~ '[[:cntrl:]]' or (k='absence')<>(obs is null) then raise exception 'invalid exception' using errcode='22023';end if;
  select * into sh from public.sec_shifts where id=p_shift and organization_id=p_org and site_id=p_site and agent_id=auth.uid() for update;
  if not found then raise exception 'shift denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,421));
  select * into v from public.sec_presence_exceptions where id=p_id;
  if found then
   if v.organization_id<>p_org or v.site_id<>p_site or v.shift_id<>p_shift or v.worker_id<>auth.uid() or v.kind<>k or v.reason<>why or v.observed_at is distinct from obs then raise exception 'event conflict' using errcode='23505';end if;
  else
   if sh.state not in ('accepted','completed') or (k='absence' and now()<sh.ends_at) or (obs is not null and (obs not between sh.starts_at and sh.ends_at or obs>now())) then raise exception 'invalid shift window' using errcode='22023';end if;
   if exists(select 1 from public.sec_presence_exceptions where shift_id=p_shift and kind=k and observed_at is not distinct from obs and state in ('pending_review','approved')) then raise exception 'duplicate exception' using errcode='23505';end if;
   insert into public.sec_presence_exceptions(id,organization_id,site_id,shift_id,worker_id,kind,observed_at,reason) values(p_id,p_org,p_site,p_shift,auth.uid(),k,obs,why) returning * into v;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'presence_exception_submit',v.id);
  end if;
  result:=to_jsonb(v);
 elsif p_op='review' and p_id is not null and p_shift is not null then
  if r not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
  if p_detail-'decision'-'reason'<>'{}'::jsonb then raise exception 'invalid fields' using errcode='22023';end if;
  decision:=p_detail->>'decision';why:=trim(coalesce(p_detail->>'reason',''));
  if decision is null or decision not in ('approved','rejected') or length(why) not between 1 and 500 or why ~ '[[:cntrl:]]' then raise exception 'invalid review' using errcode='22023';end if;
  select * into sh from public.sec_shifts where id=p_shift and organization_id=p_org and site_id=p_site for update;
  if not found then raise exception 'shift denied' using errcode='42501';end if;
  select * into v from public.sec_presence_exceptions where id=p_id and organization_id=p_org and site_id=p_site and shift_id=p_shift for update;
  if not found or v.worker_id=auth.uid() then raise exception 'independent review required' using errcode='42501';end if;
  if v.state<>'pending_review' then
   if v.state<>decision or v.reviewer_id<>auth.uid() or v.review_reason<>why then raise exception 'already reviewed' using errcode='23505';end if;
  else
   if decision='approved' and sh.state not in ('accepted','completed') then raise exception 'invalid shift state' using errcode='22023';end if;
   if decision='approved' and v.kind='absence' and (exists(select 1 from public.sec_attendance_drafts d where d.organization_id=p_org and d.site_id=p_site and d.reporter_id=sh.agent_id and d.observed_at between sh.starts_at and sh.ends_at and d.state<>'rejected') or exists(select 1 from public.sec_presence_exceptions e where e.shift_id=p_shift and e.kind<>'absence' and e.state<>'rejected')) then raise exception 'conflicting evidence' using errcode='22023';end if;
   if decision='approved' and v.kind<>'absence' and exists(select 1 from public.sec_presence_exceptions e where e.shift_id=p_shift and e.kind='absence' and e.state='approved') then raise exception 'conflicting absence' using errcode='22023';end if;
   update public.sec_presence_exceptions set state=decision,reviewer_id=auth.uid(),review_reason=why,reviewed_at=clock_timestamp() where id=v.id returning * into v;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'presence_exception_review',v.id);
  end if;
  result:=to_jsonb(v);
 else raise exception 'invalid operation' using errcode='22023';end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'shift_id',p_shift,'result',result,'physical_presence_certified',false);
end $f$;
revoke all on function sec_private.presence_exception(uuid,uuid,text,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function sec_private.presence_exception(uuid,uuid,text,uuid,uuid,jsonb) to authenticated;
create function public.sec_presence_exception(p_org uuid,p_site uuid,p_op text,p_id uuid default null,p_shift uuid default null,p_detail jsonb default '{}'::jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.presence_exception(p_org,p_site,p_op,p_id,p_shift,p_detail)$r$;
revoke all on function public.sec_presence_exception(uuid,uuid,text,uuid,uuid,jsonb) from public,anon;
grant execute on function public.sec_presence_exception(uuid,uuid,text,uuid,uuid,jsonb) to authenticated;
commit;
