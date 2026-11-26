-- Reconcile recorded supplier/deposit settlements without creating a second financial event.
begin;
create table public.zp_treasury_reconciliation(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,
 source_kind text not null check(source_kind in ('supplier_payment','container_finance')),source_id uuid not null,
 cash_id uuid,direction text not null check(direction in ('in','out')),method text not null check(method in ('cash','bank','mtn_momo','orange_money','card')),
 amount_xaf bigint not null check(amount_xaf>0),proof text not null check(length(proof) between 5 and 500),created_at timestamptz not null default now(),
 unique(site_id,source_kind,source_id),unique(member_id,request_id),check((method='cash')=(cash_id is not null)),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(cash_id,org_id,site_id) references public.zp_cash_sessions(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create view public.zp_treasury_source with (security_invoker=true) as
 select org_id,site_id,'supplier_payment'::text as kind,id as source_id,'out'::text as direction,method,amount_xaf,reference,created_at from public.zp_supplier_payments
 union all select org_id,site_id,'container_finance',id,direction,method,amount_xaf,reference,created_at from public.zp_container_finance;
revoke all on public.zp_treasury_source from public,anon,authenticated;
grant select on public.zp_treasury_source to service_role;
create or replace function public.zp_cash_expected(p_cash uuid) returns bigint language sql stable security invoker set search_path=pg_catalog,public as $$
 select c.opening_xaf+coalesce((select sum(amount_xaf) from public.zp_cash_receipts where cash_id=c.id and method='cash'),0)+coalesce((select sum(t.amount_xaf) from public.zp_cash_tenders t join public.zp_cash_receipts r on r.id=t.receipt_id where r.cash_id=c.id and t.method='cash'),0)+coalesce((select sum(p.amount_xaf) from public.zp_credit_payments p where p.cash_id=c.id and p.method='cash'),0)-coalesce((select sum(amount_xaf) from public.zp_cash_outflows where cash_id=c.id and method='cash'),0)+coalesce((select sum(case when direction='in' then amount_xaf else -amount_xaf end) from public.zp_treasury_reconciliation where cash_id=c.id),0) from public.zp_cash_sessions c where c.id=p_cash;
$$;
create function public.zp_treasury_reconcile(p_access text,p_site uuid,p_request uuid,p_kind text,p_source uuid,p_cash uuid,p_proof text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s public.zp_treasury_source;x public.zp_treasury_reconciliation;c public.zp_cash_sessions;i uuid;why text:=trim(coalesce(p_proof,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_treasury_reconciliation where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.source_kind,x.source_id,x.cash_id,x.proof) is distinct from (p_site,p_kind,p_source,p_cash,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 select * into s from public.zp_treasury_source where org_id=m.org_id and site_id=p_site and kind=p_kind and source_id=p_source;if s.source_id is null then raise exception 'DENIED';end if;
 if p_request is null or length(why) not between 5 and 500 or (s.method='cash')<>(p_cash is not null) then raise exception 'INVALID_TREASURY_LINK';end if;
 if exists(select 1 from public.zp_treasury_reconciliation where site_id=p_site and source_kind=p_kind and source_id=p_source) then raise exception 'TREASURY_ALREADY_RECONCILED';end if;
 if p_cash is not null then
 select * into c from public.zp_cash_sessions where id=p_cash and org_id=m.org_id and site_id=p_site for update;if c.id is null then raise exception 'DENIED';end if;
 if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 if s.direction='out' and s.amount_xaf>public.zp_cash_expected(c.id) then raise exception 'INSUFFICIENT_CASH_BALANCE';end if;
 end if;
 insert into public.zp_treasury_reconciliation(org_id,site_id,member_id,request_id,source_kind,source_id,cash_id,direction,method,amount_xaf,proof) values(m.org_id,p_site,m.id,p_request,p_kind,p_source,p_cash,s.direction,s.method,s.amount_xaf,why) returning id into i;return i;end $$;
create function public.zp_treasury_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 return jsonb_build_object('sessions',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'label',coalesce(d.label,'Caisse principale'),'expected_xaf',public.zp_cash_expected(c.id))) from public.zp_cash_sessions c left join public.zp_cash_desks d on d.id=c.desk_id where c.org_id=m.org_id and c.site_id=p_site and c.closed_at is null),'[]'::jsonb),
 'pending',coalesce((select jsonb_agg(to_jsonb(s) order by s.created_at) from (select kind,source_id,direction,method,amount_xaf,reference,created_at from public.zp_treasury_source s where s.org_id=m.org_id and s.site_id=p_site and not exists(select 1 from public.zp_treasury_reconciliation x where x.site_id=s.site_id and x.source_kind=s.kind and x.source_id=s.source_id) order by created_at limit 300)s),'[]'::jsonb),
 'links',coalesce((select jsonb_agg(to_jsonb(s) order by s.created_at desc) from (select x.id,x.source_kind,x.source_id,x.cash_id,x.direction,x.method,x.amount_xaf,x.proof,x.created_at,t.reference from public.zp_treasury_reconciliation x join public.zp_treasury_source t on t.kind=x.source_kind and t.source_id=x.source_id where x.org_id=m.org_id and x.site_id=p_site order by x.created_at desc limit 300)s),'[]'::jsonb));end $$;
alter table public.zp_treasury_reconciliation enable row level security;
revoke all on public.zp_treasury_reconciliation from public,anon,authenticated;
grant select,insert on public.zp_treasury_reconciliation to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_treasury_reconcile','zp_treasury_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
