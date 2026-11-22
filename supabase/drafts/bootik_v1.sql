-- BOOTIK V1.1 — retailer-first domain schema and distributor-link contract.
-- DRAFT ONLY. Not applied to Replay or Production.
-- Prerequisite: separately reviewed Famille Core schema + Auth app_id claim.
--
-- Anti-collision invariants:
--   * BOOTIK-only business data lives in schema bootik, object prefix bk_*.
--   * Every domain object is tied to the Famille application registration code 'bootik'.
--   * No public.* table, ns_* table/function, NAXA Pharmacy table/role, or NAXA
--     independent service is created, altered, or called.
--   * No client grants/policies are defined here. RLS is enabled and forced.
--   * This file is a migration candidate for isolated review only.
begin;

create schema if not exists bootik;
comment on schema bootik is
  'BOOTIK application domain only; not exposed to clients before reviewed server APIs and RLS.';
revoke all on schema bootik from public, anon, authenticated;

create table if not exists bootik.bk_app_registration (
  app_code text primary key check (app_code = 'bootik'),
  app_id uuid not null unique references famille_core.applications(id) on delete restrict,
  registered_at timestamptz not null default now()
);
insert into bootik.bk_app_registration(app_code, app_id)
select 'bootik', id
from famille_core.applications
where code = 'bootik'
on conflict (app_code) do nothing;

create table if not exists bootik.bk_activities (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  universe_code text not null check (universe_code in ('retailer','distributor')),
  profile_code text not null,
  display_name text not null,
  status text not null default 'draft'
    check (status in ('draft','active','suspended','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, app_id)
    references famille_core.organization_apps(organization_id, app_id) on delete restrict,
  unique (id, organization_id, app_id),
  check (
    (universe_code = 'retailer' and profile_code in (
      'boutique','superette','poissonnerie','boulangerie','shopping','alimentation',
      'cave','quincaillerie','parfumerie','boucherie','ferme','depot_gaz',
      'supermarche','brocante'
    ))
    or
    (universe_code = 'distributor' and profile_code in (
      'boissons_brasseries','gaz_energie','alimentaire_fmcg','frais_surgeles',
      'hygiene_entretien','beaute_soins','importateur_marques','agro_intrants'
    ))
  )
);

create table if not exists bootik.bk_activity_locations (
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  location_id uuid not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (activity_id, location_id),
  unique (activity_id, location_id, organization_id, app_id),
  foreign key (activity_id, organization_id, app_id)
    references bootik.bk_activities(id, organization_id, app_id) on delete restrict,
  foreign key (location_id, organization_id)
    references famille_core.locations(id, organization_id) on delete restrict
);

create table if not exists bootik.bk_profile_compatibility_rules (
  id uuid primary key default gen_random_uuid(),
  retailer_profile_code text not null check (retailer_profile_code in (
    'boutique','superette','poissonnerie','boulangerie','shopping','alimentation',
    'cave','quincaillerie','parfumerie','boucherie','ferme','depot_gaz',
    'supermarche','brocante'
  )),
  distributor_profile_code text not null check (distributor_profile_code in (
    'boissons_brasseries','gaz_energie','alimentaire_fmcg','frais_surgeles',
    'hygiene_entretien','beaute_soins','importateur_marques','agro_intrants'
  )),
  product_family_code text not null,
  requires_manual_qualification boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (retailer_profile_code, distributor_profile_code, product_family_code)
);

insert into bootik.bk_profile_compatibility_rules
(retailer_profile_code, distributor_profile_code, product_family_code, requires_manual_qualification)
values
 ('cave','boissons_brasseries','beverages',false),
 ('boutique','boissons_brasseries','beverages',false),
 ('superette','boissons_brasseries','beverages',false),
 ('alimentation','boissons_brasseries','beverages',false),
 ('supermarche','boissons_brasseries','beverages',false),
 ('boutique','alimentaire_fmcg','dry_food',false),
 ('superette','alimentaire_fmcg','dry_food',false),
 ('alimentation','alimentaire_fmcg','dry_food',false),
 ('supermarche','alimentaire_fmcg','dry_food',false),
 ('boulangerie','alimentaire_fmcg','bakery_ingredients',true),
 ('depot_gaz','gaz_energie','gas_cylinders',false),
 ('poissonnerie','frais_surgeles','seafood',false),
 ('boucherie','frais_surgeles','meat_and_poultry',false),
 ('boutique','frais_surgeles','fresh_food',false),
 ('superette','frais_surgeles','fresh_food',false),
 ('supermarche','frais_surgeles','fresh_food',false),
 ('boutique','hygiene_entretien','hygiene_cleaning',false),
 ('superette','hygiene_entretien','hygiene_cleaning',false),
 ('alimentation','hygiene_entretien','hygiene_cleaning',false),
 ('supermarche','hygiene_entretien','hygiene_cleaning',false),
 ('shopping','beaute_soins','beauty_personal_care',false),
 ('parfumerie','beaute_soins','beauty_personal_care',false),
 ('boutique','beaute_soins','beauty_personal_care',false),
 ('supermarche','beaute_soins','beauty_personal_care',false),
 ('shopping','importateur_marques','fashion_bags_jewellery',true),
 ('parfumerie','importateur_marques','branded_beauty',true),
 ('quincaillerie','importateur_marques','hardware_goods',true),
 ('ferme','agro_intrants','agricultural_inputs',false)
on conflict (retailer_profile_code, distributor_profile_code, product_family_code) do nothing;

create table if not exists bootik.bk_catalog_items (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  sku text not null,
  barcode text,
  display_name text not null,
  category_code text,
  brand text,
  base_unit_code text not null,
  is_serialized boolean not null default false,
  attributes jsonb not null default '{}'::jsonb,
  status text not null default 'active'
    check (status in ('active','inactive','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (activity_id, organization_id, app_id)
    references bootik.bk_activities(id, organization_id, app_id) on delete restrict,
  unique (id, organization_id, activity_id, app_id),
  unique (activity_id, sku)
);
create unique index if not exists bk_catalog_items_barcode_uq
  on bootik.bk_catalog_items(activity_id, barcode)
  where barcode is not null and barcode <> '';

create table if not exists bootik.bk_item_units (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  item_id uuid not null,
  unit_code text not null,
  unit_role text not null check (unit_role in ('base','purchase','storage','sale')),
  to_base_factor numeric(20,6) not null check (to_base_factor > 0),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (item_id, organization_id, activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict,
  unique (item_id, unit_code),
  unique (id, item_id, organization_id, activity_id, app_id)
);

create table if not exists bootik.bk_storage_locations (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  location_id uuid not null,
  parent_id uuid,
  location_code text not null,
  location_type text not null check (location_type in (
    'zone','department','aisle','shelf','rack','level','bin','counter',
    'cold_room','display_case','production_area','gas_cylinder_row','other'
  )),
  label text not null,
  created_at timestamptz not null default now(),
  foreign key (activity_id, location_id, organization_id, app_id)
    references bootik.bk_activity_locations(activity_id, location_id, organization_id, app_id) on delete restrict,
  foreign key (parent_id, organization_id, activity_id, location_id, app_id)
    references bootik.bk_storage_locations(id, organization_id, activity_id, location_id, app_id) on delete restrict,
  unique (id, organization_id, activity_id, location_id, app_id),
  unique (location_id, location_code)
);

create table if not exists bootik.bk_product_lots (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  item_id uuid not null,
  lot_code text not null,
  manufacture_date date,
  expires_at date,
  origin_label text,
  quality_state text not null default 'available'
    check (quality_state in ('available','quarantine','expired','recalled','damaged','destroyed')),
  created_at timestamptz not null default now(),
  foreign key (item_id, organization_id, activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict,
  unique (id, item_id, activity_id, organization_id, app_id),
  unique (item_id, lot_code),
  check (expires_at is null or manufacture_date is null or expires_at >= manufacture_date)
);

create table if not exists bootik.bk_inventory_balances (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  location_id uuid not null,
  item_id uuid not null,
  lot_id uuid,
  storage_location_id uuid,
  quantity_on_hand numeric(20,6) not null default 0 check (quantity_on_hand >= 0),
  quantity_reserved numeric(20,6) not null default 0 check (quantity_reserved >= 0),
  quantity_damaged numeric(20,6) not null default 0 check (quantity_damaged >= 0),
  updated_at timestamptz not null default now(),
  foreign key (activity_id, location_id, organization_id, app_id)
    references bootik.bk_activity_locations(activity_id, location_id, organization_id, app_id) on delete restrict,
  foreign key (item_id, organization_id, activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict,
  foreign key (lot_id, item_id, activity_id, organization_id, app_id)
    references bootik.bk_product_lots(id, item_id, activity_id, organization_id, app_id) on delete restrict,
  foreign key (storage_location_id, organization_id, activity_id, location_id, app_id)
    references bootik.bk_storage_locations(id, organization_id, activity_id, location_id, app_id) on delete restrict,
  check (quantity_reserved <= quantity_on_hand)
);
create unique index if not exists bk_inventory_balances_without_lot_uq
  on bootik.bk_inventory_balances(
    organization_id, activity_id, location_id, item_id,
    coalesce(storage_location_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where lot_id is null;
create unique index if not exists bk_inventory_balances_with_lot_uq
  on bootik.bk_inventory_balances(
    organization_id, activity_id, location_id, item_id, lot_id,
    coalesce(storage_location_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where lot_id is not null;

create table if not exists bootik.bk_inventory_movements (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  location_id uuid not null,
  item_id uuid not null,
  lot_id uuid,
  movement_code text not null check (movement_code in (
    'opening','purchase_receipt','sale','sale_return','transfer_out','transfer_in',
    'production_consumption','production_output','loss','damage','write_off',
    'inventory_adjustment','customer_return','supplier_return','reservation','release'
  )),
  quantity_delta numeric(20,6) not null check (quantity_delta <> 0),
  unit_code text not null,
  source_reference text,
  idempotency_key text not null,
  actor_user_id uuid references auth.users(id) on delete restrict,
  reason text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (activity_id, location_id, organization_id, app_id)
    references bootik.bk_activity_locations(activity_id, location_id, organization_id, app_id) on delete restrict,
  foreign key (item_id, organization_id, activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict,
  foreign key (lot_id, item_id, activity_id, organization_id, app_id)
    references bootik.bk_product_lots(id, item_id, activity_id, organization_id, app_id) on delete restrict,
  foreign key (item_id, unit_code)
    references bootik.bk_item_units(item_id, unit_code) on delete restrict,
  unique (organization_id, idempotency_key)
);
comment on table bootik.bk_inventory_movements is
  'Append-only movement ledger. Future write APIs must reject rewrite/delete and use compensating movements.';

create table if not exists bootik.bk_customers (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  customer_ref text,
  display_name text not null,
  phone text,
  email text,
  consent_state text not null default 'unknown'
    check (consent_state in ('unknown','granted','withdrawn')),
  attributes jsonb not null default '{}'::jsonb,
  status text not null default 'active'
    check (status in ('active','inactive','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (activity_id, organization_id, app_id)
    references bootik.bk_activities(id, organization_id, app_id) on delete restrict,
  unique (id, organization_id, activity_id, app_id),
  unique (activity_id, customer_ref)
);

create table if not exists bootik.bk_suppliers (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  supplier_ref text,
  display_name text not null,
  contact_name text,
  phone text,
  whatsapp_phone text,
  email text,
  payment_terms jsonb not null default '{}'::jsonb,
  status text not null default 'active'
    check (status in ('active','inactive','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (activity_id, organization_id, app_id)
    references bootik.bk_activities(id, organization_id, app_id) on delete restrict,
  unique (id, organization_id, activity_id, app_id),
  unique (activity_id, supplier_ref)
);

create table if not exists bootik.bk_trade_links (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  buyer_organization_id uuid not null,
  buyer_activity_id uuid not null,
  seller_organization_id uuid not null,
  seller_activity_id uuid not null,
  compatibility_rule_id uuid not null
    references bootik.bk_profile_compatibility_rules(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending','active','suspended','refused','closed')),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  closed_at timestamptz,
  foreign key (buyer_organization_id, app_id)
    references famille_core.organization_apps(organization_id, app_id) on delete restrict,
  foreign key (seller_organization_id, app_id)
    references famille_core.organization_apps(organization_id, app_id) on delete restrict,
  foreign key (buyer_activity_id, buyer_organization_id, app_id)
    references bootik.bk_activities(id, organization_id, app_id) on delete restrict,
  foreign key (seller_activity_id, seller_organization_id, app_id)
    references bootik.bk_activities(id, organization_id, app_id) on delete restrict,
  unique (buyer_activity_id, seller_activity_id),
  unique (id, buyer_organization_id, buyer_activity_id, seller_organization_id, seller_activity_id, app_id),
  check (buyer_organization_id <> seller_organization_id),
  check ((status = 'active' and activated_at is not null) or status <> 'active'),
  check ((status = 'closed' and closed_at is not null) or status <> 'closed')
);

create or replace function bootik.bk_assert_trade_activity_roles()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, bootik
as $$
declare
  v_buyer_universe text;
  v_seller_universe text;
  v_buyer_profile text;
  v_seller_profile text;
  v_rule_buyer text;
  v_rule_seller text;
begin
  select universe_code, profile_code
    into v_buyer_universe, v_buyer_profile
  from bootik.bk_activities
  where id = new.buyer_activity_id
    and organization_id = new.buyer_organization_id
    and app_id = new.app_id;

  select universe_code, profile_code
    into v_seller_universe, v_seller_profile
  from bootik.bk_activities
  where id = new.seller_activity_id
    and organization_id = new.seller_organization_id
    and app_id = new.app_id;

  select retailer_profile_code, distributor_profile_code
    into v_rule_buyer, v_rule_seller
  from bootik.bk_profile_compatibility_rules
  where id = new.compatibility_rule_id
    and active;

  if v_buyer_universe is distinct from 'retailer'
     or v_seller_universe is distinct from 'distributor'
     or v_buyer_profile is distinct from v_rule_buyer
     or v_seller_profile is distinct from v_rule_seller then
    raise exception 'bootik_trade_profiles_not_compatible'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists bk_trade_links_validate_profiles on bootik.bk_trade_links;
create trigger bk_trade_links_validate_profiles
before insert or update of buyer_activity_id, seller_activity_id,
  buyer_organization_id, seller_organization_id, app_id, compatibility_rule_id
on bootik.bk_trade_links
for each row execute function bootik.bk_assert_trade_activity_roles();

create table if not exists bootik.bk_trade_catalog_exposure (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  trade_link_id uuid not null,
  buyer_organization_id uuid not null,
  buyer_activity_id uuid not null,
  seller_organization_id uuid not null,
  seller_activity_id uuid not null,
  seller_item_id uuid not null,
  buyer_visible_name text,
  agreed_unit_price_fcfa bigint check (agreed_unit_price_fcfa is null or agreed_unit_price_fcfa >= 0),
  currency_code text not null default 'XAF' check (currency_code = 'XAF'),
  status text not null default 'hidden' check (status in ('hidden','visible','suspended')),
  published_at timestamptz,
  updated_at timestamptz not null default now(),
  foreign key (trade_link_id, buyer_organization_id, buyer_activity_id,
    seller_organization_id, seller_activity_id, app_id)
    references bootik.bk_trade_links(id, buyer_organization_id, buyer_activity_id,
      seller_organization_id, seller_activity_id, app_id) on delete restrict,
  foreign key (seller_item_id, seller_organization_id, seller_activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict,
  unique (trade_link_id, seller_item_id),
  unique (id, trade_link_id, seller_organization_id, seller_activity_id, app_id)
);

create table if not exists bootik.bk_reorder_policies (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  organization_id uuid not null,
  activity_id uuid not null,
  location_id uuid not null,
  item_id uuid not null,
  preferred_supplier_id uuid,
  preferred_trade_link_id uuid,
  preferred_distributor_organization_id uuid,
  preferred_distributor_activity_id uuid,
  minimum_quantity numeric(20,6) not null default 0 check (minimum_quantity >= 0),
  safety_quantity numeric(20,6) not null default 0 check (safety_quantity >= 0),
  target_quantity numeric(20,6) not null check (target_quantity > 0),
  auto_submit_enabled boolean not null default false,
  max_order_quantity numeric(20,6) check (max_order_quantity is null or max_order_quantity > 0),
  max_order_amount_fcfa bigint check (max_order_amount_fcfa is null or max_order_amount_fcfa > 0),
  updated_at timestamptz not null default now(),
  foreign key (activity_id, location_id, organization_id, app_id)
    references bootik.bk_activity_locations(activity_id, location_id, organization_id, app_id) on delete restrict,
  foreign key (item_id, organization_id, activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict,
  foreign key (preferred_supplier_id, organization_id, activity_id, app_id)
    references bootik.bk_suppliers(id, organization_id, activity_id, app_id) on delete restrict,
  foreign key (preferred_trade_link_id, organization_id, activity_id,
    preferred_distributor_organization_id, preferred_distributor_activity_id, app_id)
    references bootik.bk_trade_links(id, buyer_organization_id, buyer_activity_id,
      seller_organization_id, seller_activity_id, app_id) on delete restrict,
  check ((preferred_supplier_id is null) or (preferred_trade_link_id is null)),
  check (
    (preferred_trade_link_id is null and preferred_distributor_organization_id is null
      and preferred_distributor_activity_id is null)
    or
    (preferred_trade_link_id is not null and preferred_distributor_organization_id is not null
      and preferred_distributor_activity_id is not null)
  ),
  unique (id, app_id),
  unique (location_id, item_id)
);

create table if not exists bootik.bk_reorder_events (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  policy_id uuid not null,
  trigger_key text not null,
  trigger_code text not null check (trigger_code in ('low_stock','predicted_stockout','target_replenishment')),
  stock_available numeric(20,6) not null,
  suggested_quantity numeric(20,6) not null check (suggested_quantity > 0),
  state text not null default 'draft'
    check (state in ('draft','queued_offline','submitted','waiting_supplier_approval','ordered','dismissed','failed')),
  created_at timestamptz not null default now(),
  foreign key (policy_id, app_id)
    references bootik.bk_reorder_policies(id, app_id) on delete restrict,
  unique (id, app_id),
  unique (policy_id, trigger_key)
);

create table if not exists bootik.bk_trade_orders (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  trade_link_id uuid not null,
  buyer_organization_id uuid not null,
  buyer_activity_id uuid not null,
  seller_organization_id uuid not null,
  seller_activity_id uuid not null,
  reorder_event_id uuid,
  idempotency_key text not null,
  submit_mode text not null default 'manual'
    check (submit_mode in ('manual','auto_pending_supplier_approval')),
  status text not null default 'draft'
    check (status in (
      'draft','queued_offline','submitted','waiting_supplier_approval',
      'supplier_accepted','supplier_rejected','waiting_buyer_confirmation',
      'confirmed','preparing','partially_shipped','shipped','partially_delivered',
      'delivered','invoiced','partially_paid','paid','disputed',
      'return_requested','returned','cancelled'
    )),
  terms_changed_by_supplier boolean not null default false,
  supplier_approved_by uuid references auth.users(id) on delete restrict,
  supplier_approved_at timestamptz,
  buyer_confirmed_by uuid references auth.users(id) on delete restrict,
  buyer_confirmed_at timestamptz,
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (trade_link_id, buyer_organization_id, buyer_activity_id,
    seller_organization_id, seller_activity_id, app_id)
    references bootik.bk_trade_links(id, buyer_organization_id, buyer_activity_id,
      seller_organization_id, seller_activity_id, app_id) on delete restrict,
  foreign key (reorder_event_id, app_id)
    references bootik.bk_reorder_events(id, app_id) on delete restrict,
  unique (id, app_id, trade_link_id, buyer_organization_id, buyer_activity_id,
    seller_organization_id, seller_activity_id),
  unique (trade_link_id, idempotency_key),
  check (
    status not in ('supplier_accepted','waiting_buyer_confirmation','confirmed',
      'preparing','partially_shipped','shipped','partially_delivered','delivered',
      'invoiced','partially_paid','paid')
    or (supplier_approved_by is not null and supplier_approved_at is not null)
  ),
  check (
    not terms_changed_by_supplier
    or status not in ('confirmed','preparing','partially_shipped','shipped',
      'partially_delivered','delivered','invoiced','partially_paid','paid')
    or (buyer_confirmed_by is not null and buyer_confirmed_at is not null)
  )
);

create table if not exists bootik.bk_trade_order_lines (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references bootik.bk_app_registration(app_id) on delete restrict,
  trade_order_id uuid not null,
  trade_link_id uuid not null,
  buyer_organization_id uuid not null,
  buyer_activity_id uuid not null,
  seller_organization_id uuid not null,
  seller_activity_id uuid not null,
  seller_item_id uuid not null,
  requested_quantity numeric(20,6) not null check (requested_quantity > 0),
  accepted_quantity numeric(20,6) check (accepted_quantity is null or accepted_quantity >= 0),
  unit_code text not null,
  proposed_unit_price_fcfa bigint not null check (proposed_unit_price_fcfa >= 0),
  approved_unit_price_fcfa bigint check (approved_unit_price_fcfa is null or approved_unit_price_fcfa >= 0),
  change_note text,
  created_at timestamptz not null default now(),
  foreign key (trade_order_id, app_id, trade_link_id, buyer_organization_id,
    buyer_activity_id, seller_organization_id, seller_activity_id)
    references bootik.bk_trade_orders(id, app_id, trade_link_id, buyer_organization_id,
      buyer_activity_id, seller_organization_id, seller_activity_id) on delete restrict,
  foreign key (seller_item_id, seller_organization_id, seller_activity_id, app_id)
    references bootik.bk_catalog_items(id, organization_id, activity_id, app_id) on delete restrict
);

-- No policies, schema grants, or table grants are provided. A subsequent server
-- contract must implement role-aware RPC/Edge Functions and test isolation.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename
    from pg_tables
    where schemaname = 'bootik'
  loop
    execute format('alter table %I.%I enable row level security', r.schemaname, r.tablename);
    execute format('alter table %I.%I force row level security', r.schemaname, r.tablename);
    execute format('revoke all on table %I.%I from public, anon, authenticated', r.schemaname, r.tablename);
  end loop;
end $$;

revoke all on all sequences in schema bootik from public, anon, authenticated;
revoke all on all functions in schema bootik from public, anon, authenticated;
commit;
