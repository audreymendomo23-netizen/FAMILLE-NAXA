-- Isolated integration boundary. Only a trusted server can provision receipts and playback grants.
begin;
create table public.sec_media_grants(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,device_id uuid not null,
 user_id uuid not null references auth.users(id),media text not null check(media in ('video','audio')),
 playback_url text not null check(playback_url like 'https://%' and length(playback_url)<=2048),
 created_at timestamptz not null default now(),expires_at timestamptz not null,revoked_at timestamptz,
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 check(expires_at>created_at and expires_at<=created_at+interval '5 minutes')
);
alter table public.sec_media_grants enable row level security;
revoke all on public.sec_media_grants from public,anon,authenticated;
grant select on public.sec_media_grants to authenticated;
create policy sec_media_grant_self on public.sec_media_grants for select to authenticated using(
 user_id=(select auth.uid()) and revoked_at is null and expires_at>now()
 and exists(select 1 from public.sec_sites s where s.id=sec_media_grants.site_id and s.organization_id=sec_media_grants.organization_id)
 and exists(select 1 from public.sec_memberships m where m.organization_id=sec_media_grants.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager','operator') and m.active)
);
-- Read-only reconciliation: exact match of site, channel, reference and amount, never initiates funds movement.
create view public.sec_payment_reconciliation with (security_invoker=true) as
 select q.request_id,q.organization_id,q.site_id,q.reporter_id,
 case when p.id is null then 'unmatched' when p.amount_fcfa=(q.payload->>'amount_fcfa')::bigint then 'matched' else 'amount_mismatch' end as reconciliation_state,
 p.provider_confirmed_at
 from public.sec_module_requests q left join public.sec_payment_receipts p on p.organization_id=q.organization_id and p.site_id=q.site_id and p.channel=q.payload->>'channel' and p.reference=q.payload->>'reference'
 where q.kind='payment';
revoke all on public.sec_payment_reconciliation from public,anon,authenticated;
grant select on public.sec_payment_reconciliation to authenticated;
commit;
