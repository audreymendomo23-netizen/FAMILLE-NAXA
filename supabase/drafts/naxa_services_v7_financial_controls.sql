-- NAXA SERVICES v7 — financial policy, commission adjustment and provider event controls.
-- DRAFT ONLY. Depends on v1-v6. Apply only to a dedicated NAXA SERVICES staging project.
-- No provider credentials or default tax/commission rates are stored in this schema.
begin;

create unique index if not exists ns_commission_entries_id_site_org_idx
  on public.ns_commission_entries(id, site_id, org_id);
create table if not exists public.ns_commission_policy_versions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid,
  policy_code text not null check (length(trim(policy_code)) between 2 and 80),
  version integer not null check (version > 0),
  method text not null check (method in ('percent_bps','fixed_xaf')),
  rate_bps integer,
  fixed_amount_xaf bigint,
  effective_from date not null,
  effective_until date,
  status text not null default 'draft' check (status in ('draft','approved','retired')),
  source_reference text not null default '',
  approved_by uuid,
  approved_at timestamptz,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (approved_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (effective_until is null or effective_until >= effective_from),
  check (
    (method = 'percent_bps' and rate_bps between 0 and 10000 and fixed_amount_xaf is null)
    or (method = 'fixed_xaf' and rate_bps is null and fixed_amount_xaf > 0)
  ),
  check (
    status <> 'approved'
    or (approved_by is not null and approved_at is not null and length(trim(source_reference)) >= 8)
  ),
  unique nulls not distinct (org_id, site_id, policy_code, version)
);
create unique index if not exists ns_commission_policy_versions_id_org_idx
  on public.ns_commission_policy_versions(id, org_id);
create index if not exists ns_commission_policy_scope_date_idx
  on public.ns_commission_policy_versions(org_id, site_id, policy_code, effective_from desc);

alter table public.ns_payments
  drop constraint if exists ns_payments_status_check;
alter table public.ns_payments
  add constraint ns_payments_status_check
  check (status in ('initiated','pending','confirmed','failed','expired','cancelled','refunded','reversed'));

alter table public.ns_commission_entries
  add column if not exists policy_version_id uuid,
  add column if not exists source_event_id uuid,
  add column if not exists idempotency_key uuid,
  add column if not exists approved_by uuid,
  add column if not exists approved_at timestamptz;
alter table public.ns_commission_entries
  add constraint ns_commission_entries_approved_by_scope_fkey
  foreign key (approved_by, org_id)
  references public.ns_members(id, org_id) on delete restrict;
alter table public.ns_commission_entries
  add constraint ns_commission_entries_policy_version_scope_fkey
  foreign key (policy_version_id, org_id)
  references public.ns_commission_policy_versions(id, org_id) on delete restrict;
alter table public.ns_commission_entries
  drop constraint if exists ns_commission_entries_status_check;
alter table public.ns_commission_entries
  add constraint ns_commission_entries_status_check
  check (status in ('accrued','pending_approval','approved','paid','reversed'));
alter table public.ns_commission_entries
  alter column status set default 'pending_approval';
create unique index if not exists ns_commission_entries_idempotency_idx
  on public.ns_commission_entries(org_id, idempotency_key)
  where idempotency_key is not null;

create table if not exists public.ns_commission_adjustments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  commission_entry_id uuid not null,
  source_event_id uuid not null,
  idempotency_key uuid not null,
  adjustment_type text not null check (adjustment_type in ('refund_reversal','correction','manual_reversal')),
  amount_delta_xaf bigint not null check (amount_delta_xaf <> 0),
  reason text not null check (length(trim(reason)) between 4 and 500),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (commission_entry_id, site_id, org_id) references public.ns_commission_entries(id, site_id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (org_id, idempotency_key),
  unique (org_id, source_event_id)
);
create index if not exists ns_commission_adjustments_entry_idx
  on public.ns_commission_adjustments(org_id, commission_entry_id, created_at);

create table if not exists public.ns_fiscal_policies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid,
  policy_code text not null check (length(trim(policy_code)) between 2 and 80),
  version integer not null check (version > 0),
  tax_type text not null check (tax_type in ('output_tax','input_tax','withholding')),
  rate_bps integer not null check (rate_bps between 0 and 10000),
  price_mode text not null check (price_mode in ('exclusive','inclusive')),
  effective_from date not null,
  effective_until date,
  status text not null default 'draft' check (status in ('draft','approved','retired')),
  source_reference text not null default '',
  source_edition text not null default '',
  approved_by uuid,
  approved_at timestamptz,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (approved_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (effective_until is null or effective_until >= effective_from),
  check (
    status <> 'approved'
    or (
      approved_by is not null and approved_at is not null
      and length(trim(source_reference)) >= 8
      and length(trim(source_edition)) >= 3
    )
  ),
  unique nulls not distinct (org_id, site_id, policy_code, version)
);
create index if not exists ns_fiscal_policy_scope_date_idx
  on public.ns_fiscal_policies(org_id, site_id, tax_type, effective_from desc);

-- Approved policy versions are immutable. A new rate requires a new version;
-- the only permitted update after approval is retirement without changing its terms.
create or replace function public.ns_prevent_approved_financial_policy_mutation()
returns trigger
language plpgsql
set search_path = ''
as $naxa$
begin
  if old.status = 'retired' then
    raise exception 'NAXA_FINANCIAL_POLICY_RETIRED_IMMUTABLE';
  end if;
  if old.status = 'approved' then
    if new.status <> 'retired'
       or (to_jsonb(new) - 'status') is distinct from (to_jsonb(old) - 'status') then
      raise exception 'NAXA_FINANCIAL_POLICY_VERSION_IMMUTABLE';
    end if;
  end if;
  return new;
end
$naxa$;

drop trigger if exists ns_commission_policy_immutable on public.ns_commission_policy_versions;
create trigger ns_commission_policy_immutable
before update on public.ns_commission_policy_versions
for each row execute function public.ns_prevent_approved_financial_policy_mutation();
drop trigger if exists ns_fiscal_policy_immutable on public.ns_fiscal_policies;
create trigger ns_fiscal_policy_immutable
before update on public.ns_fiscal_policies
for each row execute function public.ns_prevent_approved_financial_policy_mutation();

-- Provider setup contains only a non-secret reference to the external vault.
create table if not exists public.ns_payment_provider_accounts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid,
  provider_code text not null check (provider_code in ('mtn_momo','orange_money')),
  country_code char(2) not null default 'CM' check (country_code = 'CM'),
  environment text not null check (environment in ('sandbox','production')),
  merchant_reference text not null,
  credential_reference text not null check (length(trim(credential_reference)) >= 8),
  status text not null default 'pending_onboarding'
    check (status in ('pending_onboarding','sandbox_ready','production_approved','disabled')),
  approved_by uuid,
  approved_at timestamptz,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (approved_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (
    status <> 'production_approved'
    or (environment = 'production' and approved_by is not null and approved_at is not null)
  ),
  unique nulls not distinct (org_id, site_id, provider_code, environment, merchant_reference)
);

-- Only authenticated, cryptographically verified provider events are retained.
-- Raw callbacks, payer MSISDNs, access tokens and secrets are deliberately not stored.
create unique index if not exists ns_payments_id_site_org_idx
  on public.ns_payments(id, site_id, org_id);

create table if not exists public.ns_payment_provider_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  payment_id uuid not null,
  provider_code text not null check (provider_code in ('mtn_momo','orange_money')),
  provider_event_id text not null check (length(trim(provider_event_id)) between 4 and 180),
  merchant_reference text not null,
  provider_reference text not null default '',
  amount_xaf bigint not null check (amount_xaf > 0),
  currency_code char(3) not null check (currency_code = 'XAF'),
  provider_status text not null,
  processing_status text not null default 'received'
    check (processing_status in ('received','verified','applied','rejected','duplicate','mismatch')),
  signature_verified boolean not null default false,
  verification_method text,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  rejection_code text,
  received_at timestamptz not null default now(),
  verified_at timestamptz,
  applied_at timestamptz,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (payment_id, site_id, org_id) references public.ns_payments(id, site_id, org_id) on delete restrict,
  unique (org_id, provider_code, provider_event_id),
  check (
    processing_status not in ('verified','applied')
    or (
      signature_verified = true
      and verification_method in ('signed_webhook','authenticated_status_query')
      and verified_at is not null
    )
  ),
  check (processing_status <> 'applied' or applied_at is not null)
);
create index if not exists ns_payment_provider_events_payment_idx
  on public.ns_payment_provider_events(org_id, payment_id, received_at desc);

alter table public.ns_commission_policy_versions enable row level security;
alter table public.ns_commission_adjustments enable row level security;
alter table public.ns_fiscal_policies enable row level security;
alter table public.ns_payment_provider_accounts enable row level security;
alter table public.ns_payment_provider_events enable row level security;

drop policy if exists ns_commission_policy_versions_select on public.ns_commission_policy_versions;
create policy ns_commission_policy_versions_select on public.ns_commission_policy_versions
  for select to authenticated
  using (
    (site_id is null and public.ns_is_org_member(org_id))
    or (site_id is not null and public.ns_can_access_site(org_id, site_id))
  );
drop policy if exists ns_commission_adjustments_select on public.ns_commission_adjustments;
create policy ns_commission_adjustments_select on public.ns_commission_adjustments
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_fiscal_policies_select on public.ns_fiscal_policies;
create policy ns_fiscal_policies_select on public.ns_fiscal_policies
  for select to authenticated
  using (
    (site_id is null and public.ns_is_org_member(org_id))
    or (site_id is not null and public.ns_can_access_site(org_id, site_id))
  );

-- All policy approvals, adjustments and provider callbacks are written by audited Edge services.
revoke all on public.ns_commission_policy_versions, public.ns_commission_adjustments, public.ns_fiscal_policies
  from public, anon;
grant select on public.ns_commission_policy_versions, public.ns_commission_adjustments, public.ns_fiscal_policies
  to authenticated;
grant all on public.ns_commission_policy_versions, public.ns_commission_adjustments, public.ns_fiscal_policies
  to service_role;

revoke all on public.ns_payment_provider_accounts, public.ns_payment_provider_events
  from public, anon, authenticated;
grant all on public.ns_payment_provider_accounts, public.ns_payment_provider_events
  to service_role;

revoke all on function public.ns_prevent_approved_financial_policy_mutation() from public, anon, authenticated;
grant execute on function public.ns_prevent_approved_financial_policy_mutation() to service_role;

rollback;
