-- Management statements, based only on validated journal entries and explicit account classification.
begin;
create table public.zp_ledger_classifications(
 account_id uuid primary key,org_id uuid not null,site_id uuid not null,kind text not null check(kind in ('asset','liability','equity','revenue','expense')),
 member_id uuid not null,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 foreign key(account_id,org_id,site_id) references public.zp_ledger_accounts(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_ledger_classify(p_access text,p_site uuid,p_account uuid,p_kind text,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_ledger_classifications;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_ledger_owner(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 if not exists(select 1 from public.zp_ledger_accounts where id=p_account and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 if p_kind is null or p_kind not in ('asset','liability','equity','revenue','expense') or length(why) not between 5 and 500 then raise exception 'INVALID_LEDGER_CLASSIFICATION';end if;
 select * into x from public.zp_ledger_classifications where account_id=p_account;
 if x.account_id is not null then if (x.kind,x.reason) is distinct from (p_kind,why) then raise exception 'LEDGER_CLASSIFICATION_IMMUTABLE';end if;return true;end if;
 insert into public.zp_ledger_classifications(account_id,org_id,site_id,kind,member_id,reason) values(p_account,m.org_id,p_site,p_kind,m.id,why);return true;end $$;
create function public.zp_ledger_statement(p_access text,p_site uuid,p_from date,p_to date) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;r jsonb;begin m:=public.zp_ledger_owner(p_access,p_site);
 if p_from is null or p_to is null or p_from>p_to or p_to>(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_STATEMENT_PERIOD';end if;
 with postings as (select e.entry_date,(l->>'account_id')::uuid account_id,(l->>'amount_xaf')::numeric*case l->>'side' when 'debit' then 1 else -1 end signed from public.zp_ledger_entries e cross join lateral jsonb_array_elements(public.zp_ledger_lines_for(e.id)) l where e.org_id=m.org_id and e.site_id=p_site and e.entry_date<=p_to),
 amounts as (select a.id,a.code,a.label,c.kind,c.reason,coalesce(sum(p.signed),0) balance,coalesce(sum(p.signed) filter(where p.entry_date>=p_from),0) period,count(p.account_id) entries from public.zp_ledger_accounts a left join public.zp_ledger_classifications c on c.account_id=a.id left join postings p on p.account_id=a.id where a.org_id=m.org_id and a.site_id=p_site group by a.id,a.code,a.label,c.kind,c.reason),
 summary as (select coalesce(sum(balance) filter(where kind='asset'),0) assets,-coalesce(sum(balance) filter(where kind='liability'),0) liabilities,-coalesce(sum(balance) filter(where kind='equity'),0) equity,-coalesce(sum(balance) filter(where kind in ('revenue','expense')),0) cumulative_result,-coalesce(sum(period) filter(where kind='revenue'),0) revenue,coalesce(sum(period) filter(where kind='expense'),0) expenses,count(*) filter(where kind is null and entries>0) unclassified,coalesce(sum(balance),0) net from amounts)
 select jsonb_build_object('from',p_from,'to',p_to,'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'label',label,'kind',kind,'reason',reason,'balance_xaf',balance::text,'period_xaf',period::text,'entries',entries) order by code) from amounts),'[]'::jsonb),'assets_xaf',assets::text,'liabilities_xaf',liabilities::text,'equity_xaf',equity::text,'cumulative_result_xaf',cumulative_result::text,'revenue_xaf',revenue::text,'expenses_xaf',expenses::text,'result_xaf',(revenue-expenses)::text,'balance_gap_xaf',(assets-liabilities-equity-cumulative_result)::text,'unclassified',unclassified,'journal_gap_xaf',net::text,
 'pending_sources',(select count(*) from public.zp_ledger_sources s where s.org_id=m.org_id and s.site_id=p_site and s.entry_date<=p_to and not exists(select 1 from public.zp_ledger_entries e where e.site_id=s.site_id and e.source_kind=s.kind and e.source_id=s.source_id)),
 'unknown_cost_receipts',(select count(distinct r.id) from public.zp_cash_receipts r join public.zp_sale_costs c on c.receipt_id=r.id where r.org_id=m.org_id and r.site_id=p_site and (r.created_at at time zone 'Africa/Douala')::date<=p_to and c.cost_xaf is null),
 'closed_through',(select max(through_date) from public.zp_ledger_closures where org_id=m.org_id and site_id=p_site)) into r from summary;return r;end $$;
create table public.zp_credit_limit_history(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,account_id uuid not null,member_id uuid not null,request_id uuid not null,
 old_limit bigint not null,new_limit bigint not null check(new_limit between 1 and 2147483647),reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 unique(member_id,request_id),foreign key(account_id,org_id,site_id) references public.zp_credit_accounts(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_credit_limit_revise(p_access text,p_site uuid,p_account uuid,p_request uuid,p_expected bigint,p_limit bigint,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;a public.zp_credit_accounts;x public.zp_credit_limit_history;i uuid;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_credit_limit_history where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.account_id,x.old_limit,x.new_limit,x.reason) is distinct from (p_site,p_account,p_expected,p_limit,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 select * into a from public.zp_credit_accounts where id=p_account and org_id=m.org_id and site_id=p_site for update;if a.id is null then raise exception 'DENIED';end if;
 if a.limit_xaf is distinct from p_expected then raise exception 'STALE_CREDIT_LIMIT';end if;
 if p_request is null or p_limit is null or p_limit not between 1 and 2147483647 or p_limit=p_expected or length(why) not between 5 and 500 then raise exception 'INVALID_CREDIT_LIMIT';end if;
 insert into public.zp_credit_limit_history(org_id,site_id,account_id,member_id,request_id,old_limit,new_limit,reason) values(m.org_id,p_site,a.id,m.id,p_request,a.limit_xaf,p_limit,why) returning id into i;
 update public.zp_credit_accounts set limit_xaf=p_limit where id=a.id;return i;end $$;
create table public.zp_credit_followups(
 sale_id uuid not null,followup_id uuid not null unique,org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,primary key(member_id,request_id),
 foreign key(sale_id,org_id,site_id) references public.zp_credit_sales(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_credit_followup(p_access text,p_site uuid,p_sale uuid,p_request uuid,p_channel text,p_due date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s public.zp_credit_sales;x public.zp_credit_followups;customer uuid;i uuid;begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into s from public.zp_credit_sales where id=p_sale and org_id=m.org_id and site_id=p_site;if s.id is null or s.split_mode is not null then raise exception 'DENIED';end if;
 select * into x from public.zp_credit_followups where member_id=m.id and request_id=p_request;
 if x.followup_id is not null then
 if (x.site_id,x.sale_id) is distinct from (p_site,p_sale) or not exists(select 1 from public.zp_customer_followups where id=x.followup_id and channel=p_channel and due_on=p_due) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.followup_id;end if;
 if s.balance_xaf=0 or p_request is null or p_due is null or p_due<(now() at time zone 'Africa/Douala')::date or p_channel is null or p_channel not in ('telephone','whatsapp','in_person') then raise exception 'INVALID_CREDIT_FOLLOWUP';end if;
 select customer_id into customer from public.zp_credit_accounts where id=s.account_id;
 i:=public.zp_followup_create(p_access,p_site,customer,p_request,'Relance créance / Credit follow-up #'||left(s.id::text,8),p_channel,p_due);
 insert into public.zp_credit_followups values(s.id,i,m.org_id,p_site,m.id,p_request);return i;end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_ledger_classifications','zp_credit_limit_history','zp_credit_followups'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_ledger_classify','zp_ledger_statement','zp_credit_limit_revise','zp_credit_followup') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;

-- Explicitly authorized accounting rules; no preset tax regime or automatic financial posting.
create table public.zp_ledger_mapping_versions(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,
 kind text not null,version int not null check(version>0),debit_account uuid not null,credit_account uuid not null,
 journal_code text not null check(length(journal_code) between 1 and 30),reason text not null check(length(reason) between 5 and 500),
 created_at timestamptz not null default now(),unique(site_id,kind,version),unique(member_id,request_id),
 check(debit_account<>credit_account),foreign key(debit_account,org_id,site_id) references public.zp_ledger_accounts(id,org_id,site_id),
 foreign key(credit_account,org_id,site_id) references public.zp_ledger_accounts(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_ledger_mapping_posts(entry_id uuid primary key references public.zp_ledger_entries(id),mapping_id uuid not null references public.zp_ledger_mapping_versions(id));
create function public.zp_ledger_mapping_set(p_access text,p_site uuid,p_request uuid,p_kind text,p_expected int,p_debit uuid,p_credit uuid,p_journal text,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $map$
declare m public.zp_members;x public.zp_ledger_mapping_versions;v int;i uuid;j text:=upper(trim(coalesce(p_journal,'')));why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_ledger_owner(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 if p_request is null or p_kind is null or p_kind not in ('sale','credit_sale','credit_payment','sale_cost','purchase_receipt','supplier_payment','expense','inventory_loss','deposit_in','deposit_out','braise_loss','transfer_loss','prepared_transfer_loss','refund','withdrawal','prepared_expiry_loss','inventory_gain','credit_note','credit_refund','stock_return','supplier_return','supplier_refund') or p_expected is null or p_expected<0 or p_debit is null or p_credit is null or p_debit=p_credit or length(j) not between 1 and 30 or length(why) not between 5 and 500 then raise exception 'INVALID_LEDGER_MAPPING';end if;
 select * into x from public.zp_ledger_mapping_versions where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.kind,x.version,x.debit_account,x.credit_account,x.journal_code,x.reason) is distinct from (p_site,p_kind,p_expected+1,p_debit,p_credit,j,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if (select count(*) from public.zp_ledger_accounts a join public.zp_ledger_classifications c on c.account_id=a.id where a.org_id=m.org_id and a.site_id=p_site and a.id in (p_debit,p_credit))<>2 then raise exception 'LEDGER_MAPPING_REQUIRES_CLASSIFIED_ACCOUNTS';end if;
 select coalesce(max(version),0) into v from public.zp_ledger_mapping_versions where site_id=p_site and kind=p_kind;
 if v<>p_expected then raise exception 'STALE_LEDGER_MAPPING';end if;
 insert into public.zp_ledger_mapping_versions(org_id,site_id,member_id,request_id,kind,version,debit_account,credit_account,journal_code,reason) values(m.org_id,p_site,m.id,p_request,p_kind,v+1,p_debit,p_credit,j,why) returning id into i;return i;end $map$;
create function public.zp_ledger_mapping_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $map$
declare m public.zp_members;begin m:=public.zp_ledger_owner(p_access,p_site);
 return jsonb_build_object('rules',coalesce((select jsonb_agg(to_jsonb(v) order by v.kind,v.version desc) from (select x.id,x.kind,x.version,x.debit_account,x.credit_account,x.journal_code,x.reason,x.created_at,d.code debit_code,c.code credit_code,(x.version=max(x.version) over(partition by x.kind)) active from public.zp_ledger_mapping_versions x join public.zp_ledger_accounts d on d.id=x.debit_account join public.zp_ledger_accounts c on c.id=x.credit_account where x.org_id=m.org_id and x.site_id=p_site)v),'[]'::jsonb),'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'code',a.code,'label',a.label,'kind',c.kind) order by a.code) from public.zp_ledger_accounts a join public.zp_ledger_classifications c on c.account_id=a.id where a.org_id=m.org_id and a.site_id=p_site),'[]'::jsonb));end $map$;
create function public.zp_ledger_post_mapped(p_access text,p_site uuid,p_mapping uuid,p_source uuid,p_request uuid,p_label text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $map$
declare m public.zp_members;x public.zp_ledger_mapping_versions;e public.zp_ledger_entries;i uuid;begin
 m:=public.zp_ledger_owner(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_ledger_mapping_versions where id=p_mapping and org_id=m.org_id and site_id=p_site;if x.id is null then raise exception 'DENIED';end if;
 select * into e from public.zp_ledger_entries where member_id=m.id and request_id=p_request;
 if e.id is not null then if not exists(select 1 from public.zp_ledger_mapping_posts where entry_id=e.id and mapping_id=x.id) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return public.zp_ledger_post(p_access,p_site,x.kind,p_source,p_request,x.journal_code,x.debit_account,x.credit_account,p_label);end if;
 if exists(select 1 from public.zp_ledger_mapping_versions where site_id=p_site and kind=x.kind and version>x.version) then raise exception 'STALE_LEDGER_MAPPING';end if;
 i:=public.zp_ledger_post(p_access,p_site,x.kind,p_source,p_request,x.journal_code,x.debit_account,x.credit_account,p_label);
 insert into public.zp_ledger_mapping_posts values(i,x.id);return i;end $map$;
alter table public.zp_ledger_mapping_versions enable row level security;
alter table public.zp_ledger_mapping_posts enable row level security;
revoke all on public.zp_ledger_mapping_versions,public.zp_ledger_mapping_posts from public,anon,authenticated;
grant select,insert on public.zp_ledger_mapping_versions,public.zp_ledger_mapping_posts to service_role;
revoke all on function public.zp_ledger_mapping_set(text,uuid,uuid,text,int,uuid,uuid,text,text),public.zp_ledger_mapping_snapshot(text,uuid),public.zp_ledger_post_mapped(text,uuid,uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.zp_ledger_mapping_set(text,uuid,uuid,text,int,uuid,uuid,text,text),public.zp_ledger_mapping_snapshot(text,uuid),public.zp_ledger_post_mapped(text,uuid,uuid,uuid,uuid,text) to service_role;

commit;
