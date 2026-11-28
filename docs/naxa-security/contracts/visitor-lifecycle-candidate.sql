-- Reviewed visitor lifecycle, cancellation prevents any further entry without obstructing checkout.
begin;
create function sec_private.visitor_lifecycle(p_org uuid,p_site uuid,p_op text,p_register uuid default null,p_event uuid default null,p_reason text default null,p_after uuid default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;reg public.sec_service_register%rowtype;prior public.sec_service_action_log%rowtype;why text;h text;v jsonb;next_id uuid;n int;revoked int:=0;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 if p_op='list' and p_register is null and p_event is null and p_reason is null then
  with batch as(select s.id,s.reference,s.recorded_at,s.recorded_at+make_interval(mins=>(s.details->>'duration_minutes')::integer) as expires_at,s.cancelled_at,
   (select l.direction from public.sec_passage_logs l where l.organization_id=p_org and l.site_id=p_site and l.register_id=s.id order by l.sequence desc limit 1) as last_direction
   from public.sec_service_register s where s.organization_id=p_org and s.site_id=p_site and s.kind='visitor' and (p_after is null or s.id>p_after) order by s.id limit 101),
  page as(select b.*,case when b.last_direction='entry' then 'inside' when b.cancelled_at is not null then 'cancelled' when b.last_direction='exit' then 'exited' when b.expires_at<=now() then 'expired' else 'expected' end as state from batch b order by b.id limit 100)
  select coalesce((select jsonb_agg(to_jsonb(x) order by x.id) from page x),'[]'::jsonb),(select count(*) from batch),(select id from page order by id desc limit 1) into v,n,next_id;
  return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'rows',v,'next',case when n>100 then next_id end,'can_cancel',r in ('owner','manager'),'physical_access',false);
 elsif p_op='history' and p_register is not null and p_event is null and p_reason is null and p_after is null then
  if not exists(select 1 from public.sec_service_register where id=p_register and organization_id=p_org and site_id=p_site and kind='visitor') then raise exception 'register denied' using errcode='42501';end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.sequence desc),'[]'::jsonb) into v from (select id,actor_id,direction,sequence,created_at from public.sec_passage_logs where register_id=p_register and organization_id=p_org and site_id=p_site order by sequence desc limit 100)x;
  return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'register_id',p_register,'rows',v,'physical_access',false);
 elsif p_op='cancel' and p_register is not null and p_event is not null and p_after is null then
  if r not in ('owner','manager') then raise exception 'manager required' using errcode='42501';end if;
  why:=trim(coalesce(p_reason,''));if length(why) not between 1 and 500 or why ~ '[[:cntrl:]]' then raise exception 'reason required' using errcode='22023';end if;
  h:=encode(sha256(convert_to(why,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_event::text,11));
  select * into prior from public.sec_service_action_log where id=p_event;
  if found then
   if prior.organization_id<>p_org or prior.site_id<>p_site or prior.actor_id<>auth.uid() or prior.operation<>'visitor_cancel' or prior.target_id<>p_register or prior.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;
   return prior.receipt;
  end if;
  select * into reg from public.sec_service_register where id=p_register and organization_id=p_org and site_id=p_site and kind='visitor' for update;
  if not found then raise exception 'register denied' using errcode='42501';end if;
  if reg.cancelled_at is not null then raise exception 'already cancelled' using errcode='23505';end if;
  update public.sec_service_register set cancelled_at=clock_timestamp(),cancelled_by=auth.uid() where id=reg.id returning * into reg;
  update public.sec_visit_passes set revoked_at=clock_timestamp() where organization_id=p_org and site_id=p_site and register_id=reg.id and used_at is null and revoked_at is null;
  get diagnostics revoked=row_count;
  v:=jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'event_id',p_event,'register_id',reg.id,'state','cancelled','revoked_passes',revoked,'cancelled_at',reg.cancelled_at,'physical_access',false);
  insert into public.sec_service_action_log(id,organization_id,site_id,actor_id,operation,target_id,detail_hash,receipt) values(p_event,p_org,p_site,auth.uid(),'visitor_cancel',reg.id,h,v);
  return v;
 else raise exception 'invalid operation' using errcode='22023';end if;
end $f$;
revoke all on function sec_private.visitor_lifecycle(uuid,uuid,text,uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function sec_private.visitor_lifecycle(uuid,uuid,text,uuid,uuid,text,uuid) to authenticated;
create function public.sec_visitor_lifecycle(p_org uuid,p_site uuid,p_op text,p_register uuid default null,p_event uuid default null,p_reason text default null,p_after uuid default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.visitor_lifecycle(p_org,p_site,p_op,p_register,p_event,p_reason,p_after)$r$;
revoke all on function public.sec_visitor_lifecycle(uuid,uuid,text,uuid,uuid,text,uuid) from public,anon;
grant execute on function public.sec_visitor_lifecycle(uuid,uuid,text,uuid,uuid,text,uuid) to authenticated;
commit;
