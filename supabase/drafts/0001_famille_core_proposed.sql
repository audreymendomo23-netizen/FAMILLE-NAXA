-- DRAFT ONLY: Famille NAXA shared schema proposal.
-- NOT APPLIED. Do not execute before review of schema exposure, grants and RLS policies.
-- PostgreSQL 17 / Supabase.

begin;
create schema if not exists famille_core;
comment on schema famille_core is 'Famille NAXA shared core; keep unexposed until grants and RLS are reviewed.';

create table if not exists famille_core.applications (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check (code in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad')),
 display_name text not null,
 status text not null default 'planned' check (status in ('planned','active','paused','retired')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
insert into famille_core.applications(code,display_name) values
 ('kiosko','Kiosko'),('bootik','Bootik'),('zipple','Zipple'),('naxa_services','NAXA Services'),('cotiz','CotiZ'),
 ('loyable','Loyable'),('naxa_hotel','NAXA Hotel'),('campus237','Campus237'),('naxa_security','NAXA Security'),('grillad','GrillaD')
on conflict (code) do nothing;

create table if not exists famille_core.identities (
 user_id uuid primary key references auth.users(id) on delete restrict,
 display_name text, phone_e164 text,
 locale text not null default 'fr' check(locale in ('fr','en')),
 status text not null default 'active' check(status in ('active','suspended','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table if not exists famille_core.organizations (
 id uuid primary key default gen_random_uuid(), legal_name text not null, organization_type text not null,
 country_code char(2) not null default 'CM',
 status text not null default 'pending' check(status in ('pending','active','suspended','closed')),
 created_by uuid references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table if not exists famille_core.organization_apps (
 organization_id uuid not null references famille_core.organizations(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 status text not null default 'pending' check(status in ('pending','active','suspended','closed')),
 activated_at timestamptz, created_at timestamptz not null default now(),
 primary key(organization_id,app_id)
);
create table if not exists famille_core.locations (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references famille_core.organizations(id) on delete restrict,
 code text, name text not null, address text, city text,
 latitude numeric(9,6), longitude numeric(9,6),
 timezone text not null default 'Africa/Douala',
 status text not null default 'active' check(status in ('active','inactive','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
 unique(organization_id,code)
);
create table if not exists famille_core.memberships (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete restrict,
 organization_id uuid not null references famille_core.organizations(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 status text not null default 'invited' check(status in ('invited','active','suspended','revoked')),
 invited_by uuid references auth.users(id) on delete restrict,
 joined_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(user_id,organization_id,app_id)
);
create table if not exists famille_core.role_catalog (
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 role_code text not null, display_name text not null,
 scope_type text not null check(scope_type in ('platform','organization','location','self')),
 is_system boolean not null default true, created_at timestamptz not null default now(),
 primary key(app_id,role_code)
);
create table if not exists famille_core.role_assignments (
 id uuid primary key default gen_random_uuid(),
 membership_id uuid not null references famille_core.memberships(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 role_code text not null, location_id uuid references famille_core.locations(id) on delete restrict,
 status text not null default 'active' check(status in ('active','suspended','revoked','expired')),
 granted_by uuid references auth.users(id) on delete restrict, granted_at timestamptz not null default now(),
 starts_at timestamptz not null default now(), expires_at timestamptz,
 revoked_by uuid references auth.users(id) on delete restrict, revoked_at timestamptz,
 foreign key(app_id,role_code) references famille_core.role_catalog(app_id,role_code),
 check(expires_at is null or expires_at > starts_at)
);
create table if not exists famille_core.client_app_access (
 user_id uuid not null references auth.users(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 status text not null default 'granted' check(status in ('pending','granted','suspended','revoked')),
 granted_by uuid references auth.users(id) on delete restrict, granted_at timestamptz not null default now(),
 revoked_at timestamptz, primary key(user_id,app_id)
);
create table if not exists famille_core.devices (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 device_public_id text not null, platform text not null check(platform in ('android','web')),
 device_label text, public_key_fingerprint text,
 status text not null default 'active' check(status in ('active','revoked','lost')),
 last_seen_at timestamptz, created_at timestamptz not null default now(), revoked_at timestamptz,
 unique(user_id,device_public_id)
);
create table if not exists famille_core.app_installations (
 id uuid primary key default gen_random_uuid(), device_id uuid not null references famille_core.devices(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 installation_id text not null, app_version text not null, push_token text, signing_certificate_sha256 text,
 status text not null default 'active' check(status in ('active','outdated','revoked')),
 installed_at timestamptz not null default now(), last_seen_at timestamptz,
 unique(device_id,app_id,installation_id)
);
create table if not exists famille_core.plans (
 id uuid primary key default gen_random_uuid(), app_id uuid not null references famille_core.applications(id) on delete restrict,
 code text not null, name text not null, amount_fcfa bigint not null check(amount_fcfa>=0),
 billing_period text not null check(billing_period in ('monthly','quarterly','yearly','one_time')),
 status text not null default 'active' check(status in ('active','inactive')),
 created_at timestamptz not null default now(), unique(app_id,code)
);
create table if not exists famille_core.subscriptions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references famille_core.organizations(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 plan_id uuid not null references famille_core.plans(id) on delete restrict,
 status text not null default 'pending' check(status in ('pending','active','past_due','suspended','cancelled','expired')),
 starts_at timestamptz, ends_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists famille_core.payment_intents (
 id uuid primary key default gen_random_uuid(),
 subscription_id uuid not null references famille_core.subscriptions(id) on delete restrict,
 expected_amount_fcfa bigint not null check(expected_amount_fcfa>0),
 currency text not null default 'FCFA' check(currency='FCFA'),
 channel text not null,
 status text not null default 'pending' check(status in ('pending','submitted','matched','rejected','expired','cancelled')),
 created_at timestamptz not null default now(), expires_at timestamptz
);
create table if not exists famille_core.payment_matches (
 id uuid primary key default gen_random_uuid(),
 payment_intent_id uuid not null references famille_core.payment_intents(id) on delete restrict,
 provider text not null, transaction_reference text not null,
 amount_fcfa bigint not null check(amount_fcfa>0), occurred_at timestamptz,
 verified_by uuid references auth.users(id) on delete restrict, verified_at timestamptz,
 status text not null default 'pending' check(status in ('pending','confirmed','rejected')),
 created_at timestamptz not null default now(), unique(provider,transaction_reference)
);
create table if not exists famille_core.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 event_code text not null, title_key text not null, body_key text not null,
 payload jsonb not null default '{}'::jsonb, read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists famille_core.notification_preferences (
 user_id uuid not null references auth.users(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 channel text not null check(channel in ('in_app','push','email')),
 enabled boolean not null default true, updated_at timestamptz not null default now(),
 primary key(user_id,app_id,channel)
);
create table if not exists famille_core.audit_events (
 id bigint generated always as identity primary key,
 app_id uuid references famille_core.applications(id) on delete restrict,
 organization_id uuid references famille_core.organizations(id) on delete restrict,
 location_id uuid references famille_core.locations(id) on delete restrict,
 actor_id uuid references auth.users(id) on delete restrict,
 action_code text not null, entity_type text not null, entity_id text, correlation_id uuid,
 metadata jsonb not null default '{}'::jsonb, occurred_at timestamptz not null default now()
);
create table if not exists famille_core.app_versions (
 id uuid primary key default gen_random_uuid(), app_id uuid not null references famille_core.applications(id) on delete restrict,
 platform text not null check(platform in ('android','web')), version text not null, minimum_supported_version text,
 release_channel text not null default 'stable' check(release_channel in ('stable','beta','internal')),
 released_at timestamptz, unique(app_id,platform,version,release_channel)
);
create table if not exists famille_core.payment_parser_rules (
 id uuid primary key default gen_random_uuid(), app_id uuid not null references famille_core.applications(id) on delete restrict,
 provider text not null, version integer not null check(version>0), rules jsonb not null,
 status text not null default 'draft' check(status in ('draft','active','retired')),
 created_at timestamptz not null default now(), unique(app_id,provider,version)
);
comment on table famille_core.payment_parser_rules is 'Parser metadata only; never store raw SMS, PIN or OTP content.';
create table if not exists famille_core.support_tickets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 app_id uuid not null references famille_core.applications(id) on delete restrict,
 organization_id uuid references famille_core.organizations(id) on delete restrict,
 subject text not null, description text not null,
 status text not null default 'open' check(status in ('open','in_progress','waiting_user','resolved','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table if not exists famille_core.sync_receipts (
 id uuid primary key default gen_random_uuid(), app_id uuid not null references famille_core.applications(id) on delete restrict,
 device_id uuid not null references famille_core.devices(id) on delete restrict,
 operation_id uuid not null, aggregate_type text not null, aggregate_id text not null,
 result_code text not null, server_version bigint, received_at timestamptz not null default now(),
 unique(app_id,device_id,operation_id)
);

create index if not exists idx_famille_memberships_user_app on famille_core.memberships(user_id,app_id,status);
create index if not exists idx_famille_memberships_org_app on famille_core.memberships(organization_id,app_id,status);
create index if not exists idx_famille_locations_org on famille_core.locations(organization_id,status);
create index if not exists idx_famille_roles_membership_status on famille_core.role_assignments(membership_id,status);
create index if not exists idx_famille_installations_app_status on famille_core.app_installations(app_id,status);
create index if not exists idx_famille_subscriptions_org_app on famille_core.subscriptions(organization_id,app_id,status);
create index if not exists idx_famille_audit_scope_time on famille_core.audit_events(app_id,organization_id,occurred_at desc);
create index if not exists idx_famille_notifications_user_app_time on famille_core.notifications(user_id,app_id,created_at desc);
create index if not exists idx_famille_sync_receipts_device_time on famille_core.sync_receipts(device_id,received_at desc);

-- Default-deny: RLS enabled; no grants and no policies in this draft.
do $$
declare r record;
begin
 for r in select tablename from pg_tables where schemaname='famille_core'
 loop execute format('alter table famille_core.%I enable row level security',r.tablename);
 end loop;
end $$;
commit;
