-- Candidate: adapted NAXA reservation-slot lock and strict state transitions; N1 scope and NS stock guard.
begin;
create table public.zp_zones(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,name text not null check(length(trim(name)) between 1 and 80),unique(site_id,name),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
alter table public.zp_tables add column kind text not null default 'table' check(kind in ('table','pickup')),add column zone_id uuid,add column seats int not null default 4 check(seats between 1 and 100),add foreign key(zone_id,org_id,site_id) references public.zp_zones(id,org_id,site_id);
create table public.zp_reservations(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,table_id uuid not null,member_id uuid not null,request_id uuid not null,guest_name text not null check(length(trim(guest_name)) between 1 and 160),party_size int not null check(party_size between 1 and 100),starts_at timestamptz not null,ends_at timestamptz not null,check(ends_at>starts_at),state text not null default 'booked' check(state in ('booked','seated','completed','cancelled','expired')),session_id uuid,unique(member_id,request_id),foreign key(table_id,org_id,site_id) references public.zp_tables(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id));
create table public.zp_waitlist(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,guest_name text not null check(length(trim(guest_name)) between 1 and 160),party_size int not null check(party_size between 1 and 100),state text not null default 'waiting' check(state in ('waiting','seated','completed','cancelled')),session_id uuid,created_at timestamptz not null default now(),unique(member_id,request_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id));
create table public.zp_station_grants(org_id uuid not null,site_id uuid not null,member_id uuid not null,post text not null check(post in ('kitchen','bar','snack')),granted_by uuid not null,granted_at timestamptz not null default now(),primary key(site_id,member_id,post),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(granted_by,org_id) references public.zp_members(id,org_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
create table public.zp_station_grant_events(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,post text not null,enabled boolean not null,actor_id uuid not null,created_at timestamptz not null default now(),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(actor_id,org_id) references public.zp_members(id,org_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
create table public.zp_feedback_posts(order_id uuid not null,org_id uuid not null,site_id uuid not null,post text not null check(post in ('kitchen','bar','snack','service','counter')),rating int not null check(rating between 1 and 5),primary key(order_id,post),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id));
create table public.zp_catalog_events(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,item_id uuid not null,member_id uuid not null,before_value jsonb not null,after_value jsonb not null,created_at timestamptz not null default now(),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_zone_add(p_access text,p_site uuid,p_name text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);insert into public.zp_zones(org_id,site_id,name) values(m.org_id,p_site,trim(p_name)) returning id into i;return i;end $$;
create function public.zp_table_config(p_access text,p_site uuid,p_table uuid,p_zone uuid,p_seats int) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if not found then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_reservations where table_id=p_table and state='booked' and ends_at>now() and party_size>p_seats) then raise exception 'RESERVATION_CAPACITY';end if;
 update public.zp_tables set zone_id=p_zone,seats=p_seats where id=p_table;return true;end $$;
create function public.zp_reserve_table(p_access text,p_site uuid,p_table uuid,p_request uuid,p_name text,p_party int,p_start timestamptz,p_end timestamptz) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;t public.zp_tables;x public.zp_reservations;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space='restaurant') then raise exception 'CHANNEL_DENIED';end if;
 select * into t from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if t.id is null then raise exception 'DENIED';end if;
 select * into x from public.zp_reservations where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.table_id,x.guest_name,x.party_size,x.starts_at,x.ends_at) is distinct from (p_site,p_table,trim(p_name),p_party,p_start,p_end) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if p_party is null or p_party not between 1 and t.seats or p_start is null or p_end is null or p_start<now() or p_end<=p_start or p_end-p_start>interval '12 hours' then raise exception 'RESERVATION_CAPACITY';end if;
 if exists(select 1 from public.zp_reservations where table_id=t.id and state in ('booked','seated') and starts_at<p_end and ends_at>p_start) then raise exception 'RESERVATION_OVERLAP';end if;
 insert into public.zp_reservations(org_id,site_id,table_id,member_id,request_id,guest_name,party_size,starts_at,ends_at) values(m.org_id,p_site,t.id,m.id,p_request,trim(p_name),p_party,p_start,p_end) returning id into i;return i;end $$;
create function public.zp_reservation_transition(p_access text,p_site uuid,p_reservation uuid,p_next text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_reservations;t uuid;s uuid;begin m:=public.zp_erp_actor(p_access,p_site);
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
create function public.zp_catalog_update(p_access text,p_site uuid,p_item uuid,p_category text,p_subcategory text,p_description text,p_variant text,p_kind text,p_minutes int,p_low int,p_active boolean,p_from time,p_until time) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_menu_items;y public.zp_menu_items;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if (p_from is null)<>(p_until is null) or (p_from is not null and p_from=p_until) then raise exception 'INVALID_WINDOW';end if;
 update public.zp_menu_items set category=trim(p_category),subcategory=trim(p_subcategory),description=trim(p_description),variant=trim(p_variant),kind=p_kind,prep_minutes=p_minutes,low_threshold=p_low,active=p_active,available_from=p_from,available_until=p_until where id=x.id returning * into y;
 insert into public.zp_catalog_events(org_id,site_id,item_id,member_id,before_value,after_value) values(m.org_id,p_site,x.id,m.id,to_jsonb(x),to_jsonb(y));return true;end $$;
create function public.zp_station_grant(p_access text,p_site uuid,p_member uuid,p_post text,p_enabled boolean) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);
 if m.role_code<>'promoteur' or public.zp_paid_plan(m.org_id)<>'PREMIUM' or p_enabled is null then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_members x join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id where x.id=p_member and x.org_id=m.org_id and x.active and x.role_code='staff' and sc.site_id=p_site) then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_site_modes s where s.site_id=p_site and ((s.space='restaurant' and (p_post='kitchen' or (p_post='bar' and s.bar_enabled))) or (s.space='snack_bar' and p_post='snack'))) then raise exception 'POST_DENIED';end if;
 if p_enabled then insert into public.zp_station_grants(org_id,site_id,member_id,post,granted_by) values(m.org_id,p_site,p_member,p_post,m.id) on conflict do nothing;else delete from public.zp_station_grants where site_id=p_site and member_id=p_member and post=p_post;end if;
 insert into public.zp_station_grant_events(org_id,site_id,member_id,post,enabled,actor_id) values(m.org_id,p_site,p_member,p_post,p_enabled,m.id);return true;end $$;
create function public.zp_station_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);
 return jsonb_build_object('posts',coalesce((select jsonb_agg(post) from public.zp_station_grants where member_id=m.id and site_id=p_site),'[]'::jsonb),'lines',coalesce((select jsonb_agg(jsonb_build_object('order_id',o.id,'number',o.service_number,'item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state,'promised_at',o.promised_at)) from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id join public.zp_menu_items i on i.id=l.item_id where l.org_id=m.org_id and l.site_id=p_site and o.status not in ('served','cancelled') and (m.role_code in ('promoteur','manager') or exists(select 1 from public.zp_station_grants g where g.member_id=m.id and g.site_id=p_site and g.post=l.post))),'[]'::jsonb),'items',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'post',i.post,'active',i.active,'available_qty',i.available_qty)) from public.zp_menu_items i where i.org_id=m.org_id and i.site_id=p_site and (m.role_code in ('promoteur','manager') or exists(select 1 from public.zp_station_grants g where g.member_id=m.id and g.site_id=p_site and g.post=i.post))),'[]'::jsonb));end $$;
create function public.zp_station_availability(p_access text,p_site uuid,p_item uuid,p_active boolean) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_menu_items;y public.zp_menu_items;begin m:=public.zp_business_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;if x.id is null or p_active is null or (m.role_code not in ('promoteur','manager') and not exists(select 1 from public.zp_station_grants where site_id=p_site and member_id=m.id and post=x.post)) then raise exception 'DENIED';end if;
 update public.zp_menu_items set active=p_active where id=x.id returning * into y;
 insert into public.zp_catalog_events(org_id,site_id,item_id,member_id,before_value,after_value) values(m.org_id,p_site,x.id,m.id,to_jsonb(x),to_jsonb(y));return true;end $$;
create function public.zp_guest_post_feedback(p_guest_hash text,p_order uuid,p_ratings jsonb) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare o public.zp_orders;r record;begin
 select x.* into o from public.zp_orders x join public.zp_guest_sessions g on g.id=x.guest_id join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=x.site_id join public.zp_organizations org on org.id=x.org_id where x.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and org.active and public.zp_operational_plan(x.org_id) is not null and x.status<>'cancelled' and (x.status='served' or x.guest_served_at is not null) for update of x;
 if o.id is null then raise exception 'DENIED';end if;
 if jsonb_typeof(p_ratings) is distinct from 'array' or jsonb_array_length(p_ratings) not between 1 and 5 then raise exception 'INVALID_RATINGS';end if;
 for r in select * from jsonb_to_recordset(p_ratings) as x(post text,rating int) loop
 if r.rating is null or r.rating not between 1 and 5 or r.post is null or not (exists(select 1 from public.zp_order_lines where order_id=o.id and post=r.post) or (r.post='service' and o.channel='table') or (r.post='counter' and o.channel in ('counter','takeaway'))) then raise exception 'POST_DENIED';end if;
 insert into public.zp_feedback_posts values(o.id,o.org_id,o.site_id,r.post,r.rating) on conflict do nothing;
 end loop;return true;end $$;
create function public.zp_table_bill(p_access text,p_site uuid,p_session uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 if not exists(select 1 from public.zp_table_sessions where id=p_session and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 return jsonb_build_object('total_xaf',(select coalesce(sum(total_xaf),0) from public.zp_orders where table_session_id=p_session and status<>'cancelled'),'unpaid_xaf',(select coalesce(sum(o.total_xaf),0) from public.zp_orders o where o.table_session_id=p_session and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)),'orders',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'number',o.service_number,'total_xaf',o.total_xaf,'status',o.status,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)) order by o.service_number) from public.zp_orders o where o.table_session_id=p_session and o.status<>'cancelled'),'[]'::jsonb));end $$;
create function public.zp_pickup_create(p_access text,p_site uuid,p_label text,p_hash text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space='snack_bar') then raise exception 'CHANNEL_DENIED';end if;
 insert into public.zp_tables(org_id,site_id,label,qr_hash,kind,seats) values(m.org_id,p_site,trim(p_label),p_hash,'pickup',1) returning id into i;return i;end $$;
create function public.zp_waitlist_add(p_access text,p_site uuid,p_request uuid,p_guest text,p_party int) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_waitlist;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space='restaurant') then raise exception 'CHANNEL_DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_waitlist where member_id=m.id and request_id=p_request;if x.id is not null then if (x.site_id,x.guest_name,x.party_size) is distinct from (p_site,trim(p_guest),p_party) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 insert into public.zp_waitlist(org_id,site_id,member_id,request_id,guest_name,party_size) values(m.org_id,p_site,m.id,p_request,trim(p_guest),p_party) returning id into i;return i;end $$;
create function public.zp_waitlist_transition(p_access text,p_site uuid,p_wait uuid,p_next text,p_table uuid) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_waitlist;t public.zp_tables;s uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 if p_next='seated' then select * into t from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site and kind='table' for update;if t.id is null then raise exception 'DENIED';end if;end if;
 select * into x from public.zp_waitlist where id=p_wait and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if x.state=p_next then return x.state;end if;if x.state<>'waiting' then raise exception 'INVALID_TRANSITION';end if;
 if p_next='seated' then
 if t.seats<x.party_size or exists(select 1 from public.zp_table_sessions where table_id=t.id and closed_at is null) then raise exception 'RESERVATION_UNAVAILABLE';end if;
 s:=public.zp_open_table(p_access,p_site,t.id);
 elsif p_next<>'cancelled' or p_next is null then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_waitlist set state=p_next,session_id=s where id=x.id;return p_next;end $$;
create function public.zp_complete_floor_session() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin if old.closed_at is null and new.closed_at is not null then update public.zp_reservations set state='completed' where session_id=new.id and state='seated';update public.zp_waitlist set state='completed' where session_id=new.id and state='seated';end if;return new;end $$;
create trigger zp_complete_floor_session after update of closed_at on public.zp_table_sessions for each row execute function public.zp_complete_floor_session();
create function public.zp_table_rotate_qr(p_access text,p_site uuid,p_table uuid,p_hash text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if not found then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_table_sessions where table_id=p_table and closed_at is null) then raise exception 'TABLE_MUST_BE_CLOSED';end if;
 update public.zp_tables set qr_hash=p_hash where id=p_table;return true;end $$;
create function public.zp_floor_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);return jsonb_build_object('staff',case when m.role_code='promoteur' then coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'login',x.login_id,'posts',coalesce((select jsonb_agg(g.post) from public.zp_station_grants g where g.site_id=p_site and g.member_id=x.id),'[]'::jsonb))) from public.zp_members x join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id where x.org_id=m.org_id and x.active and x.role_code='staff' and sc.site_id=p_site),'[]'::jsonb) else '[]'::jsonb end,'zones',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.zp_zones where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'tables',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',label,'zone_id',zone_id,'seats',seats,'kind',kind)) from public.zp_tables where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'waitlist',coalesce((select jsonb_agg(to_jsonb(w) order by w.created_at) from (select id,guest_name,party_size,state,created_at from public.zp_waitlist where org_id=m.org_id and site_id=p_site and state='waiting' order by created_at limit 200)w),'[]'::jsonb),'reservations',coalesce((select jsonb_agg(to_jsonb(x) order by x.starts_at) from (select id,table_id,guest_name,party_size,starts_at,ends_at,state from public.zp_reservations where org_id=m.org_id and site_id=p_site and ends_at>now()-interval '7 days' order by starts_at limit 200)x),'[]'::jsonb));end $$;
-- Initial ETA is computed from the slowest parallel station (sum per station), bounded to 240 min.
create function public.zp_order_initial_eta() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
declare mins int;begin
 if new.initial_promised_at is null and new.total_xaf>0 then
 select least(240,greatest(1,coalesce(max(x.minutes),15)))::int into mins from (select sum(i.prep_minutes::bigint*l.qty) minutes from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=new.id group by l.post)x;
 new.initial_promised_at:=clock_timestamp()+make_interval(mins=>mins);new.promised_at:=new.initial_promised_at;
 end if;return new;end $$;
create trigger zp_initial_eta before update of total_xaf on public.zp_orders for each row execute function public.zp_order_initial_eta();
create or replace function public.zp_advance_line(p_access text,p_site uuid,p_order uuid,p_item uuid,p_next text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;current_state text;overall text;begin m:=public.zp_business_actor(p_access,p_site);
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;if o.id is null or o.status='cancelled' then raise exception 'DENIED';end if;
 select state into current_state from public.zp_order_lines where order_id=p_order and item_id=p_item;if current_state is null or (m.role_code not in ('promoteur','manager') and not exists(select 1 from public.zp_station_grants g join public.zp_order_lines l on l.post=g.post where g.site_id=p_site and g.member_id=m.id and l.order_id=p_order and l.item_id=p_item)) then raise exception 'DENIED';end if;
 if current_state=p_next then return o.status;end if;
 if not ((current_state='received' and p_next='preparing') or (current_state='preparing' and p_next='ready') or (current_state='ready' and p_next='served')) then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_order_lines set state=p_next where order_id=p_order and item_id=p_item;
 select case when bool_and(state='served') then 'served' when bool_and(state in ('ready','served')) then 'ready' when bool_and(state='received') then 'received' else 'preparing' end into overall from public.zp_order_lines where order_id=p_order;
 update public.zp_orders set status=overall,served_at=case when overall='served' then clock_timestamp() else served_at end where id=p_order;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'line_state',jsonb_build_object('item_id',p_item,'state',p_next));return overall;end $$;

create or replace function public.zp_open_table(p_access text,p_site uuid,p_table uuid) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s uuid;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 perform 1 from public.zp_tables where id=p_table and org_id=m.org_id and site_id=p_site for update;if not found then raise exception 'DENIED';end if;
 select id into s from public.zp_table_sessions where table_id=p_table and closed_at is null;if s is not null then return s;end if;
 if exists(select 1 from public.zp_reservations where table_id=p_table and state='booked' and starts_at<=now()+interval '30 minutes' and ends_at>now()) then raise exception 'RESERVATION_UNAVAILABLE';end if;
 insert into public.zp_table_sessions(table_id,org_id,site_id) values(p_table,m.org_id,p_site) returning id into s;return s;end $$;

do $$ declare t text;f record;begin
 foreach t in array array['zp_zones','zp_reservations','zp_catalog_events','zp_station_grants','zp_station_grant_events','zp_feedback_posts','zp_waitlist'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_zone_add','zp_table_config','zp_reserve_table','zp_reservation_transition','zp_catalog_update','zp_floor_snapshot','zp_order_initial_eta','zp_station_grant','zp_station_snapshot','zp_station_availability','zp_guest_post_feedback','zp_table_bill','zp_advance_line','zp_open_table','zp_table_rotate_qr','zp_pickup_create','zp_waitlist_add','zp_waitlist_transition','zp_complete_floor_session') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
