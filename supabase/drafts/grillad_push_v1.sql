-- Dedicated Firebase registration; no production project or delivery assumed.
begin;
create table grillad_private.push_devices(
 device_id uuid primary key references famille_private.account_devices(id),user_id uuid not null references auth.users(id),session_id uuid not null,token text not null unique check(length(token) between 30 and 4096 and token !~ '[[:space:]]'),project_id text not null check(project_id~'^[a-z][a-z0-9-]{4,28}[a-z0-9]$' and project_id<>'naxatechnologie'),
 enabled boolean not null default true,updated_at timestamptz not null default now()
);
alter table grillad_private.push_devices enable row level security;
revoke all on grillad_private.push_devices from public,anon,authenticated;
create function grillad_private.push_register(p_org uuid,p_site uuid,p_token text,p_project text,p_enabled boolean) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare d uuid;sid uuid;u uuid:=auth.uid();
begin
 perform grillad_private.scope(p_org,p_site);
 sid:=(auth.jwt()->>'session_id')::uuid;
 select id into d from famille_private.account_devices where user_id=u and app_code='grillad' and platform='android' and auth_session_id=sid and status='active';
 if d is null then raise exception 'GRILLAD_DEVICE' using errcode='42501';end if;
 if p_enabled is null then raise exception 'GRILLAD_PUSH_INPUT' using errcode='22023';end if;
 if not p_enabled then delete from grillad_private.push_devices where device_id=d and user_id=u;return jsonb_build_object('registered',false);end if;
 if p_token is null or length(p_token) not between 30 and 4096 or p_token~'[[:space:]]' or p_project is null or p_project!~'^[a-z][a-z0-9-]{4,28}[a-z0-9]$' or p_project='naxatechnologie' then raise exception 'GRILLAD_PUSH_INPUT' using errcode='22023';end if;
 -- A token may only be rebound by the same user/device; never take over another user's registration.
 if exists(select 1 from grillad_private.push_devices where token=p_token and device_id<>d) then raise exception 'GRILLAD_PUSH_TOKEN_BOUND' using errcode='42501';end if;
 insert into grillad_private.push_devices(device_id,user_id,session_id,token,project_id,enabled) values(d,u,sid,p_token,p_project,true)
 on conflict(device_id) do update set session_id=excluded.session_id,token=excluded.token,project_id=excluded.project_id,enabled=true,updated_at=now() where grillad_private.push_devices.user_id=u;
 return jsonb_build_object('registered',true,'delivery_qualified',false);
end $$;
create function public.grillad_push_register(p_org uuid,p_site uuid,p_token text,p_project text,p_enabled boolean) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.push_register(p_org,p_site,p_token,p_project,p_enabled)$$;
revoke all on function grillad_private.push_register(uuid,uuid,text,text,boolean),public.grillad_push_register(uuid,uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function grillad_private.push_register(uuid,uuid,text,text,boolean),public.grillad_push_register(uuid,uuid,text,text,boolean) to authenticated;
commit;
