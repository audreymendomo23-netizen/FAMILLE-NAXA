-- Authorized, derived in-app inbox. No external push or delivery claim.
begin;
create table public.wm_notice_reads(
 workspace_id uuid not null references public.wm_workspaces(id),
 account_id uuid not null references public.wm_accounts(id),
 notice_key text not null check(length(notice_key) between 1 and 180),
 read_at timestamptz not null default clock_timestamp(),
 primary key(workspace_id,account_id,notice_key)
);
alter table public.wm_notice_reads enable row level security;
revoke all on public.wm_notice_reads from public,anon,authenticated;
grant select,insert on public.wm_notice_reads to service_role;
create function public.wm_notices(p_hash text,p_read text default null)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; role_name text; items jsonb; t timestamptz:=clock_timestamp();
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 select role into role_name from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled;
 if not found then return null;end if;
 with notices as(
  select 'invite:'||r.id||':'||(r.state->>'scheduledMs') as k,'invitation' as kind,r.id as ref,r.state->>'title' as title,to_timestamp((r.state->>'scheduledMs')::double precision/1000) as due
  from public.wm_rooms r where r.workspace_id=s.workspace_id and r.state->>'status'='scheduled' and r.host_id<>s.account_id and exists(select 1 from public.wm_room_actor_for(p_hash,r.id))
   and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text and p->>'response' in ('pending','maybe') and p->>'excluded'='false')
  union all
  select 'reminder:'||r.id||':'||(r.state->>'scheduledMs'),'meeting_reminder',r.id,r.state->>'title',to_timestamp((r.state->>'scheduledMs')::double precision/1000)
  from public.wm_rooms r where r.workspace_id=s.workspace_id and r.state->>'status'='scheduled' and to_timestamp((r.state->>'scheduledMs')::double precision/1000) between t and t+interval '24 hours' and exists(select 1 from public.wm_room_actor_for(p_hash,r.id))
   and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text and p->>'response'='accepted' and p->>'excluded'='false')
  union all
  select 'minutes:'||v.id,'minutes_published',r.id,r.state->>'title',v.published_at
  from public.wm_minutes_recipients x join public.wm_minutes_versions v on v.id=x.version_id and v.revoked_at is null and v.published_at is not null join public.wm_minutes_eligibility e on e.room_id=v.room_id and e.retain_until>t join public.wm_rooms r on r.id=v.room_id
  where x.account_id=s.account_id and x.revoked_at is null and r.workspace_id=s.workspace_id
  union all
  select 'task:'||k.id||':'||k.revision,case when k.state='done' then 'task_done' when k.state='submitted' then 'task_review' when k.due_at<t then 'task_overdue' else 'task_assigned' end,k.id,k.title,k.due_at
  from public.wm_tasks k join public.wm_rooms r on r.id=k.room_id and r.workspace_id=s.workspace_id join public.wm_minutes_eligibility e on e.room_id=k.room_id and e.retain_until>t join public.wm_minutes_versions v on v.id=k.version_id and v.revoked_at is null
  where k.state<>'cancelled' and ((k.assignee_id=s.account_id and exists(select 1 from public.wm_minutes_recipients x where x.version_id=k.version_id and x.account_id=s.account_id and x.revoked_at is null)) or (r.host_id=s.account_id and role_name in ('owner','promoteur','manager') and k.state='submitted'))
  union all
  select 'subscription:'||e.workspace_id||':'||extract(epoch from e.valid_until)::bigint,'subscription_expiring',e.workspace_id,null,e.valid_until
  from public.wm_room_entitlements e where e.workspace_id=s.workspace_id and e.enabled and role_name='promoteur' and e.valid_until between t and t+interval '72 hours'
 ), visible as (
  select n.k,n.kind,n.ref,n.title,n.due,r.read_at from notices n left join public.wm_notice_reads r on r.workspace_id=s.workspace_id and r.account_id=s.account_id and r.notice_key=n.k
  where n.k is not null and n.due is not null order by (r.read_at is not null),n.due,n.k limit 100
 )
 select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from visible v;
 if p_read is not null then
  if length(p_read)>180 or not exists(select 1 from jsonb_array_elements(items) x where x->>'k'=p_read) then return null;end if;
  insert into public.wm_notice_reads(workspace_id,account_id,notice_key) values(s.workspace_id,s.account_id,p_read) on conflict do nothing;
  return jsonb_build_object('read',true);
 end if;
 return jsonb_build_object('items',items);
end $wm$;
revoke all on function public.wm_notices(text,text) from public,anon,authenticated;
grant execute on function public.wm_notices(text,text) to service_role;
commit;
