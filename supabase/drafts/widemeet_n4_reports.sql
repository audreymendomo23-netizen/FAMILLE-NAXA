-- Premium organizer export: aggregate meeting data, no raw votes or private messages.
begin;
create table public.wm_report_exports(
 request_id uuid primary key,room_id uuid not null references public.wm_rooms(id),
 account_id uuid not null references public.wm_accounts(id),requested_at timestamptz not null default clock_timestamp()
);
alter table public.wm_report_exports enable row level security;
revoke all on public.wm_report_exports from public,anon,authenticated;
grant select,insert on public.wm_report_exports to service_role;
create function public.wm_report_export(p_hash text,p_room uuid,p_request uuid)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;r public.wm_rooms%rowtype;e public.wm_minutes_eligibility%rowtype;prior public.wm_report_exports%rowtype;presence jsonb;tasks jsonb;polls jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required or p_request is null then return null;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for share;if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;if not found then return null;end if;
 perform 1 from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled and role in ('owner','promoteur','manager') for share;if not found then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;if not found then return null;end if;
 if not exists(select 1 from public.wm_session_context(p_hash)) then return null;end if;
 select * into r from public.wm_rooms where id=p_room and workspace_id=s.workspace_id and host_id=s.account_id and state->>'status'='ended' for share;
 if not found then return null;end if;
 select * into e from public.wm_minutes_eligibility where room_id=p_room and premium and retain_until>clock_timestamp();
 if not found then return null;end if;
 insert into public.wm_report_exports(request_id,room_id,account_id) values(p_request,p_room,s.account_id) on conflict do nothing;
 select * into prior from public.wm_report_exports where request_id=p_request;
 if prior.room_id<>p_room or prior.account_id<>s.account_id then return null;end if;
 presence:=public.wm_presence_report(p_hash,p_room);
 select coalesce(jsonb_agg(jsonb_build_object('title',x.title,'assignee',a.display_name,'due_at',x.due_at,'state',x.state) order by x.due_at,x.id),'[]'::jsonb) into tasks
 from public.wm_tasks x join public.wm_accounts a on a.id=x.assignee_id join public.wm_minutes_versions v on v.id=x.version_id and v.revoked_at is null and v.published_at is not null
 where x.room_id=p_room and exists(select 1 from public.wm_minutes_recipients z where z.version_id=x.version_id and z.account_id=x.assignee_id and z.revoked_at is null);
 -- Reuse pollSummary's frozen electorate and response denominator, never raw identities.
 with source as (
  select q,ord,case when jsonb_typeof(q->'eligible')='array' then jsonb_array_length(q->'eligible') end as eligible,
   (select count(*) from jsonb_object_keys(coalesce(q->'votes','{}'::jsonb))) as responses,
   case when q->>'abstentionIndex' is not null then (select count(*) from jsonb_each(coalesce(q->'votes','{}'::jsonb)) b where b.value @> jsonb_build_array((q->>'abstentionIndex')::integer)) end as abstentions,
   coalesce(q->>'decisionMode','threshold') as decision_mode
  from jsonb_array_elements(coalesce(r.state->'polls','[]'::jsonb)) with ordinality p(q,ord)
 ), metrics as (
  select *,case when eligible is null then null when eligible=0 then 0::numeric else 100.0*responses/eligible end as response_rate
  from source
 ), decisions as (
  select *,case when eligible is null or q->>'quorum' is null then null else response_rate>=(q->>'quorum')::numeric end as quorum_met,
   responses-coalesce(abstentions,0) as expressed,
   case when decision_mode='absolute_majority' then eligible else responses-coalesce(abstentions,0) end as decision_denominator
  from metrics
 )
 select coalesce(jsonb_agg(jsonb_build_object(
  'question',q->>'question','kind',coalesce(q->>'kind','simple'),
  'eligible',eligible,'responses',responses,'nonresponses',case when eligible is null then null else greatest(eligible-responses,0) end,
  'abstentions',abstentions,'expressed',expressed,'decision_mode',decision_mode,'decision_denominator',decision_denominator,'response_rate',round(response_rate,2),'quorum',(q->>'quorum')::integer,'quorum_met',quorum_met,'threshold',(q->>'threshold')::integer,
  'options',(select coalesce(jsonb_agg(jsonb_build_object('label',opt,'count',votes_for,
    'share_pct',case when responses=0 then null else round(100.0*votes_for/responses,2) end,
    'accepted',case when quorum_met is true and expressed>0 and decision_denominator>0 and q->>'threshold' is not null then
     case when (q->>'abstentionIndex')::integer=opt_ord-1 then false when decision_mode='threshold' then 100.0*votes_for>=decision_denominator*(q->>'threshold')::numeric else 2*votes_for>decision_denominator end else null end)
    order by opt_ord),'[]'::jsonb)
   from jsonb_array_elements_text(q->'options') with ordinality o(opt,opt_ord)
   cross join lateral (select count(*) as votes_for from jsonb_each(coalesce(q->'votes','{}'::jsonb)) b
     where case when jsonb_typeof(b.value)='array' then b.value @> jsonb_build_array(opt_ord-1) else b.value=to_jsonb(opt_ord-1) end) c)
  ) order by ord),'[]'::jsonb) into polls from decisions;
 return jsonb_build_object('room_id',r.id,'title',e.snapshot->>'title','closed_at',e.closed_at,'recipient',(select display_name from public.wm_accounts where id=s.account_id),'presence',presence,'tasks',tasks,'polls',polls);
end $wm$;
revoke all on function public.wm_report_export(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_report_export(text,uuid,uuid) to service_role;
commit;
