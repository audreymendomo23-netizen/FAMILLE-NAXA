-- Isolated candidate: one reserved publishing room per verified account/installation.
-- Transport integration and actual SFU fencing remain mandatory before enabling.
begin;
create table public.wm_b6_device_media_leases(
 account_id uuid not null references public.wm_accounts(id),installation_id uuid not null,
 room_id uuid not null references public.wm_rooms(id),session_id uuid not null references public.wm_device_sessions(id),
 lease_id uuid not null unique,expires_at timestamptz not null,
 primary key(account_id,installation_id)
);
alter table public.wm_b6_device_media_leases enable row level security;
revoke all on public.wm_b6_device_media_leases from public,anon,authenticated;
grant select,insert,update,delete on public.wm_b6_device_media_leases to service_role;
create function public.wm_b6_device_media_claim(p_hash text,p_room uuid,p_lease uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;r jsonb;t timestamptz:=clock_timestamp(); deadline timestamptz;
begin
 if p_lease is null then return false;end if;
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return false;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-b6-device:'||s.account_id||':'||s.installation_id,0));
 -- Revalidate after acquiring the serialization lock.
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return false;end if;
 r:=public.wm_room_read(p_hash,p_room);
 if r is null or r->>'status' is distinct from 'open' or coalesce(r->>'confidentiality','standard') not in ('standard','confidential') or not exists(
 select 1 from jsonb_array_elements(r->'participants') p where p->>'memberId'=s.account_id::text and p->>'response'='accepted' and p->>'excluded'='false' and (r->>'lobbyRequired' is distinct from 'true' or r->>'hostId'=s.account_id::text or p->>'lobbyStatus'='admitted')) then return false;end if;
 deadline:=least(s.expires_at,to_timestamp((r->>'endMs')::double precision/1000),clock_timestamp()+interval '30 seconds');
 if deadline is null or deadline<=clock_timestamp() then return false;end if;
 insert into public.wm_b6_device_media_leases(account_id,installation_id,room_id,session_id,lease_id,expires_at)
 values(s.account_id,s.installation_id,p_room,s.session_id,p_lease,deadline)
 on conflict(account_id,installation_id) do update set room_id=excluded.room_id,session_id=excluded.session_id,lease_id=excluded.lease_id,expires_at=excluded.expires_at
 where wm_b6_device_media_leases.expires_at<=clock_timestamp() or (wm_b6_device_media_leases.room_id=excluded.room_id and wm_b6_device_media_leases.session_id=excluded.session_id and wm_b6_device_media_leases.lease_id=excluded.lease_id);
 return found;
end $wm$;
create function public.wm_b6_device_media_release(p_hash text,p_lease uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
begin
 delete from public.wm_b6_device_media_leases l using public.wm_session_context(p_hash) s where l.account_id=s.account_id and l.installation_id=s.installation_id and l.session_id=s.session_id and l.lease_id=p_lease and not s.password_change_required;
 return found;
end $wm$;
revoke all on function public.wm_b6_device_media_claim(text,uuid,uuid),public.wm_b6_device_media_release(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_b6_device_media_claim(text,uuid,uuid),public.wm_b6_device_media_release(text,uuid) to service_role;
commit;
