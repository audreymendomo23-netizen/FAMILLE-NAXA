-- NAXA accounting parameter model: dated, versioned, never default to a tax rate.
-- Gross-inclusive management reporting only. No statutory return generated.
begin;
create table public.zp_tax_rules(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,item_id uuid not null,member_id uuid not null,request_id uuid not null,
 version integer not null check(version>0),category text not null check(length(category) between 1 and 80),rate_bps integer not null check(rate_bps between 0 and 10000),
 valid_from date not null,validation_reference text not null check(length(validation_reference) between 5 and 500),created_at timestamptz not null default now(),
 unique(item_id,version),unique(member_id,request_id),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_sale_tax_lines(
 receipt_id uuid not null references public.zp_cash_receipts(id),org_id uuid not null,site_id uuid not null,item_id uuid not null,rule_id uuid references public.zp_tax_rules(id),
 category text,rate_bps int,gross_xaf bigint not null check(gross_xaf>=0),tax_xaf bigint check(tax_xaf>=0 and tax_xaf<=gross_xaf),
 primary key(receipt_id,item_id),check((rule_id is null)=(tax_xaf is null)),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id));
alter table public.zp_tax_rules enable row level security;
alter table public.zp_sale_tax_lines enable row level security;
revoke all on public.zp_tax_rules,public.zp_sale_tax_lines from public,anon,authenticated;
grant select,insert on public.zp_tax_rules,public.zp_sale_tax_lines to service_role;
create function public.zp_tax_rule_set(p_access text,p_site uuid,p_item uuid,p_request uuid,p_expected int,p_category text,p_rate int,p_from date,p_evidence text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;x public.zp_tax_rules;v int;i uuid;cat text:=trim(coalesce(p_category,''));why text:=trim(coalesce(p_evidence,''));begin
 m:=public.zp_ledger_owner(p_access,p_site);
 if p_request is null or p_expected is null or p_expected<0 or p_rate is null or p_rate not between 0 and 10000 or p_from is null or length(cat) not between 1 and 80 or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where org_id=m.org_id and site_id=p_site for update;
 select * into x from public.zp_tax_rules where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.item_id,x.version,x.category,x.rate_bps,x.valid_from,x.validation_reference) is distinct from (p_site,p_item,p_expected+1,cat,p_rate,p_from,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if not exists(select 1 from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 if p_from<(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_TAX_EFFECTIVE_DATE';end if;
 select coalesce(max(version),0) into v from public.zp_tax_rules where item_id=p_item;
 if v<>p_expected then raise exception 'STALE_TAX_RULE';end if;
 insert into public.zp_tax_rules(org_id,site_id,item_id,member_id,request_id,version,category,rate_bps,valid_from,validation_reference) values(m.org_id,p_site,p_item,m.id,p_request,v+1,cat,p_rate,p_from,why) returning id into i;return i;
end $f$;
create function public.zp_sale_tax_capture() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $f$
begin
 insert into public.zp_sale_tax_lines(receipt_id,org_id,site_id,item_id,rule_id,category,rate_bps,gross_xaf,tax_xaf)
 select new.id,new.org_id,new.site_id,l.item_id,r.id,r.category,r.rate_bps,l.line_total_xaf,
 case when r.id is null then null else round(l.line_total_xaf::numeric*r.rate_bps/(10000+r.rate_bps))::bigint end
 from public.zp_order_lines l left join lateral(select * from public.zp_tax_rules q where q.item_id=l.item_id and q.org_id=new.org_id and q.site_id=new.site_id and q.valid_from<=(new.created_at at time zone 'Africa/Douala')::date order by valid_from desc,version desc limit 1) r on true
 where l.order_id=new.order_id and l.site_id=new.site_id and l.org_id=new.org_id;
 return new;end $f$;
create trigger zp_sale_tax_capture_after after insert on public.zp_cash_receipts for each row execute function public.zp_sale_tax_capture();
create function public.zp_tax_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;begin m:=public.zp_ledger_owner(p_access,p_site);
 return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x)) from (select i.id,i.name,coalesce((select max(version) from public.zp_tax_rules r where r.item_id=i.id),0) version from public.zp_menu_items i where i.org_id=m.org_id and i.site_id=p_site order by i.name)x),'[]'::jsonb),
 'rules',coalesce((select jsonb_agg(to_jsonb(x)) from (select r.id,r.item_id,i.name,r.category,r.rate_bps,r.valid_from,r.version,r.validation_reference,r.created_at from public.zp_tax_rules r join public.zp_menu_items i on i.id=r.item_id where r.org_id=m.org_id and r.site_id=p_site order by r.created_at desc limit 300)x),'[]'::jsonb));
end $f$;
create function public.zp_tax_report(p_access text,p_site uuid,p_from date,p_to date) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;lo timestamptz;hi timestamptz;gross numeric;missing int;unknown int;refunds numeric;credits numeric;begin
 m:=public.zp_ledger_owner(p_access,p_site);
 if p_from is null or p_to is null or p_from>p_to or p_to>(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_STATEMENT_PERIOD';end if;
 lo:=p_from::timestamp at time zone 'Africa/Douala';hi:=(p_to+1)::timestamp at time zone 'Africa/Douala';
 select coalesce(sum(r.amount_xaf),0),count(*) filter(where r.amount_xaf is distinct from (select sum(l.gross_xaf) from public.zp_sale_tax_lines l where l.receipt_id=r.id)) into gross,missing from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;
 select count(*) into unknown from public.zp_sale_tax_lines l join public.zp_cash_receipts r on r.id=l.receipt_id where l.org_id=m.org_id and l.site_id=p_site and r.created_at>=lo and r.created_at<hi and l.rule_id is null;
 select coalesce(sum(amount_xaf),0) into refunds from public.zp_cash_outflows where org_id=m.org_id and site_id=p_site and kind='refund' and created_at>=lo and created_at<hi;
 select coalesce(sum(amount_xaf),0) into credits from public.zp_credit_notes where org_id=m.org_id and site_id=p_site and created_at>=lo and created_at<hi;
 return jsonb_build_object('from',p_from,'to',p_to,'gross_xaf',gross::text,'missing_receipts',missing,'unclassified_lines',unknown,'unallocated_adjustments_xaf',(refunds+credits)::text,'statutory_ready',false,'basis','gross_inclusive_management_only',
 'categories',coalesce((select jsonb_agg(to_jsonb(x) order by x.category,x.rate_bps) from (select l.category,l.rate_bps,sum(l.gross_xaf)::text gross_xaf,case when l.rate_bps is null then null else sum(l.gross_xaf-l.tax_xaf)::text end net_xaf,sum(l.tax_xaf)::text tax_xaf from public.zp_sale_tax_lines l join public.zp_cash_receipts r on r.id=l.receipt_id where l.org_id=m.org_id and l.site_id=p_site and r.created_at>=lo and r.created_at<hi group by l.category,l.rate_bps)x),'[]'::jsonb));
end $f$;
do $g$ declare n record;begin for n in select p.oid::regprocedure as sig from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public' and p.proname in ('zp_tax_rule_set','zp_sale_tax_capture','zp_tax_snapshot','zp_tax_report') loop execute format('revoke all on function %s from public,anon,authenticated',n.sig);execute format('grant execute on function %s to service_role',n.sig);end loop;end $g$;
commit;
