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
create function public.ns_emit_due_briefing_reminders() returns integer language plpgsql security definer set search_path='' as $fn$
declare today date:=(now() at time zone 'Africa/Douala')::date;n integer;
begin
 -- Once daily at 07:00 Douala or later; weekly on Mondays. No catchup flood.
 if extract(hour from now() at time zone 'Africa/Douala')<7 then return 0;end if;
 with eligible as (
 select r.* from public.ns_briefing_reminders r join public.ns_members m on m.id=r.member_id and m.org_id=r.org_id
 join public.ns_accounts a on a.id=m.account_id join public.ns_organizations o on o.id=r.org_id join public.ns_sites s on s.id=r.site_id and s.org_id=r.org_id
 where (r.mode='daily' or (r.mode='weekly' and extract(isodow from today)=1)) and m.status='active' and a.status='active' and not a.password_change_required and o.status='active' and s.status='active'
 and exists(select 1 from public.ns_member_scopes sc where sc.org_id=r.org_id and sc.member_id=r.member_id and sc.can_read and (sc.scope_type='organization' or sc.site_id=r.site_id))
 and not exists(select 1 from public.ns_notification_outbox x where x.org_id=r.org_id and x.channel='in_app' and x.idempotency_key='briefing-reminder:'||r.site_id::text||':'||r.member_id::text||':'||today::text)
 order by r.org_id,r.site_id,r.member_id limit 1000 for share of r,m,a,s
 ), notices as (
 insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted,status,sent_at)
 select org_id,site_id,member_id,'in_app','briefing_reminder','briefing-reminder:'||site_id::text||':'||member_id::text||':'||today::text,'{}'::jsonb,'sent',now() from eligible
 on conflict(org_id,channel,idempotency_key) do nothing returning id,org_id,site_id,recipient_member_id
 )
 insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
 select org_id,site_id,recipient_member_id,id,'briefing_reminder','{}'::jsonb,'sent',now() from notices on conflict(notification_id,member_id) do nothing;
 get diagnostics n=row_count;return n;
end $fn$;
revoke all on function public.ns_emit_due_briefing_reminders() from public,anon,authenticated;
grant execute on function public.ns_emit_due_briefing_reminders() to service_role;
rollback;
