-- Atomic enterprise series; every occurrence independently remains under normal room policy.
begin;
create table public.wm_room_series(
 id uuid primary key,workspace_id uuid not null references public.wm_workspaces(id),
 host_id uuid not null references public.wm_accounts(id),states jsonb not null,
 created_at timestamptz not null default clock_timestamp(),cancelled_at timestamptz
);
alter table public.wm_room_series enable row level security;
revoke all on public.wm_room_series from public,anon,authenticated;
grant select,insert,update on public.wm_room_series to service_role;
create function public.wm_series_create(p_hash text,p_series uuid,p_states jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record;old public.wm_room_series%rowtype;item jsonb;
begin
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or a.role not in ('promoteur','manager') or not exists(select 1 from public.wm_workspaces where id=a.workspace_id and kind='enterprise') then return null;end if;
 if p_series is null or jsonb_typeof(p_states) is distinct from 'array' or jsonb_array_length(p_states) not between 2 and 12 then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-room-quota:'||a.workspace_id::text,0));
 select * into old from public.wm_room_series where id=p_series;
 if found then
  if old.workspace_id=a.workspace_id and old.host_id=a.account_id and old.states=p_states and old.cancelled_at is null then return jsonb_build_object('series_id',p_series,'count',jsonb_array_length(p_states));end if;
  return null;
 end if;
 -- PL/pgSQL exception block rolls back every insert if any occurrence fails.
 begin
  for item in select value from jsonb_array_elements(p_states) loop
   if item->>'seriesId' is distinct from p_series::text or item->>'status' is distinct from 'scheduled' or (item->>'scheduledMs')::bigint<floor(extract(epoch from clock_timestamp()-interval '5 seconds')*1000)::bigint or (item->>'scheduledMs')::bigint+(item->>'durationMinutes')::bigint*60000>a.entitlement_end_ms or not public.wm_room_create(p_hash,item) then raise exception 'series occurrence denied' using errcode='P0001';end if;
  end loop;
  insert into public.wm_room_series(id,workspace_id,host_id,states) values(p_series,a.workspace_id,a.account_id,p_states);
 exception when raise_exception or unique_violation or check_violation or foreign_key_violation then return null;
 end;
 return jsonb_build_object('series_id',p_series,'count',jsonb_array_length(p_states));
end $wm$;
revoke all on function public.wm_series_create(text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.wm_series_create(text,uuid,jsonb) to service_role;
create function public.wm_series_cancel(p_hash text,p_series uuid)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record;s public.wm_room_series%rowtype;total integer;
begin
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or a.role not in ('promoteur','manager') then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-room-quota:'||a.workspace_id::text,0));
 select * into s from public.wm_room_series where id=p_series and workspace_id=a.workspace_id and host_id=a.account_id for update;
 if not found then return null;end if;
 update public.wm_rooms set revision=revision+1,state=state||jsonb_build_object('revision',revision+1,'status','ended','cancelled',true,'recording','off') where workspace_id=a.workspace_id and host_id=a.account_id and state->>'seriesId'=p_series::text and state->>'status'='scheduled';
 get diagnostics total=row_count;
 update public.wm_room_series set cancelled_at=coalesce(cancelled_at,clock_timestamp()) where id=p_series;
 return jsonb_build_object('series_id',p_series,'cancelled',total);
end $wm$;
revoke all on function public.wm_series_cancel(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_series_cancel(text,uuid) to service_role;
commit;
