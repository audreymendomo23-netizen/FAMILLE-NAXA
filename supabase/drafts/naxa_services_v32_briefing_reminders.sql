-- DRAFT ONLY. Opt-in recurring private in-app reminders. No financial payload, no push-delivery claim.
begin;
create table public.ns_briefing_reminders(
 org_id uuid not null,site_id uuid not null,member_id uuid not null,mode text not null check(mode in ('off','daily','weekly')),
 updated_at timestamptz not null default now(),primary key(org_id,site_id,member_id),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),foreign key(member_id,org_id) references public.ns_members(id,org_id)
);
alter table public.ns_briefing_reminders enable row level security;
revoke all on public.ns_briefing_reminders from public,anon,authenticated;
grant select,insert,update on public.ns_briefing_reminders to service_role;
create function public.ns_set_briefing_reminder(p_org uuid,p_site uuid,p_mode text) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid:=public.ns_current_member_id(p_org);
begin
 if auth.uid() is null or actor is null or p_mode is null or p_mode not in ('off','daily','weekly') then raise exception 'NS_BRIEFING_REMINDER_FORBIDDEN';end if;
 perform public.ns_daily_briefing(p_org,p_site,(now() at time zone 'Africa/Douala')::date);
 insert into public.ns_briefing_reminders(org_id,site_id,member_id,mode) values(p_org,p_site,actor,p_mode)
 on conflict(org_id,site_id,member_id) do update set mode=excluded.mode,updated_at=now();
 return jsonb_build_object('mode',p_mode);
end $fn$;
revoke all on function public.ns_set_briefing_reminder(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ns_set_briefing_reminder(uuid,uuid,text) to authenticated;

create function ns_briefing_internal.phase_at(p_at timestamptz) returns text language sql stable set search_path='' as $fn$
 select case when extract(hour from p_at at time zone 'Africa/Douala')<12 then 'morning' when extract(hour from p_at at time zone 'Africa/Douala')<18 then 'intermediate' else 'evening' end
$fn$;
revoke all on function ns_briefing_internal.phase_at(timestamptz) from public,anon,authenticated,service_role;
create table ns_briefing_internal.moments(
 org_id uuid not null,site_id uuid not null,member_id uuid not null,day date not null,phase text not null check(phase in ('morning','intermediate','evening')),
 scope_hash text not null,snapshot jsonb not null,created_at timestamptz not null default now(),
 primary key(org_id,site_id,member_id,day,phase,scope_hash),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),foreign key(member_id,org_id) references public.ns_members(id,org_id)
);
alter table ns_briefing_internal.moments enable row level security;
revoke all on ns_briefing_internal.moments from public,anon,authenticated,service_role;
create function ns_briefing_internal.capture(p_org uuid,p_site uuid,p_actor uuid,p_day date,p_phase text) returns jsonb language plpgsql set search_path='' as $fn$
declare today date:=(now() at time zone 'Africa/Douala')::date; h text; report jsonb;
begin
 if p_day is null or p_day>today or p_day<today-366 or p_phase is null or p_phase not in ('morning','intermediate','evening') or not ns_briefing_internal.can_build(p_org,p_site,p_actor) then raise exception 'NS_BRIEFING_MOMENT_FORBIDDEN';end if;
 h:=ns_briefing_internal.scope_hash(p_org,p_actor);
 select snapshot into report from ns_briefing_internal.moments where org_id=p_org and site_id=p_site and member_id=p_actor and day=p_day and phase=p_phase and scope_hash=h;
 if found then return report;end if;
 if p_day<>today or p_phase<>ns_briefing_internal.phase_at(now()) then raise exception 'NS_BRIEFING_MOMENT_UNAVAILABLE';end if;
 report:=ns_briefing_internal.build(p_org,p_site,p_day,p_actor)||jsonb_build_object('phase',p_phase,'snapshot_version',1);
 insert into ns_briefing_internal.moments(org_id,site_id,member_id,day,phase,scope_hash,snapshot) values(p_org,p_site,p_actor,p_day,p_phase,h,report) on conflict do nothing;
 select snapshot into report from ns_briefing_internal.moments where org_id=p_org and site_id=p_site and member_id=p_actor and day=p_day and phase=p_phase and scope_hash=h;
 if not found then raise exception 'NS_BRIEFING_MOMENT_UNAVAILABLE';end if;
 return report;
end $fn$;
revoke all on function ns_briefing_internal.capture(uuid,uuid,uuid,date,text) from public,anon,authenticated,service_role;
create function public.ns_read_briefing_moment(p_org uuid,p_site uuid,p_day date,p_phase text) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid:=public.ns_current_member_id(p_org);
begin
 if auth.uid() is null or actor is null or public.ns_erp_access_reason(p_org)='blocked' then raise exception 'NS_BRIEFING_MOMENT_FORBIDDEN';end if;
 return ns_briefing_internal.capture(p_org,p_site,actor,p_day,p_phase);
end $fn$;
revoke all on function public.ns_read_briefing_moment(uuid,uuid,date,text) from public,anon,authenticated;
grant execute on function public.ns_read_briefing_moment(uuid,uuid,date,text) to authenticated;

create function public.ns_emit_due_briefing_reminders() returns integer language plpgsql security definer set search_path='' as $fn$
declare today date:=(now() at time zone 'Africa/Douala')::date; current_phase text:=ns_briefing_internal.phase_at(now());n integer:=0;r record;notice uuid;k text;
begin
 -- Three distinct current moments; no fabricated catch-up snapshots. Preference and entitlement are rechecked.
 if extract(hour from now() at time zone 'Africa/Douala')<7 then return 0;end if;
 for r in select x.* from public.ns_briefing_reminders x
 where (x.mode='daily' or (x.mode='weekly' and extract(isodow from today)=1))
 and ns_briefing_internal.can_build(x.org_id,x.site_id,x.member_id)
 and not exists(select 1 from public.ns_notification_outbox o where o.org_id=x.org_id and o.channel='in_app' and o.idempotency_key='briefing-moment:'||x.site_id::text||':'||x.member_id::text||':'||today::text||':'||current_phase)
 order by x.org_id,x.site_id,x.member_id limit 100 for share of x loop
  perform ns_briefing_internal.capture(r.org_id,r.site_id,r.member_id,today,current_phase);
  k:='briefing-moment:'||r.site_id::text||':'||r.member_id::text||':'||today::text||':'||current_phase;
  notice:=null;
  insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted,status,sent_at)
  values(r.org_id,r.site_id,r.member_id,'in_app','briefing_reminder',k,'{}'::jsonb,'sent',now())
  on conflict(org_id,channel,idempotency_key) do nothing returning id into notice;
  if notice is not null then
   insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
   values(r.org_id,r.site_id,r.member_id,notice,'briefing_reminder','{}'::jsonb,'sent',now()) on conflict(notification_id,member_id) do nothing;
   n:=n+1;
  end if;
 end loop;
 return n;
end $fn$;
revoke all on function public.ns_emit_due_briefing_reminders() from public,anon,authenticated;
grant execute on function public.ns_emit_due_briefing_reminders() to service_role;
rollback;
