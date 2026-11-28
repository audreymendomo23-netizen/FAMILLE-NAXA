-- DRAFT ONLY: archive completion emits a real private in-app notification, not a push delivery claim.
begin;
create function public.ns_briefing_archive_notice() returns trigger language plpgsql security definer set search_path='' as $fn$
declare notice uuid;
begin
 insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted,status,sent_at)
 values(new.org_id,new.site_id,new.member_id,'in_app','briefing_archive_ready','briefing-archive:'||new.id::text,'{}'::jsonb,'sent',now())
 on conflict(org_id,channel,idempotency_key) do nothing returning id into notice;
 if notice is not null then
  insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
  values(new.org_id,new.site_id,new.member_id,notice,'briefing_archive_ready','{}'::jsonb,'sent',now())
  on conflict(notification_id,member_id) do nothing;
 end if;
 return new;
end $fn$;
revoke all on function public.ns_briefing_archive_notice() from public,anon,authenticated,service_role;
create trigger ns_briefing_archive_ready after insert on public.ns_briefing_archives for each row execute function public.ns_briefing_archive_notice();
rollback;
