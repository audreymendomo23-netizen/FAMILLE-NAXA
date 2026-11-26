-- Candidate operational extension. Uses N1 session scopes + paid business access.
begin;
alter table public.zp_orders add column promised_at timestamptz,add column served_at timestamptz;
alter table public.zp_order_lines add column state text not null default 'received' check(state in ('received','preparing','ready','served'));
create table public.zp_order_events(id uuid primary key default gen_random_uuid(),order_id uuid not null,org_id uuid not null,site_id uuid not null,member_id uuid not null,event_type text not null,payload jsonb not null default '{}',at timestamptz not null default now(),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_feedback(order_id uuid primary key,guest_id uuid not null,org_id uuid not null,site_id uuid not null,rating int not null check(rating between 1 and 5),comment text not null check(length(comment)<=1000),created_at timestamptz not null default now(),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),foreign key(guest_id,org_id,site_id) references public.zp_guest_sessions(id,org_id,site_id));
create table public.zp_cash_sessions(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,opened_by uuid not null,opening_xaf bigint not null check(opening_xaf>=0),opened_at timestamptz not null default now(),closed_at timestamptz,counted_xaf bigint,expected_xaf bigint,closed_by uuid,check(counted_xaf is null or counted_xaf>=0),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(opened_by,org_id) references public.zp_members(id,org_id),foreign key(closed_by,org_id) references public.zp_members(id,org_id));
create unique index zp_one_open_cash on public.zp_cash_sessions(site_id) where closed_at is null;
create table public.zp_cash_receipts(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,cash_id uuid not null,order_id uuid not null,member_id uuid not null,request_id uuid not null,method text not null check(method in ('cash','mtn_momo','orange_money','bank','card')),amount_xaf bigint not null check(amount_xaf>0),reference text,created_at timestamptz not null default now(),unique(order_id),unique(member_id,request_id),foreign key(cash_id,org_id,site_id) references public.zp_cash_sessions(id,org_id,site_id),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create unique index zp_cash_reference_unique on public.zp_cash_receipts(org_id,method,reference) where reference is not null and method<>'cash';
create function public.zp_manage_table(p_access text,p_site uuid,p_label text,p_qr_hash text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;t uuid;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;insert into public.zp_tables(org_id,site_id,label,qr_hash) values(m.org_id,p_site,trim(p_label),p_qr_hash) returning id into t;return t;end $$;
create function public.zp_open_table(p_access text,p_site uuid,p_table uuid) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s uuid;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 perform 1 from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if not found then raise exception 'DENIED';end if;
 select id into s from public.zp_table_sessions where table_id=p_table and closed_at is null;if s is not null then return s;end if;
 insert into public.zp_table_sessions(table_id,org_id,site_id) values(p_table,m.org_id,p_site) returning id into s;return s;end $$;
create function public.zp_close_table(p_access text,p_site uuid,p_table_session uuid) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 perform 1 from public.zp_table_sessions where id=p_table_session and org_id=m.org_id and site_id=p_site and closed_at is null for update;if not found then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_orders o where o.table_session_id=p_table_session and o.status<>'cancelled' and (o.status<>'served' or not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id))) then raise exception 'TABLE_HAS_OPEN_ORDERS';end if;
 update public.zp_table_sessions set closed_at=now() where id=p_table_session;return true;end $$;
create function public.zp_guest_menu(p_guest_hash text) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('site_id',g.site_id,'table_session_id',g.table_session_id,'site_name',s.name,'menu',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'price_xaf',i.price_xaf,'available',i.available_qty>0,'post',i.post) order by i.name) from public.zp_menu_items i where i.site_id=g.site_id and i.org_id=g.org_id and i.active),'[]'::jsonb))
 from public.zp_guest_sessions g join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=g.site_id join public.zp_organizations o on o.id=g.org_id where g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and o.active and public.zp_paid_plan(g.org_id) is not null
$$;
create function public.zp_set_service_delay(p_access text,p_site uuid,p_order uuid,p_minutes int) returns timestamptz language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;d timestamptz;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') or p_minutes is null or p_minutes not between 1 and 240 then raise exception 'DENIED';end if;
 update public.zp_orders set promised_at=clock_timestamp()+make_interval(mins=>p_minutes) where id=p_order and org_id=m.org_id and site_id=p_site and status in ('received','preparing','ready') returning promised_at into d;
 if d is null then raise exception 'DENIED';end if;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'delay',jsonb_build_object('minutes',p_minutes,'promised_at',d));return d;end $$;
create function public.zp_advance_line(p_access text,p_site uuid,p_order uuid,p_item uuid,p_next text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;current_state text;overall text;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;if o.id is null or o.status='cancelled' then raise exception 'DENIED';end if;
 select state into current_state from public.zp_order_lines where order_id=p_order and item_id=p_item;if current_state is null then raise exception 'DENIED';end if;
 if current_state=p_next then return o.status;end if;
 if not ((current_state='received' and p_next='preparing') or (current_state='preparing' and p_next='ready') or (current_state='ready' and p_next='served')) then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_order_lines set state=p_next where order_id=p_order and item_id=p_item;
 select case when bool_and(state='served') then 'served' when bool_and(state in ('ready','served')) then 'ready' when bool_and(state='received') then 'received' else 'preparing' end into overall from public.zp_order_lines where order_id=p_order;
 update public.zp_orders set status=overall,served_at=case when overall='served' then clock_timestamp() else served_at end where id=p_order;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'line_state',jsonb_build_object('item_id',p_item,'state',p_next));return overall;end $$;
create function public.zp_cancel_unprepared_order(p_access text,p_site uuid,p_order uuid,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') or length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;if o.id is null then raise exception 'DENIED';end if;
 if o.status='cancelled' then return false;end if;
 if o.status<>'received' or exists(select 1 from public.zp_cash_receipts where order_id=p_order) then raise exception 'CANCELLATION_REQUIRES_REVIEW';end if;
 update public.zp_menu_items i set available_qty=i.available_qty+l.qty from public.zp_order_lines l where l.order_id=p_order and l.item_id=i.id and i.org_id=m.org_id and i.site_id=p_site;
 update public.zp_orders set status='cancelled' where id=p_order;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'cancel',jsonb_build_object('reason',trim(p_reason)));return true;end $$;
create or replace function public.zp_guest_order(p_guest_hash text,p_order uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('id',o.id,'status',o.status,'total_xaf',o.total_xaf,'created_at',o.created_at,'promised_at',o.promised_at,'served_at',o.served_at,'server_now',now()) from public.zp_orders o join public.zp_guest_sessions g on g.id=o.guest_id join public.zp_table_sessions ts on ts.id=g.table_session_id join public.zp_sites si on si.id=o.site_id join public.zp_organizations org on org.id=o.org_id where o.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and ts.closed_at is null and si.active and org.active
$$;
create function public.zp_submit_feedback(p_guest_hash text,p_order uuid,p_rating int,p_comment text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare o public.zp_orders;begin
 select x.* into o from public.zp_orders x join public.zp_guest_sessions g on g.id=x.guest_id join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=x.site_id join public.zp_organizations org on org.id=x.org_id where x.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and org.active and x.status='served' for update of x;
 if o.id is null then raise exception 'DENIED';end if;
 insert into public.zp_feedback(order_id,guest_id,org_id,site_id,rating,comment) values(o.id,o.guest_id,o.org_id,o.site_id,p_rating,coalesce(p_comment,'')) on conflict(order_id) do nothing;return found;end $$;
create function public.zp_open_cash(p_access text,p_site uuid,p_opening bigint) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c uuid;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 insert into public.zp_cash_sessions(org_id,site_id,opened_by,opening_xaf) values(m.org_id,p_site,m.id,p_opening) returning id into c;return c;end $$;
-- Records money already received outside ZIPPLE, not an operator API payment confirmation.
create function public.zp_record_sale(p_access text,p_site uuid,p_cash uuid,p_order uuid,p_request uuid,p_method text,p_amount bigint,p_ref text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;o public.zp_orders;r public.zp_cash_receipts;rid uuid;begin
 m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null then raise exception 'DENIED';end if;
 select * into r from public.zp_cash_receipts where member_id=m.id and request_id=p_request;
 if r.id is not null then if (r.cash_id,r.order_id,r.method,r.amount_xaf,r.reference) is distinct from (p_cash,p_order,p_method,p_amount,p_ref) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return r.id;end if;
 if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;
 if o.id is null or o.status<>'served' or p_amount is distinct from o.total_xaf or p_amount<=0 or (p_method<>'cash' and length(trim(coalesce(p_ref,'')))<4) then raise exception 'SALE_NOT_SETTLEABLE';end if;
 insert into public.zp_cash_receipts(org_id,site_id,cash_id,order_id,member_id,request_id,method,amount_xaf,reference) values(m.org_id,p_site,c.id,o.id,m.id,p_request,p_method,p_amount,p_ref) returning id into rid;return rid;end $$;
create function public.zp_close_cash(p_access text,p_site uuid,p_cash uuid,p_counted bigint) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;expected bigint;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') or p_counted<0 or p_counted is null then raise exception 'DENIED';end if;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null then raise exception 'DENIED';end if;
 if c.closed_at is not null then if c.counted_xaf<>p_counted then raise exception 'CASH_CLOSED';end if;expected:=c.expected_xaf;
 else select c.opening_xaf+coalesce(sum(amount_xaf),0) into expected from public.zp_cash_receipts where cash_id=p_cash and method='cash';
 update public.zp_cash_sessions set closed_at=clock_timestamp(),closed_by=m.id,counted_xaf=p_counted,expected_xaf=expected where id=p_cash;end if;
 return jsonb_build_object('expected_xaf',expected,'counted_xaf',p_counted,'variance_xaf',p_counted-expected);end $$;
create function public.zp_business_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;mode jsonb;items jsonb;orders jsonb;tables jsonb;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 select to_jsonb(s) into mode from public.zp_site_modes s where s.site_id=p_site and s.org_id=m.org_id;
 select coalesce(jsonb_agg(to_jsonb(i) order by i.name),'[]'::jsonb) into items from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id;
 select coalesce(jsonb_agg(x.data),'[]'::jsonb) into orders from (select jsonb_build_object('id',o.id,'channel',o.channel,'status',o.status,'total_xaf',o.total_xaf,'promised_at',o.promised_at,'served_at',o.served_at,'created_at',o.created_at,'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id)) data from public.zp_orders o where o.site_id=p_site and o.org_id=m.org_id order by o.created_at desc limit 100) x;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.label,'session_id',(select id from public.zp_table_sessions s where s.table_id=t.id and s.closed_at is null))),'[]'::jsonb) into tables from public.zp_tables t where t.site_id=p_site and t.org_id=m.org_id;
 return jsonb_build_object('mode',mode,'items',items,'orders',orders,'tables',tables,'plan',public.zp_paid_plan(m.org_id),'server_now',now());end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_order_events','zp_feedback','zp_cash_sessions','zp_cash_receipts'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_manage_table','zp_open_table','zp_close_table','zp_guest_menu','zp_set_service_delay','zp_advance_line','zp_cancel_unprepared_order','zp_guest_order','zp_submit_feedback','zp_open_cash','zp_record_sale','zp_close_cash','zp_business_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
