-- Reuse unit conversions, purchase transactions and existing per-site validated journal.
begin;
create table public.zp_purchase_conversion_log(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,
 kind text not null check(kind in ('order','receipt')),source_id uuid not null,conversion_id uuid not null,
 input_milli bigint not null check(input_milli>0),base_milli bigint not null check(base_milli>0),created_at timestamptz not null default now(),
 unique(member_id,kind,request_id),unique(kind,source_id),foreign key(conversion_id,org_id,site_id) references public.zp_unit_conversions(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_purchase_conversion_quantity(p_org uuid,p_site uuid,p_ingredient uuid,p_conversion uuid,p_qty bigint) returns bigint language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare c public.zp_unit_conversions;product numeric;begin
 select * into c from public.zp_unit_conversions where id=p_conversion and org_id=p_org and site_id=p_site and ingredient_id=p_ingredient;
 if c.id is null then raise exception 'DENIED';end if;
 if p_qty is null or p_qty not between 1 and 1000000000 then raise exception 'INVALID_UNIT_CONVERSION';end if;
 product:=p_qty::numeric*c.base_milli_per_unit;
 if mod(product,1000)<>0 or product/1000 not between 1 and 1000000000 then raise exception 'CONVERSION_PRECISION_OR_RANGE';end if;
 return (product/1000)::bigint;end $$;
create function public.zp_purchase_create_converted(p_access text,p_site uuid,p_supplier uuid,p_ingredient uuid,p_conversion uuid,p_request uuid,p_ref text,p_qty bigint,p_total bigint) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_purchase_conversion_log;q bigint;i uuid;begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 q:=public.zp_purchase_conversion_quantity(m.org_id,p_site,p_ingredient,p_conversion,p_qty);
 select * into x from public.zp_purchase_conversion_log where member_id=m.id and request_id=p_request and kind='order';
 if x.id is not null then
 if (x.site_id,x.conversion_id,x.input_milli) is distinct from (p_site,p_conversion,p_qty) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 elsif exists(select 1 from public.zp_purchases where member_id=m.id and request_id=p_request) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 i:=public.zp_purchase_create(p_access,p_site,p_supplier,p_ingredient,p_request,p_ref,q,p_total);
 if x.id is null then insert into public.zp_purchase_conversion_log(org_id,site_id,member_id,request_id,kind,source_id,conversion_id,input_milli,base_milli) values(m.org_id,p_site,m.id,p_request,'order',i,p_conversion,p_qty,q);end if;
 return i;end $$;
create function public.zp_purchase_receive_converted(p_access text,p_site uuid,p_purchase uuid,p_conversion uuid,p_request uuid,p_qty bigint,p_label text,p_expiry date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;p public.zp_purchases;x public.zp_purchase_conversion_log;q bigint;i uuid;begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into p from public.zp_purchases where id=p_purchase and org_id=m.org_id and site_id=p_site;if p.id is null then raise exception 'DENIED';end if;
 q:=public.zp_purchase_conversion_quantity(m.org_id,p_site,p.ingredient_id,p_conversion,p_qty);
 select * into x from public.zp_purchase_conversion_log where member_id=m.id and request_id=p_request and kind='receipt';
 if x.id is not null then
 if (x.site_id,x.conversion_id,x.input_milli) is distinct from (p_site,p_conversion,p_qty) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 elsif exists(select 1 from public.zp_purchase_receipts where member_id=m.id and request_id=p_request) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 i:=public.zp_purchase_receive(p_access,p_site,p_purchase,p_request,q,p_label,p_expiry);
 if x.id is null then insert into public.zp_purchase_conversion_log(org_id,site_id,member_id,request_id,kind,source_id,conversion_id,input_milli,base_milli) values(m.org_id,p_site,m.id,p_request,'receipt',i,p_conversion,p_qty,q);end if;
 return i;end $$;
create function public.zp_purchase_conversion_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);return jsonb_build_object('events',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select x.id,x.kind,x.source_id,x.input_milli,x.base_milli,c.label,c.ingredient_id,g.unit,x.created_at from public.zp_purchase_conversion_log x join public.zp_unit_conversions c on c.id=x.conversion_id join public.zp_ingredients g on g.id=c.ingredient_id where x.org_id=m.org_id and x.site_id=p_site order by x.created_at desc limit 300)q),'[]'::jsonb));end $$;
create function public.zp_ledger_group_statement(p_access text,p_site uuid,p_from date,p_to date) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s record;v jsonb;rows jsonb:='[]';a numeric:=0;l numeric:=0;e numeric:=0;cum numeric:=0;rev numeric:=0;exp numeric:=0;pending bigint:=0;unknowns bigint:=0;unclassified bigint:=0;all_closed boolean:=true;total_sites int;n int:=0;internal_transfer numeric:=0;begin
 m:=public.zp_ledger_owner(p_access,p_site);
 if p_from is null or p_to is null or p_from>p_to or p_to>(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_STATEMENT_PERIOD';end if;
 select count(*) into total_sites from public.zp_sites where org_id=m.org_id and active;
 for s in select z.id,z.name from public.zp_sites z join public.zp_site_scopes sc on sc.site_id=z.id and sc.org_id=z.org_id and sc.member_id=m.id join public.zp_site_modes sm on sm.site_id=z.id and sm.org_id=z.org_id where z.org_id=m.org_id and z.active order by z.name,z.id loop
  v:=public.zp_ledger_statement(p_access,s.id,p_from,p_to);n:=n+1;
  a:=a+(v->>'assets_xaf')::numeric;l:=l+(v->>'liabilities_xaf')::numeric;e:=e+(v->>'equity_xaf')::numeric;cum:=cum+(v->>'cumulative_result_xaf')::numeric;rev:=rev+(v->>'revenue_xaf')::numeric;exp:=exp+(v->>'expenses_xaf')::numeric;
  pending:=pending+(v->>'pending_sources')::bigint;unknowns:=unknowns+(v->>'unknown_cost_receipts')::bigint;unclassified:=unclassified+(v->>'unclassified')::bigint;all_closed:=all_closed and coalesce((v->>'closed_through')::date>=p_to,false);
  rows:=rows||jsonb_build_array(v||jsonb_build_object('site_id',s.id,'site_name',s.name));
 end loop;
 select coalesce(sum(cost),0) into internal_transfer from (select t.transferred_cost cost from public.zp_transfers t where t.org_id=m.org_id and t.state='received' and (t.received_at at time zone 'Africa/Douala')::date between p_from and p_to and exists(select 1 from public.zp_site_scopes x where x.member_id=m.id and x.site_id=t.source_site) and exists(select 1 from public.zp_site_scopes x where x.member_id=m.id and x.site_id=t.destination_site) union all select t.transferred_cost from public.zp_prepared_transfers t where t.org_id=m.org_id and t.state='received' and (t.received_at at time zone 'Africa/Douala')::date between p_from and p_to and exists(select 1 from public.zp_site_scopes x where x.member_id=m.id and x.site_id=t.source_site) and exists(select 1 from public.zp_site_scopes x where x.member_id=m.id and x.site_id=t.destination_site))q;
 return jsonb_build_object('from',p_from,'to',p_to,'sites',rows,'sites_included',n,'sites_total',total_sites,'complete_scope',n=total_sites,'assets_xaf',a::text,'liabilities_xaf',l::text,'equity_xaf',e::text,'cumulative_result_xaf',cum::text,'revenue_xaf',rev::text,'expenses_xaf',exp::text,'result_xaf',(rev-exp)::text,'balance_gap_xaf',(a-l-e-cum)::text,'unclassified',unclassified,'pending_sources',pending,'unknown_cost_receipts',unknowns,'all_closed',all_closed,'internal_transfer_cost_xaf',internal_transfer::text);
end $$;
alter table public.zp_purchase_conversion_log enable row level security;
revoke all on public.zp_purchase_conversion_log from public,anon,authenticated;grant select,insert on public.zp_purchase_conversion_log to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_purchase_conversion_quantity','zp_purchase_create_converted','zp_purchase_receive_converted','zp_purchase_conversion_snapshot','zp_ledger_group_statement') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
