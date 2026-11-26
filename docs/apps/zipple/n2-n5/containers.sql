-- Reuse stock-movement, supplier, CRM and scoped ERP contracts; count returnable packaging.
-- Amounts are reference exposure, not cash, supplier debt, revenue or a refund.
begin;
create table public.zp_container_accounts(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,supplier_id uuid,customer_id uuid,label text not null check(length(trim(label)) between 1 and 100),unit_deposit_xaf int not null check(unit_deposit_xaf between 0 and 10000000),outstanding int not null default 0 check(outstanding>=0),created_by uuid not null,created_at timestamptz not null default now(),unique(id,org_id,site_id),check((supplier_id is null)<>(customer_id is null)),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(supplier_id,org_id,site_id) references public.zp_suppliers(id,org_id,site_id),foreign key(customer_id,org_id) references public.zp_customers(id,org_id),foreign key(created_by,org_id) references public.zp_members(id,org_id));
create unique index zp_container_supplier_unique on public.zp_container_accounts(site_id,supplier_id,label) where supplier_id is not null;
create unique index zp_container_customer_unique on public.zp_container_accounts(site_id,customer_id,label) where customer_id is not null;
create table public.zp_container_events(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,account_id uuid not null,member_id uuid not null,request_id uuid not null,kind text not null check(kind in ('issued','returned','lost')),qty int not null check(qty between 1 and 1000000),reason text not null check(length(reason)<=500),unit_deposit_xaf int not null check(unit_deposit_xaf>=0),created_at timestamptz not null default now(),unique(member_id,request_id),foreign key(account_id,org_id,site_id) references public.zp_container_accounts(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_container_account(p_access text,p_site uuid,p_supplier uuid,p_customer uuid,p_label text,p_unit int) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 if (p_supplier is null)=(p_customer is null) then raise exception 'INVALID_COUNTERPARTY';end if;
 if p_supplier is not null and not exists(select 1 from public.zp_suppliers where id=p_supplier and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 if p_customer is not null and not exists(select 1 from public.zp_customers where id=p_customer and org_id=m.org_id) then raise exception 'DENIED';end if;
 insert into public.zp_container_accounts(org_id,site_id,supplier_id,customer_id,label,unit_deposit_xaf,created_by) values(m.org_id,p_site,p_supplier,p_customer,trim(p_label),p_unit,m.id) returning id into i;return i;end $$;
create function public.zp_container_move(p_access text,p_site uuid,p_account uuid,p_request uuid,p_kind text,p_qty int,p_reason text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_container_accounts;y public.zp_container_events;i uuid;balance int;why text:=trim(coalesce(p_reason,''));begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into y from public.zp_container_events where member_id=m.id and request_id=p_request;
 if y.id is not null then if (y.site_id,y.account_id,y.kind,y.qty,y.reason) is distinct from (p_site,p_account,p_kind,p_qty,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return jsonb_build_object('id',y.id);end if;
 select * into x from public.zp_container_accounts where id=p_account and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if p_qty is null or p_qty not between 1 and 1000000 or p_kind is null or p_kind not in ('issued','returned','lost') or (p_kind='lost' and length(why)<5) or length(why)>500 then raise exception 'INVALID_CONTAINER_MOVEMENT';end if;
 if p_kind<>'issued' and p_qty>x.outstanding then raise exception 'CONTAINER_BALANCE_EXCEEDED';end if;
 balance:=x.outstanding+case when p_kind='issued' then p_qty else -p_qty end;
 insert into public.zp_container_events(org_id,site_id,account_id,member_id,request_id,kind,qty,reason,unit_deposit_xaf) values(m.org_id,p_site,x.id,m.id,p_request,p_kind,p_qty,why,x.unit_deposit_xaf) returning id into i;
 update public.zp_container_accounts set outstanding=balance where id=x.id;return jsonb_build_object('id',i);end $$;
-- Distinct confirmed deposit cash flows. Physical movements are never money by themselves.
create table public.zp_container_finance(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,
 account_id uuid not null,event_id uuid not null unique,member_id uuid not null,request_id uuid not null,
 kind text not null check(kind in ('deposit','refund')),direction text not null check(direction in ('in','out')),
 amount_xaf bigint not null check(amount_xaf>0 and amount_xaf<=2147483647),
 method text not null check(method in ('cash','bank','mtn_momo','orange_money','card')),
 reference text not null check(length(reference) between 4 and 160),created_at timestamptz not null default now(),
 unique(member_id,request_id),unique(org_id,method,reference),
 foreign key(account_id,org_id,site_id) references public.zp_container_accounts(id,org_id,site_id),
 foreign key(event_id) references public.zp_container_events(id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_container_finance_record(p_access text,p_site uuid,p_event uuid,p_request uuid,p_amount bigint,p_method text,p_reference text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;e public.zp_container_events;a public.zp_container_accounts;old public.zp_container_finance;k text;d text;r text:=lower(trim(coalesce(p_reference,'')));balance bigint;i uuid;begin
 m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into old from public.zp_container_finance where member_id=m.id and request_id=p_request;
 if old.id is not null then
  if (old.site_id,old.event_id,old.amount_xaf,old.method,old.reference) is distinct from (p_site,p_event,p_amount,p_method,r) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return old.id;
 end if;
 select * into e from public.zp_container_events where id=p_event and org_id=m.org_id and site_id=p_site;
 if e.id is null then raise exception 'DENIED';end if;
 select * into a from public.zp_container_accounts where id=e.account_id and org_id=m.org_id and site_id=p_site for update;
 if e.kind not in ('issued','returned') or p_amount is null or p_amount<>e.qty::bigint*e.unit_deposit_xaf or p_amount not between 1 and 2147483647 or p_request is null or p_method is null or p_method not in ('cash','bank','mtn_momo','orange_money','card') or length(r) not between 4 and 160 then raise exception 'INVALID_DEPOSIT_PAYMENT';end if;
 if exists(select 1 from public.zp_container_finance where event_id=e.id) then raise exception 'DEPOSIT_EVENT_ALREADY_RECORDED';end if;
 k:=case when e.kind='issued' then 'deposit' else 'refund' end;
 d:=case when (a.supplier_id is null and k='deposit') or (a.supplier_id is not null and k='refund') then 'in' else 'out' end;
 select coalesce(sum(case when kind='deposit' then amount_xaf else -amount_xaf end),0) into balance from public.zp_container_finance where account_id=a.id and org_id=m.org_id and site_id=p_site;
 if k='refund' and p_amount>balance then raise exception 'DEPOSIT_REFUND_EXCEEDS_BALANCE';end if;
 if exists(select 1 from public.zp_container_finance where org_id=m.org_id and method=p_method and reference=r) then raise exception 'DEPOSIT_REFERENCE_USED';end if;
 insert into public.zp_container_finance(org_id,site_id,account_id,event_id,member_id,request_id,kind,direction,amount_xaf,method,reference)
 values(m.org_id,p_site,a.id,e.id,m.id,p_request,k,d,p_amount,p_method,r) returning id into i;return i;
end $$;
create function public.zp_container_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('accounts',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'label',x.label,'counterparty',coalesce(s.name,c.display_name),'side',case when x.supplier_id is null then 'customer' else 'supplier' end,'outstanding',x.outstanding,'unit_deposit_xaf',x.unit_deposit_xaf,'reference_exposure_xaf',x.outstanding::bigint*x.unit_deposit_xaf,'deposit_balance_xaf',(select coalesce(sum(case when f.kind='deposit' then f.amount_xaf else -f.amount_xaf end),0) from public.zp_container_finance f where f.account_id=x.id and f.org_id=m.org_id and f.site_id=p_site))) from public.zp_container_accounts x left join public.zp_suppliers s on s.id=x.supplier_id left join public.zp_customers c on c.id=x.customer_id where x.org_id=m.org_id and x.site_id=p_site),'[]'::jsonb),'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at desc) from (select id,account_id,kind,qty,reason,unit_deposit_xaf,created_at from public.zp_container_events where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)e),'[]'::jsonb),'finance',coalesce((select jsonb_agg(to_jsonb(f) order by f.created_at desc) from (select id,account_id,event_id,kind,direction,amount_xaf,method,reference,created_at from public.zp_container_finance where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)f),'[]'::jsonb),'suppliers',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.zp_suppliers where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'customers',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',display_name)) from public.zp_customers where org_id=m.org_id),'[]'::jsonb));end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_container_accounts','zp_container_events','zp_container_finance'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_container_account','zp_container_move','zp_container_snapshot','zp_container_finance_record') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
