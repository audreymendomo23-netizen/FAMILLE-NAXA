create extension if not exists http with schema extensions;
do $setup$
begin
 if not exists(select 1 from vault.secrets where name='ns_notification_scheduler_hmac_v1') then
   perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'ns_notification_scheduler_hmac_v1','NAXA SERVICES scheduled dispatch signing key');
 end if;
end $setup$;
create or replace function public.ns_consume_notification_dispatch_ticket(p_ticket text)
returns boolean language plpgsql security definer set search_path='' as $fn$
declare v_key text; v_payload text; v_expected text; v_epoch bigint; v_now bigint;
begin
 if p_ticket is null or p_ticket !~ '^[0-9]{10}\.[0-9a-f]{32}\.[0-9a-f]{64}$' then return false; end if;
 v_epoch:=split_part(p_ticket,'.',1)::bigint; v_now:=floor(extract(epoch from clock_timestamp()))::bigint;
 if v_epoch<v_now-90 or v_epoch>v_now+10 then return false; end if;
 select decrypted_secret into v_key from vault.decrypted_secrets where name='ns_notification_scheduler_hmac_v1';
 if v_key is null then return false; end if;
 v_payload:=split_part(p_ticket,'.',1)||'.'||split_part(p_ticket,'.',2);
 v_expected:=encode(extensions.hmac(v_payload,v_key,'sha256'),'hex');
 if v_expected<>split_part(p_ticket,'.',3) then return false; end if;
 insert into ns_private.notification_dispatch_tickets(ticket_hash,expires_at) values(extensions.digest(p_ticket,'sha256'),clock_timestamp()+interval '2 minutes') on conflict do nothing;
 return found;
end $fn$;
revoke all on function public.ns_consume_notification_dispatch_ticket(text) from public,anon,authenticated;
grant execute on function public.ns_consume_notification_dispatch_ticket(text) to service_role;
create or replace function ns_private.enqueue_notification_dispatch(p_force boolean default false)
returns bigint language plpgsql security definer set search_path='' as $fn$
declare v_key text; v_payload text; v_ticket text; v_response extensions.http_response;
begin
 delete from ns_private.notification_dispatch_tickets where expires_at<=now();
 if not coalesce(p_force,false) and not exists (
  select 1 from public.ns_notification_outbox n where n.channel='push' and n.recipient_member_id is not null
    and ((n.status='pending' and n.scheduled_at<=now()) or (n.status='processing' and coalesce(n.claim_expires_at,now())<=now()))
 ) then return null; end if;
 select decrypted_secret into strict v_key from vault.decrypted_secrets where name='ns_notification_scheduler_hmac_v1';
 v_payload:=floor(extract(epoch from clock_timestamp()))::bigint::text||'.'||encode(extensions.gen_random_bytes(16),'hex');
 v_ticket:=v_payload||'.'||encode(extensions.hmac(v_payload,v_key,'sha256'),'hex');
 perform set_config('http.curlopt_timeout_msec','30000',true);
 select * into v_response from extensions.http(('POST','https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-notifications',array[extensions.http_header('x-naxa-dispatch-ticket',v_ticket)],'application/json','{"app_code":"naxa-services","action":"dispatch_scheduled","limit":10}')::extensions.http_request);
 if v_response.status<>200 then raise exception 'NS_SCHEDULED_DISPATCH_HTTP_%',v_response.status; end if;
 return v_response.status::bigint;
end $fn$;
revoke all on function ns_private.enqueue_notification_dispatch(boolean) from public,anon,authenticated,service_role;
