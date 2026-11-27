-- Isolated candidate; no production migration. Client evidence is never a confirmed attendance.
begin;
create table public.sec_attendance_drafts (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null, site_id uuid not null,
 reporter_id uuid not null references auth.users(id), request_id uuid not null unique,
 action text not null check(action in ('arrival','departure')),
 lat double precision not null check(lat between -90 and 90),
 lon double precision not null check(lon between -180 and 180),
 accuracy_m double precision not null check(accuracy_m>0 and accuracy_m<=100),
 observed_at timestamptz not null,
 source text not null default 'android' check(source in ('android','browser')),
 mock_reported boolean,
 constraint sec_attendance_source_check check ((source='android' and mock_reported is false) or (source='browser' and mock_reported is null)),
 created_at timestamptz not null default now(),
 state text not null default 'pending_review' check(state='pending_review'),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_attendance_drafts enable row level security;
revoke all on public.sec_attendance_drafts from public,anon,authenticated;
grant select on public.sec_attendance_drafts to authenticated;
grant insert(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported,source) on public.sec_attendance_drafts to authenticated;
create policy sec_attendance_read on public.sec_attendance_drafts for select to authenticated using (
 reporter_id=(select auth.uid()) and exists(select 1 from public.sec_sites s where s.id=sec_attendance_drafts.site_id and s.organization_id=sec_attendance_drafts.organization_id)
);
create policy sec_attendance_insert on public.sec_attendance_drafts for insert to authenticated with check (
 reporter_id=(select auth.uid()) and state='pending_review' and observed_at between now()-interval '120 seconds' and now()
 and exists(select 1 from public.sec_sites s where s.id=sec_attendance_drafts.site_id and s.organization_id=sec_attendance_drafts.organization_id)
 and exists(select 1 from public.sec_memberships m where m.organization_id=sec_attendance_drafts.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager','operator') and m.active)
);
commit;
