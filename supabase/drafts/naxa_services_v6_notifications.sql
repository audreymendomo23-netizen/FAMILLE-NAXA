-- NAXA SERVICES v6 candidate: secure push devices, notification inbox and leased delivery worker.
-- DRAFT ONLY. ROLLBACK by default. Do not deploy without isolated Supabase + Firebase secrets review.
begin;

alter table public.ns_notification_outbox
  add column if not exists claim_token uuid,
  add column if not exists claim_expires_at timestamptz;

create table if not exists public.ns_push_tokens (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  member_id uuid not null,
  device_id uuid not null references public.ns_devices(id) on delete restrict,
  platform text not null check (platform in ('android','web')),
  token_ciphertext text not null check (length(token_ciphertext) between 40 and 8192),
  token_iv text not null check (length(token_iv) between 12 and 64),
  token_fingerprint text not null check (token_fingerprint ~ '^[0-9a-f]{64}$'),
  token_tail text not null check (length(token_tail) between 4 and 8),
  status text not null default 'active' check (status in ('active','revoked')),
  registered_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  foreign key (member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (org_id, token_fingerprint),
  unique (id, org_id)
);
create index if not exists ns_push_tokens_recipient_idx
  on public.ns_push_tokens(org_id, member_id, status, last_seen_at desc);

create table if not exists public.ns_notification_inbox (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  site_id uuid,
  member_id uuid not null,
  notification_id uuid not null references public.ns_notification_outbox(id) on delete restrict,
  event_code text not null,
  payload_redacted jsonb not null default '{}'::jsonb,
  status text not null default 'sent' check (status in ('sent','read','actioned')),
  sent_at timestamptz not null default now(),
  read_at timestamptz,
  actioned_at timestamptz,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (notification_id, member_id)
);
create index if not exists ns_notification_inbox_member_idx
  on public.ns_notification_inbox(org_id, member_id, sent_at desc);

-- Claim rows with SKIP LOCKED and a short lease. Stale workers cannot complete a claim
-- after another worker has reclaimed it because every finalizer must present claim_token.
create or replace function public.ns_claim_notification_batch(p_limit integer default 25)
returns table (
  id uuid,
  org_id uuid,
  site_id uuid,
  recipient_member_id uuid,
  event_code text,
  idempotency_key text,
  payload_redacted jsonb,
  attempts integer,
  claim_token uuid
)
language sql
security definer
set search_path = ''
as $naxa$
  with due as (
    select n.id
    from public.ns_notification_outbox n
    where n.channel = 'push' and n.recipient_member_id is not null
      and ((n.status = 'pending' and n.scheduled_at <= now())
       or (n.status = 'processing' and (n.claim_expires_at is null or n.claim_expires_at <= now())))
    order by n.scheduled_at, n.created_at
    for update skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 100)
  ), claimed as (
    update public.ns_notification_outbox n
    set status = 'processing',
        attempts = n.attempts + 1,
        claim_token = gen_random_uuid(),
        claim_expires_at = now() + interval '5 minutes',
        last_error_code = null
    from due
    where n.id = due.id
    returning n.id, n.org_id, n.site_id, n.recipient_member_id,
      n.event_code, n.idempotency_key, n.payload_redacted, n.attempts, n.claim_token
  )
  select * from claimed;
$naxa$;

create or replace function public.ns_finish_notification_send(
  p_notification_id uuid,
  p_claim_token uuid,
  p_provider_reference text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_row public.ns_notification_outbox%rowtype;
  v_rows integer;
begin
  if p_notification_id is null or p_claim_token is null
     or nullif(trim(p_provider_reference), '') is null then
    raise exception 'NAXA_NOTIFICATION_FINALIZATION_INPUT_INVALID';
  end if;

  update public.ns_notification_outbox n
  set status = 'sent',
      provider_reference = trim(p_provider_reference),
      sent_at = now(),
      claim_token = null,
      claim_expires_at = null
  where n.id = p_notification_id
    and n.status = 'processing'
    and n.claim_token = p_claim_token
  returning n.* into v_row;
  if not found then return false; end if;

  if v_row.recipient_member_id is not null then
    insert into public.ns_notification_inbox(
      org_id, site_id, member_id, notification_id, event_code, payload_redacted, status, sent_at
    ) values (
      v_row.org_id, v_row.site_id, v_row.recipient_member_id, v_row.id,
      v_row.event_code, v_row.payload_redacted, 'sent', coalesce(v_row.sent_at, now())
    )
    on conflict (notification_id, member_id) do nothing;
  end if;
  return true;
end;
$naxa$;

create or replace function public.ns_fail_notification_send(
  p_notification_id uuid,
  p_claim_token uuid,
  p_error_code text,
  p_retryable boolean default true
) returns text
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_status text;
begin
  if p_notification_id is null or p_claim_token is null
     or nullif(trim(p_error_code), '') is null then
    raise exception 'NAXA_NOTIFICATION_FAILURE_INPUT_INVALID';
  end if;

  update public.ns_notification_outbox n
  set status = case when coalesce(p_retryable, true) and n.attempts < 5 then 'pending' else 'failed' end,
      scheduled_at = case
        when coalesce(p_retryable, true) and n.attempts < 5
        then now() + make_interval(secs => least(1800, 30 * (2 ^ least(n.attempts, 6))::integer))
        else n.scheduled_at
      end,
      last_error_code = left(trim(p_error_code), 100),
      claim_token = null,
      claim_expires_at = null
  where n.id = p_notification_id
    and n.status = 'processing'
    and n.claim_token = p_claim_token
  returning n.status into v_status;

  return coalesce(v_status, 'claim_lost');
end;
$naxa$;

alter table public.ns_push_tokens enable row level security;
alter table public.ns_notification_inbox enable row level security;

revoke all on public.ns_push_tokens, public.ns_notification_inbox from public, anon, authenticated;
grant all on public.ns_push_tokens, public.ns_notification_inbox to service_role;

revoke all on function public.ns_claim_notification_batch(integer) from public, anon, authenticated;
grant execute on function public.ns_claim_notification_batch(integer) to service_role;
revoke all on function public.ns_finish_notification_send(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.ns_finish_notification_send(uuid,uuid,text) to service_role;
revoke all on function public.ns_fail_notification_send(uuid,uuid,text,boolean) from public, anon, authenticated;
grant execute on function public.ns_fail_notification_send(uuid,uuid,text,boolean) to service_role;

-- One Firebase installation token belongs to a single current NAXA SERVICES account.
create unique index if not exists ns_push_tokens_global_fingerprint_uidx on public.ns_push_tokens(token_fingerprint);
create or replace function public.ns_register_bound_push_token(p_org_id uuid,p_member_id uuid,p_device_id uuid,p_session_id text,p_platform text,p_ciphertext text,p_iv text,p_fingerprint text,p_tail text)
returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_id uuid;
begin
  perform 1 from public.ns_devices d join public.ns_accounts a on a.id=d.account_id join public.ns_members m on m.account_id=a.id join public.ns_organizations o on o.id=m.org_id join auth.sessions s on s.id::text=d.session_id and s.user_id=a.auth_user_id
  where d.id=p_device_id and d.session_id=p_session_id and d.platform=p_platform and d.revoked_at is null and a.status='active' and m.id=p_member_id and m.org_id=p_org_id and m.status='active' and o.status='active' and (s.not_after is null or s.not_after>now()) for update of d;
  if not found then raise exception 'NS_PUSH_SESSION_NOT_ACTIVE' using errcode='42501'; end if;
  insert into public.ns_push_tokens(org_id,member_id,device_id,platform,token_ciphertext,token_iv,token_fingerprint,token_tail,status,revoked_at,last_seen_at)
  values(p_org_id,p_member_id,p_device_id,p_platform,p_ciphertext,p_iv,p_fingerprint,p_tail,'active',null,now())
  on conflict(token_fingerprint) do update set org_id=excluded.org_id,member_id=excluded.member_id,device_id=excluded.device_id,platform=excluded.platform,token_ciphertext=excluded.token_ciphertext,token_iv=excluded.token_iv,token_tail=excluded.token_tail,status='active',revoked_at=null,last_seen_at=now()
  returning id into v_id;
  update public.ns_push_tokens set status='revoked',revoked_at=now() where device_id=p_device_id and id<>v_id and status='active';
  return v_id;
end $fn$;
create or replace function public.ns_live_push_tokens(p_org_id uuid,p_member_id uuid)
returns table(id uuid,token_ciphertext text,token_iv text) language sql security definer set search_path='' as $fn$
  select t.id,t.token_ciphertext,t.token_iv from public.ns_push_tokens t
  join public.ns_devices d on d.id=t.device_id and d.platform=t.platform
  join public.ns_accounts a on a.id=d.account_id
  join public.ns_members m on m.id=t.member_id and m.org_id=t.org_id and m.account_id=a.id
  join public.ns_organizations o on o.id=m.org_id
  join auth.sessions s on s.id::text=d.session_id and s.user_id=a.auth_user_id
  where t.org_id=p_org_id and t.member_id=p_member_id and t.status='active' and t.revoked_at is null and d.revoked_at is null and a.status='active' and m.status='active' and o.status='active' and (s.not_after is null or s.not_after>now())
  order by t.last_seen_at desc,t.id limit 20;
$fn$;
revoke all on function public.ns_register_bound_push_token(uuid,uuid,uuid,text,text,text,text,text,text),public.ns_live_push_tokens(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_register_bound_push_token(uuid,uuid,uuid,text,text,text,text,text,text),public.ns_live_push_tokens(uuid,uuid) to service_role;

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

rollback;
