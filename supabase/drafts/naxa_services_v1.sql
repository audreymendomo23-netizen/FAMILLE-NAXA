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


create table if not exists public.ns_devices (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.ns_accounts(id) on delete cascade,
  installation_id text not null,
  platform text not null check (platform in ('android','web')),
  label text,
  remember_device boolean not null default false,
  refresh_token_hash text,
  session_id text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (account_id, installation_id)
);

create table if not exists public.ns_auth_attempts (
  id bigserial primary key,
  login_hash text not null,
  ip_hash text not null,
  succeeded boolean not null default false,
  attempted_at timestamptz not null default now()
);
create index if not exists ns_auth_attempts_login_idx on public.ns_auth_attempts(login_hash, attempted_at desc);
create index if not exists ns_auth_attempts_ip_idx on public.ns_auth_attempts(ip_hash, attempted_at desc);

create or replace function public.ns_auth_is_limited(p_login_hash text, p_ip_hash text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select
    (select count(*) from public.ns_auth_attempts
      where login_hash = p_login_hash
        and attempted_at > now() - interval '15 minutes'
        and succeeded = false) >= 5
    or
    (select count(*) from public.ns_auth_attempts
      where ip_hash = p_ip_hash
        and attempted_at > now() - interval '15 minutes'
        and succeeded = false) >= 20;
$naxa$;

create or replace function public.ns_auth_record_attempt(
  p_login_hash text,
  p_ip_hash text,
  p_succeeded boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $naxa$
begin
  insert into public.ns_auth_attempts(login_hash, ip_hash, succeeded)
  values (p_login_hash, p_ip_hash, p_succeeded);
  delete from public.ns_auth_attempts
    where attempted_at < now() - interval '2 days';
end;
$naxa$;

alter table public.ns_organizations enable row level security;
alter table public.ns_sites enable row level security;
alter table public.ns_workstations enable row level security;
alter table public.ns_services enable row level security;
alter table public.ns_customers enable row level security;
alter table public.ns_appointments enable row level security;
alter table public.ns_pressing_orders enable row level security;
alter table public.ns_pressing_items enable row level security;
alter table public.ns_pressing_status_events enable row level security;
alter table public.ns_cash_registers enable row level security;
alter table public.ns_cash_sessions enable row level security;
alter table public.ns_sales enable row level security;
alter table public.ns_payments enable row level security;
alter table public.ns_expenses enable row level security;
alter table public.ns_commission_rules enable row level security;
alter table public.ns_commission_entries enable row level security;
alter table public.ns_inventory_items enable row level security;
alter table public.ns_inventory_movements enable row level security;

alter table public.ns_accounts enable row level security;
alter table public.ns_members enable row level security;
alter table public.ns_member_scopes enable row level security;
alter table public.ns_auth_recovery_requests enable row level security;
alter table public.ns_auth_attempts enable row level security;
alter table public.ns_devices enable row level security;
alter table public.ns_audit_events enable row level security;

revoke all on public.ns_accounts from anon, authenticated;
revoke all on public.ns_auth_attempts from anon, authenticated;
revoke all on public.ns_auth_recovery_requests from anon, authenticated;
revoke all on public.ns_devices from anon, authenticated;
revoke all on function public.ns_auth_is_limited(text, text) from public, anon, authenticated;
revoke all on function public.ns_auth_record_attempt(text, text, boolean) from public, anon, authenticated;
grant execute on function public.ns_auth_is_limited(text, text) to service_role;
grant execute on function public.ns_auth_record_attempt(text, text, boolean) to service_role;


-- Session and tenant helpers. These functions deliberately return only scope
-- decisions; they never expose account aliases, refresh hashes or user data.
create or replace function public.ns_current_account_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $naxa$
  select a.id
  from public.ns_accounts a
  join public.ns_devices d on d.account_id = a.id
  where a.auth_user_id = auth.uid()
    and a.status = 'active'
    and d.session_id = auth.jwt() ->> 'session_id'
    and d.revoked_at is null
  limit 1;
$naxa$;

create or replace function public.ns_is_org_member(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_members m
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
  );
$naxa$;

create or replace function public.ns_can_access_site(p_org_id uuid, p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_member_scopes s
    join public.ns_members m on m.id = s.member_id and m.org_id = s.org_id
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
      and s.can_read
      and (
        s.scope_type = 'organization'
        or (s.scope_type = 'site' and s.site_id = p_site_id)
      )
  );
$naxa$;

create or replace function public.ns_can_operate_site(p_org_id uuid, p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_member_scopes s
    join public.ns_members m on m.id = s.member_id and m.org_id = s.org_id
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
      and (s.can_operate or s.can_manage)
      and (s.scope_type = 'organization' or (s.scope_type = 'site' and s.site_id = p_site_id))
  );
$naxa$;

create or replace function public.ns_can_manage_site(p_org_id uuid, p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_member_scopes s
    join public.ns_members m on m.id = s.member_id and m.org_id = s.org_id
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
      and m.role_code in ('promoter','network_manager','site_manager')
      and s.can_manage
      and (s.scope_type = 'organization' or s.site_id = p_site_id)
  );
$naxa$;

create or replace function public.ns_can_manage_org(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_members m
    join public.ns_member_scopes s on s.member_id = m.id and s.org_id = m.org_id
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
      and m.role_code = 'promoter'
      and s.scope_type = 'organization'
      and s.can_manage
  );
$naxa$;

create or replace function public.ns_can_access_workstation(p_org_id uuid, p_site_id uuid, p_workstation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_member_scopes s
    join public.ns_members m on m.id = s.member_id and m.org_id = s.org_id
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
      and s.can_read
      and (
        s.scope_type = 'organization'
        or (s.scope_type = 'site' and s.site_id = p_site_id)
        or (s.scope_type = 'workstation' and s.site_id = p_site_id and s.workstation_id = p_workstation_id)
      )
  );
$naxa$;


create or replace function public.ns_can_operate_workstation(p_org_id uuid, p_site_id uuid, p_workstation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_member_scopes s
    join public.ns_members m on m.id = s.member_id and m.org_id = s.org_id
    where m.account_id = public.ns_current_account_id()
      and m.org_id = p_org_id
      and m.status = 'active'
      and (s.can_operate or s.can_manage)
      and (
        s.scope_type = 'organization'
        or (s.scope_type = 'site' and s.site_id = p_site_id)
        or (s.scope_type = 'workstation' and s.site_id = p_site_id and s.workstation_id = p_workstation_id)
      )
  );
$naxa$;

create or replace function public.ns_can_manage_member(p_target_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $naxa$
  select exists (
    select 1
    from public.ns_members target
    where target.id = p_target_member_id
      and target.org_id in (
        select current_member.org_id
        from public.ns_members current_member
        where current_member.account_id = public.ns_current_account_id()
          and current_member.status = 'active'
      )
      and (
        public.ns_can_manage_org(target.org_id)
        or exists (
          select 1
          from public.ns_member_scopes target_scope
          where target_scope.member_id = target.id
            and target_scope.site_id is not null
            and public.ns_can_manage_site(target.org_id, target_scope.site_id)
        )
      )
  );
$naxa$;

revoke all on function public.ns_current_account_id() from public, anon;
revoke all on function public.ns_is_org_member(uuid) from public, anon;
revoke all on function public.ns_can_access_site(uuid, uuid) from public, anon;
revoke all on function public.ns_can_operate_site(uuid, uuid) from public, anon;
revoke all on function public.ns_can_manage_site(uuid, uuid) from public, anon;
revoke all on function public.ns_can_manage_org(uuid) from public, anon;
revoke all on function public.ns_can_access_workstation(uuid, uuid, uuid) from public, anon;
revoke all on function public.ns_can_operate_workstation(uuid, uuid, uuid) from public, anon;
revoke all on function public.ns_can_manage_member(uuid) from public, anon;
grant execute on function public.ns_current_account_id() to authenticated, service_role;
grant execute on function public.ns_is_org_member(uuid) to authenticated, service_role;
grant execute on function public.ns_can_access_site(uuid, uuid) to authenticated, service_role;
grant execute on function public.ns_can_operate_site(uuid, uuid) to authenticated, service_role;
grant execute on function public.ns_can_manage_site(uuid, uuid) to authenticated, service_role;
grant execute on function public.ns_can_manage_org(uuid) to authenticated, service_role;
grant execute on function public.ns_can_access_workstation(uuid, uuid, uuid) to authenticated, service_role;
grant execute on function public.ns_can_operate_workstation(uuid, uuid, uuid) to authenticated, service_role;
grant execute on function public.ns_can_manage_member(uuid) to authenticated, service_role;

-- Replace any policy with the same name, then create scoped policies.
drop policy if exists ns_orgs_select on public.ns_organizations;
create policy ns_orgs_select on public.ns_organizations
  for select to authenticated using (public.ns_is_org_member(id));

drop policy if exists ns_sites_select on public.ns_sites;
create policy ns_sites_select on public.ns_sites
  for select to authenticated using (public.ns_can_access_site(org_id, id));
drop policy if exists ns_sites_insert on public.ns_sites;
create policy ns_sites_insert on public.ns_sites
  for insert to authenticated with check (public.ns_can_manage_org(org_id));
drop policy if exists ns_sites_update on public.ns_sites;
create policy ns_sites_update on public.ns_sites
  for update to authenticated using (public.ns_can_manage_site(org_id, id))
  with check (public.ns_can_manage_site(org_id, id));

drop policy if exists ns_workstations_select on public.ns_workstations;
create policy ns_workstations_select on public.ns_workstations
  for select to authenticated using (public.ns_can_access_workstation(org_id, site_id, id));
drop policy if exists ns_workstations_write on public.ns_workstations;
create policy ns_workstations_write on public.ns_workstations
  for all to authenticated
  using (public.ns_can_manage_site(org_id, site_id))
  with check (public.ns_can_manage_site(org_id, site_id));

drop policy if exists ns_services_select on public.ns_services;
create policy ns_services_select on public.ns_services
  for select to authenticated using (
    public.ns_is_org_member(org_id)
    and (site_id is null or public.ns_can_access_site(org_id, site_id))
  );
drop policy if exists ns_services_write on public.ns_services;
create policy ns_services_write on public.ns_services
  for all to authenticated
  using (
    case when site_id is null then public.ns_can_manage_org(org_id)
    else public.ns_can_manage_site(org_id, site_id) end
  )
  with check (
    case when site_id is null then public.ns_can_manage_org(org_id)
    else public.ns_can_manage_site(org_id, site_id) end
  );

drop policy if exists ns_customers_select on public.ns_customers;
create policy ns_customers_select on public.ns_customers
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_customers_insert on public.ns_customers;
create policy ns_customers_insert on public.ns_customers
  for insert to authenticated with check (public.ns_can_operate_site(org_id, site_id));
drop policy if exists ns_customers_update on public.ns_customers;
create policy ns_customers_update on public.ns_customers
  for update to authenticated using (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  )
  with check (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  );

drop policy if exists ns_appointments_select on public.ns_appointments;
create policy ns_appointments_select on public.ns_appointments
  for select to authenticated using (
    (workstation_id is null and public.ns_can_access_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_access_workstation(org_id, site_id, workstation_id))
  );
drop policy if exists ns_appointments_insert on public.ns_appointments;
create policy ns_appointments_insert on public.ns_appointments
  for insert to authenticated with check (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  );
drop policy if exists ns_appointments_update on public.ns_appointments;
create policy ns_appointments_update on public.ns_appointments
  for update to authenticated using (public.ns_can_operate_site(org_id, site_id))
  with check (public.ns_can_operate_site(org_id, site_id));

drop policy if exists ns_pressing_orders_select on public.ns_pressing_orders;
create policy ns_pressing_orders_select on public.ns_pressing_orders
  for select to authenticated using (
    (workstation_id is null and public.ns_can_access_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_access_workstation(org_id, site_id, workstation_id))
  );
drop policy if exists ns_pressing_orders_insert on public.ns_pressing_orders;
create policy ns_pressing_orders_insert on public.ns_pressing_orders
  for insert to authenticated with check (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  );
drop policy if exists ns_pressing_orders_update on public.ns_pressing_orders;
create policy ns_pressing_orders_update on public.ns_pressing_orders
  for update to authenticated using (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  )
  with check (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  );

drop policy if exists ns_pressing_items_select on public.ns_pressing_items;
create policy ns_pressing_items_select on public.ns_pressing_items
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_pressing_items_insert on public.ns_pressing_items;
create policy ns_pressing_items_insert on public.ns_pressing_items
  for insert to authenticated with check (public.ns_can_operate_site(org_id, site_id));

drop policy if exists ns_pressing_events_select on public.ns_pressing_status_events;
create policy ns_pressing_events_select on public.ns_pressing_status_events
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_pressing_events_insert on public.ns_pressing_status_events;
create policy ns_pressing_events_insert on public.ns_pressing_status_events
  for insert to authenticated with check (public.ns_can_operate_site(org_id, site_id));

drop policy if exists ns_cash_registers_select on public.ns_cash_registers;
create policy ns_cash_registers_select on public.ns_cash_registers
  for select to authenticated using (
    (workstation_id is null and public.ns_can_access_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_access_workstation(org_id, site_id, workstation_id))
  );
drop policy if exists ns_cash_registers_manage on public.ns_cash_registers;
create policy ns_cash_registers_manage on public.ns_cash_registers
  for all to authenticated
  using (
    (workstation_id is null and public.ns_can_manage_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_access_workstation(org_id, site_id, workstation_id))
  )
  with check (
    (workstation_id is null and public.ns_can_manage_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_access_workstation(org_id, site_id, workstation_id))
  );

drop policy if exists ns_cash_sessions_select on public.ns_cash_sessions;
create policy ns_cash_sessions_select on public.ns_cash_sessions
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_cash_sessions_insert on public.ns_cash_sessions;
create policy ns_cash_sessions_insert on public.ns_cash_sessions
  for insert to authenticated with check (public.ns_can_operate_site(org_id, site_id));

drop policy if exists ns_sales_select on public.ns_sales;
create policy ns_sales_select on public.ns_sales
  for select to authenticated using (
    (workstation_id is null and public.ns_can_access_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_access_workstation(org_id, site_id, workstation_id))
  );
drop policy if exists ns_sales_insert on public.ns_sales;
create policy ns_sales_insert on public.ns_sales
  for insert to authenticated with check (
    (workstation_id is null and public.ns_can_operate_site(org_id, site_id))
    or (workstation_id is not null and public.ns_can_operate_workstation(org_id, site_id, workstation_id))
  );

drop policy if exists ns_payments_select on public.ns_payments;
create policy ns_payments_select on public.ns_payments
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_payments_insert_pending on public.ns_payments;
create policy ns_payments_insert_pending on public.ns_payments
  for insert to authenticated with check (
    status = 'pending' and confirmed_at is null and confirmed_by is null
    and public.ns_can_operate_site(org_id, site_id)
  );

drop policy if exists ns_expenses_select on public.ns_expenses;
create policy ns_expenses_select on public.ns_expenses
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_expenses_insert on public.ns_expenses;
create policy ns_expenses_insert on public.ns_expenses
  for insert to authenticated with check (public.ns_can_operate_site(org_id, site_id));

drop policy if exists ns_commission_rules_select on public.ns_commission_rules;
create policy ns_commission_rules_select on public.ns_commission_rules
  for select to authenticated using (site_id is null and public.ns_is_org_member(org_id) or public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_commission_rules_manage on public.ns_commission_rules;
create policy ns_commission_rules_manage on public.ns_commission_rules
  for all to authenticated
  using (case when site_id is null then public.ns_can_manage_org(org_id) else public.ns_can_manage_site(org_id, site_id) end)
  with check (case when site_id is null then public.ns_can_manage_org(org_id) else public.ns_can_manage_site(org_id, site_id) end);

drop policy if exists ns_commission_entries_select on public.ns_commission_entries;
create policy ns_commission_entries_select on public.ns_commission_entries
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));

drop policy if exists ns_inventory_items_select on public.ns_inventory_items;
create policy ns_inventory_items_select on public.ns_inventory_items
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_inventory_items_manage on public.ns_inventory_items;
create policy ns_inventory_items_manage on public.ns_inventory_items
  for all to authenticated
  using (public.ns_can_manage_site(org_id, site_id))
  with check (public.ns_can_manage_site(org_id, site_id));

drop policy if exists ns_inventory_movements_select on public.ns_inventory_movements;
create policy ns_inventory_movements_select on public.ns_inventory_movements
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_inventory_movements_insert on public.ns_inventory_movements;
create policy ns_inventory_movements_insert on public.ns_inventory_movements
  for insert to authenticated with check (public.ns_can_operate_site(org_id, site_id));

drop policy if exists ns_members_select on public.ns_members;
create policy ns_members_select on public.ns_members
  for select to authenticated using (
    account_id = public.ns_current_account_id()
    or public.ns_can_manage_member(id)
  );
drop policy if exists ns_member_scopes_select on public.ns_member_scopes;
create policy ns_member_scopes_select on public.ns_member_scopes
  for select to authenticated using (
    member_id in (
      select m.id from public.ns_members m where m.account_id = public.ns_current_account_id()
    )
    or public.ns_can_manage_member(member_id)
  );

drop policy if exists ns_audit_events_select on public.ns_audit_events;
create policy ns_audit_events_select on public.ns_audit_events
  for select to authenticated using (
    (site_id is null and public.ns_can_manage_org(org_id))
    or (site_id is not null and public.ns_can_manage_site(org_id, site_id))
  );

-- Internal Auth account aliases, login hashes, device hashes, recovery notes and
-- audit writes are managed only by the server-side Edge Function/service_role.
revoke all on public.ns_accounts from anon, authenticated;
revoke all on public.ns_auth_attempts from anon, authenticated;
revoke all on public.ns_auth_recovery_requests from anon, authenticated;
revoke all on public.ns_devices from anon, authenticated;
revoke all on public.ns_audit_events from anon, authenticated;
revoke all on function public.ns_auth_is_limited(text, text) from public, anon, authenticated;
revoke all on function public.ns_auth_record_attempt(text, text, boolean) from public, anon, authenticated;
grant execute on function public.ns_auth_is_limited(text, text) to service_role;
grant execute on function public.ns_auth_record_attempt(text, text, boolean) to service_role;

grant select on public.ns_organizations, public.ns_sites, public.ns_workstations, public.ns_services,
  public.ns_customers, public.ns_appointments, public.ns_pressing_orders, public.ns_pressing_items,
  public.ns_pressing_status_events, public.ns_cash_registers, public.ns_cash_sessions,
  public.ns_sales, public.ns_payments, public.ns_expenses, public.ns_commission_rules,
  public.ns_commission_entries, public.ns_inventory_items, public.ns_inventory_movements,
  public.ns_members, public.ns_member_scopes to authenticated;
grant insert, update on public.ns_sites, public.ns_workstations, public.ns_services, public.ns_customers,
  public.ns_appointments, public.ns_pressing_orders, public.ns_pressing_items, public.ns_pressing_status_events,
  public.ns_cash_registers, public.ns_cash_sessions, public.ns_sales, public.ns_expenses,
  public.ns_commission_rules, public.ns_inventory_items, public.ns_inventory_movements to authenticated;
grant insert on public.ns_payments to authenticated;

rollback;
