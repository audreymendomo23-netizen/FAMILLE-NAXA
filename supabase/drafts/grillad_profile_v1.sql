-- GRILLAD-only personal settings, independent of shared Auth identity.
begin;
create table grillad_private.personal_profiles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(length(display_name) between 2 and 80 and display_name !~ '[[:cntrl:]]'),
 revision integer not null check(revision>0),
 updated_at timestamptz not null default now()
);
alter table grillad_private.personal_profiles enable row level security;
revoke all on grillad_private.personal_profiles from public,anon,authenticated;
create function grillad_private.profile_get(p_org uuid,p_site uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare v grillad_private.personal_profiles%rowtype;
begin
 perform grillad_private.scope(p_org,p_site);
 select * into v from grillad_private.personal_profiles where user_id=auth.uid();
 return jsonb_build_object('display_name',coalesce(v.display_name,''),'revision',coalesce(v.revision,0));
end $fn$;
create function grillad_private.profile_set(p_org uuid,p_site uuid,p_name text,p_revision integer) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare u uuid:=auth.uid();v grillad_private.personal_profiles%rowtype;n text:=btrim(p_name);
begin
 perform grillad_private.scope(p_org,p_site);
 if u is null or n is null or length(n) not between 2 and 80 or n ~ '[[:cntrl:]]' or p_revision is null or p_revision<0 then raise exception 'GRILLAD_PROFILE_INPUT' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('grillad-profile:'||u::text,0));
 select * into v from grillad_private.personal_profiles where user_id=u;
 if found and v.display_name=n then return jsonb_build_object('display_name',v.display_name,'revision',v.revision);end if;
 if coalesce(v.revision,0)<>p_revision then raise exception 'GRILLAD_PROFILE_CONFLICT' using errcode='22023';end if;
 insert into grillad_private.personal_profiles(user_id,display_name,revision) values(u,n,1)
 on conflict(user_id) do update set display_name=excluded.display_name,revision=personal_profiles.revision+1,updated_at=now()
 returning * into v;
 return jsonb_build_object('display_name',v.display_name,'revision',v.revision);
end $fn$;
create function public.grillad_profile_get(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.profile_get(p_org,p_site)$fn$;
create function public.grillad_profile_set(p_org uuid,p_site uuid,p_name text,p_revision integer) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.profile_set(p_org,p_site,p_name,p_revision)$fn$;
revoke all on function grillad_private.profile_get(uuid,uuid),grillad_private.profile_set(uuid,uuid,text,integer),public.grillad_profile_get(uuid,uuid),public.grillad_profile_set(uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function grillad_private.profile_get(uuid,uuid),grillad_private.profile_set(uuid,uuid,text,integer),public.grillad_profile_get(uuid,uuid),public.grillad_profile_set(uuid,uuid,text,integer) to authenticated;
commit;
