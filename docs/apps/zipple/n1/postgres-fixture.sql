-- N1 integration fixture, isolated PostgreSQL only, never hosted migration.
create schema zipple_n1;
create table zipple_n1.members(id text primary key, app_id text not null, org_id text not null, identifier text unique not null, password_hash text not null, role text not null, active boolean not null);
create table zipple_n1.sites(id text primary key, app_id text not null, org_id text not null, name text not null, active boolean not null);
create table zipple_n1.scopes(member_id text references zipple_n1.members(id), site_id text references zipple_n1.sites(id), primary key(member_id,site_id));
create table zipple_n1.sessions(access_hash text primary key, refresh_hash text unique, member_id text references zipple_n1.members(id), expires_at bigint not null, revoked boolean default false not null);
create table zipple_n1.receipts(app_id text not null, org_id text not null, member_id text not null, site_id text not null, event_id text not null, digest text not null, primary key(app_id,org_id,member_id,site_id,event_id));
alter table zipple_n1.members enable row level security;
alter table zipple_n1.sites enable row level security;
alter table zipple_n1.scopes enable row level security;
alter table zipple_n1.sessions enable row level security;
alter table zipple_n1.receipts enable row level security;
-- Only the ephemeral server role (database owner) may access these tables.
revoke all on schema zipple_n1 from public;
revoke all on all tables in schema zipple_n1 from public;
