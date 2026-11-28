-- Disposable PostgreSQL fixture only: real GoTrue session shape and existing Famille admin registry subset.
create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
create table auth.users(id uuid primary key);
create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id),aal text not null,not_after timestamptz);
create schema famille_core;
create table famille_core.family_admins(user_id uuid primary key references auth.users(id),status text not null,revoked_at timestamptz);
