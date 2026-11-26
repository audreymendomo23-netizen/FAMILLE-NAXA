-- Candidate: adapted NAXA reservation-slot lock and strict state transitions; N1 scope and NS stock guard.
begin;
create table public.zp_zones(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,name text not null check(length(trim(name)) between 1 and 80),unique(site_id,name),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
alter table public.zp_tables add column zone_id uuid,add column seats int not null default 4 check(seats between 1 and 100),add foreign key(zone_id,org_id,site_id) references public.zp_zones(id,org_id,site_id);
create table public.zp_reservations(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,table_id uuid not null,member_id uuid not null,request_id uuid not null,guest_name text not null check(length(trim(guest_name)) between 1 and 160),party_size int not null check(party_size between 1 and 100),starts_at timestamptz not null,ends_at timestamptz not null,check(ends_at>starts_at),state text not null default 'booked' check(state in ('booked','seated','cancelled','expired')),session_id uuid,unique(member_id,request_id),foreign key(table_id,org_id,site_id) references public.zp_tables(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id));
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
create function public.zp_floor_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);return jsonb_build_object('zones',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.zp_zones where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'tables',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',label,'zone_id',zone_id,'seats',seats)) from public.zp_tables where org_id=m.org_id and site_id=p_site),'[]'::jsonb),'reservations',coalesce((select jsonb_agg(to_jsonb(x) order by x.starts_at) from (select id,table_id,guest_name,party_size,starts_at,ends_at,state from public.zp_reservations where org_id=m.org_id and site_id=p_site and ends_at>now()-interval '7 days' order by starts_at limit 200)x),'[]'::jsonb));end $$;
-- Initial ETA is computed from the slowest parallel station (sum per station), bounded to 240 min.
create function public.zp_order_initial_eta() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
declare mins int;begin
 if new.initial_promised_at is null and new.total_xaf>0 then
 select least(240,greatest(1,coalesce(max(x.minutes),15)))::int into mins from (select sum(i.prep_minutes::bigint*l.qty) minutes from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=new.id group by l.post)x;
 new.initial_promised_at:=clock_timestamp()+make_interval(mins=>mins);new.promised_at:=new.initial_promised_at;
 end if;return new;end $$;
create trigger zp_initial_eta before update of total_xaf on public.zp_orders for each row execute function public.zp_order_initial_eta();
do $$ declare t text;f record;begin
 foreach t in array array['zp_zones','zp_reservations','zp_catalog_events'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_zone_add','zp_table_config','zp_reserve_table','zp_reservation_transition','zp_catalog_update','zp_floor_snapshot','zp_order_initial_eta') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
