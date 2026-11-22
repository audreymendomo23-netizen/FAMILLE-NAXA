-- NAXA SERVICES v4 — supplier purchasing, accounting ledger, COGS and objectives.
-- DRAFT ONLY: depends on v1 + v2 + v3 candidate drafts. Review/apply only to a dedicated
-- NAXA SERVICES staging project after schema diff, RLS review, provider and rollback plan.
begin;


-- N2 domain tables and versioned catalogue/CRM/support fields.
alter table public.ns_services
  drop constraint if exists ns_services_activity_check;
alter table public.ns_services
  add constraint ns_services_activity_check check (activity in ('pressing','hair','beauty','treatment','tailoring','perfume','repair','part','manufacturing','vehicle','cleaning','contract','home','printing','event','package','material','service','retail','general'));
alter table public.ns_services
  add column if not exists category text not null default '',
  add column if not exists description text not null default '',
  add column if not exists provider_member_ids jsonb not null default '[]'::jsonb,
  add column if not exists required_workstation_kinds jsonb not null default '[]'::jsonb,
  add column if not exists package_sessions integer,
  add column if not exists revision integer not null default 1 check (revision > 0);
alter table public.ns_customers
  add column if not exists address_line text not null default '',
  add column if not exists neighborhood text not null default '',
  add column if not exists landmark text not null default '',
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists location_consent_at timestamptz,
  add column if not exists revision integer not null default 1 check (revision > 0),
  add column if not exists updated_at timestamptz not null default now();
create index if not exists ns_customers_phone_scope_idx
  on public.ns_customers(org_id, site_id, phone_contact);

create table if not exists public.ns_customer_followups (
  id uuid primary key,
  org_id uuid not null,
  site_id uuid not null,
  customer_id uuid not null,
  title text not null check (length(trim(title)) between 1 and 160),
  frequency text not null check (length(trim(frequency)) between 1 and 40),
  channel text not null check (length(trim(channel)) between 1 and 32),
  notes text not null default '',
  next_due_at timestamptz not null,
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  revision integer not null default 1 check (revision > 0),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_completed_at timestamptz,
  foreign key (customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, site_id, org_id)
);
create index if not exists ns_customer_followups_due_idx
  on public.ns_customer_followups(org_id, site_id, next_due_at) where status = 'active';

create table if not exists public.ns_customer_followup_events (
  id uuid primary key,
  org_id uuid not null,
  site_id uuid not null,
  followup_id uuid not null,
  event_type text not null check (event_type = 'completed'),
  occurred_at timestamptz not null,
  next_due_at timestamptz,
  completion_note text not null default '',
  actor_member_id uuid not null,
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  foreign key (followup_id, site_id, org_id)
    references public.ns_customer_followups(id, site_id, org_id) on delete restrict,
  foreign key (actor_member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (org_id, idempotency_key)
);

create table if not exists public.ns_support_requests (
  id uuid primary key,
  org_id uuid not null,
  site_id uuid,
  subject text not null check (length(trim(subject)) between 3 and 180),
  description text not null check (length(trim(description)) between 3 and 5000),
  priority text not null check (priority in ('low','normal','high','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','waiting_customer','resolved','closed')),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, org_id)
);

alter table public.ns_customer_followups enable row level security;
alter table public.ns_customer_followup_events enable row level security;
alter table public.ns_support_requests enable row level security;
drop policy if exists ns_customer_followups_select on public.ns_customer_followups;
create policy ns_customer_followups_select on public.ns_customer_followups
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_customer_followup_events_select on public.ns_customer_followup_events;
create policy ns_customer_followup_events_select on public.ns_customer_followup_events
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_support_requests_select on public.ns_support_requests;
create policy ns_support_requests_select on public.ns_support_requests
  for select to authenticated using (
    (site_id is null and public.ns_is_org_member(org_id))
    or (site_id is not null and public.ns_can_access_site(org_id, site_id))
  );
-- Mutating these customer/service aggregates is only allowed through typed, audited RPCs.
revoke insert, update, delete on public.ns_services, public.ns_customers
  from public, anon, authenticated;
grant select on public.ns_services, public.ns_customers to authenticated;

revoke all on public.ns_customer_followups, public.ns_customer_followup_events, public.ns_support_requests
  from public, anon;
grant select on public.ns_customer_followups, public.ns_customer_followup_events, public.ns_support_requests
  to authenticated;
grant all on public.ns_customer_followups, public.ns_customer_followup_events, public.ns_support_requests
  to service_role;
revoke insert, update, delete on public.ns_customer_followups, public.ns_customer_followup_events, public.ns_support_requests
  from authenticated;

alter table public.ns_inventory_items
  add column if not exists average_unit_cost_xaf bigint not null default 0 check (average_unit_cost_xaf >= 0),
  add column if not exists selling_price_xaf bigint not null default 0 check (selling_price_xaf >= 0);

alter table public.ns_sales
  add column if not exists cost_of_goods_xaf bigint not null default 0 check (cost_of_goods_xaf >= 0),
  add column if not exists cost_snapshot_complete boolean not null default false,
  add column if not exists inventory_posting_key uuid;
create unique index if not exists ns_sales_inventory_posting_key_idx
  on public.ns_sales(org_id, inventory_posting_key) where inventory_posting_key is not null;

create table if not exists public.ns_suppliers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  name text not null check (length(trim(name)) between 2 and 120),
  normalized_name text not null,
  phone text not null default '',
  whatsapp text not null default '',
  email text not null default '',
  address text not null default '',
  payment_terms_days integer not null default 0 check (payment_terms_days between 0 and 365),
  notes text not null default '',
  active boolean not null default true,
  created_by uuid not null,
  updated_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (updated_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, site_id, org_id),
  unique (org_id, site_id, normalized_name)
);

create table if not exists public.ns_purchase_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  supplier_id uuid not null,
  supplier_name_snapshot text not null,
  reference text not null,
  supplier_invoice_number text not null default '',
  status text not null default 'ordered' check (status in ('draft','ordered','partially_received','received','closed','cancelled')),
  idempotency_key uuid not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  subtotal_xaf bigint not null check (subtotal_xaf > 0),
  recoverable_tax_xaf bigint not null default 0 check (recoverable_tax_xaf >= 0),
  non_recoverable_tax_xaf bigint not null default 0 check (non_recoverable_tax_xaf >= 0),
  shipping_xaf bigint not null default 0 check (shipping_xaf >= 0),
  other_fees_xaf bigint not null default 0 check (other_fees_xaf >= 0),
  received_base_xaf bigint not null default 0 check (received_base_xaf between 0 and subtotal_xaf),
  recognized_non_recoverable_xaf bigint not null default 0 check (recognized_non_recoverable_xaf >= 0),
  recognized_recoverable_tax_xaf bigint not null default 0 check (recognized_recoverable_tax_xaf >= 0),
  received_total_xaf bigint not null default 0 check (received_total_xaf >= 0),
  paid_total_xaf bigint not null default 0 check (paid_total_xaf between 0 and received_total_xaf),
  due_at timestamptz,
  notes text not null default '',
  created_by uuid not null,
  updated_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (supplier_id, site_id, org_id) references public.ns_suppliers(id, site_id, org_id) on delete restrict,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (updated_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, site_id, org_id),
  unique (site_id, reference),
  unique (org_id, idempotency_key)
);

create index if not exists ns_purchase_documents_due_idx
  on public.ns_purchase_documents(org_id, site_id, due_at) where status not in ('closed','cancelled');

create table if not exists public.ns_purchase_lines (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  purchase_id uuid not null,
  inventory_item_id uuid,
  description text not null check (length(trim(description)) between 1 and 240),
  item_type text not null check (item_type in ('stock','operating_expense','fixed_asset')),
  unit text not null default 'unité',
  quantity_ordered numeric(14,3) not null check (quantity_ordered > 0),
  quantity_received numeric(14,3) not null default 0 check (quantity_received between 0 and quantity_ordered),
  unit_cost_xaf bigint not null check (unit_cost_xaf > 0),
  created_at timestamptz not null default now(),
  foreign key (purchase_id, site_id, org_id) references public.ns_purchase_documents(id, site_id, org_id) on delete restrict,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (inventory_item_id) references public.ns_inventory_items(id) on delete restrict,
  check ((item_type = 'stock' and inventory_item_id is not null) or (item_type <> 'stock' and inventory_item_id is null)),
  unique (id, purchase_id, site_id, org_id)
);
create index if not exists ns_purchase_lines_item_idx
  on public.ns_purchase_lines(org_id, site_id, inventory_item_id);

create table if not exists public.ns_purchase_receipts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  purchase_id uuid not null,
  purchase_line_id uuid not null,
  quantity_received numeric(14,3) not null check (quantity_received > 0),
  base_cost_xaf bigint not null check (base_cost_xaf > 0),
  non_recoverable_cost_xaf bigint not null default 0 check (non_recoverable_cost_xaf >= 0),
  recoverable_tax_xaf bigint not null default 0 check (recoverable_tax_xaf >= 0),
  idempotency_key uuid not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  actor_member_id uuid not null,
  received_at timestamptz not null default now(),
  foreign key (purchase_id, site_id, org_id) references public.ns_purchase_documents(id, site_id, org_id) on delete restrict,
  foreign key (purchase_line_id, purchase_id, site_id, org_id) references public.ns_purchase_lines(id, purchase_id, site_id, org_id) on delete restrict,
  foreign key (actor_member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (org_id, idempotency_key)
);

create table if not exists public.ns_supplier_payments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  purchase_id uuid not null,
  supplier_id uuid not null,
  cash_session_id uuid references public.ns_cash_sessions(id) on delete restrict,
  amount_xaf bigint not null check (amount_xaf > 0),
  payment_method text not null check (payment_method in ('cash','bank','mobile_money','other')),
  payment_reference text not null default '',
  idempotency_key uuid not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  paid_by uuid not null,
  paid_at timestamptz not null default now(),
  foreign key (purchase_id, site_id, org_id) references public.ns_purchase_documents(id, site_id, org_id) on delete restrict,
  foreign key (supplier_id, site_id, org_id) references public.ns_suppliers(id, site_id, org_id) on delete restrict,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (paid_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  check ((payment_method = 'cash' and cash_session_id is not null) or (payment_method <> 'cash' and cash_session_id is null)),
  unique (org_id, idempotency_key)
);
create index if not exists ns_supplier_payments_history_idx
  on public.ns_supplier_payments(org_id, site_id, paid_at desc);

create table if not exists public.ns_sale_lines (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  sale_id uuid not null references public.ns_sales(id) on delete restrict,
  item_type text not null check (item_type in ('stock','service')),
  inventory_item_id uuid,
  description text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price_xaf bigint not null check (unit_price_xaf >= 0),
  discount_xaf bigint not null default 0 check (discount_xaf >= 0),
  unit_cost_at_sale_xaf bigint,
  cost_of_goods_xaf bigint,
  cost_snapshot_complete boolean not null default false,
  cogs_posted_at timestamptz,
  idempotency_key uuid not null,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  unique (org_id, idempotency_key),
  check (
    (item_type = 'stock' and inventory_item_id is not null)
    or (item_type = 'service' and inventory_item_id is null)
  ),
  check (
    (cogs_posted_at is null and unit_cost_at_sale_xaf is null and cost_of_goods_xaf is null)
    or (cogs_posted_at is not null and unit_cost_at_sale_xaf is not null and cost_of_goods_xaf is not null)
  )
);
create index if not exists ns_sale_lines_sale_idx
  on public.ns_sale_lines(org_id, site_id, sale_id);

create table if not exists public.ns_accounting_entries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  journal_batch_id uuid not null,
  source_type text not null,
  source_id uuid not null,
  event_code text not null,
  debit_account text not null,
  credit_account text not null,
  amount_xaf bigint not null check (amount_xaf > 0),
  description text not null,
  actor_member_id uuid not null,
  occurred_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (actor_member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (debit_account <> credit_account),
  unique (org_id, source_type, source_id, event_code)
);
create index if not exists ns_accounting_entries_date_idx
  on public.ns_accounting_entries(org_id, site_id, occurred_at);
create index if not exists ns_accounting_entries_debit_idx
  on public.ns_accounting_entries(org_id, site_id, debit_account, occurred_at);

create table if not exists public.ns_performance_objectives (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  period_type text not null check (period_type in ('daily','monthly','annual')),
  period_start date not null,
  period_end date not null,
  version integer not null check (version > 0),
  target_revenue_xaf bigint not null check (target_revenue_xaf > 0),
  baseline_locked boolean not null default true,
  reason text not null default '',
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (period_end >= period_start),
  unique (org_id, site_id, period_type, period_start, version)
);
create index if not exists ns_performance_objectives_period_idx
  on public.ns_performance_objectives(org_id, site_id, period_type, period_start desc);

-- RLS: site visibility is scoped; writes are constrained to members who can manage that site.
alter table public.ns_suppliers enable row level security;
alter table public.ns_purchase_documents enable row level security;
alter table public.ns_purchase_lines enable row level security;
alter table public.ns_purchase_receipts enable row level security;
alter table public.ns_supplier_payments enable row level security;
alter table public.ns_sale_lines enable row level security;
alter table public.ns_accounting_entries enable row level security;
alter table public.ns_performance_objectives enable row level security;

create policy ns_suppliers_select on public.ns_suppliers
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
create policy ns_suppliers_manage on public.ns_suppliers
  for all to authenticated using (public.ns_can_manage_site(org_id, site_id))
  with check (public.ns_can_manage_site(org_id, site_id));

create policy ns_purchase_documents_select on public.ns_purchase_documents
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
-- Purchase headers and lines are created only through ns_create_supplier_purchase().

create policy ns_purchase_lines_select on public.ns_purchase_lines
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
create policy ns_purchase_receipts_select on public.ns_purchase_receipts
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
create policy ns_supplier_payments_select on public.ns_supplier_payments
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
create policy ns_sale_lines_select on public.ns_sale_lines
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
create policy ns_accounting_entries_select on public.ns_accounting_entries
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
create policy ns_performance_objectives_select on public.ns_performance_objectives
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
-- Objective baselines are appended only through ns_create_performance_objective().

revoke all on public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_accounting_entries from anon, authenticated;
grant select on public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_accounting_entries to authenticated;
grant all on public.ns_suppliers, public.ns_purchase_documents, public.ns_purchase_lines,
  public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_sale_lines,
  public.ns_accounting_entries, public.ns_performance_objectives to service_role;


drop policy if exists ns_purchase_lines_manage on public.ns_purchase_lines;
create policy ns_purchase_lines_insert on public.ns_purchase_lines
  for insert to authenticated with check (
    public.ns_can_manage_site(org_id, site_id)
    and exists (
      select 1 from public.ns_purchase_documents d
      where d.id = purchase_id
        and d.org_id = ns_purchase_lines.org_id
        and d.site_id = ns_purchase_lines.site_id
        and d.status = 'ordered'
    )
  );

drop policy if exists ns_sale_lines_insert on public.ns_sale_lines;
create policy ns_sale_lines_insert on public.ns_sale_lines
  for insert to authenticated with check (
    public.ns_can_operate_site(org_id, site_id)
    and unit_cost_at_sale_xaf is null and cost_of_goods_xaf is null
    and cost_snapshot_complete = false and cogs_posted_at is null
    and exists (
      select 1 from public.ns_sales sale
      where sale.id = sale_id and sale.org_id = org_id and sale.site_id = site_id
        and sale.status = 'draft'
    )
    and ((item_type = 'stock' and inventory_item_id is not null)
      or (item_type = 'service' and inventory_item_id is null))
  );

revoke all on public.ns_suppliers, public.ns_purchase_documents, public.ns_purchase_lines,
  public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_sale_lines,
  public.ns_accounting_entries, public.ns_performance_objectives from public, anon, authenticated;
grant select on public.ns_suppliers, public.ns_purchase_documents, public.ns_purchase_lines,
  public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_sale_lines,
  public.ns_accounting_entries, public.ns_performance_objectives to authenticated;
grant insert, update on public.ns_suppliers to authenticated;
grant insert on public.ns_sale_lines to authenticated;
grant all on public.ns_suppliers, public.ns_purchase_documents, public.ns_purchase_lines,
  public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_sale_lines,
  public.ns_accounting_entries, public.ns_performance_objectives to service_role;


create or replace function public.ns_save_supplier(
  p_supplier_id uuid, p_org_id uuid, p_site_id uuid, p_name text,
  p_phone text default '', p_whatsapp text default '', p_email text default '',
  p_address text default '', p_payment_terms_days integer default 0, p_notes text default ''
) returns jsonb
language plpgsql security definer set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_existing public.ns_suppliers%rowtype;
  v_name text;
  v_normalized text;
  v_whatsapp text;
  v_result public.ns_suppliers%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id, p_site_id) then
    raise exception 'NAXA_SUPPLIER_SAVE_FORBIDDEN';
  end if;
  v_name := trim(coalesce(p_name, ''));
  v_normalized := lower(regexp_replace(v_name, '\s+', ' ', 'g'));
  v_whatsapp := regexp_replace(coalesce(p_whatsapp, ''), '\D', '', 'g');
  if p_supplier_id is null or length(v_name) not between 2 and 120
     or length(coalesce(p_phone,'')) > 32 or length(v_whatsapp) not in (0,9,10,11,12,13,14,15)
     or length(coalesce(p_email,'')) > 254 or length(coalesce(p_address,'')) > 200
     or length(coalesce(p_notes,'')) > 1000
     or coalesce(p_payment_terms_days,0) not between 0 and 365 then
    raise exception 'NAXA_SUPPLIER_SAVE_INVALID';
  end if;
  select * into v_existing from public.ns_suppliers where id = p_supplier_id for update;
  if found then
    if v_existing.org_id <> p_org_id or v_existing.site_id <> p_site_id then
      raise exception 'NAXA_SUPPLIER_ID_SCOPE_CONFLICT';
    end if;
    update public.ns_suppliers
      set name = v_name, normalized_name = v_normalized,
          phone = trim(coalesce(p_phone,'')), whatsapp = v_whatsapp,
          email = trim(coalesce(p_email,'')), address = trim(coalesce(p_address,'')),
          payment_terms_days = p_payment_terms_days, notes = trim(coalesce(p_notes,'')),
          active = true, updated_by = v_member, updated_at = now()
      where id = p_supplier_id returning * into v_result;
  else
    insert into public.ns_suppliers(
      id, org_id, site_id, name, normalized_name, phone, whatsapp, email, address,
      payment_terms_days, notes, active, created_by, updated_by
    ) values (
      p_supplier_id, p_org_id, p_site_id, v_name, v_normalized,
      trim(coalesce(p_phone,'')), v_whatsapp, trim(coalesce(p_email,'')),
      trim(coalesce(p_address,'')), p_payment_terms_days, trim(coalesce(p_notes,'')),
      true, v_member, v_member
    ) returning * into v_result;
  end if;
  return jsonb_build_object('supplier_id', v_result.id, 'org_id', v_result.org_id,
    'site_id', v_result.site_id, 'name', v_result.name, 'whatsapp', v_result.whatsapp,
    'updated_at', v_result.updated_at, 'idempotent_identity', true);
end;
$naxa$;


create or replace function public.ns_save_inventory_item(
  p_inventory_item_id uuid, p_org_id uuid, p_site_id uuid, p_sku text,
  p_name text, p_unit text, p_reorder_level numeric, p_supplier_whatsapp text default ''
) returns jsonb
language plpgsql security definer set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_existing public.ns_inventory_items%rowtype;
  v_result public.ns_inventory_items%rowtype;
  v_sku text;
  v_name text;
  v_unit text;
  v_whatsapp text;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id,p_site_id) then
    raise exception 'NAXA_INVENTORY_ITEM_SAVE_FORBIDDEN';
  end if;
  v_sku := nullif(upper(trim(coalesce(p_sku,''))),'');
  v_name := trim(coalesce(p_name,''));
  v_unit := trim(coalesce(p_unit,''));
  v_whatsapp := regexp_replace(coalesce(p_supplier_whatsapp,''),'\D','','g');
  if p_inventory_item_id is null or length(coalesce(p_sku,'')) > 80
     or length(v_name) not between 1 and 160 or length(v_unit) not between 1 and 40
     or p_reorder_level is null or p_reorder_level < 0
     or p_reorder_level::text in ('NaN','Infinity','-Infinity')
     or p_reorder_level > 99999999999.999
     or length(v_whatsapp) not in (0,9,10,11,12,13,14,15) then
    raise exception 'NAXA_INVENTORY_ITEM_SAVE_INVALID';
  end if;
  select * into v_existing from public.ns_inventory_items
  where id = p_inventory_item_id for update;
  if found then
    if v_existing.org_id <> p_org_id or v_existing.site_id <> p_site_id then
      raise exception 'NAXA_INVENTORY_ITEM_ID_SCOPE_CONFLICT';
    end if;
    update public.ns_inventory_items
      set sku=v_sku,name=v_name,unit=v_unit,reorder_level=p_reorder_level,
          supplier_whatsapp=v_whatsapp,active=true
      where id=p_inventory_item_id returning * into v_result;
  else
    insert into public.ns_inventory_items(
      id,org_id,site_id,sku,name,unit,quantity,reorder_level,active,supplier_whatsapp
    ) values (
      p_inventory_item_id,p_org_id,p_site_id,v_sku,v_name,v_unit,0,p_reorder_level,true,v_whatsapp
    ) returning * into v_result;
  end if;
  return jsonb_build_object(
    'inventory_item_id',v_result.id,'org_id',v_result.org_id,'site_id',v_result.site_id,
    'sku',v_result.sku,'name',v_result.name,'unit',v_result.unit,'quantity',v_result.quantity,
    'idempotent_identity',true
  );
end;
$naxa$;

create or replace function public.ns_record_inventory_movement(
  p_movement_id uuid,p_org_id uuid,p_site_id uuid,p_inventory_item_id uuid,
  p_movement_type text,p_quantity_delta numeric,p_reason text
) returns jsonb
language plpgsql security definer set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_existing public.ns_inventory_movements%rowtype;
  v_item public.ns_inventory_items%rowtype;
  v_next_quantity numeric(14,3);
  v_reason text;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_INVENTORY_MOVEMENT_FORBIDDEN';
  end if;
  v_reason := trim(coalesce(p_reason,''));
  if p_movement_id is null or p_inventory_item_id is null
     or p_movement_type is null
     or p_movement_type not in ('in','consumption','loss','adjustment')
     or p_quantity_delta is null or p_quantity_delta=0
     or p_quantity_delta::text in ('NaN','Infinity','-Infinity')
     or abs(p_quantity_delta)>99999999999.999
     or abs(p_quantity_delta*1000-round(p_quantity_delta*1000))>0.000001
     or (p_movement_type='in' and p_quantity_delta<=0)
     or (p_movement_type in ('consumption','loss') and p_quantity_delta>=0)
     or length(v_reason) not between 3 and 240 then
    raise exception 'NAXA_INVENTORY_MOVEMENT_INVALID';
  end if;
  select * into v_existing from public.ns_inventory_movements
  where id=p_movement_id for update;
  if found then
    if v_existing.org_id<>p_org_id or v_existing.site_id<>p_site_id
       or v_existing.item_id<>p_inventory_item_id
       or v_existing.movement_type<>p_movement_type
       or v_existing.quantity_delta<>p_quantity_delta
       or v_existing.reason<>v_reason
       or v_existing.idempotency_key<>p_movement_id then
      raise exception 'NAXA_INVENTORY_MOVEMENT_IDEMPOTENCY_CONFLICT';
    end if;
    select quantity into v_next_quantity from public.ns_inventory_items
    where id=p_inventory_item_id and org_id=p_org_id and site_id=p_site_id;
    return jsonb_build_object(
      'movement_id',v_existing.id,'inventory_item_id',v_existing.item_id,
      'quantity',v_next_quantity,'idempotent_replay',true
    );
  end if;
  select * into v_item from public.ns_inventory_items
  where id=p_inventory_item_id and org_id=p_org_id and site_id=p_site_id and active
  for update;
  if not found then raise exception 'NAXA_INVENTORY_ITEM_NOT_FOUND'; end if;
  v_next_quantity := v_item.quantity+p_quantity_delta;
  if v_next_quantity<0 then raise exception 'NAXA_INVENTORY_STOCK_WOULD_BE_NEGATIVE'; end if;
  update public.ns_inventory_items set quantity=v_next_quantity
  where id=p_inventory_item_id and org_id=p_org_id and site_id=p_site_id;
  insert into public.ns_inventory_movements(
    id,org_id,site_id,item_id,movement_type,quantity_delta,reason,idempotency_key,actor_member_id
  ) values (
    p_movement_id,p_org_id,p_site_id,p_inventory_item_id,p_movement_type,
    p_quantity_delta,v_reason,p_movement_id,v_member
  );
  return jsonb_build_object(
    'movement_id',p_movement_id,'inventory_item_id',p_inventory_item_id,
    'quantity',v_next_quantity,'idempotent_replay',false
  );
end;
$naxa$;

create or replace function public.ns_create_supplier_purchase(
  p_org_id uuid,
  p_site_id uuid,
  p_supplier_id uuid,
  p_reference text,
  p_supplier_invoice_number text,
  p_idempotency_key uuid,
  p_payload_sha256 text,
  p_lines jsonb,
  p_recoverable_tax_xaf bigint default 0,
  p_non_recoverable_tax_xaf bigint default 0,
  p_shipping_xaf bigint default 0,
  p_other_fees_xaf bigint default 0,
  p_due_at timestamptz default null,
  p_notes text default ''
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_supplier public.ns_suppliers%rowtype;
  v_existing public.ns_purchase_documents%rowtype;
  v_purchase_id uuid;
  v_subtotal bigint := 0;
  v_line record;
  v_line_amount bigint;
  v_count integer := 0;
  v_total bigint;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id, p_site_id) then
    raise exception 'NAXA_PURCHASE_CREATE_FORBIDDEN';
  end if;
  if p_reference is null or length(trim(p_reference)) not between 3 and 80
     or p_idempotency_key is null or p_payload_sha256 is null
     or p_payload_sha256 !~ '^[0-9a-f]{64}$'
     or p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) < 1 or jsonb_array_length(p_lines) > 100
     or coalesce(p_recoverable_tax_xaf,0) < 0
     or coalesce(p_non_recoverable_tax_xaf,0) < 0
     or coalesce(p_shipping_xaf,0) < 0 or coalesce(p_other_fees_xaf,0) < 0 then
    raise exception 'NAXA_PURCHASE_CREATE_INVALID';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_org_id::text || ':supplier-purchase:' || p_idempotency_key::text, 0));
  select * into v_existing from public.ns_purchase_documents
    where org_id = p_org_id and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.id = p_idempotency_key and v_existing.site_id = p_site_id
       and v_existing.supplier_id = p_supplier_id and v_existing.payload_sha256 = p_payload_sha256 then
      return jsonb_build_object(
        'idempotent', true,
        'purchase_id', v_existing.id,
        'line_ids', coalesce((
          select jsonb_agg(jsonb_build_object('line_id', l.id) order by l.id)
          from public.ns_purchase_lines l
          where l.org_id = p_org_id and l.site_id = p_site_id and l.purchase_id = v_existing.id
        ), '[]'::jsonb),
        'subtotal_xaf', v_existing.subtotal_xaf,
        'total_ordered_xaf', v_existing.subtotal_xaf + v_existing.recoverable_tax_xaf
          + v_existing.non_recoverable_tax_xaf + v_existing.shipping_xaf + v_existing.other_fees_xaf,
        'status', v_existing.status
      );
    end if;
    raise exception 'NAXA_PURCHASE_CREATE_IDEMPOTENCY_REUSED';
  end if;

  select * into v_supplier from public.ns_suppliers
    where id = p_supplier_id and org_id = p_org_id and site_id = p_site_id and active
    for share;
  if not found then raise exception 'NAXA_PURCHASE_SUPPLIER_NOT_FOUND'; end if;

  for v_line in
    select * from jsonb_to_recordset(p_lines) as x(
      line_id uuid,
      inventory_item_id uuid,
      description text,
      item_type text,
      unit text,
      quantity_ordered numeric,
      unit_cost_xaf bigint
    )
  loop
    v_count := v_count + 1;
    if v_line.line_id is null
       or exists (select 1 from public.ns_purchase_lines l where l.id = v_line.line_id)
       or v_line.description is null or length(trim(v_line.description)) not between 1 and 240
       or v_line.item_type not in ('stock','operating_expense','fixed_asset')
       or v_line.quantity_ordered is null or v_line.quantity_ordered <= 0
       or v_line.quantity_ordered > 100000000
       or v_line.unit_cost_xaf is null or v_line.unit_cost_xaf <= 0 then
      raise exception 'NAXA_PURCHASE_LINE_INVALID';
    end if;
    if v_line.item_type = 'stock' then
      if v_line.inventory_item_id is null or not exists (
        select 1 from public.ns_inventory_items i
        where i.id = v_line.inventory_item_id and i.org_id = p_org_id
          and i.site_id = p_site_id and i.active
      ) then
        raise exception 'NAXA_PURCHASE_LINE_STOCK_SCOPE_INVALID';
      end if;
    elsif v_line.inventory_item_id is not null then
      raise exception 'NAXA_PURCHASE_NONSTOCK_ITEM_LINK_INVALID';
    end if;
    v_line_amount := round(v_line.quantity_ordered * v_line.unit_cost_xaf)::bigint;
    if v_line_amount <= 0 or v_subtotal > 9000000000000000000::bigint - v_line_amount then
      raise exception 'NAXA_PURCHASE_SUBTOTAL_OVERFLOW';
    end if;
    v_subtotal := v_subtotal + v_line_amount;
  end loop;
  if v_count < 1 or v_subtotal <= 0 then raise exception 'NAXA_PURCHASE_EMPTY'; end if;

  v_total := v_subtotal + coalesce(p_recoverable_tax_xaf,0)
      + coalesce(p_non_recoverable_tax_xaf,0)
      + coalesce(p_shipping_xaf,0) + coalesce(p_other_fees_xaf,0);
  if v_total <= 0 then raise exception 'NAXA_PURCHASE_TOTAL_INVALID'; end if;

  insert into public.ns_purchase_documents(
    id, org_id, site_id, supplier_id, supplier_name_snapshot, reference, supplier_invoice_number,
    status, subtotal_xaf, recoverable_tax_xaf, non_recoverable_tax_xaf, shipping_xaf, other_fees_xaf,
    idempotency_key, payload_sha256,
    received_base_xaf, recognized_non_recoverable_xaf, recognized_recoverable_tax_xaf,
    received_total_xaf, paid_total_xaf, due_at, notes, created_by, updated_by
  ) values (
    p_idempotency_key, p_org_id, p_site_id, p_supplier_id, v_supplier.name, trim(p_reference),
    coalesce(trim(p_supplier_invoice_number),''), 'ordered', v_subtotal,
    coalesce(p_recoverable_tax_xaf,0), coalesce(p_non_recoverable_tax_xaf,0),
    coalesce(p_shipping_xaf,0), coalesce(p_other_fees_xaf,0), p_idempotency_key, p_payload_sha256,
    0, 0, 0, 0, 0, p_due_at, coalesce(trim(p_notes),''), v_member, v_member
  ) returning id into v_purchase_id;

  insert into public.ns_purchase_lines(
    id, org_id, site_id, purchase_id, inventory_item_id, description, item_type, unit,
    quantity_ordered, quantity_received, unit_cost_xaf
  )
  select x.line_id, p_org_id, p_site_id, v_purchase_id, x.inventory_item_id, trim(x.description),
         x.item_type, coalesce(nullif(trim(x.unit),''),'unité'),
         x.quantity_ordered, 0, x.unit_cost_xaf
  from jsonb_to_recordset(p_lines) as x(
    line_id uuid, inventory_item_id uuid, description text, item_type text, unit text,
    quantity_ordered numeric, unit_cost_xaf bigint
  );

  return jsonb_build_object(
    'purchase_id', v_purchase_id,
    'line_ids', coalesce((
      select jsonb_agg(jsonb_build_object('line_id', l.id) order by l.id)
      from public.ns_purchase_lines l
      where l.org_id = p_org_id and l.site_id = p_site_id and l.purchase_id = v_purchase_id
    ), '[]'::jsonb),
    'supplier_id', p_supplier_id,
    'subtotal_xaf', v_subtotal,
    'total_ordered_xaf', v_total,
    'line_count', v_count,
    'status', 'ordered',
    'stock_and_payables_posted', false
  );
end;
$naxa$;

create or replace function public.ns_post_accounting_entry(
  p_org_id uuid, p_site_id uuid, p_source_type text, p_source_id uuid, p_event_code text,
  p_debit_account text, p_credit_account text, p_amount_xaf bigint, p_description text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_id uuid;
  v_existing public.ns_accounting_entries%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_ACCOUNTING_POST_FORBIDDEN';
  end if;
  if p_source_id is null or p_source_type is null or p_event_code is null
     or p_debit_account is null or p_credit_account is null
     or p_amount_xaf is null or p_amount_xaf <= 0 or p_debit_account = p_credit_account
     or length(trim(p_source_type)) = 0 or length(trim(p_event_code)) = 0 then
    raise exception 'NAXA_ACCOUNTING_ENTRY_INVALID';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    p_org_id::text || ':' || p_source_type || ':' || p_source_id::text || ':' || p_event_code, 0
  ));
  select * into v_existing from public.ns_accounting_entries
    where org_id = p_org_id and source_type = p_source_type and source_id = p_source_id and event_code = p_event_code
    for update;
  if found then
    if v_existing.site_id = p_site_id and v_existing.debit_account = p_debit_account
       and v_existing.credit_account = p_credit_account and v_existing.amount_xaf = p_amount_xaf
       and v_existing.description = trim(p_description) then
      return v_existing.id;
    end if;
    raise exception 'NAXA_ACCOUNTING_IDEMPOTENCY_CONFLICT';
  end if;
  v_id := gen_random_uuid();
  insert into public.ns_accounting_entries(
    id, org_id, site_id, journal_batch_id, source_type, source_id, event_code,
    debit_account, credit_account, amount_xaf, description, actor_member_id
  ) values (
    v_id, p_org_id, p_site_id,
    md5(p_org_id::text || ':' || p_source_type || ':' || p_source_id::text)::uuid,
    p_source_type, p_source_id, p_event_code,
    p_debit_account, p_credit_account, p_amount_xaf, trim(p_description), v_member
  );
  return v_id;
end;
$naxa$;

create or replace function public.ns_receive_supplier_purchase_line(
  p_org_id uuid, p_site_id uuid, p_purchase_id uuid, p_line_id uuid,
  p_quantity numeric, p_idempotency_key uuid, p_payload_sha256 text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_purchase public.ns_purchase_documents%rowtype;
  v_line public.ns_purchase_lines%rowtype;
  v_receipt public.ns_purchase_receipts%rowtype;
  v_item public.ns_inventory_items%rowtype;
  v_base bigint;
  v_next_base bigint;
  v_new_nonrecoverable bigint;
  v_new_recoverable bigint;
  v_nonrecoverable_delta bigint;
  v_recoverable_delta bigint;
  v_expense_base bigint;
  v_old_cost bigint;
  v_new_qty numeric(14,3);
  v_new_cost bigint;
  v_received_total bigint;
  v_complete boolean;
  v_receipt_id uuid;
  v_now timestamptz := now();
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_PURCHASE_RECEIVE_FORBIDDEN';
  end if;
  if p_quantity is null or p_quantity <= 0 or p_idempotency_key is null
     or p_payload_sha256 is null or p_payload_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'NAXA_PURCHASE_RECEIVE_INVALID';
  end if;

  select * into v_receipt from public.ns_purchase_receipts
    where org_id = p_org_id and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.purchase_id = p_purchase_id and v_receipt.purchase_line_id = p_line_id
       and v_receipt.quantity_received = p_quantity and v_receipt.payload_sha256 = p_payload_sha256 then
      return jsonb_build_object('idempotent', true, 'receipt_id', v_receipt.id);
    end if;
    raise exception 'NAXA_PURCHASE_RECEIPT_IDEMPOTENCY_REUSED';
  end if;

  select * into v_purchase from public.ns_purchase_documents
    where id = p_purchase_id and org_id = p_org_id and site_id = p_site_id for update;
  if not found or v_purchase.status in ('cancelled','closed') then raise exception 'NAXA_PURCHASE_NOT_RECEIVABLE'; end if;
  select * into v_line from public.ns_purchase_lines
    where id = p_line_id and purchase_id = p_purchase_id and org_id = p_org_id and site_id = p_site_id for update;
  if not found or p_quantity > v_line.quantity_ordered - v_line.quantity_received then
    raise exception 'NAXA_PURCHASE_RECEIPT_EXCEEDS_ORDER';
  end if;

  v_base := round(p_quantity * v_line.unit_cost_xaf)::bigint;
  v_next_base := v_purchase.received_base_xaf + v_base;
  if v_base <= 0 or v_next_base > v_purchase.subtotal_xaf then raise exception 'NAXA_PURCHASE_RECEIPT_VALUE_INVALID'; end if;

  v_new_nonrecoverable := round(
    (v_purchase.non_recoverable_tax_xaf + v_purchase.shipping_xaf + v_purchase.other_fees_xaf)::numeric
    * v_next_base / v_purchase.subtotal_xaf
  )::bigint;
  v_new_recoverable := round(v_purchase.recoverable_tax_xaf::numeric * v_next_base / v_purchase.subtotal_xaf)::bigint;
  v_nonrecoverable_delta := greatest(0, v_new_nonrecoverable - v_purchase.recognized_non_recoverable_xaf);
  v_recoverable_delta := greatest(0, v_new_recoverable - v_purchase.recognized_recoverable_tax_xaf);
  v_expense_base := v_base + v_nonrecoverable_delta;

  insert into public.ns_purchase_receipts(
    org_id, site_id, purchase_id, purchase_line_id, quantity_received,
    base_cost_xaf, non_recoverable_cost_xaf, recoverable_tax_xaf,
    idempotency_key, payload_sha256, actor_member_id
  ) values (
    p_org_id, p_site_id, p_purchase_id, p_line_id, p_quantity,
    v_base, v_nonrecoverable_delta, v_recoverable_delta,
    p_idempotency_key, p_payload_sha256, v_member
  ) returning id into v_receipt_id;

  if v_line.item_type = 'stock' then
    select * into v_item from public.ns_inventory_items
      where id = v_line.inventory_item_id and org_id = p_org_id and site_id = p_site_id and active for update;
    if not found then raise exception 'NAXA_PURCHASE_STOCK_ITEM_NOT_FOUND'; end if;
    v_old_cost := v_item.average_unit_cost_xaf;
    v_new_qty := v_item.quantity + p_quantity;
    v_new_cost := round((v_item.quantity * v_old_cost + v_expense_base)::numeric / v_new_qty)::bigint;
    update public.ns_inventory_items
      set quantity = v_new_qty, average_unit_cost_xaf = v_new_cost
      where id = v_item.id and org_id = p_org_id and site_id = p_site_id;
    insert into public.ns_inventory_movements(
      org_id, site_id, item_id, movement_type, quantity_delta, reason, idempotency_key, actor_member_id
    ) values (
      p_org_id, p_site_id, v_item.id, 'in', p_quantity, 'Réception fournisseur ' || v_purchase.reference,
      p_idempotency_key, v_member
    );
    perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'purchase_receipt', v_receipt_id, 'inventory_received',
      'INVENTORY_ASSET', 'SUPPLIER_PAYABLE', v_expense_base, 'Réception stock ' || v_line.description);
  elsif v_line.item_type = 'operating_expense' then
    perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'purchase_receipt', v_receipt_id, 'expense_received',
      'OPERATING_EXPENSE_PURCHASE', 'SUPPLIER_PAYABLE', v_expense_base, 'Achat consommable/service ' || v_line.description);
  else
    perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'purchase_receipt', v_receipt_id, 'asset_received',
      'FIXED_ASSET', 'SUPPLIER_PAYABLE', v_expense_base, 'Immobilisation reçue ' || v_line.description);
  end if;

  if v_recoverable_delta > 0 then
    perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'purchase_receipt', v_receipt_id, 'recoverable_input_tax',
      'INPUT_TAX_RECEIVABLE', 'SUPPLIER_PAYABLE', v_recoverable_delta, 'Taxe récupérable facture ' || v_purchase.reference);
  end if;

  update public.ns_purchase_lines set quantity_received = quantity_received + p_quantity where id = p_line_id;
  select bool_and(quantity_received >= quantity_ordered - 0.000001) into v_complete
    from public.ns_purchase_lines where purchase_id = p_purchase_id;
  v_received_total := v_purchase.received_total_xaf + v_expense_base + v_recoverable_delta;
  update public.ns_purchase_documents
    set received_base_xaf = v_next_base,
        recognized_non_recoverable_xaf = v_new_nonrecoverable,
        recognized_recoverable_tax_xaf = v_new_recoverable,
        received_total_xaf = v_received_total,
        status = case when v_complete and v_purchase.paid_total_xaf >= v_received_total then 'closed'
                      when v_complete then 'received' else 'partially_received' end,
        updated_by = v_member, updated_at = v_now
    where id = p_purchase_id;
  return jsonb_build_object('idempotent', false, 'receipt_id', v_receipt_id, 'received_total_xaf', v_received_total,
    'supplier_payable_xaf', greatest(0, v_received_total - v_purchase.paid_total_xaf));
end;
$naxa$;

create or replace function public.ns_record_supplier_payment(
  p_org_id uuid, p_site_id uuid, p_purchase_id uuid, p_amount_xaf bigint,
  p_payment_method text, p_cash_session_id uuid, p_payment_reference text,
  p_idempotency_key uuid, p_payload_sha256 text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_purchase public.ns_purchase_documents%rowtype;
  v_payment public.ns_supplier_payments%rowtype;
  v_cash_session public.ns_cash_sessions%rowtype;
  v_payment_id uuid;
  v_balance bigint;
  v_treasury text;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_SUPPLIER_PAYMENT_FORBIDDEN';
  end if;
  if p_amount_xaf is null or p_amount_xaf <= 0 or p_idempotency_key is null
     or p_payload_sha256 is null or p_payload_sha256 !~ '^[0-9a-f]{64}$'
     or p_payment_method not in ('cash','bank','mobile_money','other') then
    raise exception 'NAXA_SUPPLIER_PAYMENT_INVALID';
  end if;
  select * into v_payment from public.ns_supplier_payments
    where org_id = p_org_id and idempotency_key = p_idempotency_key;
  if found then
    if v_payment.site_id = p_site_id and v_payment.purchase_id = p_purchase_id
       and v_payment.amount_xaf = p_amount_xaf and v_payment.payment_method = p_payment_method
       and v_payment.cash_session_id is not distinct from p_cash_session_id
       and v_payment.payload_sha256 = p_payload_sha256 then
      return jsonb_build_object('idempotent', true, 'payment_id', v_payment.id);
    end if;
    raise exception 'NAXA_SUPPLIER_PAYMENT_IDEMPOTENCY_REUSED';
  end if;

  select * into v_purchase from public.ns_purchase_documents
    where id = p_purchase_id and org_id = p_org_id and site_id = p_site_id for update;
  if not found or v_purchase.status not in ('partially_received','received') then
    raise exception 'NAXA_SUPPLIER_PAYMENT_NOT_PAYABLE';
  end if;
  v_balance := v_purchase.received_total_xaf - v_purchase.paid_total_xaf;
  if p_amount_xaf > v_balance then raise exception 'NAXA_SUPPLIER_PAYMENT_EXCEEDS_BALANCE'; end if;

  if p_payment_method = 'cash' then
    if p_cash_session_id is null then raise exception 'NAXA_SUPPLIER_PAYMENT_CASH_SESSION_REQUIRED'; end if;
    select * into v_cash_session from public.ns_cash_sessions c
      where c.id = p_cash_session_id and c.org_id = p_org_id and c.site_id = p_site_id
      and c.status = 'open' for update;
    if not found or not public.ns_can_access_cash_register(p_org_id, p_site_id, v_cash_session.register_id, true) then
      raise exception 'NAXA_SUPPLIER_PAYMENT_CASH_SESSION_FORBIDDEN';
    end if;
  elsif p_cash_session_id is not null then
    raise exception 'NAXA_SUPPLIER_PAYMENT_CASH_SESSION_NOT_ALLOWED';
  end if;

  insert into public.ns_supplier_payments(
    org_id, site_id, purchase_id, supplier_id, cash_session_id, amount_xaf, payment_method,
    payment_reference, idempotency_key, payload_sha256, paid_by
  ) values (
    p_org_id, p_site_id, p_purchase_id, v_purchase.supplier_id, p_cash_session_id, p_amount_xaf,
    p_payment_method, coalesce(trim(p_payment_reference), ''), p_idempotency_key, p_payload_sha256, v_member
  ) returning id into v_payment_id;

  if p_payment_method = 'cash' then
    insert into public.ns_expenses(org_id, site_id, cash_session_id, category, description, amount_xaf, reason, created_by)
    values (p_org_id, p_site_id, p_cash_session_id, 'supplier_payment',
      'Règlement fournisseur ' || v_purchase.reference, p_amount_xaf,
      'Paiement enregistré dans le journal fournisseur', v_member);
  end if;
  v_treasury := case p_payment_method
    when 'cash' then 'CASH_REGISTER'
    when 'bank' then 'BANK'
    when 'mobile_money' then 'MOBILE_MONEY_CLEARING'
    else 'OTHER_TREASURY'
  end;
  perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'supplier_payment', v_payment_id,
    'payable_settlement', 'SUPPLIER_PAYABLE', v_treasury, p_amount_xaf,
    'Règlement fournisseur ' || v_purchase.reference);
  update public.ns_purchase_documents
    set paid_total_xaf = paid_total_xaf + p_amount_xaf,
        status = case when received_base_xaf >= subtotal_xaf - 1
                           and paid_total_xaf + p_amount_xaf >= received_total_xaf then 'closed'
                      else status end,
        updated_by = v_member, updated_at = now()
    where id = p_purchase_id;
  return jsonb_build_object('idempotent', false, 'payment_id', v_payment_id,
    'remaining_supplier_payable_xaf', greatest(0, v_balance - p_amount_xaf));
end;
$naxa$;

-- Approved objectives are versioned, never overwritten retroactively.

create or replace function public.ns_post_sale_inventory(
  p_org_id uuid, p_site_id uuid, p_sale_id uuid, p_inventory_posting_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_sale public.ns_sales%rowtype;
  v_line public.ns_sale_lines%rowtype;
  v_item public.ns_inventory_items%rowtype;
  v_payment record;
  v_confirmed bigint;
  v_unit_cost bigint;
  v_line_cogs bigint;
  v_total_cogs bigint := 0;
  v_treasury text;
  v_line_count integer := 0;
  v_all_costed boolean := true;
  v_now timestamptz := now();
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_SALE_INVENTORY_FORBIDDEN';
  end if;
  if p_sale_id is null or p_inventory_posting_key is null then
    raise exception 'NAXA_SALE_INVENTORY_INVALID';
  end if;

  select * into v_sale
  from public.ns_sales
  where id = p_sale_id and org_id = p_org_id and site_id = p_site_id
  for update;
  if not found or v_sale.status <> 'posted' then
    raise exception 'NAXA_SALE_NOT_POSTED';
  end if;

  if v_sale.inventory_posting_key is not null then
    if v_sale.inventory_posting_key = p_inventory_posting_key then
      return jsonb_build_object(
        'idempotent', true, 'sale_id', v_sale.id,
        'revenue_xaf', v_sale.total_xaf,
        'cost_of_goods_xaf', v_sale.cost_of_goods_xaf,
        'cost_snapshot_complete', v_sale.cost_snapshot_complete
      );
    end if;
    raise exception 'NAXA_SALE_INVENTORY_ALREADY_POSTED';
  end if;

  select coalesce(sum(amount_xaf),0)::bigint into v_confirmed
  from public.ns_payments
  where sale_id = p_sale_id and org_id = p_org_id and site_id = p_site_id and status = 'confirmed';
  if v_confirmed < v_sale.total_xaf then raise exception 'NAXA_SALE_NOT_FULLY_SETTLED'; end if;
  if v_confirmed > v_sale.total_xaf then raise exception 'NAXA_SALE_PAYMENT_MISMATCH'; end if;

  for v_line in
    select * from public.ns_sale_lines
    where sale_id = p_sale_id and org_id = p_org_id and site_id = p_site_id
    order by id
    for update
  loop
    v_line_count := v_line_count + 1;
    if v_line.cogs_posted_at is not null then raise exception 'NAXA_SALE_LINE_ALREADY_COSTED'; end if;

    if v_line.item_type = 'stock' then
      select * into v_item
      from public.ns_inventory_items
      where id = v_line.inventory_item_id and org_id = p_org_id and site_id = p_site_id and active
      for update;
      if not found or v_item.quantity < v_line.quantity then raise exception 'NAXA_SALE_STOCK_INSUFFICIENT'; end if;

      v_unit_cost := v_item.average_unit_cost_xaf;
      v_line_cogs := round(v_line.quantity * v_unit_cost)::bigint;
      update public.ns_inventory_items
        set quantity = quantity - v_line.quantity
        where id = v_item.id and org_id = p_org_id and site_id = p_site_id;
      update public.ns_sale_lines
        set unit_cost_at_sale_xaf = v_unit_cost,
            cost_of_goods_xaf = v_line_cogs,
            cost_snapshot_complete = true,
            cogs_posted_at = v_now
        where id = v_line.id and org_id = p_org_id and site_id = p_site_id;

      insert into public.ns_inventory_movements(
        org_id, site_id, item_id, movement_type, quantity_delta, reason, idempotency_key, actor_member_id
      ) values (
        p_org_id, p_site_id, v_item.id, 'consumption', -v_line.quantity,
        'Vente confirmée ' || v_sale.sale_number, v_line.idempotency_key, v_member
      );

      if v_line_cogs > 0 then
        perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'sale_line', v_line.id, 'cost_of_goods_sold',
          'COST_OF_GOODS_SOLD', 'INVENTORY_ASSET', v_line_cogs, 'Coût des ventes ' || v_line.description);
      end if;
    else
      -- Service revenue remains turnover, but no gross margin is claimed until its direct labour/material cost is documented.
      v_all_costed := false;
      v_line_cogs := 0;
      update public.ns_sale_lines
        set unit_cost_at_sale_xaf = 0,
            cost_of_goods_xaf = 0,
            cost_snapshot_complete = false,
            cogs_posted_at = v_now
        where id = v_line.id and org_id = p_org_id and site_id = p_site_id;
    end if;
    v_total_cogs := v_total_cogs + v_line_cogs;
  end loop;

  for v_payment in
    select * from public.ns_payments
    where sale_id = p_sale_id and org_id = p_org_id and site_id = p_site_id and status = 'confirmed'
    order by confirmed_at nulls last, created_at, id
  loop
    v_treasury := case v_payment.payment_method
      when 'cash' then 'CASH_REGISTER'
      when 'mobile_money' then 'MOBILE_MONEY_CLEARING'
      when 'mixed' then 'TREASURY_MIXED_CLEARING'
      else 'OTHER_TREASURY'
    end;
    perform public.ns_post_accounting_entry(p_org_id, p_site_id, 'sale_payment', v_payment.id, 'revenue_recognized',
      v_treasury, 'SALES_REVENUE', v_payment.amount_xaf, 'Encaissement vente ' || v_sale.sale_number);
  end loop;

  update public.ns_sales
    set cost_of_goods_xaf = v_total_cogs,
        cost_snapshot_complete = (v_line_count > 0 and v_all_costed),
        inventory_posting_key = p_inventory_posting_key
    where id = p_sale_id and org_id = p_org_id and site_id = p_site_id;
  return jsonb_build_object(
    'idempotent', false,
    'sale_id', p_sale_id,
    'revenue_xaf', v_confirmed,
    'cost_of_goods_xaf', v_total_cogs,
    'cost_snapshot_complete', (v_line_count > 0 and v_all_costed),
    'gross_profit_xaf', case when v_line_count > 0 and v_all_costed then v_confirmed - v_total_cogs else null end
  );
end;
$naxa$;;

create or replace function public.ns_create_performance_objective(
  p_org_id uuid, p_site_id uuid, p_period_type text, p_period_start date,
  p_period_end date, p_target_revenue_xaf bigint, p_reason text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_version integer;
  v_id uuid;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id, p_site_id) then
    raise exception 'NAXA_OBJECTIVE_FORBIDDEN';
  end if;
  if p_period_type not in ('daily','monthly','annual') or p_period_start is null or p_period_end is null
     or p_period_end < p_period_start or p_target_revenue_xaf is null or p_target_revenue_xaf <= 0 then
    raise exception 'NAXA_OBJECTIVE_INVALID';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_org_id::text || ':' || p_site_id::text || ':' || p_period_type || ':' || p_period_start::text, 0));
  select coalesce(max(version),0) + 1 into v_version
  from public.ns_performance_objectives
  where org_id = p_org_id and site_id = p_site_id and period_type = p_period_type and period_start = p_period_start;
  insert into public.ns_performance_objectives(
    org_id, site_id, period_type, period_start, period_end, version, target_revenue_xaf, reason, created_by
  ) values (
    p_org_id, p_site_id, p_period_type, p_period_start, p_period_end, v_version,
    p_target_revenue_xaf, coalesce(trim(p_reason), ''), v_member
  ) returning id into v_id;
  return v_id;
end;
$naxa$;

-- Read models are security-invoker views: they inherit the caller's table RLS policies.
create or replace view public.ns_performance_daily
with (security_invoker = true)
as
with settled_sales as (
  select s.id, s.org_id, s.site_id, s.created_at, s.total_xaf, s.cost_of_goods_xaf, s.cost_snapshot_complete
  from public.ns_sales s
  join lateral (
    select coalesce(sum(p.amount_xaf),0)::bigint as confirmed_amount
    from public.ns_payments p
    where p.sale_id = s.id and p.org_id = s.org_id and p.site_id = s.site_id and p.status = 'confirmed'
  ) paid on paid.confirmed_amount >= s.total_xaf
  where s.status = 'posted'
)
select
  s.org_id,
  s.site_id,
  (s.created_at at time zone 'Africa/Douala')::date as performance_day,
  sum(s.total_xaf)::bigint as revenue_xaf,
  sum(coalesce(s.cost_of_goods_xaf,0))::bigint as cost_of_goods_xaf,
  case when bool_and(s.cost_snapshot_complete)
    then sum(s.total_xaf - coalesce(s.cost_of_goods_xaf,0))::bigint else null end as gross_profit_xaf,
  count(*) filter (where not s.cost_snapshot_complete)::integer as uncosted_sales_count,
  count(*)::integer as confirmed_sales_count
from settled_sales s
group by s.org_id, s.site_id, (s.created_at at time zone 'Africa/Douala')::date;

create or replace view public.ns_performance_monthly
with (security_invoker = true)
as
select org_id, site_id, date_trunc('month', performance_day)::date as performance_month,
       sum(revenue_xaf)::bigint as revenue_xaf,
       sum(cost_of_goods_xaf)::bigint as known_cost_of_goods_xaf,
       case when sum(uncosted_sales_count) = 0 then sum(gross_profit_xaf)::bigint else null end as gross_profit_xaf,
       sum(uncosted_sales_count)::integer as uncosted_sales_count,
       sum(confirmed_sales_count)::integer as confirmed_sales_count
from public.ns_performance_daily
group by org_id, site_id, date_trunc('month', performance_day)::date;

create or replace view public.ns_performance_annual
with (security_invoker = true)
as
select org_id, site_id, date_trunc('year', performance_day)::date as performance_year,
       sum(revenue_xaf)::bigint as revenue_xaf,
       sum(cost_of_goods_xaf)::bigint as known_cost_of_goods_xaf,
       case when sum(uncosted_sales_count) = 0 then sum(gross_profit_xaf)::bigint else null end as gross_profit_xaf,
       sum(uncosted_sales_count)::integer as uncosted_sales_count,
       sum(confirmed_sales_count)::integer as confirmed_sales_count
from public.ns_performance_daily
group by org_id, site_id, date_trunc('year', performance_day)::date;

grant select on public.ns_performance_daily, public.ns_performance_monthly, public.ns_performance_annual to authenticated, service_role;

revoke all on function public.ns_save_inventory_item(uuid,uuid,uuid,text,text,text,numeric,text) from public,anon;
grant execute on function public.ns_save_inventory_item(uuid,uuid,uuid,text,text,text,numeric,text) to authenticated,service_role;
revoke all on function public.ns_record_inventory_movement(uuid,uuid,uuid,uuid,text,numeric,text) from public,anon;
grant execute on function public.ns_record_inventory_movement(uuid,uuid,uuid,uuid,text,numeric,text) to authenticated,service_role;

revoke all on function public.ns_post_sale_inventory(uuid,uuid,uuid,uuid) from public, anon;
grant execute on function public.ns_post_sale_inventory(uuid,uuid,uuid,uuid) to authenticated, service_role;



-- N2 addendum: typed sync mutation gateway and transactional receipts.
-- The receipt and the business mutation are part of this single PostgreSQL transaction.
-- Only the explicitly allowlisted actions below are executable through this gateway.

create or replace function public.ns_upsert_recurring_charge(
  p_charge_id uuid, p_org_id uuid, p_site_id uuid, p_name text, p_category text,
  p_amount_xaf bigint, p_recurrence text, p_next_due_at timestamptz,
  p_reminder_days integer, p_active boolean
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_existing public.ns_recurring_charges%rowtype;
  v_result public.ns_recurring_charges%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id, p_site_id) then
    raise exception 'NAXA_RECURRING_CHARGE_FORBIDDEN';
  end if;
  if p_charge_id is null
     or length(trim(coalesce(p_name,''))) not between 2 and 120
     or length(trim(coalesce(p_category,''))) not between 1 and 80
     or p_amount_xaf is null or p_amount_xaf <= 0
     or p_recurrence not in ('monthly','quarterly','annual','one_time')
     or p_next_due_at is null
     or p_reminder_days is null or p_reminder_days not between 0 and 30
     or p_active is null then
    raise exception 'NAXA_RECURRING_CHARGE_INVALID';
  end if;

  select * into v_existing
  from public.ns_recurring_charges
  where id = p_charge_id
  for update;
  if found then
    if v_existing.org_id <> p_org_id or v_existing.site_id <> p_site_id then
      raise exception 'NAXA_RECURRING_CHARGE_ID_SCOPE_CONFLICT';
    end if;
    update public.ns_recurring_charges
      set name = trim(p_name), category = trim(p_category),
          amount_xaf = p_amount_xaf, recurrence = p_recurrence,
          next_due_at = p_next_due_at, reminder_days = p_reminder_days,
          active = p_active, updated_by = v_member, updated_at = now(),
          last_reminder_at = null
      where id = p_charge_id
      returning * into v_result;
  else
    insert into public.ns_recurring_charges(
      id, org_id, site_id, name, category, amount_xaf, recurrence,
      next_due_at, reminder_days, active, created_by, updated_by
    ) values (
      p_charge_id, p_org_id, p_site_id, trim(p_name), trim(p_category),
      p_amount_xaf, p_recurrence, p_next_due_at, p_reminder_days,
      p_active, v_member, v_member
    ) returning * into v_result;
  end if;
  return jsonb_build_object(
    'charge_id', v_result.id, 'org_id', v_result.org_id,
    'site_id', v_result.site_id, 'active', v_result.active,
    'updated_at', v_result.updated_at
  );
end;
$naxa$;

create or replace function public.ns_deactivate_recurring_charge(
  p_charge_id uuid, p_org_id uuid, p_site_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_charge public.ns_recurring_charges%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id, p_site_id) then
    raise exception 'NAXA_RECURRING_CHARGE_FORBIDDEN';
  end if;
  select * into v_charge
  from public.ns_recurring_charges
  where id = p_charge_id and org_id = p_org_id and site_id = p_site_id
  for update;
  if not found then raise exception 'NAXA_RECURRING_CHARGE_NOT_FOUND'; end if;
  if v_charge.active then
    update public.ns_recurring_charges
      set active = false, updated_by = v_member, updated_at = now(),
          last_reminder_at = null
      where id = p_charge_id and org_id = p_org_id and site_id = p_site_id;
  end if;
  return jsonb_build_object('charge_id', p_charge_id, 'active', false, 'idempotent', not v_charge.active);
end;
$naxa$;

create or replace function public.ns_upsert_loyalty_program(
  p_program_id uuid, p_org_id uuid, p_activity_profile text, p_program_code text,
  p_name text, p_description text, p_metric_code text, p_unit_amount_xaf bigint,
  p_target_value bigint, p_reward_description text, p_window_days integer,
  p_active boolean
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_existing public.ns_loyalty_programs%rowtype;
  v_result public.ns_loyalty_programs%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_org(p_org_id) then
    raise exception 'NAXA_LOYALTY_PROGRAM_FORBIDDEN';
  end if;
  if p_program_id is null
     or p_activity_profile not in (
       'pressing','coiffure','couture','beaute','parfumerie','reparation','menuiserie',
       'garage','nettoyage','domicile','impression','photo_evenementiel','autre'
     )
     or p_program_code not in ('points','visits','spend','frequency')
     or length(trim(coalesce(p_name,''))) not between 2 and 80
     or length(coalesce(p_description,'')) > 1000
     or p_metric_code not in ('points','visits','spend')
     or p_unit_amount_xaf is null or p_unit_amount_xaf <= 0
     or p_target_value is null or p_target_value <= 0
     or length(trim(coalesce(p_reward_description,''))) not between 2 and 240
     or p_window_days is null or p_window_days not between 0 and 365
     or p_active is null then
    raise exception 'NAXA_LOYALTY_PROGRAM_INVALID';
  end if;

  select * into v_existing
  from public.ns_loyalty_programs
  where id = p_program_id
  for update;
  if found then
    if v_existing.org_id <> p_org_id then
      raise exception 'NAXA_LOYALTY_PROGRAM_ID_SCOPE_CONFLICT';
    end if;
    update public.ns_loyalty_programs
      set activity_profile = p_activity_profile, program_code = p_program_code,
          name = trim(p_name), description = coalesce(p_description,''),
          metric_code = p_metric_code, unit_amount_xaf = p_unit_amount_xaf,
          target_value = p_target_value, reward_description = trim(p_reward_description),
          window_days = p_window_days, active = p_active,
          updated_by = v_member, updated_at = now()
      where id = p_program_id
      returning * into v_result;
  else
    insert into public.ns_loyalty_programs(
      id, org_id, activity_profile, program_code, name, description, metric_code,
      unit_amount_xaf, target_value, reward_description, window_days,
      active, created_by, updated_by
    ) values (
      p_program_id, p_org_id, p_activity_profile, p_program_code, trim(p_name),
      coalesce(p_description,''), p_metric_code, p_unit_amount_xaf,
      p_target_value, trim(p_reward_description), p_window_days,
      p_active, v_member, v_member
    ) returning * into v_result;
  end if;
  return jsonb_build_object(
    'program_id', v_result.id, 'org_id', v_result.org_id,
    'activity_profile', v_result.activity_profile,
    'program_code', v_result.program_code, 'active', v_result.active,
    'updated_at', v_result.updated_at
  );
end;
$naxa$;

create or replace function public.ns_apply_sync_event(
  p_org_id uuid,
  p_site_id uuid,
  p_workstation_id uuid,
  p_device_id uuid,
  p_event_id uuid,
  p_device_sequence bigint,
  p_aggregate_type text,
  p_aggregate_id text,
  p_action_code text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_account_id uuid;
  v_member_id uuid;
  v_session_id text;
  v_device public.ns_devices%rowtype;
  v_existing public.ns_sync_receipts%rowtype;
  v_payload_hash text;
  v_expected_aggregate text;
  v_payload_aggregate text;
  v_result jsonb;
  v_response jsonb;
begin
  if p_org_id is null or p_device_id is null or p_event_id is null
     or p_device_sequence is null or p_device_sequence <= 0
     or length(trim(coalesce(p_aggregate_type,''))) not between 1 and 80
     or length(trim(coalesce(p_aggregate_id,''))) not between 1 and 180
     or length(trim(coalesce(p_action_code,''))) not between 1 and 100
     or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'NAXA_SYNC_ENVELOPE_INVALID';
  end if;
  if (p_payload->>'org_id') is distinct from p_org_id::text then
    raise exception 'NAXA_SYNC_ORGANIZATION_PAYLOAD_MISMATCH';
  end if;

  v_account_id := public.ns_current_account_id();
  v_member_id := public.ns_current_member_id(p_org_id);
  v_session_id := auth.jwt() ->> 'session_id';
  if v_account_id is null or v_member_id is null or v_session_id is null then
    raise exception 'NAXA_SYNC_AUTH_REQUIRED';
  end if;

  select * into v_device
  from public.ns_devices d
  where d.id = p_device_id
    and d.account_id = v_account_id
    and d.session_id = v_session_id
    and d.revoked_at is null
  for share;
  if not found then raise exception 'NAXA_SYNC_DEVICE_NOT_REGISTERED'; end if;

  if p_action_code = 'loyalty_program.updated' then
    if p_site_id is not null or p_workstation_id is not null
       or not public.ns_can_manage_org(p_org_id) then
      raise exception 'NAXA_SYNC_SCOPE_FORBIDDEN';
    end if;
  elsif p_action_code = 'support_request.created' and p_site_id is null then
    if p_payload->>'site_id' is not null or p_workstation_id is not null
       or not public.ns_is_org_member(p_org_id) then
      raise exception 'NAXA_SYNC_SCOPE_FORBIDDEN';
    end if;
  else
    if p_site_id is null
       or (p_payload->>'site_id') is distinct from p_site_id::text
       or not exists (
         select 1 from public.ns_sites s
         where s.id = p_site_id and s.org_id = p_org_id and s.status = 'active'
       )
       or not public.ns_can_operate_site(p_org_id, p_site_id) then
      raise exception 'NAXA_SYNC_SCOPE_FORBIDDEN';
    end if;
    if p_workstation_id is not null and (
      not exists (
        select 1 from public.ns_workstations w
        where w.id = p_workstation_id and w.org_id = p_org_id
          and w.site_id = p_site_id and w.status = 'active'
      )
      or not public.ns_can_operate_workstation(p_org_id, p_site_id, p_workstation_id)
    ) then
      raise exception 'NAXA_SYNC_WORKSTATION_SCOPE_FORBIDDEN';
    end if;
  end if;

  v_expected_aggregate := case
    when p_action_code = 'supplier.saved' then 'supplier'
    when p_action_code like 'inventory_item.%' then 'inventory_item'
    when p_action_code like 'inventory_movement.%' then 'inventory_movement'
    when p_action_code = 'purchase.ordered' then 'purchase'
    when p_action_code = 'purchase.receipt.confirmed' then 'purchase_receipt'
    when p_action_code = 'supplier.payment.recorded' then 'supplier_payment'
    when p_action_code like 'recurring_charge.%' then 'recurring_charge'
    when p_action_code = 'loyalty_program.updated' then 'loyalty_program'
    when p_action_code = 'loyalty_activity.recorded' then 'loyalty_activity'
    when p_action_code = 'loyalty_reward.redeemed' then 'loyalty_reward'
    when p_action_code like 'service.%' then 'service'
    when p_action_code = 'customer.created' then 'customer'
    when p_action_code like 'customer_followup.%' then 'customer_followup'
    when p_action_code = 'support_request.created' then 'support_request'
    else null
  end;
  if v_expected_aggregate is null then
    raise exception 'NAXA_SYNC_ACTION_NOT_SUPPORTED';
  end if;
  if p_aggregate_type <> v_expected_aggregate then
    raise exception 'NAXA_SYNC_AGGREGATE_ACTION_MISMATCH';
  end if;

  v_payload_aggregate := case
    when p_action_code = 'supplier.saved' then p_payload->>'supplier_id'
    when p_action_code like 'inventory_item.%' then p_payload->>'inventory_item_id'
    when p_action_code like 'inventory_movement.%' then p_payload->>'movement_id'
    when p_action_code = 'purchase.ordered' then p_payload->>'purchase_id'
    when p_action_code = 'purchase.receipt.confirmed' then coalesce(p_payload->>'receipt_id', p_payload->>'idempotency_key')
    when p_action_code = 'supplier.payment.recorded' then coalesce(p_payload->>'payment_id', p_payload->>'idempotency_key')
    when p_action_code like 'recurring_charge.%' then p_payload->>'charge_id'
    when p_action_code = 'loyalty_program.updated' then p_payload->>'program_id'
    when p_action_code = 'loyalty_activity.recorded' then p_payload->>'activity_event_id'
    when p_action_code = 'loyalty_reward.redeemed' then p_payload->>'reward_event_id'
    when p_action_code like 'service.%' then p_payload->>'service_id'
    when p_action_code = 'customer.created' then p_payload->>'customer_id'
    when p_action_code like 'customer_followup.%' then p_payload->>'followup_id'
    when p_action_code = 'support_request.created' then p_payload->>'request_id'
    else null
  end;
  if v_payload_aggregate is not null and v_payload_aggregate <> p_aggregate_id then
    raise exception 'NAXA_SYNC_AGGREGATE_ID_MISMATCH';
  end if;

  v_payload_hash := encode(extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':' || p_event_id::text, 0)
  );

  select * into v_existing
  from public.ns_sync_receipts r
  where r.org_id = p_org_id and r.client_event_id = p_event_id
  for update;
  if found then
    if v_existing.device_id <> p_device_id
       or v_existing.device_sequence <> p_device_sequence
       or v_existing.action_code <> p_action_code
       or v_existing.aggregate_type <> p_aggregate_type
       or v_existing.aggregate_id <> p_aggregate_id
       or v_existing.site_id is distinct from p_site_id
       or v_existing.workstation_id is distinct from p_workstation_id
       or v_existing.payload_sha256 <> v_payload_hash then
      raise exception 'NAXA_SYNC_EVENT_IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.status <> 'applied' then
      raise exception 'NAXA_SYNC_EVENT_NOT_FINAL';
    end if;
    return v_existing.response_json || jsonb_build_object('idempotent', true);
  end if;

  insert into public.ns_sync_receipts(
    org_id, site_id, workstation_id, device_id, member_id,
    client_event_id, device_sequence, aggregate_type, aggregate_id,
    action_code, payload_sha256, status, response_json
  ) values (
    p_org_id, p_site_id, p_workstation_id, p_device_id, v_member_id,
    p_event_id, p_device_sequence, p_aggregate_type, p_aggregate_id,
    p_action_code, v_payload_hash, 'accepted',
    jsonb_build_object('status','accepted')
  );

  case p_action_code
    when 'supplier.saved' then
      v_result := public.ns_save_supplier(
        (p_payload->>'supplier_id')::uuid, p_org_id, p_site_id,
        p_payload->>'name', coalesce(p_payload->>'phone',''),
        coalesce(p_payload->>'whatsapp',''), coalesce(p_payload->>'email',''),
        coalesce(p_payload->>'address',''), coalesce((p_payload->>'payment_terms_days')::integer,0),
        coalesce(p_payload->>'notes','')
      );
    when 'inventory_item.created' then
      v_result := public.ns_save_inventory_item(
        (p_payload->>'inventory_item_id')::uuid, p_org_id, p_site_id,
        coalesce(p_payload->>'sku',''), p_payload->>'name', p_payload->>'unit',
        (p_payload->>'reorder_level')::numeric, coalesce(p_payload->>'supplier_whatsapp','')
      );
    when 'inventory_item.imported' then
      v_result := public.ns_save_inventory_item(
        (p_payload->>'inventory_item_id')::uuid, p_org_id, p_site_id,
        coalesce(p_payload->>'sku',''), p_payload->>'name', p_payload->>'unit',
        (p_payload->>'reorder_level')::numeric, coalesce(p_payload->>'supplier_whatsapp','')
      );
    when 'inventory_item.import_updated' then
      v_result := public.ns_save_inventory_item(
        (p_payload->>'inventory_item_id')::uuid, p_org_id, p_site_id,
        coalesce(p_payload->>'sku',''), p_payload->>'name', p_payload->>'unit',
        (p_payload->>'reorder_level')::numeric, coalesce(p_payload->>'supplier_whatsapp','')
      );
    when 'inventory_item.supplier_whatsapp_updated' then
      v_result := public.ns_save_inventory_item(
        (p_payload->>'inventory_item_id')::uuid, p_org_id, p_site_id,
        coalesce(p_payload->>'sku',''), p_payload->>'name', p_payload->>'unit',
        (p_payload->>'reorder_level')::numeric, coalesce(p_payload->>'supplier_whatsapp','')
      );
    when 'inventory_movement.created' then
      v_result := public.ns_record_inventory_movement(
        (p_payload->>'movement_id')::uuid, p_org_id, p_site_id,
        (p_payload->>'inventory_item_id')::uuid, p_payload->>'movement_type',
        (p_payload->>'quantity_delta')::numeric, p_payload->>'reason'
      );
    when 'inventory_movement.import_initial' then
      v_result := public.ns_record_inventory_movement(
        (p_payload->>'movement_id')::uuid, p_org_id, p_site_id,
        (p_payload->>'inventory_item_id')::uuid, p_payload->>'movement_type',
        (p_payload->>'quantity_delta')::numeric, p_payload->>'reason'
      );
    when 'inventory_movement.import_adjustment' then
      v_result := public.ns_record_inventory_movement(
        (p_payload->>'movement_id')::uuid, p_org_id, p_site_id,
        (p_payload->>'inventory_item_id')::uuid, p_payload->>'movement_type',
        (p_payload->>'quantity_delta')::numeric, p_payload->>'reason'
      );
    when 'purchase.ordered' then
      v_result := public.ns_create_supplier_purchase(
        p_org_id, p_site_id, (p_payload->>'supplier_id')::uuid,
        p_payload->>'reference', coalesce(p_payload->>'supplier_invoice_number',''),
        coalesce((p_payload->>'idempotency_key')::uuid, (p_payload->>'purchase_id')::uuid),
        v_payload_hash, coalesce(p_payload->'lines','[]'::jsonb),
        coalesce((p_payload->>'recoverable_tax_xaf')::bigint,0),
        coalesce((p_payload->>'non_recoverable_tax_xaf')::bigint,0),
        coalesce((p_payload->>'shipping_xaf')::bigint,0),
        coalesce((p_payload->>'other_fees_xaf')::bigint,0),
        nullif(p_payload->>'due_at','')::timestamptz,
        coalesce(p_payload->>'notes','')
      );
    when 'purchase.receipt.confirmed' then
      v_result := public.ns_receive_supplier_purchase_line(
        p_org_id, p_site_id, (p_payload->>'purchase_id')::uuid,
        (p_payload->>'line_id')::uuid, (p_payload->>'quantity')::numeric,
        (p_payload->>'idempotency_key')::uuid, v_payload_hash
      );
    when 'supplier.payment.recorded' then
      v_result := public.ns_record_supplier_payment(
        p_org_id, p_site_id, (p_payload->>'purchase_id')::uuid,
        (p_payload->>'amount_xaf')::bigint, p_payload->>'payment_method',
        nullif(p_payload->>'cash_session_id','')::uuid,
        coalesce(p_payload->>'payment_reference',''),
        (p_payload->>'idempotency_key')::uuid, v_payload_hash
      );
    when 'recurring_charge.saved' then
      v_result := public.ns_upsert_recurring_charge(
        (p_payload->>'charge_id')::uuid, p_org_id, p_site_id,
        p_payload->>'name', p_payload->>'category',
        (p_payload->>'amount_xaf')::bigint, p_payload->>'recurrence',
        (p_payload->>'next_due_at')::timestamptz,
        coalesce((p_payload->>'reminder_days')::integer,3),
        coalesce((p_payload->>'active')::boolean,true)
      );
    when 'recurring_charge.deactivated' then
      v_result := public.ns_deactivate_recurring_charge(
        (p_payload->>'charge_id')::uuid, p_org_id, p_site_id
      );
    when 'recurring_charge.payment_recorded' then
      v_result := public.ns_record_charge_payment(
        p_org_id, p_site_id, (p_payload->>'charge_id')::uuid,
        (p_payload->>'amount_xaf')::bigint,
        coalesce((p_payload->>'payment_id')::uuid, p_event_id),
        coalesce(p_payload->>'payment_method','manual'),
        nullif(p_payload->>'payment_reference','')
      );
    when 'loyalty_program.updated' then
      v_result := public.ns_upsert_loyalty_program(
        (p_payload->>'program_id')::uuid, p_org_id,
        p_payload->>'activity_profile', p_payload->>'program_code',
        p_payload->>'name', coalesce(p_payload->>'description',''),
        p_payload->>'metric_code', (p_payload->>'unit_amount_xaf')::bigint,
        (p_payload->>'target_value')::bigint, p_payload->>'reward_description',
        coalesce((p_payload->>'window_days')::integer,0),
        coalesce((p_payload->>'active')::boolean,true)
      );
    when 'loyalty_activity.recorded' then
      v_result := public.ns_record_loyalty_activity(
        p_org_id, p_site_id, (p_payload->>'program_id')::uuid,
        (p_payload->>'customer_id')::uuid, (p_payload->>'amount_xaf')::bigint,
        (p_payload->>'activity_event_id')::uuid
      );
    when 'service.created' then
      v_result := public.ns_create_service(
        (p_payload->>'service_id')::uuid,p_org_id,p_site_id,
        p_payload->>'code',p_payload->>'activity',p_payload->>'name',
        nullif(p_payload->>'duration_minutes','')::integer,
        (p_payload->>'price_xaf')::bigint,
        coalesce((p_payload->>'active')::boolean,true),
        coalesce(p_payload->>'category',''),coalesce(p_payload->>'description',''),
        coalesce(p_payload->'provider_member_ids','[]'::jsonb),
        coalesce(p_payload->'required_workstation_kinds','[]'::jsonb),
        nullif(p_payload->>'package_sessions','')::integer
      );
    when 'service.updated' then
      v_result := public.ns_update_service(
        (p_payload->>'service_id')::uuid,p_org_id,p_site_id,
        p_payload->>'code',p_payload->>'activity',p_payload->>'name',
        nullif(p_payload->>'duration_minutes','')::integer,
        (p_payload->>'price_xaf')::bigint,
        coalesce((p_payload->>'active')::boolean,true),
        (p_payload->>'expected_version')::integer
      );
    when 'service.configuration_updated' then
      v_result := public.ns_update_service_configuration(
        (p_payload->>'service_id')::uuid,p_org_id,p_site_id,
        coalesce(p_payload->>'category',''),coalesce(p_payload->>'description',''),
        coalesce(p_payload->'provider_member_ids','[]'::jsonb),
        coalesce(p_payload->'required_workstation_kinds','[]'::jsonb),
        nullif(p_payload->>'package_sessions','')::integer,
        (p_payload->>'expected_version')::integer
      );
    when 'customer.created' then
      v_result := public.ns_create_customer(
        (p_payload->>'customer_id')::uuid,p_org_id,p_site_id,
        p_payload->>'display_name',coalesce(p_payload->>'phone_contact',''),
        coalesce((p_payload->>'contact_consent')::boolean,false),
        coalesce(p_payload->>'address_line',''),coalesce(p_payload->>'neighborhood',''),
        coalesce(p_payload->>'landmark',''),
        nullif(p_payload->>'latitude','')::numeric,
        nullif(p_payload->>'longitude','')::numeric,
        nullif(p_payload->>'location_consent_at','')::timestamptz,
        coalesce(p_payload->>'notes_private','')
      );
    when 'customer_followup.created' then
      v_result := public.ns_create_customer_followup(
        (p_payload->>'followup_id')::uuid,p_org_id,p_site_id,
        (p_payload->>'customer_id')::uuid,p_payload->>'title',
        p_payload->>'frequency',p_payload->>'channel',coalesce(p_payload->>'notes',''),
        (p_payload->>'next_due_at')::timestamptz,coalesce(p_payload->>'status','active')
      );
    when 'customer_followup.completed' then
      v_result := public.ns_complete_customer_followup(
        (p_payload->>'followup_id')::uuid,p_org_id,p_site_id,p_event_id,
        (p_payload->>'completed_at')::timestamptz,
        nullif(p_payload->>'next_due_at_if_repeating','')::timestamptz,
        coalesce(p_payload->>'completion_note','')
      );
    when 'support_request.created' then
      v_result := public.ns_create_support_request(
        (p_payload->>'request_id')::uuid,p_org_id,p_site_id,
        p_payload->>'subject',p_payload->>'description',p_payload->>'priority'
      );
    when 'loyalty_reward.redeemed' then
      if not public.ns_redeem_loyalty_reward(
        p_org_id, p_site_id, (p_payload->>'reward_event_id')::uuid
      ) then
        raise exception 'NAXA_LOYALTY_REWARD_NOT_AVAILABLE';
      end if;
      v_result := jsonb_build_object(
        'reward_event_id', p_payload->>'reward_event_id', 'redeemed', true
      );
    else
      raise exception 'NAXA_SYNC_ACTION_NOT_SUPPORTED';
  end case;

  v_response := jsonb_build_object(
    'status','applied', 'event_id',p_event_id,
    'action_code',p_action_code, 'aggregate_type',p_aggregate_type,
    'aggregate_id',p_aggregate_id, 'payload_sha256',v_payload_hash,
    'result',coalesce(v_result,'{}'::jsonb), 'idempotent',false
  );
  update public.ns_sync_receipts
    set status = 'applied', response_json = v_response, applied_at = now()
    where org_id = p_org_id and client_event_id = p_event_id;
  return v_response;
end;
$naxa$;


create or replace function public.ns_create_service(
  p_service_id uuid, p_org_id uuid, p_site_id uuid, p_code text,
  p_activity text, p_name text, p_duration_minutes integer,
  p_price_xaf bigint, p_active boolean, p_category text,
  p_description text, p_provider_member_ids jsonb,
  p_required_workstation_kinds jsonb, p_package_sessions integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_service public.ns_services%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id,p_site_id) then
    raise exception 'NAXA_SERVICE_CREATE_FORBIDDEN';
  end if;
  if p_service_id is null
     or length(trim(coalesce(p_code,''))) not between 1 and 80
     or p_activity not in ('pressing','hair','beauty','treatment','tailoring','perfume','repair','part','manufacturing','vehicle','cleaning','contract','home','printing','event','package','material','service','retail','general')
     or length(trim(coalesce(p_name,''))) not between 2 and 160
     or (p_duration_minutes is not null and p_duration_minutes <= 0)
     or p_price_xaf is null or p_price_xaf < 0
     or p_active is null
     or length(coalesce(p_category,'')) > 80
     or length(coalesce(p_description,'')) > 2000
     or jsonb_typeof(coalesce(p_provider_member_ids,'[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_required_workstation_kinds,'[]'::jsonb)) <> 'array'
     or (p_package_sessions is not null and p_package_sessions not between 1 and 100) then
    raise exception 'NAXA_SERVICE_CREATE_INVALID';
  end if;
  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_provider_member_ids,'[]'::jsonb)) x(member_id)
    where not exists (
      select 1 from public.ns_members m
      join public.ns_member_scopes ms on ms.member_id=m.id and ms.org_id=m.org_id
      where m.id::text=x.member_id and m.org_id=p_org_id and m.status='active'
        and (ms.scope_type='organization' or ms.site_id=p_site_id)
    )
  ) then raise exception 'NAXA_SERVICE_PROVIDER_SCOPE_INVALID'; end if;
  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_required_workstation_kinds,'[]'::jsonb)) x(kind)
    where not exists (
      select 1 from public.ns_workstations w
      where w.org_id=p_org_id and w.site_id=p_site_id and w.kind=x.kind and w.status='active'
    )
  ) then raise exception 'NAXA_SERVICE_WORKSTATION_KIND_INVALID'; end if;

  insert into public.ns_services(
    id,org_id,site_id,code,activity,name,duration_minutes,price_xaf,active,
    category,description,provider_member_ids,required_workstation_kinds,package_sessions,revision
  ) values (
    p_service_id,p_org_id,p_site_id,trim(p_code),p_activity,trim(p_name),
    p_duration_minutes,p_price_xaf,p_active,trim(coalesce(p_category,'')),
    coalesce(p_description,''),coalesce(p_provider_member_ids,'[]'::jsonb),
    coalesce(p_required_workstation_kinds,'[]'::jsonb),
    p_package_sessions,1
  ) returning * into v_service;
  return jsonb_build_object('service_id',v_service.id,'revision',v_service.revision,'created',true);
end;
$naxa$;

create or replace function public.ns_update_service(
  p_service_id uuid, p_org_id uuid, p_site_id uuid, p_code text,
  p_activity text, p_name text, p_duration_minutes integer,
  p_price_xaf bigint, p_active boolean, p_expected_version integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_service public.ns_services%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id,p_site_id) then
    raise exception 'NAXA_SERVICE_UPDATE_FORBIDDEN';
  end if;
  select * into v_service from public.ns_services
   where id=p_service_id and org_id=p_org_id and site_id=p_site_id
   for update;
  if not found then raise exception 'NAXA_SERVICE_NOT_FOUND'; end if;
  if p_expected_version is null or p_expected_version <> v_service.revision then
    raise exception 'NAXA_SERVICE_VERSION_CONFLICT';
  end if;
  if length(trim(coalesce(p_code,''))) not between 1 and 80
     or p_activity not in ('pressing','hair','retail')
     or length(trim(coalesce(p_name,''))) not between 2 and 160
     or (p_duration_minutes is not null and p_duration_minutes <= 0)
     or p_price_xaf is null or p_price_xaf < 0 or p_active is null then
    raise exception 'NAXA_SERVICE_UPDATE_INVALID';
  end if;
  update public.ns_services
    set code=trim(p_code),activity=p_activity,name=trim(p_name),
        duration_minutes=p_duration_minutes,price_xaf=p_price_xaf,
        active=p_active,revision=revision+1
    where id=p_service_id and org_id=p_org_id and site_id=p_site_id
    returning * into v_service;
  return jsonb_build_object('service_id',v_service.id,'revision',v_service.revision,'updated',true);
end;
$naxa$;

create or replace function public.ns_update_service_configuration(
  p_service_id uuid, p_org_id uuid, p_site_id uuid, p_category text,
  p_description text, p_provider_member_ids jsonb,
  p_required_workstation_kinds jsonb, p_package_sessions integer,
  p_expected_version integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_service public.ns_services%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_manage_site(p_org_id,p_site_id) then
    raise exception 'NAXA_SERVICE_CONFIGURATION_FORBIDDEN';
  end if;
  select * into v_service from public.ns_services
   where id=p_service_id and org_id=p_org_id and site_id=p_site_id
   for update;
  if not found then raise exception 'NAXA_SERVICE_NOT_FOUND'; end if;
  if p_expected_version is null or p_expected_version <> v_service.revision then
    raise exception 'NAXA_SERVICE_VERSION_CONFLICT';
  end if;
  if length(coalesce(p_category,'')) > 80 or length(coalesce(p_description,'')) > 2000
     or jsonb_typeof(coalesce(p_provider_member_ids,'[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_required_workstation_kinds,'[]'::jsonb)) <> 'array'
     or (p_package_sessions is not null and p_package_sessions not between 1 and 100) then
    raise exception 'NAXA_SERVICE_CONFIGURATION_INVALID';
  end if;
  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_provider_member_ids,'[]'::jsonb)) x(member_id)
    where not exists (
      select 1 from public.ns_members m
      join public.ns_member_scopes ms on ms.member_id=m.id and ms.org_id=m.org_id
      where m.id::text=x.member_id and m.org_id=p_org_id and m.status='active'
        and (ms.scope_type='organization' or ms.site_id=p_site_id)
    )
  ) then raise exception 'NAXA_SERVICE_PROVIDER_SCOPE_INVALID'; end if;
  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_required_workstation_kinds,'[]'::jsonb)) x(kind)
    where not exists (
      select 1 from public.ns_workstations w
      where w.org_id=p_org_id and w.site_id=p_site_id and w.kind=x.kind and w.status='active'
    )
  ) then raise exception 'NAXA_SERVICE_WORKSTATION_KIND_INVALID'; end if;
  update public.ns_services
    set category=coalesce(p_category,''),description=coalesce(p_description,''),
        provider_member_ids=coalesce(p_provider_member_ids,'[]'::jsonb),
        required_workstation_kinds=coalesce(p_required_workstation_kinds,'[]'::jsonb),
        package_sessions=p_package_sessions,
        revision=revision+1
    where id=p_service_id and org_id=p_org_id and site_id=p_site_id
    returning * into v_service;
  return jsonb_build_object('service_id',v_service.id,'revision',v_service.revision,'updated',true);
end;
$naxa$;

create or replace function public.ns_create_customer(
  p_customer_id uuid, p_org_id uuid, p_site_id uuid, p_display_name text,
  p_phone_contact text, p_contact_consent boolean, p_address_line text,
  p_neighborhood text, p_landmark text, p_latitude numeric,
  p_longitude numeric, p_location_consent_at timestamptz,
  p_notes_private text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_customer public.ns_customers%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_CUSTOMER_CREATE_FORBIDDEN';
  end if;
  if p_customer_id is null
     or length(trim(coalesce(p_display_name,''))) not between 2 and 160
     or length(coalesce(p_phone_contact,'')) > 32
     or p_contact_consent is null
     or length(coalesce(p_address_line,'')) > 240
     or length(coalesce(p_neighborhood,'')) > 120
     or length(coalesce(p_landmark,'')) > 160
     or length(coalesce(p_notes_private,'')) > 2000 then
    raise exception 'NAXA_CUSTOMER_CREATE_INVALID';
  end if;
  if (p_latitude is not null or p_longitude is not null) and p_location_consent_at is null then
    raise exception 'NAXA_CUSTOMER_LOCATION_CONSENT_REQUIRED';
  end if;
  if (p_latitude is null) <> (p_longitude is null)
     or (p_latitude is not null and (p_latitude not between -90 and 90 or p_longitude not between -180 and 180)) then
    raise exception 'NAXA_CUSTOMER_LOCATION_INVALID';
  end if;
  if coalesce(p_notes_private,'') <> '' and not public.ns_can_manage_site(p_org_id,p_site_id) then
    raise exception 'NAXA_CUSTOMER_PRIVATE_NOTES_FORBIDDEN';
  end if;
  insert into public.ns_customers(
    id,org_id,site_id,display_name,phone_contact,contact_consent,
    address_line,neighborhood,landmark,latitude,longitude,location_consent_at,
    notes_private,revision,updated_at
  ) values (
    p_customer_id,p_org_id,p_site_id,trim(p_display_name),trim(coalesce(p_phone_contact,'')),
    p_contact_consent,trim(coalesce(p_address_line,'')),trim(coalesce(p_neighborhood,'')),
    trim(coalesce(p_landmark,'')),p_latitude,p_longitude,p_location_consent_at,
    case when public.ns_can_manage_site(p_org_id,p_site_id) then coalesce(p_notes_private,'') else '' end,
    1,now()
  ) returning * into v_customer;
  return jsonb_build_object('customer_id',v_customer.id,'revision',v_customer.revision,'created',true);
end;
$naxa$;

create or replace function public.ns_create_customer_followup(
  p_followup_id uuid, p_org_id uuid, p_site_id uuid, p_customer_id uuid,
  p_title text, p_frequency text, p_channel text, p_notes text,
  p_next_due_at timestamptz, p_status text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_followup public.ns_customer_followups%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_FORBIDDEN';
  end if;
  if p_followup_id is null or p_customer_id is null
     or length(trim(coalesce(p_title,''))) not between 1 and 160
     or length(trim(coalesce(p_frequency,''))) not between 1 and 40
     or length(trim(coalesce(p_channel,''))) not between 1 and 32
     or length(coalesce(p_notes,'')) > 2000
     or p_next_due_at is null or coalesce(p_status,'active') <> 'active' then
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_INVALID';
  end if;
  if not exists (
    select 1 from public.ns_customers c
    where c.id=p_customer_id and c.org_id=p_org_id and c.site_id=p_site_id
  ) then raise exception 'NAXA_CUSTOMER_FOLLOWUP_CUSTOMER_NOT_FOUND'; end if;
  insert into public.ns_customer_followups(
    id,org_id,site_id,customer_id,title,frequency,channel,notes,
    next_due_at,status,created_by
  ) values (
    p_followup_id,p_org_id,p_site_id,p_customer_id,trim(p_title),trim(p_frequency),
    trim(p_channel),coalesce(p_notes,''),p_next_due_at,'active',v_member
  ) returning * into v_followup;
  return jsonb_build_object('followup_id',v_followup.id,'revision',v_followup.revision,'status',v_followup.status);
end;
$naxa$;

create or replace function public.ns_complete_customer_followup(
  p_followup_id uuid, p_org_id uuid, p_site_id uuid, p_event_id uuid,
  p_completed_at timestamptz, p_next_due_at timestamptz, p_completion_note text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_followup public.ns_customer_followups%rowtype;
  v_existing public.ns_customer_followup_events%rowtype;
  v_next timestamptz;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_FORBIDDEN';
  end if;
  if p_followup_id is null or p_event_id is null or p_completed_at is null
     or length(coalesce(p_completion_note,'')) > 1000 then
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_COMPLETION_INVALID';
  end if;
  select * into v_existing from public.ns_customer_followup_events
   where org_id=p_org_id and idempotency_key=p_event_id;
  if found then
    if v_existing.followup_id=p_followup_id and v_existing.site_id=p_site_id then
      return jsonb_build_object('followup_id',p_followup_id,'idempotent',true);
    end if;
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_IDEMPOTENCY_CONFLICT';
  end if;
  select * into v_followup from public.ns_customer_followups
   where id=p_followup_id and org_id=p_org_id and site_id=p_site_id
   for update;
  if not found or v_followup.status <> 'active' then
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_NOT_ACTIVE';
  end if;
  v_next := p_next_due_at;
  if v_next is not null and v_next <= p_completed_at then
    raise exception 'NAXA_CUSTOMER_FOLLOWUP_NEXT_DATE_INVALID';
  end if;
  insert into public.ns_customer_followup_events(
    id,org_id,site_id,followup_id,event_type,occurred_at,next_due_at,
    completion_note,actor_member_id,idempotency_key
  ) values (
    p_event_id,p_org_id,p_site_id,p_followup_id,'completed',p_completed_at,
    v_next,coalesce(p_completion_note,''),v_member,p_event_id
  );
  update public.ns_customer_followups
   set status=case when v_next is null then 'completed' else 'active' end,
       next_due_at=coalesce(v_next,next_due_at),revision=revision+1,
       updated_at=now(),last_completed_at=p_completed_at
   where id=p_followup_id and org_id=p_org_id and site_id=p_site_id
   returning * into v_followup;
  return jsonb_build_object('followup_id',v_followup.id,'status',v_followup.status,
    'revision',v_followup.revision,'idempotent',false);
end;
$naxa$;

create or replace function public.ns_create_support_request(
  p_request_id uuid, p_org_id uuid, p_site_id uuid, p_subject text,
  p_description text, p_priority text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_request public.ns_support_requests%rowtype;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null then raise exception 'NAXA_SUPPORT_REQUEST_FORBIDDEN'; end if;
  if p_site_id is null then
    if not public.ns_is_org_member(p_org_id) then raise exception 'NAXA_SUPPORT_REQUEST_FORBIDDEN'; end if;
  elsif not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_SUPPORT_REQUEST_FORBIDDEN';
  end if;
  if p_request_id is null
     or length(trim(coalesce(p_subject,''))) not between 3 and 180
     or length(trim(coalesce(p_description,''))) not between 3 and 5000
     or p_priority not in ('low','normal','high','urgent') then
    raise exception 'NAXA_SUPPORT_REQUEST_INVALID';
  end if;
  insert into public.ns_support_requests(
    id,org_id,site_id,subject,description,priority,created_by
  ) values (
    p_request_id,p_org_id,p_site_id,trim(p_subject),trim(p_description),p_priority,v_member
  ) returning * into v_request;
  return jsonb_build_object('request_id',v_request.id,'status',v_request.status,'created',true);
end;
$naxa$;

revoke all on function public.ns_create_service(uuid,uuid,uuid,text,text,text,integer,bigint,boolean,text,text,jsonb,jsonb,integer) from public, anon;
grant execute on function public.ns_create_service(uuid,uuid,uuid,text,text,text,integer,bigint,boolean,text,text,jsonb,jsonb,integer) to authenticated, service_role;
revoke all on function public.ns_update_service(uuid,uuid,uuid,text,text,text,integer,bigint,boolean,integer) from public, anon;
grant execute on function public.ns_update_service(uuid,uuid,uuid,text,text,text,integer,bigint,boolean,integer) to authenticated, service_role;
revoke all on function public.ns_update_service_configuration(uuid,uuid,uuid,text,text,jsonb,jsonb,integer,integer) from public, anon;
grant execute on function public.ns_update_service_configuration(uuid,uuid,uuid,text,text,jsonb,jsonb,integer,integer) to authenticated, service_role;
revoke all on function public.ns_create_customer(uuid,uuid,uuid,text,text,boolean,text,text,text,numeric,numeric,timestamptz,text) from public, anon;
grant execute on function public.ns_create_customer(uuid,uuid,uuid,text,text,boolean,text,text,text,numeric,numeric,timestamptz,text) to authenticated, service_role;
revoke all on function public.ns_create_customer_followup(uuid,uuid,uuid,uuid,text,text,text,text,timestamptz,text) from public, anon;
grant execute on function public.ns_create_customer_followup(uuid,uuid,uuid,uuid,text,text,text,text,timestamptz,text) to authenticated, service_role;
revoke all on function public.ns_complete_customer_followup(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text) from public, anon;
grant execute on function public.ns_complete_customer_followup(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text) to authenticated, service_role;
revoke all on function public.ns_create_support_request(uuid,uuid,uuid,text,text,text) from public, anon;
grant execute on function public.ns_create_support_request(uuid,uuid,uuid,text,text,text) to authenticated, service_role;

revoke all on function public.ns_upsert_recurring_charge(uuid,uuid,uuid,text,text,bigint,text,timestamptz,integer,boolean) from public, anon;
grant execute on function public.ns_upsert_recurring_charge(uuid,uuid,uuid,text,text,bigint,text,timestamptz,integer,boolean) to authenticated, service_role;
revoke all on function public.ns_deactivate_recurring_charge(uuid,uuid,uuid) from public, anon;
grant execute on function public.ns_deactivate_recurring_charge(uuid,uuid,uuid) to authenticated, service_role;
revoke all on function public.ns_upsert_loyalty_program(uuid,uuid,text,text,text,text,text,bigint,bigint,text,integer,boolean) from public, anon;
grant execute on function public.ns_upsert_loyalty_program(uuid,uuid,text,text,text,text,text,bigint,bigint,text,integer,boolean) to authenticated, service_role;
revoke all on function public.ns_apply_sync_event(uuid,uuid,uuid,uuid,uuid,bigint,text,text,text,jsonb) from public, anon;
grant execute on function public.ns_apply_sync_event(uuid,uuid,uuid,uuid,uuid,bigint,text,text,text,jsonb) to authenticated, service_role;


revoke all on function public.ns_save_supplier(uuid,uuid,uuid,text,text,text,text,text,integer,text) from public, anon;
grant execute on function public.ns_save_supplier(uuid,uuid,uuid,text,text,text,text,text,integer,text) to authenticated, service_role;
revoke all on function public.ns_create_supplier_purchase(uuid,uuid,uuid,text,text,uuid,text,jsonb,bigint,bigint,bigint,bigint,timestamptz,text) from public, anon;
grant execute on function public.ns_create_supplier_purchase(uuid,uuid,uuid,text,text,uuid,text,jsonb,bigint,bigint,bigint,bigint,timestamptz,text) to authenticated, service_role;
revoke all on function public.ns_post_accounting_entry(uuid,uuid,text,uuid,text,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.ns_post_accounting_entry(uuid,uuid,text,uuid,text,text,text,bigint,text) to service_role;
revoke all on function public.ns_receive_supplier_purchase_line(uuid,uuid,uuid,uuid,numeric,uuid,text) from public, anon;
grant execute on function public.ns_receive_supplier_purchase_line(uuid,uuid,uuid,uuid,numeric,uuid,text) to authenticated, service_role;
revoke all on function public.ns_record_supplier_payment(uuid,uuid,uuid,bigint,text,uuid,text,uuid,text) from public, anon;
grant execute on function public.ns_record_supplier_payment(uuid,uuid,uuid,bigint,text,uuid,text,uuid,text) to authenticated, service_role;
revoke all on function public.ns_create_performance_objective(uuid,uuid,text,date,date,bigint,text) from public, anon;
grant execute on function public.ns_create_performance_objective(uuid,uuid,text,date,date,bigint,text) to authenticated, service_role;

rollback;
