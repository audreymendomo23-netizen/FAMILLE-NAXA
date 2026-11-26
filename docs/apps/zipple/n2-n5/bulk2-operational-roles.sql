-- Explicit staff operational capabilities. Never imply ERP, administration or cross-site rights.
begin;
alter table public.zp_orders add column no_show_at timestamptz;
alter table public.zp_orders add column billing_session_id uuid references public.zp_table_sessions(id);
alter table public.zp_orders add foreign key(billing_session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id);
alter table public.zp_feedback add column reason text check(reason in ('wait','accuracy','quality','temperature','presentation','welcome','other'));
create table public.zp_bill_transfers(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,order_id uuid not null,source_session_id uuid not null,target_session_id uuid not null,member_id uuid not null,request_id uuid not null,reason text not null check(length(trim(reason)) between 5 and 500),created_at timestamptz not null default now(),unique(member_id,request_id),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),foreign key(source_session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id),foreign key(target_session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_operational_grants(org_id uuid not null,site_id uuid not null,member_id uuid not null,role text not null check(role in ('server','floor','cashier')),granted_by uuid not null,granted_at timestamptz not null default now(),primary key(site_id,member_id,role),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(granted_by,org_id) references public.zp_members(id,org_id));
create table public.zp_operational_grant_events(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,role text not null,enabled boolean not null,actor_id uuid not null,created_at timestamptz not null default now(),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(actor_id,org_id) references public.zp_members(id,org_id));
create function public.zp_operational_grant(p_access text,p_site uuid,p_member uuid,p_role text,p_enabled boolean) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);
 if m.role_code<>'promoteur' or public.zp_paid_plan(m.org_id)<>'PREMIUM' or p_role not in ('server','floor','cashier') or p_enabled is null then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_members x join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id where x.id=p_member and x.org_id=m.org_id and x.active and x.role_code='staff' and sc.site_id=p_site) then raise exception 'DENIED';end if;
 if p_enabled then insert into public.zp_operational_grants(org_id,site_id,member_id,role,granted_by) values(m.org_id,p_site,p_member,p_role,m.id) on conflict do nothing;else delete from public.zp_operational_grants where site_id=p_site and member_id=p_member and role=p_role;end if;
 insert into public.zp_operational_grant_events(org_id,site_id,member_id,role,enabled,actor_id) values(m.org_id,p_site,p_member,p_role,p_enabled,m.id);return true;end $$;
create function public.zp_can_operate(p_member uuid,p_site uuid,p_cap text) returns boolean language sql stable security invoker set search_path=pg_catalog,public as $$
 select exists(select 1 from public.zp_members m join public.zp_site_scopes sc on sc.member_id=m.id and sc.org_id=m.org_id where m.id=p_member and sc.site_id=p_site and m.active and not m.reset_pending and (m.role_code in ('promoteur','manager') or (m.role_code='staff' and exists(select 1 from public.zp_operational_grants g where g.org_id=m.org_id and g.site_id=p_site and g.member_id=m.id and case p_cap when 'order' then g.role in ('server','floor','cashier') when 'serve' then g.role in ('server','floor') when 'cash' then g.role='cashier' when 'floor' then g.role='floor' when 'table' then g.role in ('server','floor') when 'bill' then g.role in ('server','floor','cashier') when 'call' then g.role in ('server','floor','cashier') else false end))))
$$;
create or replace function public.zp_open_table(p_access text,p_site uuid,p_table uuid) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'table') then raise exception 'DENIED';end if;
 perform 1 from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if not found then raise exception 'DENIED';end if;
 select id into s from public.zp_table_sessions where table_id=p_table and closed_at is null;if s is not null then return s;end if;
 if exists(select 1 from public.zp_reservations where table_id=p_table and state='booked' and starts_at<=now()+interval '30 minutes' and ends_at>now()) then raise exception 'RESERVATION_UNAVAILABLE';end if;
 insert into public.zp_table_sessions(table_id,org_id,site_id) values(p_table,m.org_id,p_site) returning id into s;return s;end $$;
create function public.zp_bill_transfer(p_access text,p_site uuid,p_order uuid,p_source uuid,p_target uuid,p_request uuid,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;x public.zp_bill_transfers;begin
 m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'floor') and not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
 if p_source=p_target or p_source is null or p_target is null or length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'INVALID_BILL_TRANSFER';end if;
 perform 1 from public.zp_table_sessions where id in (p_source,p_target) and org_id=m.org_id and site_id=p_site order by id for update;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_bill_transfers where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.order_id,x.source_session_id,x.target_session_id,x.reason) is distinct from (p_order,p_source,p_target,trim(p_reason)) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return true;end if;
 if (select count(*) from public.zp_table_sessions z join public.zp_tables t on t.id=z.table_id where z.id in (p_source,p_target) and z.org_id=m.org_id and z.site_id=p_site and z.closed_at is null and t.kind='table')<>2 then raise exception 'INVALID_BILL_TRANSFER';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site and channel='table' and status<>'cancelled' and coalesce(billing_session_id,table_session_id)=p_source for update;
 if o.id is null or exists(select 1 from public.zp_cash_receipts where order_id=p_order) then raise exception 'INVALID_BILL_TRANSFER';end if;
 update public.zp_orders set billing_session_id=p_target where id=p_order;
 insert into public.zp_bill_transfers(org_id,site_id,order_id,source_session_id,target_session_id,member_id,request_id,reason) values(m.org_id,p_site,p_order,p_source,p_target,m.id,p_request,trim(p_reason));return true;
end $$;
create function public.zp_feedback_complete(p_guest_hash text,p_order uuid,p_rating int,p_comment text,p_reason text,p_ratings jsonb) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare inserted boolean;begin
 if p_reason is not null and p_reason not in ('wait','accuracy','quality','temperature','presentation','welcome','other') then raise exception 'INVALID_RATINGS';end if;
 if jsonb_typeof(p_ratings) is distinct from 'array' or jsonb_array_length(p_ratings)>5 then raise exception 'INVALID_RATINGS';end if;
 inserted:=public.zp_submit_feedback(p_guest_hash,p_order,p_rating,p_comment);
 if inserted then update public.zp_feedback set reason=p_reason where order_id=p_order;if jsonb_array_length(p_ratings)>0 then perform public.zp_guest_post_feedback(p_guest_hash,p_order,p_ratings);end if;end if;
 return inserted;
end $$;
create function public.zp_no_show(p_access text,p_site uuid,p_order uuid,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;begin
 m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'call') then raise exception 'DENIED';end if;
 if length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site and channel in ('counter','takeaway') and status='ready' and called_at is not null and guest_served_at is null for update;
 if o.id is null then raise exception 'DENIED';end if;if o.no_show_at is not null then return true;end if;
 update public.zp_orders set no_show_at=clock_timestamp() where id=o.id;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(o.id,m.org_id,p_site,m.id,'no_show',jsonb_build_object('reason',trim(p_reason)));return true;
end $$;
create function public.zp_station_window(p_access text,p_site uuid,p_item uuid,p_from time,p_until time) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_menu_items;y public.zp_menu_items;begin
 m:=public.zp_business_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;
 if x.id is null or (p_from is null)<>(p_until is null) or (p_from is not null and p_from=p_until) or (m.role_code not in ('promoteur','manager') and not exists(select 1 from public.zp_station_grants g where g.site_id=p_site and g.member_id=m.id and g.post=x.post)) then raise exception 'DENIED';end if;
 update public.zp_menu_items set available_from=p_from,available_until=p_until where id=x.id returning * into y;
 insert into public.zp_catalog_events(org_id,site_id,item_id,member_id,before_value,after_value) values(m.org_id,p_site,x.id,m.id,to_jsonb(x),to_jsonb(y));return true;
end $$;
create function public.zp_station_limit(p_access text,p_site uuid,p_item uuid,p_limit int) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_menu_items;y public.zp_menu_items;begin
 m:=public.zp_business_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;
 if x.id is null or x.kind='formula' or (p_limit is not null and p_limit not between 0 and x.available_qty) or (m.role_code not in ('promoteur','manager') and not exists(select 1 from public.zp_station_grants where site_id=p_site and member_id=m.id and post=x.post)) then raise exception 'DENIED';end if;
 update public.zp_menu_items set sale_limit=p_limit,sale_limit_epoch=gen_random_uuid() where id=x.id returning * into y;
 insert into public.zp_catalog_events(org_id,site_id,item_id,member_id,before_value,after_value) values(m.org_id,p_site,x.id,m.id,to_jsonb(x),to_jsonb(y));return true;
end $$;
create function public.zp_release_sale_limit() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin if old.status<>'cancelled' and new.status='cancelled' then update public.zp_menu_items i set sale_limit=i.sale_limit+l.qty from public.zp_order_lines l where l.order_id=new.id and l.item_id=i.id and i.sale_limit is not null and i.sale_limit_epoch=l.sale_limit_epoch;end if;return new;end $$;
create trigger zp_release_sale_limit_trigger after update of status on public.zp_orders for each row execute function public.zp_release_sale_limit();
create function public.zp_catalog_base_set(p_access text,p_site uuid,p_item uuid,p_name text,p_sku text,p_unit text,p_price int,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_menu_items;y public.zp_menu_items;begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 if length(trim(coalesce(p_name,''))) not between 1 and 160 or length(coalesce(p_sku,''))>80 or length(trim(coalesce(p_unit,''))) not between 1 and 80 or p_price is null or p_price<1 or length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'INVALID_PRICE_RULE';end if;
 select * into x from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 update public.zp_menu_items set name=trim(p_name),sku=trim(coalesce(p_sku,'')),sale_unit=trim(p_unit),price_xaf=p_price where id=x.id returning * into y;
 insert into public.zp_catalog_events(org_id,site_id,item_id,member_id,before_value,after_value) values(m.org_id,p_site,x.id,m.id,to_jsonb(x),to_jsonb(y)||jsonb_build_object('reason',trim(p_reason)));return true;
end $$;
create or replace function public.zp_close_table(p_access text,p_site uuid,p_table_session uuid) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'table') then raise exception 'DENIED';end if;
 perform 1 from public.zp_table_sessions where id=p_table_session and org_id=m.org_id and site_id=p_site and closed_at is null for update;if not found then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_orders o where (o.table_session_id=p_table_session or o.billing_session_id=p_table_session) and o.status<>'cancelled' and (o.status<>'served' or not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id))) then raise exception 'TABLE_HAS_OPEN_ORDERS';end if;
 update public.zp_table_sessions set closed_at=now() where id=p_table_session;return true;end $$;
create or replace function public.zp_open_cash(p_access text,p_site uuid,p_opening bigint) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
 insert into public.zp_cash_sessions(org_id,site_id,opened_by,opening_xaf) values(m.org_id,p_site,m.id,p_opening) returning id into c;return c;end $$;
create or replace function public.zp_close_cash(p_access text,p_site uuid,p_cash uuid,p_counted bigint) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;expected bigint;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') or p_counted<0 or p_counted is null then raise exception 'DENIED';end if;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null then raise exception 'DENIED';end if;
 if c.closed_at is not null then if c.counted_xaf<>p_counted then raise exception 'CASH_CLOSED';end if;expected:=c.expected_xaf;
 else select c.opening_xaf+coalesce(sum(amount_xaf),0) into expected from public.zp_cash_receipts where cash_id=p_cash and method='cash';
 update public.zp_cash_sessions set closed_at=clock_timestamp(),closed_by=m.id,counted_xaf=p_counted,expected_xaf=expected where id=p_cash;end if;
 return jsonb_build_object('expected_xaf',expected,'counted_xaf',p_counted,'variance_xaf',p_counted-expected);end $$;
create or replace function public.zp_record_sale(p_access text,p_site uuid,p_cash uuid,p_order uuid,p_request uuid,p_method text,p_amount bigint,p_ref text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;o public.zp_orders;r public.zp_cash_receipts;rid uuid;begin
 m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') then raise exception 'DENIED';end if;
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
 if c.id is null then raise exception 'DENIED';end if;if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
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
create or replace function public.zp_reserve_table(p_access text,p_site uuid,p_table uuid,p_request uuid,p_name text,p_party int,p_start timestamptz,p_end timestamptz) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;t public.zp_tables;x public.zp_reservations;i uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'floor') then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space='restaurant') then raise exception 'CHANNEL_DENIED';end if;
 select * into t from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if t.id is null then raise exception 'DENIED';end if;
 select * into x from public.zp_reservations where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.table_id,x.guest_name,x.party_size,x.starts_at,x.ends_at) is distinct from (p_site,p_table,trim(p_name),p_party,p_start,p_end) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if p_party is null or p_party not between 1 and t.seats or p_start is null or p_end is null or p_start<now() or p_end<=p_start or p_end-p_start>interval '12 hours' then raise exception 'RESERVATION_CAPACITY';end if;
 if exists(select 1 from public.zp_reservations where table_id=t.id and state in ('booked','seated') and starts_at<p_end and ends_at>p_start) then raise exception 'RESERVATION_OVERLAP';end if;
 insert into public.zp_reservations(org_id,site_id,table_id,member_id,request_id,guest_name,party_size,starts_at,ends_at) values(m.org_id,p_site,t.id,m.id,p_request,trim(p_name),p_party,p_start,p_end) returning id into i;return i;end $$;
create or replace function public.zp_reservation_transition(p_access text,p_site uuid,p_reservation uuid,p_next text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_reservations;t uuid;s uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'floor') then raise exception 'DENIED';end if;
 select table_id into t from public.zp_reservations where id=p_reservation and org_id=m.org_id and site_id=p_site;if t is null then raise exception 'DENIED';end if;
 perform 1 from public.zp_tables where id=t for update;
 select * into x from public.zp_reservations where id=p_reservation for update;
 if x.state=p_next then return x.state;end if;if x.state<>'booked' then raise exception 'INVALID_TRANSITION';end if;
 if p_next='seated' then
 if now()<x.starts_at-interval '30 minutes' or now()>=x.ends_at or exists(select 1 from public.zp_table_sessions where table_id=t and closed_at is null) or exists(select 1 from public.zp_reservations where table_id=t and id<>x.id and state='booked' and starts_at<=now() and ends_at>now()) then raise exception 'RESERVATION_UNAVAILABLE';end if;
 update public.zp_reservations set state='seated' where id=x.id;
 s:=public.zp_open_table(p_access,p_site,t);
 elsif p_next='expired' then if now()<x.ends_at then raise exception 'INVALID_TRANSITION';end if;
 elsif p_next<>'cancelled' or p_next is null then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_reservations set state=p_next,session_id=s where id=x.id;return p_next;end $$;
create or replace function public.zp_waitlist_add(p_access text,p_site uuid,p_request uuid,p_guest text,p_party int) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_waitlist;i uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'floor') then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space='restaurant') then raise exception 'CHANNEL_DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_waitlist where member_id=m.id and request_id=p_request;if x.id is not null then if (x.site_id,x.guest_name,x.party_size) is distinct from (p_site,trim(p_guest),p_party) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 insert into public.zp_waitlist(org_id,site_id,member_id,request_id,guest_name,party_size) values(m.org_id,p_site,m.id,p_request,trim(p_guest),p_party) returning id into i;return i;end $$;
create or replace function public.zp_waitlist_transition(p_access text,p_site uuid,p_wait uuid,p_next text,p_table uuid) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_waitlist;t public.zp_tables;s uuid;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'floor') then raise exception 'DENIED';end if;
 if p_next='seated' then select * into t from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site and kind='table' for update;if t.id is null then raise exception 'DENIED';end if;end if;
 select * into x from public.zp_waitlist where id=p_wait and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if x.state=p_next then return x.state;end if;if x.state<>'waiting' then raise exception 'INVALID_TRANSITION';end if;
 if p_next='seated' then
 if t.seats<x.party_size or exists(select 1 from public.zp_table_sessions where table_id=t.id and closed_at is null) then raise exception 'RESERVATION_UNAVAILABLE';end if;
 s:=public.zp_open_table(p_access,p_site,t.id);
 elsif p_next<>'cancelled' or p_next is null then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_waitlist set state=p_next,session_id=s where id=x.id;return p_next;end $$;
create or replace function public.zp_table_bill(p_access text,p_site uuid,p_session uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'bill') then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_table_sessions where id=p_session and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 return jsonb_build_object('total_xaf',(select coalesce(sum(total_xaf),0) from public.zp_orders where coalesce(billing_session_id,table_session_id)=p_session and status<>'cancelled'),'unpaid_xaf',(select coalesce(sum(o.total_xaf),0) from public.zp_orders o where coalesce(o.billing_session_id,o.table_session_id)=p_session and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)),'orders',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'number',o.service_number,'total_xaf',o.total_xaf,'status',o.status,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)) order by o.service_number) from public.zp_orders o where coalesce(o.billing_session_id,o.table_session_id)=p_session and o.status<>'cancelled'),'[]'::jsonb));end $$;
create or replace function public.zp_call_number(p_access text,p_site uuid,p_order uuid) returns timestamptz language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;ts timestamptz;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'call') then raise exception 'DENIED';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site and channel in ('counter','takeaway') and status='ready' for update;if o.id is null then raise exception 'DENIED';end if;
 if o.called_at is not null then return o.called_at;end if;
 update public.zp_orders set called_at=clock_timestamp() where id=o.id returning called_at into ts;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(o.id,m.org_id,p_site,m.id,'number_called',jsonb_build_object('number',o.service_number));return ts;end $$;
create or replace function public.zp_create_order(p_access text,p_guest_hash text,p_site uuid,p_channel text,p_table_session uuid,p_request uuid,p_lines jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g public.zp_guest_sessions;s public.zp_site_modes;org uuid;oid uuid;old public.zp_orders;line record;item public.zp_menu_items;total bigint:=0;body jsonb;commercial jsonb:='[]';guest_channel text;selection jsonb;req record;begin
 if (p_access is null)=(p_guest_hash is null) then raise exception 'DENIED';end if;
 if p_guest_hash is not null then
 select x.* into g from public.zp_guest_sessions x join public.zp_table_sessions ts on ts.id=x.table_session_id join public.zp_sites si on si.id=x.site_id join public.zp_organizations o on o.id=x.org_id where x.token_hash=p_guest_hash and x.expires_at>now() and ts.closed_at is null and si.active and o.active for update of ts;
 select case when t.kind='pickup' then 'counter' else 'table' end into guest_channel from public.zp_table_sessions ts join public.zp_tables t on t.id=ts.table_id where ts.id=g.table_session_id;
 if g.id is null or g.site_id<>p_site or p_channel is distinct from guest_channel or p_table_session is distinct from g.table_session_id then raise exception 'DENIED';end if;org:=g.org_id;
 else m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'order') then raise exception 'DENIED';end if;org:=m.org_id;end if;
 if public.zp_operational_plan(org) is null then raise exception 'SUBSCRIPTION_REQUIRED';end if;
 select * into s from public.zp_site_modes where site_id=p_site and org_id=org;
 if s.site_id is null or p_channel is null or p_channel not in ('table','counter','takeaway','delivery') or p_channel='delivery' then raise exception 'CHANNEL_DENIED';end if;
 if p_channel='table' or g.id is not null then perform 1 from public.zp_table_sessions where id=p_table_session and org_id=org and site_id=p_site and closed_at is null for update;if not found then raise exception 'TABLE_CLOSED';end if;
 if p_channel='table' and not exists(select 1 from public.zp_table_sessions ts join public.zp_tables t on t.id=ts.table_id where ts.id=p_table_session and t.kind='table') then raise exception 'CHANNEL_DENIED';end if;elsif p_table_session is not null then raise exception 'INVALID_TABLE';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) not between 1 and 50 then raise exception 'INVALID_LINES';end if;
 if exists(select 1 from jsonb_to_recordset(p_lines) as x(item_id uuid,qty int,note text) where x.item_id is null or x.qty is null or x.qty not between 1 and 1000 or length(coalesce(x.note,''))>500) then raise exception 'INVALID_QUANTITY';end if;
 -- Serializes duplicate submissions before stock changes, even for different requests.
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 body:=jsonb_build_object('site',p_site,'channel',p_channel,'table_session',p_table_session,'lines',p_lines);
 select * into old from public.zp_orders where request_id=p_request and ((m.id is not null and member_id=m.id) or (g.id is not null and guest_id=g.id));
 if old.id is not null then if old.request_body<>body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return jsonb_build_object('id',old.id,'total_xaf',old.total_xaf,'status',old.status);end if;
 insert into public.zp_orders(org_id,site_id,member_id,guest_id,table_session_id,request_id,request_body,channel) values(org,p_site,m.id,g.id,p_table_session,p_request,body,p_channel) returning id into oid;
 for req in select * from jsonb_to_recordset(p_lines) as x(item_id uuid,qty int,note text,choices jsonb) loop
 select * into item from public.zp_menu_items where id=req.item_id and org_id=org and site_id=p_site;
 if item.id is null or public.zp_sellable_channel_qty(item.id,p_channel)<req.qty then raise exception 'ITEM_UNAVAILABLE';end if;
 selection:=public.zp_resolve_selection(item.id,p_channel,req.choices);
 commercial:=commercial||jsonb_build_array(jsonb_build_object('item_id',item.id,'name',item.name,'qty',req.qty,'price_xaf',(selection->>'price_xaf')::bigint,'note',coalesce(req.note,''),'choices',selection->'choices','components',selection->'components'));
 total:=total+req.qty*(selection->>'price_xaf')::bigint;
 end loop;
 for line in
 with requests as (select x.*,q.ordinality from jsonb_array_elements(commercial) with ordinality as q(value,ordinality) cross join lateral jsonb_to_record(q.value) as x(item_id uuid,qty int,price_xaf bigint,note text,components jsonb)),
 weights as (select r.ordinality,c.item_id,r.qty::bigint*c.qty qty,r.qty::numeric*r.price_xaf price,coalesce(r.note,'') note,c.qty::numeric*public.zp_current_price(c.item_id,p_channel) weight from requests r cross join lateral jsonb_to_recordset(r.components) as c(item_id uuid,qty int)),
 expanded as (select w.*, (floor(price*sum(weight) over(partition by ordinality order by item_id)/sum(weight) over(partition by ordinality))-floor(price*(sum(weight) over(partition by ordinality order by item_id)-weight)/sum(weight) over(partition by ordinality)))::bigint allocation from weights w)
 select item_id,sum(qty)::bigint qty,sum(allocation)::bigint allocation,coalesce(jsonb_agg(jsonb_build_object('qty',qty,'note',note)) filter(where note<>''),'[]'::jsonb) instructions from expanded group by item_id order by item_id
 loop
 if line.qty not between 1 and 100000 then raise exception 'INVALID_QUANTITY';end if;
 update public.zp_menu_items set available_qty=available_qty-line.qty::int,sale_limit=case when sale_limit is null then null else sale_limit-line.qty::int end where id=line.item_id and org_id=org and site_id=p_site and kind<>'formula' and public.zp_item_open(id,p_channel) and available_qty>=line.qty and (sale_limit is null or sale_limit>=line.qty) returning * into item;
 if not found then raise exception 'ITEM_UNAVAILABLE';end if;
 insert into public.zp_order_lines(order_id,org_id,site_id,item_id,qty,unit_xaf,post,line_total_xaf,instructions,sale_limit_epoch) values(oid,org,p_site,item.id,line.qty::int,public.zp_current_price(item.id,p_channel),item.post,line.allocation,line.instructions,case when item.sale_limit is null then null else item.sale_limit_epoch end);
 end loop;
 if (select coalesce(sum(line_total_xaf),0) from public.zp_order_lines where order_id=oid)<>total then raise exception 'FORMULA_ALLOCATION_MISMATCH';end if;
 update public.zp_orders set total_xaf=total,commercial_lines=commercial where id=oid;
 return jsonb_build_object('id',oid,'total_xaf',total,'status','received');end $$;
create or replace function public.zp_advance_line(p_access text,p_site uuid,p_order uuid,p_item uuid,p_next text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;current_state text;overall text;begin m:=public.zp_business_actor(p_access,p_site);
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;if o.id is null or o.status='cancelled' then raise exception 'DENIED';end if;
 select state into current_state from public.zp_order_lines where order_id=p_order and item_id=p_item;if current_state is null or (m.role_code not in ('promoteur','manager') and not (p_next='served' and public.zp_can_operate(m.id,p_site,'serve')) and not exists(select 1 from public.zp_station_grants g join public.zp_order_lines l on l.post=g.post where g.site_id=p_site and g.member_id=m.id and l.order_id=p_order and l.item_id=p_item)) then raise exception 'DENIED';end if;
 if p_next='served' and o.channel='table' and exists(select 1 from public.zp_site_modes sm where sm.site_id=p_site and sm.org_id=m.org_id and sm.space='snack_bar') and not public.zp_can_operate(m.id,p_site,'serve') then raise exception 'DENIED';end if;
 if current_state=p_next then return o.status;end if;
 if not ((current_state='received' and p_next='preparing') or (current_state='preparing' and p_next='ready') or (current_state='ready' and p_next='served')) then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_order_lines set state=p_next where order_id=p_order and item_id=p_item;
 select case when bool_and(state='served') then 'served' when bool_and(state in ('ready','served')) then 'ready' when bool_and(state='received') then 'received' else 'preparing' end into overall from public.zp_order_lines where order_id=p_order;
 update public.zp_orders set status=overall,served_at=case when overall='served' then clock_timestamp() else served_at end where id=p_order;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'line_state',jsonb_build_object('item_id',p_item,'state',p_next));return overall;end $$;
create or replace function public.zp_business_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;mode jsonb;items jsonb;orders jsonb;tables jsonb;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'order') then raise exception 'DENIED';end if;
 select to_jsonb(s) into mode from public.zp_site_modes s where s.site_id=p_site and s.org_id=m.org_id;
 select coalesce(jsonb_agg(to_jsonb(i)||jsonb_build_object('sellable_qty',public.zp_sellable_qty(i.id),'channels',jsonb_build_object('table',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'table'),'qty',public.zp_sellable_channel_qty(i.id,'table'),'groups',public.zp_formula_groups_view(i.id,'table')),'counter',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'counter'),'qty',public.zp_sellable_channel_qty(i.id,'counter'),'groups',public.zp_formula_groups_view(i.id,'counter')),'takeaway',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'takeaway'),'qty',public.zp_sellable_channel_qty(i.id,'takeaway'),'groups',public.zp_formula_groups_view(i.id,'takeaway')))) order by i.name),'[]'::jsonb) into items from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id;
 select coalesce(jsonb_agg(x.data),'[]'::jsonb) into orders from (select jsonb_build_object('id',o.id,'number',o.service_number,'table_session_id',o.table_session_id,'initial_promised_at',o.initial_promised_at,'guest_served_at',o.guest_served_at,'priority',o.priority,'called_at',o.called_at,'no_show_at',o.no_show_at,'eta_saturated',o.eta_saturated,'channel',o.channel,'status',o.status,'total_xaf',o.total_xaf,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id),'promised_at',o.promised_at,'served_at',o.served_at,'created_at',o.created_at,'commercial_lines',o.commercial_lines,'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state,'line_total_xaf',l.line_total_xaf,'instructions',l.instructions)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id)) data from public.zp_orders o where o.site_id=p_site and o.org_id=m.org_id order by case when o.status in ('received','preparing','ready') then 0 else 1 end,o.priority desc,case when o.status in ('received','preparing','ready') then o.created_at end, o.created_at desc limit 100) x;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.label,'kind',t.kind,'session_id',(select id from public.zp_table_sessions s where s.table_id=t.id and s.closed_at is null))),'[]'::jsonb) into tables from public.zp_tables t where t.site_id=p_site and t.org_id=m.org_id;
 return jsonb_build_object('mode',mode,'operation_roles',coalesce((select jsonb_agg(role) from public.zp_operational_grants where site_id=p_site and member_id=m.id),'[]'::jsonb),'items',items,'orders',orders,'tables',tables,'cash_session',case when public.zp_can_operate(m.id,p_site,'cash') then (select jsonb_build_object('id',c.id,'opening_xaf',c.opening_xaf,'opened_at',c.opened_at) from public.zp_cash_sessions c where c.org_id=m.org_id and c.site_id=p_site and c.closed_at is null) else null end,'plan',public.zp_paid_plan(m.org_id),'server_now',now());end $$;
create or replace function public.zp_floor_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'bill') then raise exception 'DENIED';end if;return jsonb_build_object('staff',case when m.role_code='promoteur' then coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'login',x.login_id,'operations',coalesce((select jsonb_agg(g.role) from public.zp_operational_grants g where g.site_id=p_site and g.member_id=x.id),'[]'::jsonb),'posts',coalesce((select jsonb_agg(g.post) from public.zp_station_grants g where g.site_id=p_site and g.member_id=x.id),'[]'::jsonb))) from public.zp_members x join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id where x.org_id=m.org_id and x.active and x.role_code='staff' and sc.site_id=p_site),'[]'::jsonb) else '[]'::jsonb end,'zones',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.zp_zones where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'tables',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',label,'zone_id',zone_id,'seats',seats,'kind',kind)) from public.zp_tables where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'waitlist',case when public.zp_can_operate(m.id,p_site,'floor') then coalesce((select jsonb_agg(to_jsonb(w) order by w.created_at) from (select id,guest_name,party_size,state,created_at from public.zp_waitlist where org_id=m.org_id and site_id=p_site and state='waiting' order by created_at limit 200)w),'[]'::jsonb) else '[]'::jsonb end,'reservations',case when public.zp_can_operate(m.id,p_site,'floor') then coalesce((select jsonb_agg(to_jsonb(x) order by x.starts_at) from (select id,table_id,guest_name,party_size,starts_at,ends_at,state from public.zp_reservations where org_id=m.org_id and site_id=p_site and ends_at>now()-interval '7 days' order by starts_at limit 200)x),'[]'::jsonb) else '[]'::jsonb end);end $$;

-- Final station snapshot exposes the same table handoff capability as zp_advance_line.
create or replace function public.zp_station_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);
 return jsonb_build_object('server_now',now(),'posts',coalesce((select jsonb_agg(post) from public.zp_station_grants where member_id=m.id and site_id=p_site),'[]'::jsonb),'lines',coalesce((select jsonb_agg(jsonb_build_object('order_id',o.id,'number',o.service_number,'item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state,'handoff_allowed',(o.channel<>'table' or not exists(select 1 from public.zp_site_modes sm where sm.site_id=p_site and sm.space='snack_bar') or public.zp_can_operate(m.id,p_site,'serve')),'priority',o.priority,'instructions',l.instructions,'guest_served_at',o.guest_served_at,'promised_at',o.promised_at) order by o.priority desc,o.created_at) from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id join public.zp_menu_items i on i.id=l.item_id where l.org_id=m.org_id and l.site_id=p_site and o.status not in ('served','cancelled') and (m.role_code in ('promoteur','manager') or exists(select 1 from public.zp_station_grants g where g.member_id=m.id and g.site_id=p_site and g.post=l.post))),'[]'::jsonb),'categories',coalesce((select jsonb_agg(jsonb_build_object('category',c.category,'active',coalesce(k.active,true))) from (select distinct i.category from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id and (m.role_code in ('promoteur','manager') or not exists(select 1 from public.zp_menu_items j where j.site_id=p_site and j.org_id=m.org_id and j.category=i.category and not exists(select 1 from public.zp_station_grants g where g.site_id=p_site and g.member_id=m.id and g.post=j.post)))) c left join public.zp_category_controls k on k.site_id=p_site and k.category=c.category),'[]'::jsonb),'items',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'post',i.post,'active',i.active,'available_qty',i.available_qty,'sale_limit',i.sale_limit,'kind',i.kind,'available_from',i.available_from,'available_until',i.available_until)) from public.zp_menu_items i where i.org_id=m.org_id and i.site_id=p_site and (m.role_code in ('promoteur','manager') or exists(select 1 from public.zp_station_grants g where g.member_id=m.id and g.site_id=p_site and g.post=i.post))),'[]'::jsonb));end $$;

do $$ declare t text;f record;begin
 foreach t in array array['zp_operational_grants','zp_operational_grant_events','zp_bill_transfers'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_no_show','zp_station_window','zp_station_limit','zp_release_sale_limit','zp_catalog_base_set','zp_bill_transfer','zp_feedback_complete','zp_operational_grant','zp_can_operate','zp_open_table','zp_close_table','zp_open_cash','zp_close_cash','zp_record_sale','zp_record_group_sale','zp_reserve_table','zp_reservation_transition','zp_waitlist_add','zp_waitlist_transition','zp_table_bill','zp_call_number','zp_create_order','zp_advance_line','zp_business_snapshot','zp_floor_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
