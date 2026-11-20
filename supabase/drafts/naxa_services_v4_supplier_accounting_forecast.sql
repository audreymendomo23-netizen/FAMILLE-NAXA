-- NAXA SERVICES v4 — supplier purchasing, accounting ledger, COGS and objectives.
-- DRAFT ONLY: depends on v1 + v2 + v3 candidate drafts. Review/apply only to a dedicated
-- NAXA SERVICES staging project after schema diff, RLS review, provider and rollback plan.
begin;

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
  unique (site_id, reference)
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
  inventory_item_id uuid not null references public.ns_inventory_items(id) on delete restrict,
  description text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price_xaf bigint not null check (unit_price_xaf >= 0),
  discount_xaf bigint not null default 0 check (discount_xaf >= 0),
  unit_cost_at_sale_xaf bigint,
  cost_of_goods_xaf bigint,
  cogs_posted_at timestamptz,
  idempotency_key uuid not null,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  unique (org_id, idempotency_key),
  check ((cogs_posted_at is null and unit_cost_at_sale_xaf is null and cost_of_goods_xaf is null)
      or (cogs_posted_at is not null and unit_cost_at_sale_xaf is not null and cost_of_goods_xaf is not null))
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
create policy ns_purchase_documents_manage on public.ns_purchase_documents
  for all to authenticated using (public.ns_can_manage_site(org_id, site_id))
  with check (public.ns_can_manage_site(org_id, site_id));

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
create policy ns_performance_objectives_insert on public.ns_performance_objectives
  for insert to authenticated with check (
    created_by = public.ns_current_member_id(org_id) and public.ns_can_manage_site(org_id, site_id)
  );

revoke all on public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_accounting_entries from anon, authenticated;
grant select on public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_accounting_entries to authenticated;
grant all on public.ns_suppliers, public.ns_purchase_documents, public.ns_purchase_lines,
  public.ns_purchase_receipts, public.ns_supplier_payments, public.ns_sale_lines,
  public.ns_accounting_entries, public.ns_performance_objectives to service_role;

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
  if p_amount_xaf is null or p_amount_xaf <= 0 or p_debit_account = p_credit_account
     or length(trim(p_source_type)) = 0 or length(trim(p_event_code)) = 0 then
    raise exception 'NAXA_ACCOUNTING_ENTRY_INVALID';
  end if;
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
  select s.id, s.org_id, s.site_id, s.created_at, s.total_xaf, s.cost_of_goods_xaf
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
  sum(s.total_xaf - coalesce(s.cost_of_goods_xaf,0))::bigint as gross_profit_xaf,
  count(*)::integer as confirmed_sales_count
from settled_sales s
group by s.org_id, s.site_id, (s.created_at at time zone 'Africa/Douala')::date;

create or replace view public.ns_performance_monthly
with (security_invoker = true)
as
select org_id, site_id, date_trunc('month', performance_day)::date as performance_month,
       sum(revenue_xaf)::bigint as revenue_xaf, sum(cost_of_goods_xaf)::bigint as cost_of_goods_xaf,
       sum(gross_profit_xaf)::bigint as gross_profit_xaf, sum(confirmed_sales_count)::integer as confirmed_sales_count
from public.ns_performance_daily
group by org_id, site_id, date_trunc('month', performance_day)::date;

create or replace view public.ns_performance_annual
with (security_invoker = true)
as
select org_id, site_id, date_trunc('year', performance_day)::date as performance_year,
       sum(revenue_xaf)::bigint as revenue_xaf, sum(cost_of_goods_xaf)::bigint as cost_of_goods_xaf,
       sum(gross_profit_xaf)::bigint as gross_profit_xaf, sum(confirmed_sales_count)::integer as confirmed_sales_count
from public.ns_performance_daily
group by org_id, site_id, date_trunc('year', performance_day)::date;

revoke all on function public.ns_post_accounting_entry(uuid,uuid,text,uuid,text,text,text,bigint,text) from public, anon;
grant execute on function public.ns_post_accounting_entry(uuid,uuid,text,uuid,text,text,text,bigint,text) to authenticated, service_role;
revoke all on function public.ns_receive_supplier_purchase_line(uuid,uuid,uuid,uuid,numeric,uuid,text) from public, anon;
grant execute on function public.ns_receive_supplier_purchase_line(uuid,uuid,uuid,uuid,numeric,uuid,text) to authenticated, service_role;
revoke all on function public.ns_record_supplier_payment(uuid,uuid,uuid,bigint,text,uuid,text,uuid,text) from public, anon;
grant execute on function public.ns_record_supplier_payment(uuid,uuid,uuid,bigint,text,uuid,text,uuid,text) to authenticated, service_role;
revoke all on function public.ns_create_performance_objective(uuid,uuid,text,date,date,bigint,text) from public, anon;
grant execute on function public.ns_create_performance_objective(uuid,uuid,text,date,date,bigint,text) to authenticated, service_role;

rollback;
