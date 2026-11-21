-- NAXA SERVICES v5 candidate: customer-to-customer referral and legally gated promotions.
-- DRAFT ONLY. ROLLBACK by default. Never deploy without legal/business sign-off and isolated migration review.
begin;

create table if not exists public.ns_customer_referral_campaigns (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  site_id uuid,
  name text not null check (length(trim(name)) between 2 and 100),
  status text not null default 'draft' check (status in ('draft','active','paused','expired')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  beneficiary_mode text not null check (beneficiary_mode in ('referrer','both')),
  reward_kind text not null check (reward_kind in ('points','discount_xaf','credit_xaf','free_service')),
  reward_value bigint not null check (reward_value > 0),
  minimum_paid_sale_xaf bigint not null default 0 check (minimum_paid_sale_xaf >= 0),
  reward_expiry_days integer check (reward_expiry_days is null or reward_expiry_days between 1 and 3650),
  terms_version text not null check (length(trim(terms_version)) between 1 and 80),
  created_by uuid not null,
  approved_by uuid,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (approved_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, org_id),
  check (ends_at is null or ends_at > starts_at),
  check (
    status <> 'active'
    or (approved_by is not null and approved_at is not null and terms_version <> '')
  )
);
create index if not exists ns_customer_referral_campaigns_org_status_idx
  on public.ns_customer_referral_campaigns(org_id, status, starts_at, ends_at);

create table if not exists public.ns_customer_referral_codes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  campaign_id uuid not null,
  customer_id uuid not null,
  code text not null unique check (code ~ '^CREF-[A-Z0-9]{6,10}$'),
  status text not null default 'active' check (status in ('active','revoked')),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  foreign key (campaign_id, org_id) references public.ns_customer_referral_campaigns(id, org_id) on delete restrict,
  foreign key (customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  unique (id, org_id),
  unique (campaign_id, customer_id),
  check ((status = 'active' and revoked_at is null) or status = 'revoked')
);
create index if not exists ns_customer_referral_codes_customer_idx
  on public.ns_customer_referral_codes(org_id, customer_id, status);

create table if not exists public.ns_customer_referrals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  campaign_id uuid not null,
  referral_code_id uuid not null,
  referrer_customer_id uuid not null,
  referrer_site_id uuid not null,
  referred_customer_id uuid not null,
  referred_site_id uuid not null,
  status text not null default 'pending' check (status in ('pending','qualified','rejected')),
  rejection_reason text,
  created_at timestamptz not null default now(),
  first_paid_sale_id uuid unique references public.ns_sales(id) on delete restrict,
  provider_event_id text unique,
  first_paid_at timestamptz,
  foreign key (campaign_id, org_id) references public.ns_customer_referral_campaigns(id, org_id) on delete restrict,
  foreign key (referral_code_id, org_id) references public.ns_customer_referral_codes(id, org_id) on delete restrict,
  foreign key (referrer_customer_id, referrer_site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  foreign key (referred_customer_id, referred_site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  unique (org_id, referred_customer_id),
  check (referrer_customer_id <> referred_customer_id),
  check (
    (status = 'pending' and first_paid_sale_id is null and provider_event_id is null and first_paid_at is null)
    or (status = 'qualified' and first_paid_sale_id is not null and provider_event_id is not null and first_paid_at is not null)
    or status = 'rejected'
  )
);
create index if not exists ns_customer_referrals_referrer_idx
  on public.ns_customer_referrals(org_id, referrer_customer_id, created_at desc);
create index if not exists ns_customer_referrals_campaign_status_idx
  on public.ns_customer_referrals(org_id, campaign_id, status, created_at desc);

create table if not exists public.ns_customer_referral_rewards (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  campaign_id uuid not null,
  referral_id uuid not null,
  beneficiary_customer_id uuid not null,
  beneficiary_site_id uuid not null,
  reward_kind text not null check (reward_kind in ('points','discount_xaf','credit_xaf','free_service')),
  reward_value bigint not null check (reward_value > 0),
  status text not null default 'pending_issuance' check (status in ('pending_issuance','issued','redeemed','cancelled','expired')),
  idempotency_key uuid not null default gen_random_uuid(),
  external_ledger_reference text,
  issued_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (campaign_id, org_id) references public.ns_customer_referral_campaigns(id, org_id) on delete restrict,
  foreign key (referral_id) references public.ns_customer_referrals(id) on delete restrict,
  foreign key (beneficiary_customer_id, beneficiary_site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  unique (org_id, idempotency_key),
  unique (referral_id, beneficiary_customer_id),
  check ((status = 'issued' and issued_at is not null and external_ledger_reference is not null) or status <> 'issued')
);
create index if not exists ns_customer_referral_rewards_beneficiary_idx
  on public.ns_customer_referral_rewards(org_id, beneficiary_customer_id, status, created_at desc);

-- Random-promotion campaigns are server controlled. An active campaign cannot exist without
-- written legal review, applicable authorization, dated public terms and an approving actor.
create table if not exists public.ns_promotion_campaigns (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  site_id uuid,
  title text not null check (length(trim(title)) between 2 and 120),
  campaign_type text not null check (campaign_type in ('wheel')),
  status text not null default 'draft' check (status in ('draft','legal_review','approved','active','suspended','expired')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  terms_version text,
  legal_opinion_reference text,
  authorization_reference text,
  legal_reviewer_name text,
  legal_reviewed_at timestamptz,
  authorization_expires_at timestamptz,
  approved_by uuid,
  approved_at timestamptz,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (approved_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, org_id),
  check (ends_at is null or ends_at > starts_at),
  check (
    status <> 'active'
    or (
      nullif(trim(terms_version), '') is not null
      and nullif(trim(legal_opinion_reference), '') is not null
      and nullif(trim(authorization_reference), '') is not null
      and nullif(trim(legal_reviewer_name), '') is not null
      and legal_reviewed_at is not null
      and authorization_expires_at is not null
      and approved_by is not null and approved_at is not null
    )
  )
);
create index if not exists ns_promotion_campaigns_org_status_idx
  on public.ns_promotion_campaigns(org_id, status, starts_at, ends_at);

create table if not exists public.ns_promotion_prizes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  campaign_id uuid not null,
  label text not null check (length(trim(label)) between 1 and 100),
  prize_kind text not null check (prize_kind in ('no_prize','points','discount_xaf','credit_xaf','free_service','product')),
  reward_value bigint not null default 0 check (reward_value >= 0),
  weight integer not null check (weight between 1 and 1000000),
  max_awards integer check (max_awards is null or max_awards > 0),
  awarded_count integer not null default 0 check (awarded_count >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  foreign key (campaign_id, org_id) references public.ns_promotion_campaigns(id, org_id) on delete restrict,
  unique (id, campaign_id, org_id),
  check ((prize_kind = 'no_prize' and reward_value = 0) or (prize_kind <> 'no_prize' and reward_value > 0)),
  check (max_awards is null or awarded_count <= max_awards)
);
create index if not exists ns_promotion_prizes_campaign_active_idx
  on public.ns_promotion_prizes(org_id, campaign_id, active);

create table if not exists public.ns_promotion_spins (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  campaign_id uuid not null,
  customer_id uuid not null,
  customer_site_id uuid not null,
  attempt_id uuid not null,
  prize_id uuid,
  outcome text not null check (outcome in ('awarded','no_prize')),
  random_ticket bigint not null check (random_ticket >= 0),
  total_weight bigint not null check (total_weight > 0),
  created_at timestamptz not null default now(),
  foreign key (campaign_id, org_id) references public.ns_promotion_campaigns(id, org_id) on delete restrict,
  foreign key (customer_id, customer_site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  foreign key (prize_id, campaign_id, org_id) references public.ns_promotion_prizes(id, campaign_id, org_id) on delete restrict,
  unique (campaign_id, attempt_id),
  check ((outcome = 'awarded' and prize_id is not null) or (outcome = 'no_prize' and prize_id is not null))
);
create index if not exists ns_promotion_spins_customer_idx
  on public.ns_promotion_spins(org_id, customer_id, created_at desc);

-- Referral functions are service-only: the Edge gateway verifies the actor and the sale/payment
-- server events before invoking these RPCs. The Android client cannot qualify or issue rewards.
create or replace function public.ns_apply_customer_referral_code(
  p_org_id uuid, p_referred_site_id uuid, p_referred_customer_id uuid, p_code text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_code public.ns_customer_referral_codes%rowtype;
  v_campaign public.ns_customer_referral_campaigns%rowtype;
  v_referred_site uuid;
  v_existing public.ns_customer_referrals%rowtype;
  v_referral_id uuid;
begin
  if p_org_id is null or p_referred_site_id is null or p_referred_customer_id is null
     or nullif(trim(p_code), '') is null then
    raise exception 'NAXA_CUSTOMER_REFERRAL_INPUT_INVALID';
  end if;

  select * into v_code
  from public.ns_customer_referral_codes c
  where c.org_id = p_org_id and upper(c.code) = upper(trim(p_code))
  for update;
  if not found or v_code.status <> 'active' then
    return jsonb_build_object('accepted', false, 'reason', 'invalid_or_revoked_code');
  end if;

  select * into v_campaign
  from public.ns_customer_referral_campaigns c
  where c.id = v_code.campaign_id and c.org_id = p_org_id
  for update;
  if not found or v_campaign.status <> 'active'
     or now() < v_campaign.starts_at
     or (v_campaign.ends_at is not null and now() >= v_campaign.ends_at) then
    return jsonb_build_object('accepted', false, 'reason', 'campaign_inactive');
  end if;

  if v_campaign.site_id is not null and
     (v_campaign.site_id <> v_code.site_id or v_campaign.site_id <> p_referred_site_id) then
    return jsonb_build_object('accepted', false, 'reason', 'campaign_site_scope_mismatch');
  end if;

  select c.site_id into v_referred_site
  from public.ns_customers c
  where c.id = p_referred_customer_id and c.org_id = p_org_id and c.site_id = p_referred_site_id;
  if not found then
    return jsonb_build_object('accepted', false, 'reason', 'referred_customer_not_found');
  end if;

  if v_code.customer_id = p_referred_customer_id then
    return jsonb_build_object('accepted', false, 'reason', 'self_referral');
  end if;

  select * into v_existing
  from public.ns_customer_referrals r
  where r.org_id = p_org_id and r.referred_customer_id = p_referred_customer_id
  for update;
  if found then
    if v_existing.referral_code_id = v_code.id then
      return jsonb_build_object('accepted', true, 'idempotent', true, 'referral_id', v_existing.id, 'status', v_existing.status);
    end if;
    return jsonb_build_object('accepted', false, 'reason', 'customer_already_attributed');
  end if;

  if exists (
    select 1
    from public.ns_sales s
    join public.ns_payments p
      on p.sale_id = s.id and p.org_id = s.org_id and p.site_id = s.site_id
    where s.org_id = p_org_id
      and s.customer_id = p_referred_customer_id
      and s.status = 'posted'
      and p.status = 'confirmed'
      and p.confirmed_at is not null
    group by s.id, s.total_xaf
    having sum(p.amount_xaf) >= s.total_xaf
  ) then
    return jsonb_build_object('accepted', false, 'reason', 'first_paid_sale_already_recorded');
  end if;

  insert into public.ns_customer_referrals(
    org_id, campaign_id, referral_code_id,
    referrer_customer_id, referrer_site_id,
    referred_customer_id, referred_site_id
  ) values (
    p_org_id, v_campaign.id, v_code.id,
    v_code.customer_id, v_code.site_id,
    p_referred_customer_id, v_referred_site
  ) returning id into v_referral_id;

  return jsonb_build_object('accepted', true, 'idempotent', false, 'referral_id', v_referral_id, 'status', 'pending');
end;
$naxa$;

create or replace function public.ns_record_customer_referral_first_paid_sale(
  p_sale_id uuid, p_provider_event_id text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_sale public.ns_sales%rowtype;
  v_referral public.ns_customer_referrals%rowtype;
  v_campaign public.ns_customer_referral_campaigns%rowtype;
  v_paid_total bigint;
  v_paid_at timestamptz;
  v_first_paid_sale_id uuid;
  v_reward_count integer := 0;
  v_rows integer := 0;
  v_reward_ids jsonb := '[]'::jsonb;
begin
  if p_sale_id is null or nullif(trim(p_provider_event_id), '') is null then
    raise exception 'NAXA_CUSTOMER_REFERRAL_PAYMENT_EVENT_INVALID';
  end if;

  select r.id, r.first_paid_sale_id
  into v_referral.id, v_referral.first_paid_sale_id
  from public.ns_customer_referrals r
  where r.provider_event_id = trim(p_provider_event_id)
  limit 1;
  if found then
    if v_referral.first_paid_sale_id = p_sale_id then
      return jsonb_build_object('qualified', true, 'idempotent', true, 'referral_id', v_referral.id);
    end if;
    raise exception 'NAXA_CUSTOMER_REFERRAL_PROVIDER_EVENT_REUSED';
  end if;

  select * into v_sale
  from public.ns_sales s
  where s.id = p_sale_id
  for update;
  if not found or v_sale.customer_id is null or v_sale.status <> 'posted' then
    return jsonb_build_object('qualified', false, 'reason', 'sale_not_eligible');
  end if;

  select coalesce(sum(p.amount_xaf), 0)::bigint, max(p.confirmed_at)
  into v_paid_total, v_paid_at
  from public.ns_payments p
  where p.org_id = v_sale.org_id and p.site_id = v_sale.site_id
    and p.sale_id = v_sale.id and p.status = 'confirmed' and p.confirmed_at is not null;

  if v_paid_total < v_sale.total_xaf or v_paid_at is null then
    return jsonb_build_object('qualified', false, 'reason', 'sale_not_fully_paid');
  end if;

  select * into v_referral
  from public.ns_customer_referrals r
  where r.org_id = v_sale.org_id
    and r.referred_customer_id = v_sale.customer_id
  for update;
  if not found then
    return jsonb_build_object('qualified', false, 'reason', 'no_customer_referral');
  end if;
  if v_referral.status = 'qualified' and v_referral.first_paid_sale_id = p_sale_id then
    return jsonb_build_object('qualified', true, 'idempotent', true, 'referral_id', v_referral.id);
  end if;
  if v_referral.status <> 'pending' then
    return jsonb_build_object('qualified', false, 'reason', 'referral_not_pending');
  end if;

  select s.id
  into v_first_paid_sale_id
  from public.ns_sales s
  join public.ns_payments p
    on p.sale_id = s.id and p.org_id = s.org_id and p.site_id = s.site_id
  where s.org_id = v_sale.org_id
    and s.customer_id = v_sale.customer_id
    and s.status = 'posted'
    and p.status = 'confirmed'
    and p.confirmed_at is not null
  group by s.id, s.created_at, s.total_xaf
  having sum(p.amount_xaf) >= s.total_xaf
  order by max(p.confirmed_at), s.created_at, s.id
  limit 1;

  if v_first_paid_sale_id is distinct from p_sale_id then
    update public.ns_customer_referrals
    set status = 'rejected', rejection_reason = 'not_first_fully_paid_sale'
    where id = v_referral.id and status = 'pending';
    return jsonb_build_object('qualified', false, 'reason', 'not_first_fully_paid_sale');
  end if;

  select * into v_campaign
  from public.ns_customer_referral_campaigns c
  where c.id = v_referral.campaign_id and c.org_id = v_referral.org_id
  for update;
  if not found or v_campaign.status <> 'active'
     or v_paid_at < v_campaign.starts_at
     or (v_campaign.ends_at is not null and v_paid_at >= v_campaign.ends_at)
     or (v_campaign.site_id is not null and v_campaign.site_id <> v_sale.site_id) then
    update public.ns_customer_referrals
    set status = 'rejected', rejection_reason = 'campaign_not_eligible_at_first_paid_sale'
    where id = v_referral.id and status = 'pending';
    return jsonb_build_object('qualified', false, 'reason', 'campaign_not_eligible_at_first_paid_sale');
  end if;

  if v_sale.total_xaf < v_campaign.minimum_paid_sale_xaf then
    update public.ns_customer_referrals
    set status = 'rejected', rejection_reason = 'first_paid_sale_below_campaign_minimum'
    where id = v_referral.id and status = 'pending';
    return jsonb_build_object('qualified', false, 'reason', 'first_paid_sale_below_campaign_minimum');
  end if;

  update public.ns_customer_referrals
  set status = 'qualified',
      first_paid_sale_id = p_sale_id,
      provider_event_id = trim(p_provider_event_id),
      first_paid_at = v_paid_at,
      rejection_reason = null
  where id = v_referral.id and status = 'pending';

  insert into public.ns_customer_referral_rewards(
    org_id, campaign_id, referral_id, beneficiary_customer_id, beneficiary_site_id,
    reward_kind, reward_value, expires_at
  )
  values (
    v_referral.org_id, v_campaign.id, v_referral.id,
    v_referral.referrer_customer_id, v_referral.referrer_site_id,
    v_campaign.reward_kind, v_campaign.reward_value,
    case when v_campaign.reward_expiry_days is null then null else v_paid_at + make_interval(days => v_campaign.reward_expiry_days) end
  )
  on conflict (referral_id, beneficiary_customer_id) do nothing;
  get diagnostics v_reward_count = row_count;

  if v_campaign.beneficiary_mode = 'both' then
    insert into public.ns_customer_referral_rewards(
      org_id, campaign_id, referral_id, beneficiary_customer_id, beneficiary_site_id,
      reward_kind, reward_value, expires_at
    )
    values (
      v_referral.org_id, v_campaign.id, v_referral.id,
      v_referral.referred_customer_id, v_referral.referred_site_id,
      v_campaign.reward_kind, v_campaign.reward_value,
      case when v_campaign.reward_expiry_days is null then null else v_paid_at + make_interval(days => v_campaign.reward_expiry_days) end
    )
    on conflict (referral_id, beneficiary_customer_id) do nothing;
    get diagnostics v_rows = row_count;
    v_reward_count := v_reward_count + v_rows;
  end if;

  select coalesce(jsonb_agg(r.id order by r.created_at), '[]'::jsonb)
  into v_reward_ids
  from public.ns_customer_referral_rewards r
  where r.referral_id = v_referral.id;

  return jsonb_build_object(
    'qualified', true,
    'idempotent', false,
    'referral_id', v_referral.id,
    'first_paid_sale_id', p_sale_id,
    'paid_at', v_paid_at,
    'rewards_created', v_reward_count,
    'reward_ids', v_reward_ids
  );
end;
$naxa$;

create or replace function public.ns_mark_customer_referral_reward_issued(
  p_reward_id uuid, p_external_ledger_reference text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_rows integer;
begin
  if p_reward_id is null or nullif(trim(p_external_ledger_reference), '') is null then
    raise exception 'NAXA_CUSTOMER_REFERRAL_LEDGER_REFERENCE_REQUIRED';
  end if;
  update public.ns_customer_referral_rewards
  set status = 'issued',
      issued_at = now(),
      external_ledger_reference = trim(p_external_ledger_reference)
  where id = p_reward_id and status = 'pending_issuance';
  get diagnostics v_rows = row_count;
  if v_rows = 1 then return true; end if;
  return exists (
    select 1 from public.ns_customer_referral_rewards
    where id = p_reward_id and status = 'issued'
      and external_ledger_reference = trim(p_external_ledger_reference)
  );
end;
$naxa$;

-- A promotion spin is selected exclusively inside a security-definer RPC with pgcrypto randomness.
-- Campaign-level locking serializes stock caps and prevents a result from exceeding prize limits.
create or replace function public.ns_spin_promotion_wheel(
  p_campaign_id uuid, p_customer_id uuid, p_attempt_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_campaign public.ns_promotion_campaigns%rowtype;
  v_customer_site uuid;
  v_existing public.ns_promotion_spins%rowtype;
  v_total_weight bigint;
  v_limit bigint;
  v_random bigint;
  v_pick bigint;
  v_bytes bytea;
  v_selected public.ns_promotion_prizes%rowtype;
  v_created public.ns_promotion_spins%rowtype;
begin
  if p_campaign_id is null or p_customer_id is null or p_attempt_id is null then
    raise exception 'NAXA_PROMOTION_SPIN_INPUT_INVALID';
  end if;

  select * into v_existing
  from public.ns_promotion_spins s
  where s.campaign_id = p_campaign_id and s.attempt_id = p_attempt_id;
  if found then
    if v_existing.customer_id <> p_customer_id then
      raise exception 'NAXA_PROMOTION_ATTEMPT_ID_REUSED';
    end if;
    return jsonb_build_object(
      'idempotent', true, 'spin_id', v_existing.id,
      'outcome', v_existing.outcome, 'prize_id', v_existing.prize_id
    );
  end if;

  select * into v_campaign
  from public.ns_promotion_campaigns c
  where c.id = p_campaign_id
  for update;
  if not found or v_campaign.status <> 'active'
     or now() < v_campaign.starts_at
     or (v_campaign.ends_at is not null and now() >= v_campaign.ends_at)
     or nullif(trim(v_campaign.legal_opinion_reference), '') is null
     or nullif(trim(v_campaign.authorization_reference), '') is null
     or nullif(trim(v_campaign.legal_reviewer_name), '') is null
     or v_campaign.legal_reviewed_at is null
     or v_campaign.authorization_expires_at is null
     or v_campaign.authorization_expires_at <= now()
     or nullif(trim(v_campaign.terms_version), '') is null
     or v_campaign.approved_by is null or v_campaign.approved_at is null then
    raise exception 'NAXA_PROMOTION_CAMPAIGN_NOT_ACTIVE_OR_NOT_LEGAL';
  end if;

  select c.site_id into v_customer_site
  from public.ns_customers c
  where c.id = p_customer_id and c.org_id = v_campaign.org_id;
  if not found then
    raise exception 'NAXA_PROMOTION_CUSTOMER_NOT_FOUND';
  end if;
  if v_campaign.site_id is not null and v_campaign.site_id <> v_customer_site then
    raise exception 'NAXA_PROMOTION_CUSTOMER_SITE_SCOPE_MISMATCH';
  end if;

  perform 1
  from public.ns_promotion_prizes p
  where p.org_id = v_campaign.org_id and p.campaign_id = v_campaign.id and p.active
    and (p.max_awards is null or p.awarded_count < p.max_awards)
  order by p.id
  for update;

  select coalesce(sum(p.weight), 0)::bigint into v_total_weight
  from public.ns_promotion_prizes p
  where p.org_id = v_campaign.org_id and p.campaign_id = v_campaign.id and p.active
    and (p.max_awards is null or p.awarded_count < p.max_awards);
  if v_total_weight <= 0 or v_total_weight > 1000000000 then
    raise exception 'NAXA_PROMOTION_NO_AVAILABLE_PRIZES';
  end if;

  -- Unbiased rejection sampling over a 32-bit cryptographically secure value.
  loop
    v_bytes := public.gen_random_bytes(4);
    v_random :=
      (get_byte(v_bytes, 0)::bigint << 24) +
      (get_byte(v_bytes, 1)::bigint << 16) +
      (get_byte(v_bytes, 2)::bigint << 8) +
      get_byte(v_bytes, 3)::bigint;
    v_limit := floor(4294967296::numeric / v_total_weight)::bigint * v_total_weight;
    exit when v_random < v_limit;
  end loop;
  v_pick := mod(v_random, v_total_weight);

  select p.id, p.org_id, p.campaign_id, p.label, p.prize_kind, p.reward_value,
         p.weight, p.max_awards, p.awarded_count, p.active, p.created_at
  into v_selected
  from (
    select prizes.*, sum(prizes.weight) over (order by prizes.created_at, prizes.id) as cumulative_weight
    from public.ns_promotion_prizes prizes
    where prizes.org_id = v_campaign.org_id and prizes.campaign_id = v_campaign.id and prizes.active
      and (prizes.max_awards is null or prizes.awarded_count < prizes.max_awards)
  ) p
  where v_pick < p.cumulative_weight
  order by p.cumulative_weight
  limit 1;
  if not found then
    raise exception 'NAXA_PROMOTION_WEIGHT_SELECTION_FAILED';
  end if;

  update public.ns_promotion_prizes
  set awarded_count = awarded_count + 1
  where id = v_selected.id and org_id = v_campaign.org_id
    and (max_awards is null or awarded_count < max_awards);
  if not found then
    raise exception 'NAXA_PROMOTION_PRIZE_CAP_REACHED';
  end if;

  insert into public.ns_promotion_spins(
    org_id, campaign_id, customer_id, customer_site_id, attempt_id,
    prize_id, outcome, random_ticket, total_weight
  ) values (
    v_campaign.org_id, v_campaign.id, p_customer_id, v_customer_site, p_attempt_id,
    v_selected.id,
    case when v_selected.prize_kind = 'no_prize' then 'no_prize' else 'awarded' end,
    v_pick, v_total_weight
  ) returning * into v_created;

  return jsonb_build_object(
    'idempotent', false,
    'spin_id', v_created.id,
    'outcome', v_created.outcome,
    'prize_id', v_created.prize_id,
    'prize_label', v_selected.label
  );
end;
$naxa$;

-- All v5 records and RPCs are server-only until a reviewed UI/API policy is added.
alter table public.ns_customer_referral_campaigns enable row level security;
alter table public.ns_customer_referral_codes enable row level security;
alter table public.ns_customer_referrals enable row level security;
alter table public.ns_customer_referral_rewards enable row level security;
alter table public.ns_promotion_campaigns enable row level security;
alter table public.ns_promotion_prizes enable row level security;
alter table public.ns_promotion_spins enable row level security;

revoke all on public.ns_customer_referral_campaigns, public.ns_customer_referral_codes,
  public.ns_customer_referrals, public.ns_customer_referral_rewards,
  public.ns_promotion_campaigns, public.ns_promotion_prizes, public.ns_promotion_spins
from public, anon, authenticated;
grant all on public.ns_customer_referral_campaigns, public.ns_customer_referral_codes,
  public.ns_customer_referrals, public.ns_customer_referral_rewards,
  public.ns_promotion_campaigns, public.ns_promotion_prizes, public.ns_promotion_spins
to service_role;

revoke all on function public.ns_apply_customer_referral_code(uuid,uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.ns_apply_customer_referral_code(uuid,uuid,uuid,text) to service_role;
revoke all on function public.ns_record_customer_referral_first_paid_sale(uuid,text) from public, anon, authenticated;
grant execute on function public.ns_record_customer_referral_first_paid_sale(uuid,text) to service_role;
revoke all on function public.ns_mark_customer_referral_reward_issued(uuid,text) from public, anon, authenticated;
grant execute on function public.ns_mark_customer_referral_reward_issued(uuid,text) to service_role;
revoke all on function public.ns_spin_promotion_wheel(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.ns_spin_promotion_wheel(uuid,uuid,uuid) to service_role;

rollback;
