-- Additive candidate: exact central identity registry model from 0004_prompt_0_3_central_admin_identity_audit.sql.
-- Does not provision any user. Review against actual deployed Famille schema before applying.
begin;
create schema if not exists famille_core;
create table if not exists famille_core.family_admins (
 user_id uuid primary key references auth.users(id) on delete restrict,
 status text not null default 'active' check (status in ('active','suspended','revoked')),
 granted_at timestamptz not null default now(),
 granted_by uuid references auth.users(id) on delete restrict,
 revoked_at timestamptz,
 check ((status='active' and revoked_at is null) or status<>'active')
);
create unique index if not exists uq_famille_single_active_central_admin on famille_core.family_admins(status) where status='active';
alter table famille_core.family_admins enable row level security;
revoke all on famille_core.family_admins from public,anon,authenticated;
commit;
