-- Isolated qualification only. Provider IDs and private paths are never returned to clients.
begin;
create table public.wm_recording_runs(
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.wm_rooms(id),
 request_id uuid not null,
 phase text not null default 'starting' check(phase in ('starting','active','stopping','complete','discarded','failed')),
 disposition text not null default 'retain' check(disposition in ('retain','discard')),
 provider_id text unique,
 object_name text not null unique,
 started_at timestamptz,
 finished_at timestamptz,
 content_sha256 text,
 bytes bigint,
 created_at timestamptz not null default clock_timestamp(),
 unique(room_id,request_id),
 check(phase<>'complete' or (content_sha256 is not null and length(content_sha256)=64 and bytes>0 and finished_at is not null and disposition='retain'))
);
create unique index wm_one_live_recording on public.wm_recording_runs(room_id) where phase in ('starting','active','stopping');
alter table public.wm_recording_runs enable row level security;
revoke all on public.wm_recording_runs from public,anon,authenticated;
grant select,insert,update on public.wm_recording_runs to service_role;

-- The room, host, members and paid entitlement must still be valid.
create function public.wm_recording_policy(p_room uuid)
returns jsonb language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select jsonb_build_object(
  'room_id',r.id,
  'request_id',(select (e->>'id')::uuid from jsonb_array_elements(r.state->'events') with ordinality as x(e,n) where e->>'action'='record' and (e->>'payload')::jsonb->2='true'::jsonb order by n desc limit 1),
  'permitted',r.state->>'status'='open' and r.state->>'recording'='requested'
    and (r.state->>'endMs')::bigint>floor(extract(epoch from now())*1000)::bigint
    and exists(select 1 from public.wm_workspaces w where w.id=r.workspace_id and w.enabled)
    and exists(select 1 from public.wm_accounts a join public.wm_memberships m on m.account_id=a.id and m.workspace_id=r.workspace_id and m.enabled where a.id=r.host_id and a.enabled and not a.password_change_required and m.role in ('owner','promoteur','manager'))
    and (exists(select 1 from public.wm_room_entitlements e where e.workspace_id=r.workspace_id and e.enabled and e.plan='premium' and e.valid_until>now())
      or exists(select 1 from public.wm_paid_passes p where p.consumed_room_id=r.id and p.workspace_id=r.workspace_id and p.valid_until>now()))
    and not exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'response'='accepted' and p->>'excluded'='false' and (p->>'consent' is distinct from 'true' or not exists(select 1 from public.wm_accounts a join public.wm_memberships m on m.account_id=a.id and m.workspace_id=r.workspace_id and m.enabled where a.id::text=p->>'memberId' and a.enabled))),
  'normal_stop',coalesce((select e->>'action'='record' and (e->>'payload')::jsonb->2='false'::jsonb and e->>'actor'=r.host_id::text from jsonb_array_elements(r.state->'events') with ordinality as x(e,n) order by n desc limit 1),false)
 ) from public.wm_rooms r where r.id=p_room
$wm$;
revoke all on function public.wm_recording_policy(uuid) from public,anon,authenticated;
grant execute on function public.wm_recording_policy(uuid) to service_role;

create function public.wm_recording_claim(p_room uuid,p_request uuid)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare policy jsonb; rid uuid:=gen_random_uuid(); x public.wm_recording_runs%rowtype;
begin
 perform 1 from public.wm_rooms where id=p_room for update;
 if not found then return null;end if;
 policy:=public.wm_recording_policy(p_room);
 if policy->>'permitted' is distinct from 'true' or policy->>'request_id' is distinct from p_request::text then return null;end if;
 insert into public.wm_recording_runs(id,room_id,request_id,object_name)
 values(rid,p_room,p_request,rid::text||'.ogg') on conflict do nothing returning * into x;
 if not found then return null;end if;
 return to_jsonb(x);
end $wm$;
revoke all on function public.wm_recording_claim(uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_recording_claim(uuid,uuid) to service_role;

-- Every change that removes consent or room availability fences recording state
-- immediately in the same transaction. Provider stop is handled by the worker.
create function public.wm_recording_room_guard()
returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare p jsonb;
begin
 p:=public.wm_recording_policy(new.id);
 if p->>'permitted' is distinct from 'true' then
  update public.wm_recording_runs
   set phase='stopping',disposition=case when disposition='discard' or p->>'normal_stop' is distinct from 'true' then 'discard' else 'retain' end
   where room_id=new.id and phase in ('starting','active','stopping');
 else
  update public.wm_recording_runs set phase='stopping',disposition='discard'
   where room_id=new.id and phase in ('starting','active','stopping') and request_id::text is distinct from p->>'request_id';
 end if;
 return new;
end $wm$;
revoke all on function public.wm_recording_room_guard() from public,anon,authenticated;
grant execute on function public.wm_recording_room_guard() to service_role;
create trigger wm_recording_guard after update of state on public.wm_rooms for each row execute function public.wm_recording_room_guard();

-- Public projection is limited to an admitted room member, never provider ID or path.
create function public.wm_recording_status(p_hash text,p_room uuid)
returns jsonb language plpgsql security invoker stable set search_path=pg_catalog,public as $wm$
declare r jsonb; x public.wm_recording_runs%rowtype; a record; p jsonb;
begin
 r:=public.wm_room_read(p_hash,p_room);
 if r is null then return null;end if;
 select * into a from public.wm_room_actor_for(p_hash,p_room);
 if not found or not exists(select 1 from jsonb_array_elements(r->'participants') x where x->>'memberId'=a.account_id::text and x->>'response'='accepted' and x->>'excluded'='false') then return null;end if;
 select * into x from public.wm_recording_runs where room_id=p_room order by created_at desc limit 1;
 if not found then return jsonb_build_object('phase','off');end if;
 p:=public.wm_recording_policy(p_room);
 return jsonb_build_object('phase',case when x.phase in ('starting','active') and p->>'permitted' is distinct from 'true' then 'stopping' else x.phase end,'started_at',x.started_at,'finished_at',x.finished_at);
end $wm$;
revoke all on function public.wm_recording_status(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_recording_status(text,uuid) to service_role;
commit;
