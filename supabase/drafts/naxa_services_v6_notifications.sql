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
    where (n.status = 'pending' and n.scheduled_at <= now())
       or (n.status = 'processing' and (n.claim_expires_at is null or n.claim_expires_at <= now()))
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

rollback;
