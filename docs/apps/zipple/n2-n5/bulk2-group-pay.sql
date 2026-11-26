-- Adapt NAXA caisse reservation atomic settlement to a group of whole served orders.
-- Each order keeps exactly one receipt and the existing actual sale-cost trigger.
begin;
create table public.zp_payment_groups(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,cash_id uuid not null,table_session_id uuid not null,member_id uuid not null,request_id uuid not null,order_ids uuid[] not null,method text not null check(method in ('cash','mtn_momo','orange_money','bank','card')),reference text,amount_xaf bigint not null check(amount_xaf>0),created_at timestamptz not null default now(),unique(member_id,request_id),unique(id,org_id,site_id),foreign key(cash_id,org_id,site_id) references public.zp_cash_sessions(id,org_id,site_id),foreign key(table_session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_settlement_references(org_id uuid not null references public.zp_organizations(id),method text not null check(method in ('mtn_momo','orange_money','bank','card')),reference text not null check(length(trim(reference)) between 4 and 160),primary key(org_id,method,reference));
alter table public.zp_cash_receipts add column payment_group_id uuid,add foreign key(payment_group_id,org_id,site_id) references public.zp_payment_groups(id,org_id,site_id);
insert into public.zp_settlement_references select org_id,method,trim(reference) from public.zp_cash_receipts where method<>'cash' and reference is not null;
drop index public.zp_cash_reference_unique;
create unique index zp_cash_reference_unique on public.zp_cash_receipts(org_id,method,reference) where reference is not null and method<>'cash' and payment_group_id is null;
create function public.zp_record_group_sale(p_access text,p_site uuid,p_cash uuid,p_session uuid,p_orders uuid[],p_request uuid,p_method text,p_amount bigint,p_ref text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g public.zp_payment_groups;c public.zp_cash_sessions;o record;ids uuid[];total bigint;gid uuid;begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_orders is null or cardinality(p_orders) not between 1 and 50 or p_method is null or p_method not in ('cash','mtn_momo','orange_money','bank','card') or p_amount is null or p_amount<=0 then raise exception 'INVALID_GROUP';end if;
 select array_agg(distinct x order by x) into ids from unnest(p_orders) x;
 if cardinality(ids)<>cardinality(p_orders) or array_position(ids,null) is not null then raise exception 'INVALID_GROUP';end if;
 p_ref:=case when p_method='cash' then null else trim(p_ref) end;
 if p_method<>'cash' and (p_ref is null or length(p_ref) not between 4 and 160) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into g from public.zp_payment_groups where member_id=m.id and request_id=p_request;
 if g.id is not null then if (g.site_id,g.cash_id,g.table_session_id,g.order_ids,g.method,g.amount_xaf,g.reference) is distinct from (p_site,p_cash,p_session,ids,p_method,p_amount,p_ref) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return g.id;end if;
 select * into c from public.zp_cash_sessions where id=p_cash and org_id=m.org_id and site_id=p_site for update;
 if c.id is null then raise exception 'DENIED';end if;if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 if not exists(select 1 from public.zp_table_sessions where id=p_session and org_id=m.org_id and site_id=p_site and closed_at is null) then raise exception 'DENIED';end if;
 perform 1 from public.zp_orders where id=any(ids) and org_id=m.org_id and site_id=p_site order by id for update;
 if (select count(*) from public.zp_orders where id=any(ids) and org_id=m.org_id and site_id=p_site and table_session_id=p_session and status='served' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=zp_orders.id))<>cardinality(ids) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 select sum(total_xaf) into total from public.zp_orders where id=any(ids);
 if p_amount is distinct from total then raise exception 'SALE_NOT_SETTLEABLE';end if;
 if p_method<>'cash' then insert into public.zp_settlement_references values(m.org_id,p_method,p_ref);end if;
 insert into public.zp_payment_groups(org_id,site_id,cash_id,table_session_id,member_id,request_id,order_ids,method,reference,amount_xaf) values(m.org_id,p_site,p_cash,p_session,m.id,p_request,ids,p_method,p_ref,p_amount) returning id into gid;
 for o in select id,total_xaf from public.zp_orders where id=any(ids) order by id loop
 insert into public.zp_cash_receipts(org_id,site_id,cash_id,order_id,member_id,request_id,method,amount_xaf,reference,payment_group_id) values(m.org_id,p_site,p_cash,o.id,m.id,gen_random_uuid(),p_method,o.total_xaf,p_ref,gid);
 end loop;return gid;end $$;
create or replace function public.zp_record_sale(p_access text,p_site uuid,p_cash uuid,p_order uuid,p_request uuid,p_method text,p_amount bigint,p_ref text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;o public.zp_orders;r public.zp_cash_receipts;rid uuid;begin
 m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 p_ref:=case when p_method='cash' then null else trim(p_ref) end;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null then raise exception 'DENIED';end if;
 select * into r from public.zp_cash_receipts where member_id=m.id and request_id=p_request;
 if r.id is not null then if (r.cash_id,r.order_id,r.method,r.amount_xaf,r.reference) is distinct from (p_cash,p_order,p_method,p_amount,p_ref) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return r.id;end if;
 if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;
 if o.id is null or o.status<>'served' or p_amount is distinct from o.total_xaf or p_amount<=0 or (p_method<>'cash' and length(trim(coalesce(p_ref,'')))<4) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 if p_method<>'cash' then insert into public.zp_settlement_references values(m.org_id,p_method,p_ref);end if;
 insert into public.zp_cash_receipts(org_id,site_id,cash_id,order_id,member_id,request_id,method,amount_xaf,reference) values(m.org_id,p_site,c.id,o.id,m.id,p_request,p_method,p_amount,p_ref) returning id into rid;return rid;end $$;

do $$ declare t text;f record;begin
 foreach t in array array['zp_payment_groups','zp_settlement_references'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_record_group_sale','zp_record_sale') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
