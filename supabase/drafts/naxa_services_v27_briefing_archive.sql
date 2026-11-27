-- DRAFT ONLY; requires v11. Server-generated snapshots, private per member.
begin;
create table public.ns_briefing_archives(
 id uuid primary key,org_id uuid not null,site_id uuid not null,member_id uuid not null,
 period_start date not null,period_end date not null,scope text not null check(scope in ('site','personal')),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='array'),created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 check(period_end-period_start between 0 and 29),check(jsonb_array_length(snapshot)=period_end-period_start+1)
);
create index ns_briefing_archives_owner_idx on public.ns_briefing_archives(org_id,site_id,member_id,created_at desc);
alter table public.ns_briefing_archives enable row level security;
revoke all on public.ns_briefing_archives from public,anon,authenticated;
grant select,insert,delete on public.ns_briefing_archives to service_role;
create function public.ns_archive_briefing(p_org uuid,p_site uuid,p_id uuid,p_start date,p_end date) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; fact jsonb; snapshots jsonb:='[]'::jsonb; d date; v_scope text; old public.ns_briefing_archives%rowtype; today date:=(now() at time zone 'Africa/Douala')::date;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or p_id is null or p_start is null or p_end is null or p_end-p_start not between 0 and 29 or p_start<today-366 or p_end>=today then raise exception 'NS_ARCHIVE_INVALID_OR_FORBIDDEN';end if;
 v_scope:=public.ns_daily_briefing(p_org,p_site,p_end)->>'scope';
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org::text||':'||p_site::text||':'||actor::text||':briefing-archive',0));
 select * into old from public.ns_briefing_archives where id=p_id;
 if found then
  if old.org_id<>p_org or old.site_id<>p_site or old.member_id<>actor or old.scope<>v_scope or old.period_start<>p_start or old.period_end<>p_end then raise exception 'NS_ARCHIVE_CONFLICT';end if;
  return jsonb_build_object('id',p_id,'scope',old.scope,'period_start',old.period_start,'period_end',old.period_end,'created_at',old.created_at);
 end if;
 if (select count(*) from public.ns_briefing_archives where org_id=p_org and site_id=p_site and member_id=actor)>=100 then raise exception 'NS_ARCHIVE_LIMIT';end if;
 d:=p_start;while d<=p_end loop
  fact:=public.ns_daily_briefing(p_org,p_site,d);if fact->>'scope'<>v_scope then raise exception 'NS_ARCHIVE_SCOPE_CHANGED';end if;
  snapshots:=snapshots||jsonb_build_array(fact);d:=d+1;
 end loop;
 insert into public.ns_briefing_archives(id,org_id,site_id,member_id,period_start,period_end,scope,snapshot) values(p_id,p_org,p_site,actor,p_start,p_end,v_scope,snapshots) returning * into old;
 return jsonb_build_object('id',old.id,'scope',old.scope,'period_start',old.period_start,'period_end',old.period_end,'created_at',old.created_at);
end $fn$;
create function public.ns_list_briefing_archives(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare actor uuid; v_scope text; today date:=(now() at time zone 'Africa/Douala')::date;
begin
 actor:=public.ns_current_member_id(p_org);if auth.uid() is null or actor is null then raise exception 'NS_ARCHIVE_FORBIDDEN';end if;
 v_scope:=public.ns_daily_briefing(p_org,p_site,today)->>'scope';
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id) from(select id,scope,period_start,period_end,created_at from public.ns_briefing_archives where org_id=p_org and site_id=p_site and member_id=actor and scope=v_scope order by created_at desc,id limit 100) q),'[]'::jsonb);
end $fn$;
create function public.ns_read_briefing_archive(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare actor uuid; v_scope text; today date:=(now() at time zone 'Africa/Douala')::date; a public.ns_briefing_archives%rowtype;
begin
 actor:=public.ns_current_member_id(p_org);if auth.uid() is null or actor is null then raise exception 'NS_ARCHIVE_FORBIDDEN';end if;
 v_scope:=public.ns_daily_briefing(p_org,p_site,today)->>'scope';
 select * into a from public.ns_briefing_archives where id=p_id and org_id=p_org and site_id=p_site and member_id=actor and scope=v_scope;
 if not found then raise exception 'NS_ARCHIVE_FORBIDDEN';end if;
 return jsonb_build_object('id',a.id,'scope',a.scope,'period_start',a.period_start,'period_end',a.period_end,'created_at',a.created_at,'snapshot',a.snapshot);
end $fn$;
create function public.ns_delete_briefing_archive(p_org uuid,p_site uuid,p_id uuid) returns boolean language plpgsql security definer set search_path='' as $fn$
declare actor uuid;
begin
 actor:=public.ns_current_member_id(p_org);if auth.uid() is null or actor is null then raise exception 'NS_ARCHIVE_FORBIDDEN';end if;
 perform public.ns_daily_briefing(p_org,p_site,(now() at time zone 'Africa/Douala')::date);
 delete from public.ns_briefing_archives where id=p_id and org_id=p_org and site_id=p_site and member_id=actor;
 return true;
end $fn$;
revoke all on function public.ns_archive_briefing(uuid,uuid,uuid,date,date),public.ns_list_briefing_archives(uuid,uuid),public.ns_read_briefing_archive(uuid,uuid,uuid),public.ns_delete_briefing_archive(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_archive_briefing(uuid,uuid,uuid,date,date),public.ns_list_briefing_archives(uuid,uuid),public.ns_read_briefing_archive(uuid,uuid,uuid),public.ns_delete_briefing_archive(uuid,uuid,uuid) to authenticated;
rollback;
