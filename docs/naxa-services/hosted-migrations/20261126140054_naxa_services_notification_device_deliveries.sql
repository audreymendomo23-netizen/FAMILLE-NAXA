-- Track terminal provider outcomes per notification/installation. Never expose token material.
create table if not exists public.ns_notification_device_deliveries (
  notification_id uuid not null references public.ns_notification_outbox(id) on delete restrict,
  token_id uuid not null references public.ns_push_tokens(id) on delete restrict,
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  member_id uuid not null,
  outcome text not null check(outcome in ('accepted','rejected')),
  provider_reference text,
  error_code text,
  recorded_at timestamptz not null default now(),
  primary key(notification_id,token_id),
  foreign key(member_id,org_id) references public.ns_members(id,org_id) on delete restrict,
  check((outcome='accepted' and provider_reference is not null and error_code is null) or (outcome='rejected' and provider_reference is null and error_code is not null))
);
alter table public.ns_notification_device_deliveries enable row level security;
revoke all on public.ns_notification_device_deliveries from public,anon,authenticated;
grant all on public.ns_notification_device_deliveries to service_role;

create or replace function public.ns_pending_push_targets(p_notification_id uuid,p_claim_token uuid)
returns table(id uuid,token_ciphertext text,token_iv text)
language sql security definer set search_path='' as $fn$
 select t.id,t.token_ciphertext,t.token_iv
 from public.ns_notification_outbox n
 cross join lateral public.ns_live_push_tokens(n.org_id,n.recipient_member_id) t
 where n.id=p_notification_id and n.claim_token=p_claim_token and n.status='processing'
   and n.claim_expires_at>now() and n.channel='push'
   and not exists(select 1 from public.ns_notification_device_deliveries d where d.notification_id=n.id and d.token_id=t.id);
$fn$;
create or replace function public.ns_record_push_device_outcome(p_notification_id uuid,p_claim_token uuid,p_token_id uuid,p_outcome text,p_provider_reference text,p_error_code text)
returns boolean language plpgsql security definer set search_path='' as $fn$
declare v_row public.ns_notification_outbox%rowtype;
begin
 select n.* into v_row from public.ns_notification_outbox n where n.id=p_notification_id and n.claim_token=p_claim_token and n.status='processing' and n.claim_expires_at>now() and n.channel='push' for update;
 if not found then return false; end if;
 if not exists(select 1 from public.ns_push_tokens t where t.id=p_token_id and t.org_id=v_row.org_id and t.member_id=v_row.recipient_member_id) then return false; end if;
 if p_outcome not in ('accepted','rejected') then return false; end if;
 insert into public.ns_notification_device_deliveries(notification_id,token_id,org_id,member_id,outcome,provider_reference,error_code)
 values(v_row.id,p_token_id,v_row.org_id,v_row.recipient_member_id,p_outcome,case when p_outcome='accepted' then left(nullif(trim(p_provider_reference),''),512) end,case when p_outcome='rejected' then left(nullif(trim(p_error_code),''),100) end)
 on conflict(notification_id,token_id) do nothing;
 return true;
end $fn$;
create or replace function public.ns_push_delivery_summary(p_notification_id uuid,p_claim_token uuid)
returns jsonb language sql security definer set search_path='' as $fn$
 select jsonb_build_object(
  'accepted',(select count(*) from public.ns_notification_device_deliveries d where d.notification_id=n.id and d.outcome='accepted'),
  'rejected',(select count(*) from public.ns_notification_device_deliveries d where d.notification_id=n.id and d.outcome='rejected'),
  'pending',(select count(*) from public.ns_pending_push_targets(n.id,p_claim_token)),
  'provider_reference',(select d.provider_reference from public.ns_notification_device_deliveries d where d.notification_id=n.id and d.outcome='accepted' order by d.recorded_at,d.token_id limit 1))
 from public.ns_notification_outbox n
 where n.id=p_notification_id and n.claim_token=p_claim_token and n.status='processing' and n.claim_expires_at>now() and n.channel='push';
$fn$;
revoke all on function public.ns_pending_push_targets(uuid,uuid),public.ns_record_push_device_outcome(uuid,uuid,uuid,text,text,text),public.ns_push_delivery_summary(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_pending_push_targets(uuid,uuid),public.ns_record_push_device_outcome(uuid,uuid,uuid,text,text,text),public.ns_push_delivery_summary(uuid,uuid) to service_role;

