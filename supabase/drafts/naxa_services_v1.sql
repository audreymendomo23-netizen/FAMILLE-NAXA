-- NAXA SERVICES / SQL CANDIDATE — DRAFT ONLY.
-- Do not apply to Production or Replay from this file.
-- Audit the canonical Supabase schema, RLS, grants, auth and extension set first.
begin;

create extension if not exists pgcrypto;

create table if not exists public.ns_organizations (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  business_mode text not null check (business_mode in ('solo','single_site_multi_workstation','multi_site_network')),
  status text not null default 'active' check (status in ('active','suspended','closed')),
  default_locale text not null default 'fr' check (default_locale in ('fr','en')),
  created_at timestamptz not null default now()
);

create table if not exists public.ns_sites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  code text not null,
  name text not null,
  address_label text,
  phone_contact text,
  status text not null default 'active' check (status in ('active','suspended','closed')),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

create table if not exists public.ns_workstations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  code text not null,
  name text not null,
  kind text not null check (kind in ('hair_chair','pressing_counter','pressing_workshop','reception','cashier','other')),
  status text not null default 'active' check (status in ('active','inactive')),
  capacity integer not null default 1 check (capacity > 0),
  created_at timestamptz not null default now(),
  unique (site_id, code),
  unique (id, site_id, org_id),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict
);

-- auth_alias is private technical resolution data; never expose it to app clients.
create table if not exists public.ns_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete restrict,
  login_id text not null unique,
  auth_alias text not null unique,
  status text not null default 'active' check (status in ('invited','active','locked','suspended','closed')),
  password_change_required boolean not null default true,
  created_at timestamptz not null default now(),
  last_login_at timestamptz
);

create table if not exists public.ns_members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  account_id uuid not null references public.ns_accounts(id) on delete restrict,
  display_name text not null,
  contact_phone text,
  role_code text not null check (role_code in (
    'promoter','network_manager','site_manager','workstation_manager',
    'cashier','receptionist','hair_stylist','pressing_operator',
    'stock_manager','accountant'
  )),
  status text not null default 'active' check (status in ('active','suspended','left')),
  created_at timestamptz not null default now(),
  unique (org_id, account_id),
  unique (id, org_id)
);

create table if not exists public.ns_member_scopes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  member_id uuid not null,
  scope_type text not null check (scope_type in ('organization','site','workstation')),
  scope_id uuid,
  site_id uuid,
  workstation_id uuid,
  can_read boolean not null default true,
  can_operate boolean not null default false,
  can_manage boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (member_id, org_id) references public.ns_members(id, org_id) on delete cascade,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete cascade,
  foreign key (workstation_id, site_id, org_id) references public.ns_workstations(id, site_id, org_id) on delete cascade,
  check (
    (scope_type = 'organization' and scope_id = org_id and site_id is null and workstation_id is null)
    or (scope_type = 'site' and scope_id = site_id and site_id is not null and workstation_id is null)
    or (scope_type = 'workstation' and scope_id = workstation_id and site_id is not null and workstation_id is not null)
  )
);

create table if not exists public.ns_services (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  site_id uuid,
  code text not null,
  activity text not null check (activity in ('pressing','hair','retail')),
  name text not null,
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  price_xaf bigint not null check (price_xaf >= 0),
  active boolean not null default true,
  effective_from date not null default current_date,
  effective_until date,
  created_at timestamptz not null default now(),
  unique (org_id, site_id, code),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  check (effective_until is null or effective_until >= effective_from)
);

create table if not exists public.ns_customers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  display_name text not null,
  phone_contact text,
  notes_private text,
  contact_consent boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  unique (id, site_id, org_id)
);

create table if not exists public.ns_appointments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  workstation_id uuid,
  customer_id uuid not null,
  service_id uuid not null references public.ns_services(id) on delete restrict,
  assigned_member_id uuid,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'booked' check (status in ('requested','booked','confirmed','arrived','completed','cancelled','no_show')),
  deposit_xaf bigint not null default 0 check (deposit_xaf >= 0),
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (workstation_id, site_id, org_id) references public.ns_workstations(id, site_id, org_id) on delete restrict,
  foreign key (customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  foreign key (assigned_member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (ends_at > starts_at)
);

create table if not exists public.ns_pressing_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  workstation_id uuid,
  customer_id uuid not null,
  ticket_number text not null,
  received_at timestamptz not null default now(),
  promised_at timestamptz,
  picked_up_at timestamptz,
  status text not null default 'received' check (status in ('received','in_progress','ready','picked_up','cancelled')),
  total_xaf bigint not null default 0 check (total_xaf >= 0),
  deposit_xaf bigint not null default 0 check (deposit_xaf >= 0),
  created_by_member uuid,
  created_at timestamptz not null default now(),
  unique (site_id, ticket_number),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (workstation_id, site_id, org_id) references public.ns_workstations(id, site_id, org_id) on delete restrict,
  foreign key (customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  foreign key (created_by_member, org_id) references public.ns_members(id, org_id) on delete restrict
);

create table if not exists public.ns_pressing_items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  order_id uuid not null references public.ns_pressing_orders(id) on delete restrict,
  item_type text not null,
  quantity integer not null default 1 check (quantity > 0),
  unit_price_xaf bigint not null check (unit_price_xaf >= 0),
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict
);

create table if not exists public.ns_pressing_status_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  order_id uuid not null references public.ns_pressing_orders(id) on delete restrict,
  from_status text,
  to_status text not null,
  reason text,
  actor_member_id uuid,
  occurred_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (actor_member_id, org_id) references public.ns_members(id, org_id) on delete restrict
);

create table if not exists public.ns_cash_registers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  code text not null,
  name text not null,
  workstation_id uuid,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (site_id, code),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (workstation_id, site_id, org_id) references public.ns_workstations(id, site_id, org_id) on delete restrict
);

create table if not exists public.ns_cash_sessions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  register_id uuid not null references public.ns_cash_registers(id) on delete restrict,
  opened_by uuid not null references public.ns_members(id) on delete restrict,
  closed_by uuid references public.ns_members(id) on delete restrict,
  opening_float_xaf bigint not null check (opening_float_xaf >= 0),
  expected_close_xaf bigint,
  counted_close_xaf bigint,
  variance_xaf bigint,
  status text not null default 'open' check (status in ('open','closed','reviewed')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  variance_reason text,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  check ((status = 'open' and closed_at is null) or (status <> 'open' and closed_at is not null))
);

create table if not exists public.ns_sales (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  workstation_id uuid,
  customer_id uuid,
  cash_session_id uuid references public.ns_cash_sessions(id) on delete restrict,
  sale_number text not null,
  subtotal_xaf bigint not null check (subtotal_xaf >= 0),
  discount_xaf bigint not null default 0 check (discount_xaf >= 0),
  total_xaf bigint not null check (total_xaf >= 0),
  status text not null default 'posted' check (status in ('draft','posted','voided','refunded')),
  created_by uuid not null references public.ns_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (site_id, sale_number),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (workstation_id, site_id, org_id) references public.ns_workstations(id, site_id, org_id) on delete restrict,
  foreign key (customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict
);

create table if not exists public.ns_payments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  sale_id uuid references public.ns_sales(id) on delete restrict,
  pressing_order_id uuid references public.ns_pressing_orders(id) on delete restrict,
  payment_method text not null check (payment_method in ('cash','mobile_money','mixed','other')),
  provider_reference text,
  amount_xaf bigint not null check (amount_xaf > 0),
  status text not null default 'pending' check (status in ('pending','confirmed','failed','refunded','reversed')),
  confirmation_source text,
  confirmed_by uuid references public.ns_members(id) on delete restrict,
  confirmed_at timestamptz,
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  unique (org_id, idempotency_key),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  check ((status = 'confirmed' and confirmed_at is not null) or status <> 'confirmed'),
  check ((sale_id is not null) <> (pressing_order_id is not null))
);

create table if not exists public.ns_expenses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  cash_session_id uuid references public.ns_cash_sessions(id) on delete restrict,
  category text not null,
  description text not null,
  amount_xaf bigint not null check (amount_xaf > 0),
  reason text,
  created_by uuid not null references public.ns_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict
);

create table if not exists public.ns_commission_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid,
  member_id uuid,
  service_id uuid references public.ns_services(id) on delete restrict,
  rate_basis text not null check (rate_basis in ('fixed','percent')),
  rate_value bigint not null check (rate_value >= 0),
  effective_from date not null,
  effective_until date,
  active boolean not null default true,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (effective_until is null or effective_until >= effective_from)
);

create table if not exists public.ns_commission_entries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  member_id uuid not null references public.ns_members(id) on delete restrict,
  sale_id uuid references public.ns_sales(id) on delete restrict,
  appointment_id uuid references public.ns_appointments(id) on delete restrict,
  base_amount_xaf bigint not null check (base_amount_xaf >= 0),
  commission_xaf bigint not null check (commission_xaf >= 0),
  status text not null default 'accrued' check (status in ('accrued','approved','paid','reversed')),
  calculation_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict
);

create table if not exists public.ns_inventory_items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  sku text,
  name text not null,
  unit text not null,
  quantity numeric(14,3) not null default 0 check (quantity >= 0),
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  unique (site_id, sku)
);

create table if not exists public.ns_inventory_movements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  item_id uuid not null references public.ns_inventory_items(id) on delete restrict,
  movement_type text not null check (movement_type in ('in','consumption','loss','adjustment','transfer_out','transfer_in')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  reason text not null,
  idempotency_key uuid not null,
  actor_member_id uuid references public.ns_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  unique (org_id, idempotency_key)
);

create table if not exists public.ns_auth_recovery_requests (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references public.ns_accounts(id) on delete restrict,
  login_hint_hash text not null,
  request_note text,
  status text not null default 'pending' check (status in ('pending','identity_checked','approved','rejected','completed')),
  assigned_to uuid,
  identity_check_method text,
  identity_check_note text,
  requested_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.ns_audit_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  site_id uuid,
  actor_auth_user_id uuid,
  actor_member_id uuid,
  action_code text not null,
  object_type text not null,
  object_id uuid,
  reason text,
  metadata_redacted jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

-- Do not create policies yet. First reconcile the existing cross-app RLS contract
-- and prove helper ownership, grants and tenant boundary tests.
rollback;
