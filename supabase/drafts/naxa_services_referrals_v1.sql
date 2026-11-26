-- NAXA SERVICES referrals — candidate migration, deliberately NOT applied.
-- The client never writes qualification/rewards. Only a signed server-to-server
-- first-paid-subscription event can qualify a referral.
begin;

create table if not exists public.ns_referral_codes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null unique references public.ns_organizations(id) on delete restrict,
  code text not null unique check (code ~ '^NS-[A-Z0-9]{7}$'),
  status text not null default 'active' check (status in ('active','revoked')),
  created_by_member uuid not null references public.ns_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists public.ns_referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_org_id uuid not null references public.ns_organizations(id) on delete restrict,
  referred_org_id uuid not null unique references public.ns_organizations(id) on delete restrict,
  referral_code_id uuid not null references public.ns_referral_codes(id) on delete restrict,
  referred_org_name_snapshot text not null,
  status text not null default 'pending' check (status in ('pending','qualified','rejected')),
  created_at timestamptz not null default now(),
  first_subscription_paid_at timestamptz,
  first_subscription_id text unique,
  provider_event_id text unique,
  referrer_plan_cadence text check (referrer_plan_cadence is null or referrer_plan_cadence in ('monthly','annual')),
  check (referrer_org_id <> referred_org_id),
  check (
    (status = 'pending' and first_subscription_paid_at is null and first_subscription_id is null and provider_event_id is null)
    or
    (status = 'qualified' and first_subscription_paid_at is not null and first_subscription_id is not null and provider_event_id is not null and referrer_plan_cadence is not null)
    or status = 'rejected'
  )
);
create index if not exists ns_referrals_referrer_created_idx
  on public.ns_referrals(referrer_org_id, created_at desc);
create index if not exists ns_referrals_referrer_activation_idx
  on public.ns_referrals(referrer_org_id, first_subscription_paid_at desc)
  where status = 'qualified';

create table if not exists public.ns_referral_rewards (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  wave_number integer not null check (wave_number > 0),
  qualified_referrals_count integer not null check (qualified_referrals_count >= wave_number * 5),
  subscription_cadence text not null check (subscription_cadence in ('monthly','annual')),
  reward_kind text not null check (reward_kind in ('monthly_free_cycle','annual_extension_month')),
  status text not null default 'pending_entitlement' check (status in ('pending_entitlement','applied','failed')),
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  entitlement_reference text,
  failure_reason text,
  unique (org_id, wave_number),
  check ((status = 'applied' and applied_at is not null and entitlement_reference is not null) or status <> 'applied')
);
create index if not exists ns_referral_rewards_org_status_idx
  on public.ns_referral_rewards(org_id, status, wave_number);

-- Data is only accessed by the authenticated Edge Function using service_role.
alter table public.ns_referral_codes enable row level security;
alter table public.ns_referrals enable row level security;
alter table public.ns_referral_rewards enable row level security;
revoke all on public.ns_referral_codes, public.ns_referrals, public.ns_referral_rewards from public, anon, authenticated;
grant select, insert, update, delete on public.ns_referral_codes, public.ns_referrals, public.ns_referral_rewards to service_role;

create or replace function public.ns_record_referral_first_subscription(
  p_referred_org_id uuid,
  p_provider_event_id text,
  p_subscription_id text,
  p_paid_at timestamptz,
  p_referrer_plan_cadence text
) returns jsonb
language plpgsql
set search_path = ''
as $naxa$
declare
  v_referrer_org_id uuid;
  v_referral_id uuid;
  v_status text;
  v_count integer;
  v_wave integer;
  v_reward_kind text;
  v_reward_id uuid;
  v_existing_subscription_id text;
  v_existing_referred_org_id uuid;
begin
  if p_referred_org_id is null
     or nullif(trim(p_provider_event_id), '') is null
     or nullif(trim(p_subscription_id), '') is null
     or p_paid_at is null
     or p_referrer_plan_cadence is null
     or p_referrer_plan_cadence not in ('monthly','annual') then
    raise exception 'NAXA_REFERRAL_FIRST_PAYMENT_INVALID';
  end if;

  select id, first_subscription_id, referred_org_id
    into v_referral_id, v_existing_subscription_id, v_existing_referred_org_id
  from public.ns_referrals
  where provider_event_id = p_provider_event_id
  limit 1;
  if found then
    if v_existing_subscription_id = trim(p_subscription_id)
       and v_existing_referred_org_id = p_referred_org_id then
      return jsonb_build_object('qualified', true, 'idempotent', true, 'referral_id', v_referral_id);
    end if;
    raise exception 'NAXA_REFERRAL_PROVIDER_EVENT_REUSED';
  end if;

  select id, referrer_org_id, status, first_subscription_id
    into v_referral_id, v_referrer_org_id, v_status, v_existing_subscription_id
  from public.ns_referrals
  where referred_org_id = p_referred_org_id
  for update;
  if not found then
    return jsonb_build_object('qualified', false, 'reason', 'no_referral_code_applied');
  end if;
  if v_status = 'qualified' then
    if v_existing_subscription_id = trim(p_subscription_id) then
      return jsonb_build_object('qualified', true, 'idempotent', true, 'referral_id', v_referral_id);
    end if;
    return jsonb_build_object('qualified', false, 'reason', 'already_qualified_by_another_subscription');
  end if;
  if v_status <> 'pending' then
    return jsonb_build_object('qualified', false, 'reason', 'referral_not_pending');
  end if;

  -- Serialize activations per referrer to prevent duplicate wave issuance.
  perform 1 from public.ns_organizations where id = v_referrer_org_id for update;
  update public.ns_referrals
  set status = 'qualified',
      first_subscription_paid_at = p_paid_at,
      first_subscription_id = trim(p_subscription_id),
      provider_event_id = trim(p_provider_event_id),
      referrer_plan_cadence = p_referrer_plan_cadence
  where id = v_referral_id and status = 'pending';

  select count(*)::integer into v_count
  from public.ns_referrals
  where referrer_org_id = v_referrer_org_id and status = 'qualified';

  v_wave := floor(v_count::numeric / 5)::integer;
  if v_count >= 5 and mod(v_count, 5) = 0 then
    v_reward_kind := case p_referrer_plan_cadence
      when 'monthly' then 'monthly_free_cycle'
      when 'annual' then 'annual_extension_month'
    end;
    insert into public.ns_referral_rewards(
      org_id, wave_number, qualified_referrals_count, subscription_cadence, reward_kind
    ) values (
      v_referrer_org_id, v_wave, v_count, p_referrer_plan_cadence, v_reward_kind
    )
    on conflict (org_id, wave_number) do nothing
    returning id into v_reward_id;
  end if;

  return jsonb_build_object(
    'qualified', true,
    'idempotent', false,
    'referral_id', v_referral_id,
    'qualified_count', v_count,
    'completed_wave', case when v_count >= 5 and mod(v_count, 5) = 0 then v_wave else null end,
    'reward_id', v_reward_id
  );
end;
$naxa$;

create or replace function public.ns_mark_referral_reward_applied(
  p_reward_id uuid,
  p_entitlement_reference text,
  p_applied_at timestamptz default now()
) returns boolean
language plpgsql
set search_path = ''
as $naxa$
declare
  v_rows integer;
begin
  if p_reward_id is null or nullif(trim(p_entitlement_reference), '') is null or p_applied_at is null then
    raise exception 'NAXA_REFERRAL_ENTITLEMENT_REFERENCE_REQUIRED';
  end if;
  update public.ns_referral_rewards
  set status = 'applied',
      applied_at = p_applied_at,
      entitlement_reference = trim(p_entitlement_reference),
      failure_reason = null
  where id = p_reward_id and status = 'pending_entitlement';
  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$naxa$;

revoke all on function public.ns_record_referral_first_subscription(uuid,text,text,timestamptz,text) from public, anon, authenticated;
grant execute on function public.ns_record_referral_first_subscription(uuid,text,text,timestamptz,text) to service_role;
revoke all on function public.ns_mark_referral_reward_applied(uuid,text,timestamptz) from public, anon, authenticated;
grant execute on function public.ns_mark_referral_reward_applied(uuid,text,timestamptz) to service_role;
rollback;
