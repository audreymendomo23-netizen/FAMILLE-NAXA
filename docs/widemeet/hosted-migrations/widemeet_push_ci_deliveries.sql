begin;
create table public.wm_push_ci_deliveries(
 campaign_sha text not null check(campaign_sha ~ '^[a-f0-9]{40}$'),
 kind text not null check(kind in ('web-foreground','web-background','android')),
 jti_hash text not null unique check(jti_hash ~ '^[a-f0-9]{64}$'),
 notification_id uuid not null unique,
 provider_status text not null check(provider_status in ('claimed','accepted','rejected','uncertain')),
 created_at timestamptz not null default clock_timestamp(),finished_at timestamptz,
 primary key(campaign_sha,kind)
);
alter table public.wm_push_ci_deliveries enable row level security;
revoke all on public.wm_push_ci_deliveries from public,anon,authenticated;
grant select,insert,update on public.wm_push_ci_deliveries to service_role;
commit;
