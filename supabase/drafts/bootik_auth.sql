-- Isolated candidate. Runtime role provisioned by infrastructure, never by a client.
begin;
create table bootik.bk_credentials (
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,identifier text not null unique,
 salt_hex text not null check(salt_hex ~ '^[0-9a-f]{32}$'),
 verifier_hex text not null check(verifier_hex ~ '^[0-9a-f]{128}$'),
 primary key(organization_id,app_id,user_id),
 foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
create table bootik.bk_sessions (
 token_hash text primary key check(token_hash ~ '^[0-9a-f]{64}$'), organization_id uuid not null,app_id uuid not null,user_id uuid not null,
 expires_at timestamptz not null,revoked_at timestamptz,
 foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
create table bootik.bk_recovery_requests (
 id uuid primary key default gen_random_uuid(),identifier text not null,created_at timestamptz not null default now()
);
do $$ declare n text;begin foreach n in array array['bk_credentials','bk_sessions','bk_recovery_requests'] loop
 execute format('alter table bootik.%I enable row level security',n);
 execute format('alter table bootik.%I force row level security',n);
 execute format('revoke all on bootik.%I from public,anon,authenticated',n);
 end loop;end $$;
commit;
