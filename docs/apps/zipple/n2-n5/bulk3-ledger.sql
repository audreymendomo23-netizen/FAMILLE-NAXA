-- ZIPPLE accounting: reuse NAXA exact double-entry model, no default tax/account mapping.
-- Only confirmed source events, human posting, immutable entries, site-scoped closing.
begin;
create table public.zp_ledger_accounts(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,code text not null check(length(code) between 1 and 30),
 label text not null check(length(label) between 2 and 160),section text not null check(length(section) between 2 and 80),
 member_id uuid not null,created_at timestamptz not null default now(),unique(site_id,code),unique(id,org_id,site_id),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_ledger_entries(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,source_kind text not null,source_id uuid not null,
 entry_date date not null,journal_code text not null check(length(journal_code) between 1 and 30),label text not null check(length(label) between 5 and 250),
 debit_account uuid not null,credit_account uuid not null,amount_xaf bigint not null check(amount_xaf>0),member_id uuid not null,request_id uuid not null,
 created_at timestamptz not null default now(),check(debit_account<>credit_account),unique(site_id,source_kind,source_id),unique(member_id,request_id),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),
 foreign key(debit_account,org_id,site_id) references public.zp_ledger_accounts(id,org_id,site_id),
 foreign key(credit_account,org_id,site_id) references public.zp_ledger_accounts(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_ledger_closures(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,through_date date not null,
 member_id uuid not null,reason text not null check(length(reason) between 5 and 250),created_at timestamptz not null default now(),
 unique(site_id,through_date),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id));
create view public.zp_ledger_sources with (security_invoker=true) as
 select org_id,site_id,'sale'::text as kind,id as source_id,(created_at at time zone 'Africa/Douala')::date as entry_date,amount_xaf,'Sale receipt'::text as label from public.zp_cash_receipts
 union all select r.org_id,r.site_id,'sale_cost',r.id,(r.created_at at time zone 'Africa/Douala')::date,sum(c.cost_xaf)::bigint,'Cost of sale' from public.zp_cash_receipts r join public.zp_sale_costs c on c.receipt_id=r.id group by r.id,r.org_id,r.site_id,r.created_at having count(*)=count(c.cost_xaf) and sum(c.cost_xaf)>0
 union all select org_id,site_id,'purchase_receipt',id,(created_at at time zone 'Africa/Douala')::date,cost_xaf,'Purchase receipt' from public.zp_purchase_receipts where cost_xaf>0
 union all select org_id,site_id,'supplier_payment',id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,'Supplier payment' from public.zp_supplier_payments
 union all select org_id,site_id,'expense',id,expense_date,amount_xaf,label from public.zp_expenses
 union all select org_id,site_id,'inventory_loss',id,(created_at at time zone 'Africa/Douala')::date,loss_cost,reason from public.zp_inventory_counts where loss_cost>0
 union all select org_id,site_id,'deposit_'||direction,id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,'Packaging deposit/refund' from public.zp_container_finance;
revoke all on public.zp_ledger_sources from public,anon,authenticated;
grant select on public.zp_ledger_sources to service_role;
create function public.zp_ledger_owner(p_access text,p_site uuid) returns public.zp_members language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;return m;end $$;
create function public.zp_ledger_account_add(p_access text,p_site uuid,p_code text,p_label text,p_section text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_ledger_owner(p_access,p_site);
 insert into public.zp_ledger_accounts(org_id,site_id,code,label,section,member_id) values(m.org_id,p_site,upper(trim(p_code)),trim(p_label),trim(p_section),m.id) returning id into i;return i;end $$;
create function public.zp_ledger_post(p_access text,p_site uuid,p_kind text,p_source uuid,p_request uuid,p_journal text,p_debit uuid,p_credit uuid,p_label text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_ledger_sources;old public.zp_ledger_entries;i uuid;j text:=upper(trim(coalesce(p_journal,'')));lbl text:=trim(coalesce(p_label,''));begin m:=public.zp_ledger_owner(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into old from public.zp_ledger_entries where member_id=m.id and request_id=p_request;
 if old.id is not null then
  if (old.site_id,old.source_kind,old.source_id,old.journal_code,old.debit_account,old.credit_account,old.label) is distinct from (p_site,p_kind,p_source,j,p_debit,p_credit,lbl) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 select * into x from public.zp_ledger_sources where org_id=m.org_id and site_id=p_site and kind=p_kind and source_id=p_source;
 if x.source_id is null then raise exception 'LEDGER_SOURCE_UNAVAILABLE';end if;
 if p_request is null or p_debit is null or p_credit is null or p_debit=p_credit or length(j) not between 1 and 30 or length(lbl) not between 5 and 250 then raise exception 'INVALID_LEDGER_ENTRY';end if;
 if (select count(*) from public.zp_ledger_accounts where org_id=m.org_id and site_id=p_site and id in (p_debit,p_credit))<>2 then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_ledger_entries where site_id=p_site and source_kind=p_kind and source_id=p_source) then raise exception 'LEDGER_SOURCE_ALREADY_POSTED';end if;
 if exists(select 1 from public.zp_ledger_closures where org_id=m.org_id and site_id=p_site and through_date>=x.entry_date) then raise exception 'LEDGER_PERIOD_CLOSED';end if;
 insert into public.zp_ledger_entries(org_id,site_id,source_kind,source_id,entry_date,journal_code,label,debit_account,credit_account,amount_xaf,member_id,request_id)
 values(m.org_id,p_site,p_kind,p_source,x.entry_date,j,lbl,p_debit,p_credit,x.amount_xaf,m.id,p_request) returning id into i;return i;end $$;
create function public.zp_ledger_close(p_access text,p_site uuid,p_through date,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_ledger_owner(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 if p_through is null or p_through>(now() at time zone 'Africa/Douala')::date or length(trim(coalesce(p_reason,''))) not between 5 and 250 then raise exception 'INVALID_LEDGER_CLOSE';end if;
 if exists(select 1 from public.zp_ledger_closures where org_id=m.org_id and site_id=p_site and through_date>=p_through) then raise exception 'LEDGER_PERIOD_CLOSED';end if;
 if exists(select 1 from public.zp_ledger_sources s where s.org_id=m.org_id and s.site_id=p_site and s.entry_date<=p_through and not exists(select 1 from public.zp_ledger_entries e where e.site_id=s.site_id and e.source_kind=s.kind and e.source_id=s.source_id)) then raise exception 'LEDGER_UNPOSTED_SOURCES';end if;
 if exists(select 1 from public.zp_cash_receipts r join public.zp_sale_costs c on c.receipt_id=r.id where r.org_id=m.org_id and r.site_id=p_site and (r.created_at at time zone 'Africa/Douala')::date<=p_through and c.cost_xaf is null) then raise exception 'LEDGER_UNKNOWN_COST';end if;
 insert into public.zp_ledger_closures(org_id,site_id,through_date,member_id,reason) values(m.org_id,p_site,p_through,m.id,trim(p_reason)) returning id into i;return i;end $$;
create function public.zp_ledger_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_ledger_owner(p_access,p_site);
 return jsonb_build_object('accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'label',label,'section',section) order by code) from public.zp_ledger_accounts where org_id=m.org_id and site_id=p_site),'[]'::jsonb),
 'entries',coalesce((select jsonb_agg(to_jsonb(e) order by e.entry_date,e.created_at) from (select id,source_kind,source_id,entry_date,journal_code,label,debit_account,credit_account,amount_xaf::text as amount_xaf,created_at from public.zp_ledger_entries where org_id=m.org_id and site_id=p_site)e),'[]'::jsonb),
 'pending',coalesce((select jsonb_agg(to_jsonb(s) order by s.entry_date,s.source_id) from (select kind,source_id,entry_date,amount_xaf::text as amount_xaf,label from public.zp_ledger_sources x where x.org_id=m.org_id and x.site_id=p_site and not exists(select 1 from public.zp_ledger_entries e where e.site_id=x.site_id and e.source_kind=x.kind and e.source_id=x.source_id))s),'[]'::jsonb),
 'closed_through',(select max(through_date) from public.zp_ledger_closures where org_id=m.org_id and site_id=p_site),
 'unknown_cost_receipts',(select count(distinct r.id) from public.zp_cash_receipts r join public.zp_sale_costs c on c.receipt_id=r.id where r.org_id=m.org_id and r.site_id=p_site and c.cost_xaf is null));end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_ledger_accounts','zp_ledger_entries','zp_ledger_closures'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_ledger_owner','zp_ledger_account_add','zp_ledger_post','zp_ledger_close','zp_ledger_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
