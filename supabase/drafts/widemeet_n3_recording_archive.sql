-- Host-only recording export candidate; explicit request audit, not delivery proof.
begin;
create table public.wm_recording_exports(
 request_id uuid primary key,recording_id uuid not null references public.wm_recording_runs(id),
 account_id uuid not null references public.wm_accounts(id),requested_at timestamptz not null default clock_timestamp()
);
alter table public.wm_recording_exports enable row level security;
revoke all on public.wm_recording_exports from public,anon,authenticated;
grant select,insert on public.wm_recording_exports to service_role;
create function public.wm_recording_archive(p_hash text,p_room uuid,p_action text,p_recording uuid default null,p_request uuid default null)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;r public.wm_rooms%rowtype;v public.wm_recording_runs%rowtype;role_name text;prior public.wm_recording_exports%rowtype;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for share;
 if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;
 if not found then return null;end if;
 select role into role_name from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled for share;
 if not found or role_name not in ('owner','promoteur','manager') then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;
 if not found or not exists(select 1 from public.wm_session_context(p_hash)) then return null;end if;
 select * into r from public.wm_rooms where id=p_room and workspace_id=s.workspace_id and host_id=s.account_id and state->>'status'='ended' and state->>'cancelled' is distinct from 'true' for share;
 if not found then return null;end if;
 if p_action='list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object('recording_id',x.id,'started_at',x.started_at,'finished_at',x.finished_at,'bytes',x.bytes,'sha256',x.content_sha256) order by x.created_at) from public.wm_recording_runs x where x.room_id=p_room and x.phase='complete' and x.disposition='retain' and x.storage_key is not null and x.finished_at>clock_timestamp()-interval '90 days'),'[]'::jsonb));
 end if;
 if p_action<>'read' or p_recording is null or p_request is null then return null;end if;
 select * into v from public.wm_recording_runs where id=p_recording and room_id=p_room and phase='complete' and disposition='retain' and storage_key is not null and finished_at>clock_timestamp()-interval '90 days' for share;
 if not found then return null;end if;
 insert into public.wm_recording_exports(request_id,recording_id,account_id) values(p_request,p_recording,s.account_id) on conflict do nothing;
 select * into prior from public.wm_recording_exports where request_id=p_request;
 if prior.recording_id<>p_recording or prior.account_id<>s.account_id then return null;end if;
 return jsonb_build_object('key',v.storage_key,'bytes',v.bytes,'sha256',v.content_sha256);
end $wm$;
revoke all on function public.wm_recording_archive(text,uuid,text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_recording_archive(text,uuid,text,uuid,uuid) to service_role;
commit;
