-- NAXA SERVICES v3: operations, loyalty, idempotent payments and sync receipts.
-- DRAFT ONLY. Depends on v1 + v2 candidate schemas and their ns_* scope helpers.
-- Review and apply only on an isolated NAXA SERVICES Supabase project.
begin;

alter table public.ns_inventory_items
  add column if not exists supplier_whatsapp text not null default '';
alter table public.ns_inventory_items
  drop constraint if exists ns_inventory_items_supplier_whatsapp_check;
alter table public.ns_inventory_items
  add constraint ns_inventory_items_supplier_whatsapp_check
  check (supplier_whatsapp = '' or supplier_whatsapp ~ '^[0-9]{9,15}$');

create table if not exists public.ns_recurring_charges (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  name text not null,
  category text not null check (category in ('rent','electricity','water','internet','tax','insurance','payroll','maintenance','other')),
  description text not null default '',
  amount_xaf bigint not null check (amount_xaf > 0),
  recurrence text not null check (recurrence in ('monthly','quarterly','annual','one_time')),
  next_due_at timestamptz not null,
  reminder_days integer not null default 3 check (reminder_days between 0 and 30),
  active boolean not null default true,
  created_by uuid not null,
  updated_by uuid not null,
  last_reminder_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (updated_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (id, site_id, org_id)
);
create index if not exists ns_recurring_charges_due_idx
  on public.ns_recurring_charges(org_id, site_id, next_due_at) where active;

create table if not exists public.ns_charge_payments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  charge_id uuid not null,
  reference_due_at timestamptz not null,
  amount_xaf bigint not null check (amount_xaf > 0),
  payment_method text not null default 'manual' check (payment_method in ('manual','bank','cash','mobile_money','other')),
  payment_reference text,
  idempotency_key uuid not null,
  paid_by uuid not null,
  paid_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (charge_id, site_id, org_id) references public.ns_recurring_charges(id, site_id, org_id) on delete restrict,
  foreign key (paid_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (org_id, idempotency_key)
);
create index if not exists ns_charge_payments_cycle_idx
  on public.ns_charge_payments(org_id, charge_id, reference_due_at, paid_at);

create table if not exists public.ns_loyalty_programs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  activity_profile text not null check (activity_profile in (
    'pressing','coiffure','couture','beaute','parfumerie','reparation','menuiserie',
    'garage','nettoyage','domicile','impression','photo_evenementiel','autre'
  )),
  program_code text not null check (program_code in ('points','visits','spend','frequency')),
  name text not null check (length(trim(name)) between 2 and 80),
  description text not null default '',
  metric_code text not null check (metric_code in ('points','visits','spend')),
  unit_amount_xaf bigint not null check (unit_amount_xaf > 0),
  target_value bigint not null check (target_value > 0),
  reward_description text not null check (length(trim(reward_description)) between 2 and 240),
  window_days integer not null default 0 check (window_days between 0 and 365),
  active boolean not null default true,
  created_by uuid not null,
  updated_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (created_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (updated_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  unique (org_id, activity_profile, program_code),
  unique (id, org_id)
);

create table if not exists public.ns_loyalty_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid not null,
  program_id uuid not null,
  customer_id uuid not null,
  event_type text not null check (event_type in ('activity','reward_earned')),
  amount_xaf bigint not null default 0 check (amount_xaf >= 0),
  metric_delta bigint not null default 0 check (metric_delta >= 0),
  wave_number integer check (wave_number is null or wave_number > 0),
  related_event_id uuid references public.ns_loyalty_events(id) on delete restrict,
  reward_status text check (reward_status is null or reward_status in ('available','redeemed','expired','cancelled')),
  description text not null default '',
  idempotency_key uuid,
  actor_member_id uuid not null,
  created_at timestamptz not null default now(),
  redeemed_at timestamptz,
  redeemed_by uuid,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (program_id, org_id) references public.ns_loyalty_programs(id, org_id) on delete restrict,
  foreign key (customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  foreign key (actor_member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (redeemed_by, org_id) references public.ns_members(id, org_id) on delete restrict,
  check (
    (event_type = 'activity' and reward_status is null and wave_number is null and related_event_id is null)
    or
    (event_type = 'reward_earned' and reward_status is not null and wave_number is not null and related_event_id is not null)
  )
);
create unique index if not exists ns_loyalty_events_idempotency_idx
  on public.ns_loyalty_events(org_id, idempotency_key) where idempotency_key is not null;
create index if not exists ns_loyalty_events_history_idx
  on public.ns_loyalty_events(org_id, site_id, program_id, customer_id, created_at desc);

-- Server-only receipts keep retries safe across offline devices and API restarts.
create table if not exists public.ns_sync_receipts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  site_id uuid,
  workstation_id uuid,
  device_id uuid not null references public.ns_devices(id) on delete restrict,
  member_id uuid not null,
  client_event_id uuid not null,
  device_sequence bigint not null check (device_sequence > 0),
  aggregate_type text not null,
  aggregate_id text not null,
  action_code text not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  status text not null check (status in ('accepted','applied','conflict','rejected')),
  response_json jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  applied_at timestamptz,
  foreign key (member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (workstation_id, site_id, org_id) references public.ns_workstations(id, site_id, org_id) on delete restrict,
  unique (org_id, client_event_id),
  unique (device_id, device_sequence)
);
create index if not exists ns_sync_receipts_pending_idx
  on public.ns_sync_receipts(org_id, received_at) where status in ('accepted','conflict');

create table if not exists public.ns_sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  receipt_id uuid not null unique references public.ns_sync_receipts(id) on delete restrict,
  aggregate_type text not null,
  aggregate_id text not null,
  server_version bigint,
  client_version bigint,
  server_snapshot jsonb not null default '{}'::jsonb,
  client_snapshot jsonb not null default '{}'::jsonb,
  resolution text check (resolution is null or resolution in ('server_wins','client_wins','merged','manual')),
  resolved_by uuid,
  resolution_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  foreign key (resolved_by, org_id) references public.ns_members(id, org_id) on delete restrict
);

create table if not exists public.ns_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  site_id uuid,
  recipient_member_id uuid,
  recipient_customer_id uuid,
  channel text not null check (channel in ('push','sms','whatsapp','email','in_app')),
  event_code text not null,
  idempotency_key text not null,
  payload_redacted jsonb not null default '{}'::jsonb,
  scheduled_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','processing','sent','failed','cancelled')),
  attempts integer not null default 0 check (attempts >= 0),
  last_error_code text,
  provider_reference text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (site_id, org_id) references public.ns_sites(id, org_id) on delete restrict,
  foreign key (recipient_member_id, org_id) references public.ns_members(id, org_id) on delete restrict,
  foreign key (recipient_customer_id, site_id, org_id) references public.ns_customers(id, site_id, org_id) on delete restrict,
  unique (org_id, channel, idempotency_key)
);
create index if not exists ns_notification_outbox_due_idx
  on public.ns_notification_outbox(scheduled_at) where status = 'pending';

alter table public.ns_recurring_charges enable row level security;
alter table public.ns_charge_payments enable row level security;
alter table public.ns_loyalty_programs enable row level security;
alter table public.ns_loyalty_events enable row level security;
alter table public.ns_sync_receipts enable row level security;
alter table public.ns_sync_conflicts enable row level security;
alter table public.ns_notification_outbox enable row level security;

drop policy if exists ns_recurring_charges_select on public.ns_recurring_charges;
create policy ns_recurring_charges_select on public.ns_recurring_charges
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));
drop policy if exists ns_recurring_charges_manage on public.ns_recurring_charges;
create policy ns_recurring_charges_manage on public.ns_recurring_charges
  for all to authenticated
  using (public.ns_can_manage_site(org_id, site_id))
  with check (public.ns_can_manage_site(org_id, site_id));

drop policy if exists ns_charge_payments_select on public.ns_charge_payments;
create policy ns_charge_payments_select on public.ns_charge_payments
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));

drop policy if exists ns_loyalty_programs_select on public.ns_loyalty_programs;
create policy ns_loyalty_programs_select on public.ns_loyalty_programs
  for select to authenticated using (public.ns_is_org_member(org_id));
drop policy if exists ns_loyalty_programs_manage on public.ns_loyalty_programs;
create policy ns_loyalty_programs_manage on public.ns_loyalty_programs
  for all to authenticated
  using (public.ns_can_manage_org(org_id))
  with check (public.ns_can_manage_org(org_id));

drop policy if exists ns_loyalty_events_select on public.ns_loyalty_events;
create policy ns_loyalty_events_select on public.ns_loyalty_events
  for select to authenticated using (public.ns_can_access_site(org_id, site_id));

-- The online sync gateway and scheduler use service_role only.
revoke all on public.ns_sync_receipts, public.ns_sync_conflicts, public.ns_notification_outbox from public, anon, authenticated;
grant all on public.ns_sync_receipts, public.ns_sync_conflicts, public.ns_notification_outbox to service_role;

revoke all on public.ns_recurring_charges, public.ns_charge_payments, public.ns_loyalty_programs, public.ns_loyalty_events from anon;
grant select, insert, update, delete on public.ns_recurring_charges, public.ns_charge_payments, public.ns_loyalty_programs, public.ns_loyalty_events to authenticated;
grant all on public.ns_recurring_charges, public.ns_charge_payments, public.ns_loyalty_programs, public.ns_loyalty_events to service_role;
revoke insert, update, delete on public.ns_charge_payments, public.ns_loyalty_events from authenticated;

create or replace function public.ns_record_charge_payment(
  p_org_id uuid, p_site_id uuid, p_charge_id uuid, p_amount_xaf bigint, p_idempotency_key uuid,
  p_payment_method text default 'manual', p_payment_reference text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_charge public.ns_recurring_charges%rowtype;
  v_payment_id uuid;
  v_paid_before bigint;
  v_paid_after bigint;
  v_now timestamptz := now();
  v_next_due timestamptz;
begin
  if p_org_id is null or p_site_id is null or p_charge_id is null or p_idempotency_key is null
     or p_amount_xaf is null or p_amount_xaf <= 0
     or p_payment_method not in ('manual','bank','cash','mobile_money','other') then
    raise exception 'NAXA_CHARGE_PAYMENT_INVALID';
  end if;
  if public.ns_current_member_id(p_org_id) is null
     or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_CHARGE_PAYMENT_FORBIDDEN';
  end if;
  select * into v_charge
  from public.ns_recurring_charges
  where id = p_charge_id and org_id = p_org_id and site_id = p_site_id and active
  for update;
  if not found then raise exception 'NAXA_CHARGE_NOT_FOUND'; end if;

  select id into v_payment_id from public.ns_charge_payments
    where org_id = p_org_id and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('idempotent', true, 'payment_id', v_payment_id);
  end if;

  select coalesce(sum(amount_xaf), 0)::bigint into v_paid_before
  from public.ns_charge_payments
  where org_id = p_org_id and charge_id = p_charge_id and reference_due_at = v_charge.next_due_at;
  if p_amount_xaf > v_charge.amount_xaf - v_paid_before then
    raise exception 'NAXA_CHARGE_PAYMENT_EXCEEDS_BALANCE';
  end if;

  insert into public.ns_charge_payments(
    org_id, site_id, charge_id, reference_due_at, amount_xaf,
    payment_method, payment_reference, idempotency_key, paid_by
  ) values (
    p_org_id, p_site_id, p_charge_id, v_charge.next_due_at, p_amount_xaf,
    p_payment_method, nullif(trim(p_payment_reference), ''), p_idempotency_key,
    public.ns_current_member_id(p_org_id)
  ) returning id into v_payment_id;

  v_paid_after := v_paid_before + p_amount_xaf;
  if v_paid_after >= v_charge.amount_xaf then
    if v_charge.recurrence = 'one_time' then
      update public.ns_recurring_charges set active = false, updated_by = public.ns_current_member_id(p_org_id), updated_at = v_now
      where id = v_charge.id;
    else
      v_next_due := case v_charge.recurrence
        when 'monthly' then v_charge.next_due_at + interval '1 month'
        when 'quarterly' then v_charge.next_due_at + interval '3 months'
        when 'annual' then v_charge.next_due_at + interval '1 year'
      end;
      update public.ns_recurring_charges
        set next_due_at = v_next_due, updated_by = public.ns_current_member_id(p_org_id),
            updated_at = v_now, last_reminder_at = null
      where id = v_charge.id;
    end if;
  end if;
  return jsonb_build_object('idempotent', false, 'payment_id', v_payment_id, 'remaining_xaf', greatest(0, v_charge.amount_xaf - v_paid_after));
end;
$naxa$;

create or replace function public.ns_record_loyalty_activity(
  p_org_id uuid, p_site_id uuid, p_program_id uuid, p_customer_id uuid,
  p_amount_xaf bigint, p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_program public.ns_loyalty_programs%rowtype;
  v_activity_id uuid;
  v_existing_id uuid;
  v_delta bigint;
  v_previous bigint;
  v_total bigint;
  v_old_wave bigint;
  v_new_wave bigint;
  v_wave bigint;
  v_since timestamptz;
  v_rewards integer := 0;
  v_member uuid;
begin
  if p_org_id is null or p_site_id is null or p_program_id is null or p_customer_id is null
     or p_idempotency_key is null or p_amount_xaf is null or p_amount_xaf < 0 then
    raise exception 'NAXA_LOYALTY_ACTIVITY_INVALID';
  end if;
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_LOYALTY_ACTIVITY_FORBIDDEN';
  end if;
  select id into v_existing_id from public.ns_loyalty_events
    where org_id = p_org_id and idempotency_key = p_idempotency_key;
  if found then return jsonb_build_object('idempotent', true, 'activity_id', v_existing_id); end if;

  select * into v_program
  from public.ns_loyalty_programs
  where id = p_program_id and org_id = p_org_id and active
  for update;
  if not found then raise exception 'NAXA_LOYALTY_PROGRAM_NOT_FOUND'; end if;
  if not exists (
    select 1 from public.ns_customers
    where id = p_customer_id and org_id = p_org_id and site_id = p_site_id
  ) then raise exception 'NAXA_LOYALTY_CUSTOMER_OUT_OF_SCOPE'; end if;

  v_delta := case v_program.metric_code
    when 'points' then floor(p_amount_xaf::numeric / v_program.unit_amount_xaf)::bigint
    when 'visits' then 1
    when 'spend' then p_amount_xaf
  end;
  if v_delta is null or v_delta <= 0 then raise exception 'NAXA_LOYALTY_ACTIVITY_BELOW_MINIMUM'; end if;
  v_since := case when v_program.window_days > 0
    then now() - make_interval(days => v_program.window_days)
    else '-infinity'::timestamptz end;

  insert into public.ns_loyalty_events(
    org_id, site_id, program_id, customer_id, event_type, amount_xaf, metric_delta,
    description, idempotency_key, actor_member_id
  ) values (
    p_org_id, p_site_id, p_program_id, p_customer_id, 'activity', p_amount_xaf, v_delta,
    case when v_program.metric_code = 'visits' then 'Visite validée' else 'Achat validé' end,
    p_idempotency_key, v_member
  ) returning id into v_activity_id;

  select coalesce(sum(metric_delta), 0)::bigint into v_total
  from public.ns_loyalty_events
  where org_id = p_org_id and program_id = p_program_id and customer_id = p_customer_id
    and event_type = 'activity' and created_at >= v_since;
  v_previous := greatest(0, v_total - v_delta);
  v_old_wave := floor(v_previous::numeric / v_program.target_value)::bigint;
  v_new_wave := floor(v_total::numeric / v_program.target_value)::bigint;
  if v_new_wave > v_old_wave then
    for v_wave in (v_old_wave + 1)..v_new_wave loop
      insert into public.ns_loyalty_events(
        org_id, site_id, program_id, customer_id, event_type, metric_delta, wave_number,
        related_event_id, reward_status, description, actor_member_id
      ) values (
        p_org_id, p_site_id, p_program_id, p_customer_id, 'reward_earned', 0, v_wave::integer,
        v_activity_id, 'available', v_program.reward_description, v_member
      );
      v_rewards := v_rewards + 1;
    end loop;
  end if;
  return jsonb_build_object('idempotent', false, 'activity_id', v_activity_id, 'metric_delta', v_delta, 'rewards_earned', v_rewards);
end;
$naxa$;

create or replace function public.ns_redeem_loyalty_reward(
  p_org_id uuid, p_site_id uuid, p_event_id uuid
) returns boolean
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid;
  v_rows integer;
begin
  v_member := public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id, p_site_id) then
    raise exception 'NAXA_LOYALTY_REWARD_FORBIDDEN';
  end if;
  update public.ns_loyalty_events
  set reward_status = 'redeemed', redeemed_at = now(), redeemed_by = v_member
  where id = p_event_id and org_id = p_org_id and site_id = p_site_id
    and event_type = 'reward_earned' and reward_status = 'available';
  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$naxa$;

revoke all on function public.ns_record_charge_payment(uuid,uuid,uuid,bigint,uuid,text,text) from public, anon;
grant execute on function public.ns_record_charge_payment(uuid,uuid,uuid,bigint,uuid,text,text) to authenticated, service_role;
revoke all on function public.ns_record_loyalty_activity(uuid,uuid,uuid,uuid,bigint,uuid) from public, anon;
grant execute on function public.ns_record_loyalty_activity(uuid,uuid,uuid,uuid,bigint,uuid) to authenticated, service_role;
revoke all on function public.ns_redeem_loyalty_reward(uuid,uuid,uuid) from public, anon;
grant execute on function public.ns_redeem_loyalty_reward(uuid,uuid,uuid) to authenticated, service_role;

rollback;
