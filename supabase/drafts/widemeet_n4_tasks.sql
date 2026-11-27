-- Isolated N4 task workflow: explicit human assignment, no inferred decisions.
begin;
create table public.wm_tasks(
 id uuid primary key, room_id uuid not null references public.wm_minutes_eligibility(room_id),
 version_id uuid not null references public.wm_minutes_versions(id),
 assignee_id uuid not null references public.wm_accounts(id), created_by uuid not null references public.wm_accounts(id),
 title text not null check(length(title) between 1 and 200),
 due_at timestamptz not null, state text not null default 'assigned' check(state in ('assigned','submitted','done','cancelled')),
 evidence text check(evidence is null or length(evidence) between 1 and 2000),
 revision integer not null default 1 check(revision>0), created_at timestamptz not null default clock_timestamp(),
 changed_at timestamptz not null default clock_timestamp()
);
-- Append-only action history; no old evidence or recipient access is broadened.
create table public.wm_task_history(
 task_id uuid not null references public.wm_tasks(id),revision integer not null,
 actor_id uuid not null references public.wm_accounts(id),action text not null check(action in ('create','submit','approve','return','cancel')),
 state text not null check(state in ('assigned','submitted','done','cancelled')),
 occurred_at timestamptz not null default clock_timestamp(),primary key(task_id,revision)
);
alter table public.wm_task_history enable row level security;
revoke all on public.wm_task_history from public,anon,authenticated;
grant select,insert on public.wm_task_history to service_role;
create index wm_tasks_assignee on public.wm_tasks(assignee_id,due_at);
alter table public.wm_tasks enable row level security;
revoke all on public.wm_tasks from public,anon,authenticated;
grant select,insert,update on public.wm_tasks to service_role;
create function public.wm_task_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; role_name text; t public.wm_tasks%rowtype; r public.wm_rooms%rowtype; v public.wm_minutes_versions%rowtype; tid uuid; rid uuid; vid uuid; assignee uuid; deadline timestamptz; title_text text; evidence_text text; host boolean;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required or jsonb_typeof(p_data) is distinct from 'object' then return null;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for share;
 if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;
 if not found then return null;end if;
 select role into role_name from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled for share;
 if not found then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;
 if not found or not exists(select 1 from public.wm_session_context(p_hash)) then return null;end if;
 if p_action='list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(q)) from (
   select k.id,k.room_id,k.version_id,k.title,k.due_at,k.state,k.evidence,k.revision,k.assignee_id,ac.display_name as assignee_name,rr.state->>'title' as meeting_title,
   rr.host_id=s.account_id and role_name in ('owner','promoteur','manager') as can_manage,
   (k.state='assigned' and k.due_at<=clock_timestamp()) as overdue,
   coalesce((select jsonb_agg(jsonb_build_object('revision',j.revision,'action',j.action,'state',j.state,'at',j.occurred_at) order by j.revision) from public.wm_task_history j where j.task_id=k.id),'[]'::jsonb) as history
   from public.wm_tasks k join public.wm_rooms rr on rr.id=k.room_id join public.wm_minutes_eligibility e on e.room_id=rr.id
   join public.wm_minutes_versions mv on mv.id=k.version_id and mv.revoked_at is null
   join public.wm_accounts ac on ac.id=k.assignee_id
   where rr.workspace_id=s.workspace_id and e.retain_until>clock_timestamp()
   and (rr.host_id=s.account_id and role_name in ('owner','promoteur','manager') or k.assignee_id=s.account_id and exists(select 1 from public.wm_minutes_recipients m where m.version_id=k.version_id and m.account_id=s.account_id and m.revoked_at is null))
   order by k.due_at,k.id limit 100) q),'[]'::jsonb));
 end if;
 begin tid:=(p_data->>'id')::uuid;rid:=(p_data->>'room_id')::uuid;vid:=(p_data->>'version_id')::uuid;assignee:=(p_data->>'assignee_id')::uuid;deadline:=(p_data->>'due_at')::timestamptz;exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then return null;end;
 if tid is null then return null;end if;
 if p_action<>'create' then
  select * into t from public.wm_tasks where id=tid;
  if not found then return null;end if;
  rid:=t.room_id;vid:=t.version_id;
 end if;
 select * into r from public.wm_rooms where id=rid and workspace_id=s.workspace_id for update;
 if not found then return null;end if;
 if not exists(select 1 from public.wm_minutes_eligibility e where e.room_id=rid and e.premium and e.retain_until>clock_timestamp()) then return null;end if;
 select * into v from public.wm_minutes_versions where id=vid and room_id=rid and published_at is not null and revoked_at is null;
 if not found then return null;end if;
 host:=r.host_id=s.account_id and role_name in ('owner','promoteur','manager');
 if p_action='create' then
  title_text:=btrim(p_data->>'title');
  if not host or title_text is null or length(title_text) not between 1 and 200 or deadline is null or deadline<=clock_timestamp() or deadline>clock_timestamp()+interval '90 days' or assignee is null then return null;end if;
  if not exists(select 1 from public.wm_minutes_recipients m join public.wm_memberships mb on mb.account_id=m.account_id and mb.workspace_id=r.workspace_id and mb.enabled join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.version_id=vid and m.account_id=assignee and m.revoked_at is null) then return null;end if;
  select * into t from public.wm_tasks where id=tid;
  if found then
   if t.room_id=rid and t.version_id=vid and t.assignee_id=assignee and t.title=title_text and t.due_at=deadline and t.created_by=s.account_id then return jsonb_build_object('id',tid,'revision',t.revision);end if;
   return null;
  end if;
  if (select count(*) from public.wm_tasks where room_id=rid)>=100 then return null;end if;
  insert into public.wm_tasks(id,room_id,version_id,assignee_id,created_by,title,due_at) values(tid,rid,vid,assignee,s.account_id,title_text,deadline);
  insert into public.wm_task_history(task_id,revision,actor_id,action,state) values(tid,1,s.account_id,'create','assigned');
  return jsonb_build_object('id',tid,'revision',1);
 end if;
 select * into t from public.wm_tasks where id=tid and room_id=rid for update;
 if not found or p_data->>'expected_revision' is distinct from t.revision::text then return null;end if;
 if p_action='submit' then
  evidence_text:=btrim(p_data->>'evidence');
  if t.assignee_id<>s.account_id or t.state<>'assigned' or evidence_text is null or length(evidence_text) not between 1 and 2000 or not exists(select 1 from public.wm_minutes_recipients where version_id=vid and account_id=s.account_id and revoked_at is null) then return null;end if;
  update public.wm_tasks set state='submitted',evidence=evidence_text,revision=revision+1,changed_at=clock_timestamp() where id=tid;
 elsif p_action='approve' and host and t.state='submitted' then
  update public.wm_tasks set state='done',revision=revision+1,changed_at=clock_timestamp() where id=tid;
 elsif p_action='return' and host and t.state='submitted' then
  update public.wm_tasks set state='assigned',revision=revision+1,changed_at=clock_timestamp() where id=tid;
 elsif p_action='cancel' and host and t.state in ('assigned','submitted') then
  update public.wm_tasks set state='cancelled',revision=revision+1,changed_at=clock_timestamp() where id=tid;
 else return null;end if;
 insert into public.wm_task_history(task_id,revision,actor_id,action,state)
 select id,revision,s.account_id,p_action,state from public.wm_tasks where id=tid;
 return jsonb_build_object('id',tid,'revision',t.revision+1);
end $wm$;
revoke all on function public.wm_task_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_task_action(text,text,jsonb) to service_role;
commit;
