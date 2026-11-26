-- Multi-drawer and mixed receipt extension; preserves one sale receipt and cost allocation per order.
begin;
create table public.zp_cash_desks(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,label text not null check(length(label) between 2 and 100),
 assigned_member uuid not null,created_by uuid not null,created_at timestamptz not null default now(),
 unique(site_id,label),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),
 foreign key(assigned_member,org_id) references public.zp_members(id,org_id),foreign key(created_by,org_id) references public.zp_members(id,org_id));
alter table public.zp_cash_sessions add column desk_id uuid,add foreign key(desk_id,org_id,site_id) references public.zp_cash_desks(id,org_id,site_id);
drop index public.zp_one_open_cash;
create unique index zp_one_open_cash on public.zp_cash_sessions(site_id) where closed_at is null and desk_id is null;
create unique index zp_one_open_cash_desk on public.zp_cash_sessions(desk_id) where closed_at is null and desk_id is not null;
alter table public.zp_cash_receipts drop constraint zp_cash_receipts_method_check;
alter table public.zp_cash_receipts add constraint zp_cash_receipts_method_check check(method in ('cash','mtn_momo','orange_money','bank','card','mixed'));
create table public.zp_cash_tenders(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,receipt_id uuid not null,
 method text not null check(method in ('cash','mtn_momo','orange_money','bank','card')),amount_xaf bigint not null check(amount_xaf>0),
 reference text,position int not null check(position between 1 and 5),unique(receipt_id,position),
 foreign key(receipt_id,org_id,site_id) references public.zp_cash_receipts(id,org_id,site_id),
 check((method='cash' and reference is null) or (method<>'cash' and reference is not null and length(reference) between 4 and 160)));
create function public.zp_cash_desk_access(p_member uuid,p_cash uuid) returns boolean language sql stable security invoker set search_path=pg_catalog,public as $$
 select exists(select 1 from public.zp_cash_sessions c join public.zp_members m on m.id=p_member and m.org_id=c.org_id left join public.zp_cash_desks d on d.id=c.desk_id where c.id=p_cash and (c.desk_id is null or d.assigned_member=m.id or m.role_code='promoteur'));
$$;
create function public.zp_cash_desk_add(p_access text,p_site uuid,p_label text,p_member uuid) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' or not public.zp_can_operate(p_member,p_site,'cash') or not exists(select 1 from public.zp_members x join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id where x.id=p_member and x.org_id=m.org_id and x.active and sc.site_id=p_site) then raise exception 'DENIED';end if;
 insert into public.zp_cash_desks(org_id,site_id,label,assigned_member,created_by) values(m.org_id,p_site,trim(p_label),p_member,m.id) returning id into i;return i;end $$;
create function public.zp_cash_desk_open(p_access text,p_site uuid,p_desk uuid,p_opening bigint) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;d public.zp_cash_desks;i uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') or p_opening is null or p_opening not between 0 and 2147483647 then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into d from public.zp_cash_desks where id=p_desk and org_id=m.org_id and site_id=p_site;
 if d.id is null or (d.assigned_member<>m.id and m.role_code<>'promoteur') then raise exception 'DENIED';end if;
 insert into public.zp_cash_sessions(org_id,site_id,desk_id,opened_by,opening_xaf) values(m.org_id,p_site,d.id,m.id,p_opening) returning id into i;return i;end $$;
create function public.zp_cash_desks_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
 return jsonb_build_object('desks',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'label',d.label,'assigned_member',d.assigned_member,'cash_id',c.id,'opening_xaf',c.opening_xaf) order by d.label) from public.zp_cash_desks d left join public.zp_cash_sessions c on c.desk_id=d.id and c.closed_at is null where d.org_id=m.org_id and d.site_id=p_site and (d.assigned_member=m.id or m.role_code='promoteur')),'[]'::jsonb),
 'members',case when m.role_code='promoteur' then coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'login',x.login_id) order by x.login_id) from public.zp_members x join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id where x.org_id=m.org_id and x.active and sc.site_id=p_site and public.zp_can_operate(x.id,p_site,'cash')),'[]'::jsonb) else '[]'::jsonb end);end $$;
create function public.zp_record_mixed_sale(p_access text,p_site uuid,p_cash uuid,p_order uuid,p_request uuid,p_tenders jsonb) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;o public.zp_orders;old public.zp_cash_receipts;line jsonb;normalized jsonb:='[]';old_tenders jsonb;method text;ref text;amt bigint;total bigint:=0;rid uuid;pos int:=0;begin
 m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
 if p_request is null or jsonb_typeof(p_tenders) is distinct from 'array' then raise exception 'INVALID_TENDERS';end if;
 if jsonb_array_length(p_tenders) not between 2 and 5 then raise exception 'INVALID_TENDERS';end if;
 for line in select value from jsonb_array_elements(p_tenders) loop
  if jsonb_typeof(line)<>'object' or coalesce(line->>'amount_xaf','') !~ '^[1-9][0-9]{0,9}$' then raise exception 'INVALID_TENDERS';end if;
  method:=line->>'method';amt:=(line->>'amount_xaf')::bigint;ref:=case when method='cash' then null else trim(line->>'reference') end;
  if method is null or method not in ('cash','mtn_momo','orange_money','bank','card') or amt>2147483647 or (method<>'cash' and (ref is null or length(ref) not between 4 and 160)) then raise exception 'INVALID_TENDERS';end if;
  normalized:=normalized||jsonb_build_array(jsonb_build_object('method',method,'amount_xaf',amt,'reference',ref));total:=total+amt;
 end loop;
 if (select count(distinct value->>'method') from jsonb_array_elements(normalized))<2 then raise exception 'INVALID_TENDERS';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into c from public.zp_cash_sessions where id=p_cash and org_id=m.org_id and site_id=p_site for update;if c.id is null or not public.zp_cash_desk_access(m.id,c.id) then raise exception 'DENIED';end if;
 select * into old from public.zp_cash_receipts where member_id=m.id and request_id=p_request;
 if old.id is not null then
  select jsonb_agg(jsonb_build_object('method',t.method,'amount_xaf',t.amount_xaf,'reference',t.reference) order by t.position) into old_tenders from public.zp_cash_tenders t where t.receipt_id=old.id;
  if (old.site_id,old.cash_id,old.order_id,old.method,old_tenders) is distinct from (p_site,p_cash,p_order,'mixed',normalized) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;
 if o.id is null or o.status<>'served' or o.total_xaf<>total or exists(select 1 from public.zp_cash_receipts where order_id=p_order) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 insert into public.zp_cash_receipts(org_id,site_id,cash_id,order_id,member_id,request_id,method,amount_xaf,reference) values(m.org_id,p_site,c.id,o.id,m.id,p_request,'mixed',total,null) returning id into rid;
 for line in select value from jsonb_array_elements(normalized) loop
  method:=line->>'method';amt:=(line->>'amount_xaf')::bigint;ref:=line->>'reference';pos:=pos+1;
  if method<>'cash' then insert into public.zp_settlement_references values(m.org_id,method,ref);end if;
  insert into public.zp_cash_tenders(org_id,site_id,receipt_id,method,amount_xaf,reference,position) values(m.org_id,p_site,rid,method,amt,ref,pos);
 end loop;return rid;end $$;
create or replace function public.zp_close_cash(p_access text,p_site uuid,p_cash uuid,p_counted bigint) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;expected bigint;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') or p_counted<0 or p_counted is null then raise exception 'DENIED';end if;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null or not public.zp_cash_desk_access(m.id,c.id) then raise exception 'DENIED';end if;
 if c.closed_at is not null then if c.counted_xaf<>p_counted then raise exception 'CASH_CLOSED';end if;expected:=c.expected_xaf;
 else select c.opening_xaf+coalesce((select sum(amount_xaf) from public.zp_cash_receipts where cash_id=p_cash and method='cash'),0)+coalesce((select sum(t.amount_xaf) from public.zp_cash_tenders t join public.zp_cash_receipts r on r.id=t.receipt_id where r.cash_id=p_cash and t.method='cash'),0) into expected;
 update public.zp_cash_sessions set closed_at=clock_timestamp(),closed_by=m.id,counted_xaf=p_counted,expected_xaf=expected where id=p_cash;end if;
 return jsonb_build_object('expected_xaf',expected,'counted_xaf',p_counted,'variance_xaf',p_counted-expected);end $$;
create or replace function public.zp_record_sale(p_access text,p_site uuid,p_cash uuid,p_order uuid,p_request uuid,p_method text,p_amount bigint,p_ref text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;o public.zp_orders;r public.zp_cash_receipts;rid uuid;begin
 m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
 p_ref:=case when p_method='cash' then null else trim(p_ref) end;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null or not public.zp_cash_desk_access(m.id,c.id) then raise exception 'DENIED';end if;
 select * into r from public.zp_cash_receipts where member_id=m.id and request_id=p_request;
 if r.id is not null then if (r.cash_id,r.order_id,r.method,r.amount_xaf,r.reference) is distinct from (p_cash,p_order,p_method,p_amount,p_ref) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return r.id;end if;
 if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;
 if o.id is null or o.status<>'served' or p_amount is distinct from o.total_xaf or p_amount<=0 or (p_method<>'cash' and length(trim(coalesce(p_ref,'')))<4) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 if p_method<>'cash' then insert into public.zp_settlement_references values(m.org_id,p_method,p_ref);end if;
 insert into public.zp_cash_receipts(org_id,site_id,cash_id,order_id,member_id,request_id,method,amount_xaf,reference) values(m.org_id,p_site,c.id,o.id,m.id,p_request,p_method,p_amount,p_ref) returning id into rid;return rid;end $$;
create or replace function public.zp_record_group_sale(p_access text,p_site uuid,p_cash uuid,p_session uuid,p_orders uuid[],p_request uuid,p_method text,p_amount bigint,p_ref text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g public.zp_payment_groups;c public.zp_cash_sessions;o record;ids uuid[];total bigint;gid uuid;begin
 m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
 if p_orders is null or cardinality(p_orders) not between 1 and 50 or p_method is null or p_method not in ('cash','mtn_momo','orange_money','bank','card') or p_amount is null or p_amount<=0 then raise exception 'INVALID_GROUP';end if;
 select array_agg(distinct x order by x) into ids from unnest(p_orders) x;
 if cardinality(ids)<>cardinality(p_orders) or array_position(ids,null) is not null then raise exception 'INVALID_GROUP';end if;
 p_ref:=case when p_method='cash' then null else trim(p_ref) end;
 if p_method<>'cash' and (p_ref is null or length(p_ref) not between 4 and 160) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into g from public.zp_payment_groups where member_id=m.id and request_id=p_request;
 if g.id is not null then if (g.site_id,g.cash_id,g.table_session_id,g.order_ids,g.method,g.amount_xaf,g.reference) is distinct from (p_site,p_cash,p_session,ids,p_method,p_amount,p_ref) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return g.id;end if;
 select * into c from public.zp_cash_sessions where id=p_cash and org_id=m.org_id and site_id=p_site for update;
 if c.id is null or not public.zp_cash_desk_access(m.id,c.id) then raise exception 'DENIED';end if;if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 if not exists(select 1 from public.zp_table_sessions where id=p_session and org_id=m.org_id and site_id=p_site and closed_at is null) then raise exception 'DENIED';end if;
 perform 1 from public.zp_orders where id=any(ids) and org_id=m.org_id and site_id=p_site order by id for update;
 if (select count(*) from public.zp_orders where id=any(ids) and org_id=m.org_id and site_id=p_site and coalesce(billing_session_id,table_session_id)=p_session and status='served' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=zp_orders.id))<>cardinality(ids) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 select sum(total_xaf) into total from public.zp_orders where id=any(ids);
 if p_amount is distinct from total then raise exception 'SALE_NOT_SETTLEABLE';end if;
 if p_method<>'cash' then insert into public.zp_settlement_references values(m.org_id,p_method,p_ref);end if;
 insert into public.zp_payment_groups(org_id,site_id,cash_id,table_session_id,member_id,request_id,order_ids,method,reference,amount_xaf) values(m.org_id,p_site,p_cash,p_session,m.id,p_request,ids,p_method,p_ref,p_amount) returning id into gid;
 for o in select id,total_xaf from public.zp_orders where id=any(ids) order by id loop
 insert into public.zp_cash_receipts(org_id,site_id,cash_id,order_id,member_id,request_id,method,amount_xaf,reference,payment_group_id) values(m.org_id,p_site,p_cash,o.id,m.id,gen_random_uuid(),p_method,o.total_xaf,p_ref,gid);
 end loop;return gid;end $$;
create or replace function public.zp_business_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;mode jsonb;items jsonb;orders jsonb;tables jsonb;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'order') then raise exception 'DENIED';end if;
 select to_jsonb(s) into mode from public.zp_site_modes s where s.site_id=p_site and s.org_id=m.org_id;
 select coalesce(jsonb_agg(to_jsonb(i)||jsonb_build_object('sellable_qty',public.zp_sellable_qty(i.id),'channels',jsonb_build_object('table',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'table'),'qty',public.zp_sellable_channel_qty(i.id,'table'),'groups',public.zp_formula_groups_view(i.id,'table')),'counter',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'counter'),'qty',public.zp_sellable_channel_qty(i.id,'counter'),'groups',public.zp_formula_groups_view(i.id,'counter')),'takeaway',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'takeaway'),'qty',public.zp_sellable_channel_qty(i.id,'takeaway'),'groups',public.zp_formula_groups_view(i.id,'takeaway')))) order by i.name),'[]'::jsonb) into items from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id;
 select coalesce(jsonb_agg(x.data),'[]'::jsonb) into orders from (select jsonb_build_object('id',o.id,'number',o.service_number,'table_session_id',o.table_session_id,'initial_promised_at',o.initial_promised_at,'guest_served_at',o.guest_served_at,'priority',o.priority,'called_at',o.called_at,'no_show_at',o.no_show_at,'eta_saturated',o.eta_saturated,'channel',o.channel,'status',o.status,'total_xaf',o.total_xaf,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id),'promised_at',o.promised_at,'served_at',o.served_at,'created_at',o.created_at,'commercial_lines',o.commercial_lines,'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state,'line_total_xaf',l.line_total_xaf,'instructions',l.instructions)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id)) data from public.zp_orders o where o.site_id=p_site and o.org_id=m.org_id order by case when o.status in ('received','preparing','ready') then 0 else 1 end,o.priority desc,case when o.status in ('received','preparing','ready') then o.created_at end, o.created_at desc limit 100) x;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.label,'kind',t.kind,'session_id',(select id from public.zp_table_sessions s where s.table_id=t.id and s.closed_at is null))),'[]'::jsonb) into tables from public.zp_tables t where t.site_id=p_site and t.org_id=m.org_id;
 return jsonb_build_object('mode',mode,'operation_roles',coalesce((select jsonb_agg(role) from public.zp_operational_grants where site_id=p_site and member_id=m.id),'[]'::jsonb),'items',items,'orders',orders,'tables',tables,'cash_session',case when public.zp_can_operate(m.id,p_site,'cash') then (select jsonb_build_object('id',c.id,'opening_xaf',c.opening_xaf,'opened_at',c.opened_at) from public.zp_cash_sessions c where c.org_id=m.org_id and c.site_id=p_site and c.closed_at is null and c.desk_id is null) else null end,'plan',public.zp_paid_plan(m.org_id),'server_now',now());end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_cash_desks','zp_cash_tenders'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_cash_desk_access','zp_cash_desk_add','zp_cash_desk_open','zp_cash_desks_snapshot','zp_record_mixed_sale') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
