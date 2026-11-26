create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create schema if not exists ns_private;
revoke all on schema ns_private from public,anon,authenticated;
create table if not exists ns_private.notification_dispatch_tickets (
  ticket_hash bytea primary key, expires_at timestamptz not null, created_at timestamptz not null default now()
);
alter table ns_private.notification_dispatch_tickets enable row level security;
revoke all on ns_private.notification_dispatch_tickets from public,anon,authenticated,service_role;
create or replace function public.ns_consume_notification_dispatch_ticket(p_ticket text)
returns boolean language plpgsql security definer set search_path='' as $fn$
begin
  if p_ticket is null or p_ticket !~ '^[0-9a-f]{64}$' then return false; end if;
  delete from ns_private.notification_dispatch_tickets
    where ticket_hash=extensions.digest(p_ticket,'sha256') and expires_at>now();
  return found;
end $fn$;
revoke all on function public.ns_consume_notification_dispatch_ticket(text) from public,anon,authenticated;
grant execute on function public.ns_consume_notification_dispatch_ticket(text) to service_role;
create or replace function ns_private.enqueue_notification_dispatch(p_force boolean default false)
returns bigint language plpgsql security definer set search_path='' as $fn$
declare v_ticket text; v_request bigint;
begin
  delete from ns_private.notification_dispatch_tickets where expires_at<=now();
  if not coalesce(p_force,false) and not exists (
    select 1 from public.ns_notification_outbox n
    where n.channel='push' and n.recipient_member_id is not null
      and ((n.status='pending' and n.scheduled_at<=now()) or (n.status='processing' and coalesce(n.claim_expires_at,now())<=now()))
  ) then return null; end if;
  v_ticket:=encode(extensions.gen_random_bytes(32),'hex');
  insert into ns_private.notification_dispatch_tickets(ticket_hash,expires_at) values(extensions.digest(v_ticket,'sha256'),now()+interval '2 minutes');
  select net.http_post(url:='https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-notifications',
    headers:=jsonb_build_object('Content-Type','application/json','x-naxa-dispatch-ticket',v_ticket),
    body:=jsonb_build_object('app_code','naxa-services','action','dispatch_scheduled','limit',10),
    timeout_milliseconds:=30000) into v_request;
  return v_request;
end $fn$;
revoke all on function ns_private.enqueue_notification_dispatch(boolean) from public,anon,authenticated,service_role;
