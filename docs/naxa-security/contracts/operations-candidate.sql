-- SECURITY operational candidate: append-only manual incident reports, no physical commands.
begin;
alter table public.sec_incidents add column reporter_id uuid references auth.users(id);
alter table public.sec_incidents add column request_id uuid unique;
alter table public.sec_incidents add constraint sec_report_subject_length check(length(trim(subject)) between 1 and 500);
grant insert(organization_id,site_id,subject,priority,state,reporter_id,request_id) on public.sec_incidents to authenticated;
create policy sec_manual_report on public.sec_incidents for insert to authenticated with check (
 reporter_id=(select auth.uid()) and request_id is not null and state='new' and device_id is null
 and priority in ('P2','P3','P4')
 and exists(select 1 from public.sec_sites s where s.id=sec_incidents.site_id and s.organization_id=sec_incidents.organization_id)
 and exists(select 1 from public.sec_memberships m where m.organization_id=sec_incidents.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager','operator') and m.active)
);
create table public.sec_work_orders(id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,subject text not null check(length(trim(subject)) between 1 and 500),kind text not null check(kind in ('preventive','corrective','inspection')),state text not null default 'requested' check(state in ('requested','assigned','in_progress','completed','cancelled')),reporter_id uuid not null references auth.users(id),request_id uuid not null unique,created_at timestamptz not null default now(),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id));
alter table public.sec_work_orders enable row level security;
revoke all on public.sec_work_orders from public,anon,authenticated;
grant select on public.sec_work_orders to authenticated;
grant insert(organization_id,site_id,subject,kind,reporter_id,request_id) on public.sec_work_orders to authenticated;
create policy sec_work_read on public.sec_work_orders for select to authenticated using(exists(select 1 from public.sec_sites s where s.id=sec_work_orders.site_id and s.organization_id=sec_work_orders.organization_id));
create policy sec_work_insert on public.sec_work_orders for insert to authenticated with check(state='requested' and reporter_id=(select auth.uid()) and exists(select 1 from public.sec_sites s where s.id=sec_work_orders.site_id and s.organization_id=sec_work_orders.organization_id) and exists(select 1 from public.sec_memberships m where m.organization_id=sec_work_orders.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager','operator') and m.active));
commit;
