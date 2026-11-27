-- CANDIDATE ONLY. Execute on isolated PostgreSQL 17 after shared drafts 0001/0002/0003.
-- No hosted migration, no client service key. grillad_private must remain unexposed.
begin;
create schema grillad_private;
revoke all on schema grillad_private from public,anon,authenticated;
-- Explicit provisioning boundary: shared family locations alone do not grant GRILLAD access.
create table grillad_private.enabled_sites(org uuid not null,site uuid not null,enabled boolean not null default true,primary key(org,site),foreign key(site,org) references famille_core.locations(id,organization_id));
alter table grillad_private.enabled_sites enable row level security;
-- Exact product plan identifiers. Do not overwrite an existing catalog price.
insert into famille_core.plans(app_id,code,name,amount_fcfa,billing_period)
select a.id,p.code,p.name,p.amount,p.cycle from famille_core.applications a cross join (values
 ('grillad_access_month','GRILLAD ACCÈS mensuel',2000,'monthly'),
 ('grillad_access_year','GRILLAD ACCÈS annuel',24000,'yearly'),
 ('grillad_premium_month','GRILLAD PREMIUM mensuel',6000,'monthly'),
 ('grillad_premium_year','GRILLAD PREMIUM annuel',60000,'yearly')
) p(code,name,amount,cycle) where a.code='grillad' on conflict(app_id,code) do nothing;
create table grillad_private.items(
 id uuid primary key, org uuid not null, site uuid not null, name text not null check(length(name) between 1 and 160),
 family text not null check(family in ('Porc','Poulet','Poisson','Brochettes','Omelettes')),
 price bigint not null check(price between 1 and 1000000000), cost bigint check(cost between 0 and 1000000000),
 prepared bigint not null default 0 check(prepared>=0), sold bigint not null default 0 check(sold between 0 and prepared),
 active boolean not null default true, unique(id,org,site),
 foreign key(site,org) references famille_core.locations(id,organization_id)
);
create table grillad_private.cash(
 id uuid primary key,org uuid not null,site uuid not null,opening bigint not null check(opening>=0),
 opened_by uuid not null,opened_at timestamptz not null default now(), closed_at timestamptz,
 counted bigint check(counted>=0),expected bigint, close_reason text,
 unique(id,org,site),foreign key(site,org) references famille_core.locations(id,organization_id)
);
create unique index grillad_one_cash on grillad_private.cash(org,site) where closed_at is null;
create table grillad_private.preparations(
 id uuid primary key,org uuid not null,site uuid not null,item uuid not null,qty bigint not null check(qty>0),
 actor uuid not null,created_at timestamptz not null default now(),
 foreign key(item,org,site) references grillad_private.items(id,org,site)
);
create table grillad_private.sales(
 id uuid primary key,org uuid not null,site uuid not null,item uuid not null,cash uuid not null,
 actor uuid not null,qty bigint not null check(qty>0),price bigint not null check(price>0),
 cost bigint, total bigint generated always as (qty*price) stored,
 created_at timestamptz not null default now(),cancelled_at timestamptz,cancelled_by uuid,cancel_reason text,
 foreign key(item,org,site) references grillad_private.items(id,org,site),
 foreign key(cash,org,site) references grillad_private.cash(id,org,site)
);
create table grillad_private.expenses(
 id uuid primary key,org uuid not null,site uuid not null,cash uuid not null,
 actor uuid not null,label text not null check(length(label) between 1 and 160),value bigint not null check(value>0),
 created_at timestamptz not null default now(),foreign key(cash,org,site) references grillad_private.cash(id,org,site)
);
create table grillad_private.events(
 org uuid not null,site uuid not null,id uuid not null,actor uuid not null,action text not null,payload jsonb not null,
 result jsonb not null,created_at timestamptz not null default now(),primary key(org,site,id),
 foreign key(site,org) references famille_core.locations(id,organization_id)
);
create table grillad_private.targets(org uuid not null,site uuid not null,day date not null,amount bigint not null check(amount>=0),primary key(org,site,day),foreign key(site,org) references famille_core.locations(id,organization_id));
alter table grillad_private.items enable row level security;
alter table grillad_private.cash enable row level security;
alter table grillad_private.preparations enable row level security;
alter table grillad_private.sales enable row level security;
alter table grillad_private.expenses enable row level security;
alter table grillad_private.events enable row level security;
alter table grillad_private.targets enable row level security;
revoke all on all tables in schema grillad_private from public,anon,authenticated;
-- Scope requires live session, signed GRILLAD app claim, active client grant, subscription and membership.
create function grillad_private.scope(p_org uuid,p_site uuid) returns text
language plpgsql stable security definer set search_path=pg_catalog as $$
declare u uuid:=auth.uid(); a uuid; sid uuid; r text; plan_code text; plan_count bigint;
begin
 if u is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then raise exception 'GRILLAD_AUTH' using errcode='42501'; end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid; exception when invalid_text_representation then raise exception 'GRILLAD_AUTH' using errcode='42501'; end;
 if sid is null or not exists(select 1 from auth.sessions where id=sid and user_id=u) then raise exception 'GRILLAD_SESSION' using errcode='42501'; end if;
 select id into a from famille_core.applications where code='grillad' and status='active';
 if a is null or famille_core.current_app_id() is distinct from a or
 not exists(select 1 from famille_core.client_app_access where user_id=u and app_id=a and status='granted') or
 not exists(select 1 from famille_core.organizations where id=p_org and status='active') or
 not exists(select 1 from grillad_private.enabled_sites where org=p_org and site=p_site and enabled) or
 not famille_core.can_access_outlet(p_org,a,p_site) or not famille_core.subscription_allows_workspace(p_org,a) then
 raise exception 'GRILLAD_SCOPE' using errcode='42501'; end if;
 select count(*),min(p.code) into plan_count,plan_code from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id
 where s.organization_id=p_org and s.app_id=a and p.status='active'
 and ((s.status='active' and (s.starts_at is null or s.starts_at<=now()) and (s.ends_at is null or s.ends_at>=now())) or (s.status='past_due' and s.grace_until is not null and s.grace_until>=now()))
 and ((p.code='grillad_access_month' and p.amount_fcfa=2000 and p.billing_period='monthly') or (p.code='grillad_access_year' and p.amount_fcfa=24000 and p.billing_period='yearly') or (p.code='grillad_premium_month' and p.amount_fcfa=6000 and p.billing_period='monthly') or (p.code='grillad_premium_year' and p.amount_fcfa=60000 and p.billing_period='yearly'));
 if plan_count<>1 or (plan_code like 'grillad_access_%' and (select count(*) from grillad_private.enabled_sites where org=p_org and enabled)<>1) then raise exception 'GRILLAD_ENTITLEMENT' using errcode='42501';end if;
 select ra.role_code into r from famille_core.memberships m join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id and ra.organization_id=m.organization_id
 where m.user_id=u and m.app_id=a and m.organization_id=p_org and m.status='active' and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now())
 and ((ra.role_code='owner' and ra.location_id is null) or (ra.role_code in ('manager','seller') and ra.location_id=p_site))
 order by case ra.role_code when 'owner' then 1 when 'manager' then 2 else 3 end limit 1;
 if r is null then raise exception 'GRILLAD_ROLE' using errcode='42501'; end if;
 return r;
end $$;
insert into famille_core.role_catalog(app_id,role_code,display_name,scope_type,is_system)
 select id,'seller','Vendeur GRILLAD','location',true from famille_core.applications where code='grillad'
 on conflict(app_id,role_code) do nothing;
create function grillad_private.run(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text; u uuid:=auth.uid(); old grillad_private.events%rowtype; x grillad_private.items%rowtype; c grillad_private.cash%rowtype; v grillad_private.sales%rowtype;
 item_id uuid; qty bigint; n bigint; cost bigint; label text; reason text; v_expected bigint; result jsonb; d date;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_event is null or p_action is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>8192 then raise exception 'GRILLAD_INPUT' using errcode='22023';end if;
 if r='seller' and p_action not in ('sell','prepare') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 -- Serialize all mutations for the same site; no cross-site stock or drawer race.
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 select * into old from grillad_private.events where org=p_org and site=p_site and id=p_event;
 if found then
  if old.actor is distinct from u or old.action is distinct from p_action or old.payload is distinct from p_payload then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023'; end if;
  return old.result;
 end if;
 if p_action in ('prepare','sell') then
  item_id:=(p_payload->>'item')::uuid; qty:=(p_payload->>'qty')::bigint;
  if qty is null or qty not between 1 and 1000000 then raise exception 'GRILLAD_QTY' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
 end if;
 if p_action in ('sell','expense','close_cash','cancel_sale') then
  select * into c from grillad_private.cash where org=p_org and site=p_site and closed_at is null;
  if not found then raise exception 'GRILLAD_CASH_CLOSED' using errcode='22023';end if;
 end if;
 case p_action
 when 'add_item' then
  label:=btrim(p_payload->>'name');n:=(p_payload->>'price')::bigint;cost:=(p_payload->>'cost')::bigint;
  if label is null or length(label) not between 1 and 160 or n is null or n not between 1 and 1000000000 or (cost is not null and cost not between 0 and 1000000000) then raise exception 'GRILLAD_ITEM' using errcode='22023';end if;
  insert into grillad_private.items(id,org,site,name,family,price,cost) values(p_event,p_org,p_site,label,p_payload->>'family',n,cost);
  result:=jsonb_build_object('id',p_event);
 when 'prepare' then
  update grillad_private.items set prepared=prepared+qty where id=x.id;
  insert into grillad_private.preparations values(p_event,p_org,p_site,x.id,qty,u,now());
  result:=jsonb_build_object('id',p_event,'remaining',x.prepared+qty-x.sold);
 when 'open_cash' then
  n:=(p_payload->>'opening')::bigint;if n is null or n not between 0 and 1000000000 then raise exception 'GRILLAD_AMOUNT' using errcode='22023';end if;
  insert into grillad_private.cash(id,org,site,opening,opened_by) values(p_event,p_org,p_site,n,u);
  result:=jsonb_build_object('id',p_event);
 when 'sell' then
  if qty>x.prepared-x.sold then raise exception 'GRILLAD_STOCK' using errcode='22023';end if;
  insert into grillad_private.sales(id,org,site,item,cash,actor,qty,price,cost) values(p_event,p_org,p_site,x.id,c.id,u,qty,x.price,x.cost);
  update grillad_private.items set sold=sold+qty where id=x.id;
  result:=jsonb_build_object('id',p_event,'total',qty*x.price,'remaining',x.prepared-x.sold-qty);
 when 'cancel_sale' then
  reason:=btrim(p_payload->>'reason');if reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  select * into v from grillad_private.sales where id=(p_payload->>'sale')::uuid and org=p_org and site=p_site and cash=c.id and cancelled_at is null;
  if not found then raise exception 'GRILLAD_SALE' using errcode='22023';end if;
  update grillad_private.sales set cancelled_at=now(),cancelled_by=u,cancel_reason=reason where id=v.id;
  update grillad_private.items set sold=sold-v.qty where id=v.item;
  result:=jsonb_build_object('id',v.id,'cancelled',true);
 when 'expense' then
  label:=btrim(p_payload->>'label');n:=(p_payload->>'value')::bigint;
  if label is null or length(label) not between 1 and 160 or n is null or n not between 1 and 1000000000 then raise exception 'GRILLAD_EXPENSE' using errcode='22023';end if;
  insert into grillad_private.expenses(id,org,site,cash,actor,label,value) values(p_event,p_org,p_site,c.id,u,label,n);
  result:=jsonb_build_object('id',p_event);
 when 'close_cash' then
  n:=(p_payload->>'counted')::bigint;reason:=btrim(p_payload->>'reason');
  if n is null or n<0 then raise exception 'GRILLAD_AMOUNT' using errcode='22023';end if;
  v_expected:=c.opening+coalesce((select sum(total) from grillad_private.sales where cash=c.id and cancelled_at is null),0)-coalesce((select sum(value) from grillad_private.expenses where cash=c.id),0);
  if n<>v_expected and (reason is null or length(reason) not between 1 and 300) then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  update grillad_private.cash set counted=n,expected=v_expected,closed_at=now(),close_reason=reason where id=c.id;
  result:=jsonb_build_object('id',c.id,'expected',v_expected,'counted',n,'difference',n-v_expected);
 when 'target' then
  d:=(p_payload->>'day')::date;n:=(p_payload->>'amount')::bigint;
  if d is null or n is null or n not between 0 and 1000000000 then raise exception 'GRILLAD_TARGET' using errcode='22023';end if;
  insert into grillad_private.targets values(p_org,p_site,d,n) on conflict(org,site,day) do update set amount=excluded.amount;
  result:=jsonb_build_object('day',d,'amount',n);
 else raise exception 'GRILLAD_ACTION' using errcode='22023';
 end case;
 insert into grillad_private.events values(p_org,p_site,p_event,u,p_action,p_payload,result,now());
 return result;
end $$;
-- Read only own site; seller gets no costs, expenses, manager totals, or other sellers' sales.
create function grillad_private.snapshot(p_org uuid,p_site uuid,p_from date,p_to date)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();v_items jsonb;v_sales jsonb;v_finance jsonb;v_cash jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'GRILLAD_PERIOD' using errcode='22023';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'family',i.family,'price',i.price,'prepared',i.prepared,'sold',i.sold,'remaining',i.prepared-i.sold)||case when r='seller' then '{}'::jsonb else jsonb_build_object('cost',i.cost) end order by i.name),'[]'::jsonb) into v_items from grillad_private.items i where org=p_org and site=p_site and active;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'item',s.item,'qty',s.qty,'total',s.total,'actor',s.actor,'at',s.created_at,'cancelled',s.cancelled_at is not null) order by s.created_at desc),'[]'::jsonb) into v_sales from (select * from grillad_private.sales where org=p_org and site=p_site and (r<>'seller' or actor=u) and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) s;
 if r<>'seller' then
 select jsonb_build_object('ca',coalesce(sum(total),0),'sales_count',count(*),'cost',case when count(*) filter(where cost is null)>0 then null else coalesce(sum(qty*cost),0) end,'charges',(select coalesce(sum(value),0) from grillad_private.expenses where org=p_org and site=p_site and (created_at at time zone 'Africa/Douala')::date between p_from and p_to)) into v_finance from grillad_private.sales where org=p_org and site=p_site and cancelled_at is null and (created_at at time zone 'Africa/Douala')::date between p_from and p_to;
 select jsonb_build_object('id',c.id,'opening',c.opening,'expected',c.opening+coalesce((select sum(total) from grillad_private.sales where cash=c.id and cancelled_at is null),0)-coalesce((select sum(value) from grillad_private.expenses where cash=c.id),0)) into v_cash from grillad_private.cash c where org=p_org and site=p_site and closed_at is null;
 else select jsonb_build_object('id',c.id) into v_cash from grillad_private.cash c where org=p_org and site=p_site and closed_at is null;
 end if;
 return jsonb_build_object('role',r,'items',v_items,'sales',v_sales,'finance',v_finance,'cash',v_cash,'from',p_from,'to',p_to,'generated_at',now());
end $$;
-- Server-derived workspace list. No arbitrary organization/site values from login.
create function grillad_private.workspace() returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $
declare s record;r text;out jsonb:='[]'::jsonb;
begin
 if auth.uid() is null or not exists(select 1 from famille_core.applications where code='grillad' and id=famille_core.current_app_id()) then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 for s in select e.org,e.site,l.name,o.legal_name from grillad_private.enabled_sites e join famille_core.locations l on l.id=e.site and l.organization_id=e.org join famille_core.organizations o on o.id=e.org where e.enabled and exists(select 1 from famille_core.memberships m where m.user_id=auth.uid() and m.organization_id=e.org and m.app_id=famille_core.current_app_id() and m.status='active') order by l.name,e.site loop
  begin r:=grillad_private.scope(s.org,s.site);out:=out||jsonb_build_array(jsonb_build_object('org',s.org,'site',s.site,'name',s.name,'organization',s.legal_name,'role',r));exception when insufficient_privilege then null;end;
 end loop;
 return out;
end $;
create function public.grillad_workspace() returns jsonb language sql stable security invoker set search_path=pg_catalog as $select grillad_private.workspace()$;
-- Explicit narrow public RPCs are invoker wrappers. All authorization lives inside private functions.
create function public.grillad_action(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb)
returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.run(p_org,p_site,p_event,p_action,p_payload)$$;
create function public.grillad_snapshot(p_org uuid,p_site uuid,p_from date,p_to date)
returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.snapshot(p_org,p_site,p_from,p_to)$$;
revoke all on all functions in schema grillad_private from public,anon,authenticated;
grant usage on schema grillad_private to authenticated;
grant execute on function grillad_private.workspace() to authenticated;
revoke all on function public.grillad_workspace() from public,anon,authenticated;
grant execute on function public.grillad_workspace() to authenticated;
grant execute on function grillad_private.run(uuid,uuid,uuid,text,jsonb),grillad_private.snapshot(uuid,uuid,date,date) to authenticated;
revoke all on function public.grillad_action(uuid,uuid,uuid,text,jsonb),public.grillad_snapshot(uuid,uuid,date,date) from public,anon,authenticated;
grant execute on function public.grillad_action(uuid,uuid,uuid,text,jsonb),public.grillad_snapshot(uuid,uuid,date,date) to authenticated;
commit;
