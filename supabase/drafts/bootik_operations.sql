-- Isolated BOOTIK operational candidate; trusted server only, no hosted application.
begin;
create table bootik.bk_members (
 organization_id uuid not null, app_id uuid not null, user_id uuid not null references auth.users(id),
 role text not null check(role in ('promoteur','manager','staff')), active boolean not null default true,
 primary key(organization_id,app_id,user_id), foreign key(organization_id,app_id) references bootik.bk_organizations(organization_id,app_id)
);
create table bootik.bk_member_sites (
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,location_id uuid not null,
 primary key(organization_id,app_id,user_id,location_id),
 foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id),
 foreign key(location_id,organization_id,app_id) references bootik.bk_locations(id,organization_id,app_id)
);
-- Site-wide assignments remain explicit; restricted assignments need a matching activity.
alter table bootik.bk_member_sites add column activity_restricted boolean not null default false;
create table bootik.bk_member_activity_scopes (
 organization_id uuid not null, app_id uuid not null, user_id uuid not null, location_id uuid not null, activity_id uuid not null,
 primary key(organization_id,app_id,user_id,location_id,activity_id),
 foreign key(organization_id,app_id,user_id,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
alter table bootik.bk_member_activity_scopes enable row level security;
alter table bootik.bk_member_activity_scopes force row level security;
revoke all on bootik.bk_member_activity_scopes from public,anon,authenticated;
create function bootik.bk_can_access_activity(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_activity uuid)
returns boolean language sql stable security invoker set search_path=pg_catalog,bootik as $$
 select p_activity is not null and exists (
 select 1 from bootik.bk_member_sites s join bootik.bk_members m using(organization_id,app_id,user_id)
 where s.organization_id=p_org and s.app_id=p_app and s.user_id=p_actor and s.location_id=p_site and m.active
 and (not s.activity_restricted or exists (
 select 1 from bootik.bk_member_activity_scopes a where a.organization_id=p_org and a.app_id=p_app and a.user_id=p_actor and a.location_id=p_site and a.activity_id=p_activity)));
$$;
revoke all on function bootik.bk_can_access_activity(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;
create table bootik.bk_trials (
 organization_id uuid not null,app_id uuid not null,universe text not null check(universe in ('retailer','distributor')),
 plan text not null check(plan in ('access','premium')), activated_at timestamptz not null default now(),
 primary key(organization_id,app_id,universe),foreign key(organization_id,app_id) references bootik.bk_organizations(organization_id,app_id)
);
create table bootik.bk_sales (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,app_id uuid not null,activity_id uuid not null,location_id uuid not null,
 actor uuid not null,idempotency_key text not null, balance_id uuid not null references bootik.bk_inventory_balances(id),
 quantity numeric(20,6) not null check(quantity>0),unit_price_fcfa bigint not null check(unit_price_fcfa>=0),
 total_fcfa bigint not null check(total_fcfa>=0), created_at timestamptz not null default now(),
 unique(organization_id,app_id,idempotency_key),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
create table bootik.bk_support_requests (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,app_id uuid not null,location_id uuid not null,actor uuid not null,
 kind text not null check(kind in ('ticket','audio','video','screen','camera','alert')),
 consent_at timestamptz, revoked_at timestamptz, created_at timestamptz not null default clock_timestamp(),
 state text not null default 'requested' check(state in ('requested','cancelled','closed')),
 check(kind not in ('audio','video','screen') or consent_at is not null),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
create function bootik.bk_assert_scope(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_manager boolean default false)
returns void language plpgsql security invoker set search_path=pg_catalog,bootik as $$
begin
 if not exists(select 1 from bootik.bk_member_sites s join bootik.bk_members m using(organization_id,app_id,user_id)
 where s.organization_id=p_org and s.app_id=p_app and s.user_id=p_user and s.location_id=p_site and m.active
 and (not p_manager or m.role in ('promoteur','manager'))) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501'; end if;
end $$;
create function bootik.bk_quote(p_universe text,p_plan text,p_months integer)
returns bigint language plpgsql immutable security invoker set search_path=pg_catalog as $$
declare m bigint;
begin
 if p_months is null or p_months not in (1,12) then raise exception 'BOOTIK_INVALID_DURATION';end if;
 m:=case when p_universe='retailer' and p_plan='access' then 4000 when p_universe='retailer' and p_plan='premium' then 10000 when p_universe='distributor' and p_plan='access' then 10000 when p_universe='distributor' and p_plan='premium' then 25000 else null end;
 if m is null then raise exception 'BOOTIK_INVALID_OFFER';end if;
 return m * case when p_months=12 then 10 else 1 end;
end $$;
-- BOOTIK billing and canonical selling prices: trusted server contracts.
create table bootik.bk_paid_periods (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, app_id uuid not null,
 universe text not null check(universe in ('retailer','distributor')), plan text not null check(plan in ('access','premium')),
 months integer not null check(months in (1,12)), amount_fcfa bigint not null check(amount_fcfa>0),
 provider_reference text not null unique, starts_at timestamptz not null, ends_at timestamptz not null,
 revoked_at timestamptz, check(ends_at>starts_at),
 foreign key(organization_id,app_id) references bootik.bk_organizations(organization_id,app_id)
);
create function bootik.bk_start_trial(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_universe text,p_plan text)
returns timestamptz language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare v timestamptz;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_user,p_site,true);
 perform bootik.bk_quote(p_universe,p_plan,1);
 insert into bootik.bk_trials(organization_id,app_id,universe,plan) values(p_org,p_app,p_universe,p_plan) on conflict do nothing;
 select activated_at+interval '72 hours' into v from bootik.bk_trials where organization_id=p_org and app_id=p_app and universe=p_universe;
 return v;
end $$;
create function bootik.bk_has_entitlement(p_org uuid,p_app uuid,p_universe text)
returns boolean language sql stable security invoker set search_path=pg_catalog,bootik as $$
 select exists(select 1 from bootik.bk_trials where organization_id=p_org and app_id=p_app and universe=p_universe and activated_at<=now() and now()<activated_at+interval '72 hours')
 or exists(select 1 from bootik.bk_paid_periods where organization_id=p_org and app_id=p_app and universe=p_universe and revoked_at is null and starts_at<=now() and now()<ends_at);
$$;
create function bootik.bk_confirm_paid_period(p_org uuid,p_app uuid,p_universe text,p_plan text,p_months integer,p_amount bigint,p_reference text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare v uuid; old bootik.bk_paid_periods%rowtype; start_time timestamptz;
begin
 if p_amount is distinct from bootik.bk_quote(p_universe,p_plan,p_months) or nullif(btrim(p_reference),'') is null then raise exception 'BOOTIK_PAYMENT_MISMATCH';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_universe,1));
 select * into old from bootik.bk_paid_periods where provider_reference=p_reference;
 if found then
 if (old.organization_id,old.app_id,old.universe,old.plan,old.months,old.amount_fcfa) is distinct from (p_org,p_app,p_universe,p_plan,p_months,p_amount) then raise exception 'BOOTIK_PAYMENT_CONFLICT';end if;
 return old.id;end if;
 select greatest(now(),coalesce(max(ends_at),now())) into start_time from bootik.bk_paid_periods where organization_id=p_org and app_id=p_app and universe=p_universe and revoked_at is null;
 insert into bootik.bk_paid_periods(organization_id,app_id,universe,plan,months,amount_fcfa,provider_reference,starts_at,ends_at)
 values(p_org,p_app,p_universe,p_plan,p_months,p_amount,p_reference,start_time,start_time+make_interval(months=>p_months)) returning id into v;
 return v;
end $$;
create table bootik.bk_sale_prices (
 item_id uuid not null, organization_id uuid not null, activity_id uuid not null, app_id uuid not null,
 unit_price_fcfa bigint not null check(unit_price_fcfa>=0),
 primary key(item_id,organization_id,activity_id,app_id),
 foreign key(item_id,organization_id,activity_id,app_id) references bootik.bk_catalog_items(id,organization_id,activity_id,app_id)
);
create function bootik.bk_cancel_support(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_request uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,bootik as $$
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_user,p_site);
 update bootik.bk_support_requests set state='cancelled',revoked_at=clock_timestamp()
 where id=p_request and organization_id=p_org and app_id=p_app and actor=p_user and location_id=p_site and state='requested';
 return found;
end $$;

create function bootik.bk_record_sale(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_balance uuid,p_quantity numeric,p_price bigint,p_key text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare b bootik.bk_inventory_balances%rowtype; old bootik.bk_sales%rowtype; v_id uuid; v_unit text; v_total numeric; v_universe text; v_price bigint;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_user,p_site);
 if p_quantity is null or p_quantity<=0 or p_quantity<>round(p_quantity,6) or p_price is null or p_price<0 or nullif(btrim(p_key),'') is null then raise exception 'BOOTIK_INVALID_SALE';end if;
 if not bootik.bk_can_access_activity(p_org,p_app,p_user,p_site,(select activity_id from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_key,0));
 select * into old from bootik.bk_sales where organization_id=p_org and app_id=p_app and idempotency_key=p_key;
 if found then
 if (old.actor,old.location_id,old.balance_id,old.quantity,old.unit_price_fcfa) is distinct from (p_user,p_site,p_balance,p_quantity,p_price) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;
 return old.id;end if;
 select * into b from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site for update;
 if not found then raise exception 'BOOTIK_BALANCE_DENIED';end if;
 select universe_code into v_universe from bootik.bk_activities a where a.id=b.activity_id and a.status='active';
 if not found then raise exception 'BOOTIK_ACTIVITY_INACTIVE';end if;
 if not bootik.bk_has_entitlement(p_org,p_app,v_universe) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 select unit_price_fcfa into v_price from bootik.bk_sale_prices where item_id=b.item_id and organization_id=p_org and activity_id=b.activity_id and app_id=p_app;
 if not found or v_price is distinct from p_price then raise exception 'BOOTIK_PRICE_MISMATCH';end if;
 if b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged<p_quantity then raise exception 'BOOTIK_STOCK_INSUFFICIENT';end if;
 if b.lot_id is not null and not exists(select 1 from bootik.bk_product_lots l where l.id=b.lot_id and l.quality_state='available' and (l.expires_at is null or l.expires_at>=current_date)) then raise exception 'BOOTIK_LOT_UNAVAILABLE';end if;
 select base_unit_code into v_unit from bootik.bk_catalog_items where id=b.item_id and status='active' and (not is_serialized or p_quantity=1);
 if not found then raise exception 'BOOTIK_ITEM_UNAVAILABLE';end if;
 v_total:=p_quantity*p_price;if v_total<>round(v_total) then raise exception 'BOOTIK_FRACTIONAL_XAF';end if;
 insert into bootik.bk_sales(organization_id,app_id,activity_id,location_id,actor,idempotency_key,balance_id,quantity,unit_price_fcfa,total_fcfa)
 values(p_org,p_app,b.activity_id,p_site,p_user,p_key,p_balance,p_quantity,p_price,v_total::bigint) returning id into v_id;
 update bootik.bk_inventory_balances set quantity_on_hand=quantity_on_hand-p_quantity,updated_at=now() where id=p_balance;
 insert into bootik.bk_inventory_movements(app_id,organization_id,activity_id,location_id,item_id,lot_id,movement_code,quantity_delta,unit_code,source_reference,idempotency_key,actor_user_id)
 values(p_app,p_org,b.activity_id,p_site,b.item_id,b.lot_id,'sale',-p_quantity,v_unit,v_id::text,'sale:'||p_key,p_user);
 return v_id;
end $$;
create function bootik.bk_request_support(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_kind text,p_consent boolean)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare v uuid;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_user,p_site,p_kind='camera');
 if p_kind in ('audio','video','screen') and p_consent is distinct from true then raise exception 'BOOTIK_CONSENT_REQUIRED';end if;
 insert into bootik.bk_support_requests(organization_id,app_id,location_id,actor,kind,consent_at)
 values(p_org,p_app,p_site,p_user,p_kind,case when p_consent is true then clock_timestamp() end) returning id into v;
 return v;
end $$;
do $$ declare r record;begin for r in select tablename from pg_tables where schemaname='bootik' loop
 execute format('alter table bootik.%I enable row level security',r.tablename);
 execute format('alter table bootik.%I force row level security',r.tablename);
 execute format('revoke all on table bootik.%I from public,anon,authenticated',r.tablename);
 end loop;end $$;
revoke all on all functions in schema bootik from public,anon,authenticated;
commit;
