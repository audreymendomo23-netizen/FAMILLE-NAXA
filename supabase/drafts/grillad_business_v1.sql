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
 cost_basis text not null default 'manual' check(cost_basis in ('manual','composition_estimate')),cost_components jsonb,
 adjustment_net bigint not null default 0,
 prepared bigint not null default 0 check(prepared>=0), sold bigint not null default 0 check(sold between 0 and prepared),connect_reserved bigint not null default 0 check(connect_reserved>=0 and sold+connect_reserved<=prepared),
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
create table grillad_private.stock_adjustments(
 id uuid primary key,org uuid not null,site uuid not null,item uuid not null,delta bigint not null check(delta<>0),reason text not null check(length(reason) between 1 and 300),actor uuid not null,created_at timestamptz not null default now(),foreign key(item,org,site) references grillad_private.items(id,org,site)
);
create table grillad_private.sales(
 id uuid primary key,org uuid not null,site uuid not null,item uuid not null,cash uuid not null,
 actor uuid not null,qty bigint not null check(qty>0),price bigint not null check(price>0),
 cost bigint, total bigint generated always as (qty*price) stored,
 source text not null default 'direct' check(source in ('direct','connect')),connect_order uuid,direct_order uuid,check((source='connect')=(connect_order is not null)),check(direct_order is null or source='direct'),created_at timestamptz not null default now(),cancelled_at timestamptz,cancelled_by uuid,cancel_reason text,
 foreign key(item,org,site) references grillad_private.items(id,org,site),
 foreign key(cash,org,site) references grillad_private.cash(id,org,site)
);
create table grillad_private.expenses(
 id uuid primary key,org uuid not null,site uuid not null,cash uuid not null,
 actor uuid not null,label text not null check(length(label) between 1 and 160),value bigint not null check(value>0),
 created_at timestamptz not null default now(),cancelled_at timestamptz,cancelled_by uuid,cancel_reason text,
 check((cancelled_at is null and cancelled_by is null and cancel_reason is null) or (cancelled_at is not null and cancelled_by is not null and length(cancel_reason) between 1 and 300)),foreign key(cash,org,site) references grillad_private.cash(id,org,site)
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
alter table grillad_private.stock_adjustments enable row level security;
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
declare r text; u uuid:=auth.uid(); old grillad_private.events%rowtype; x grillad_private.items%rowtype; c grillad_private.cash%rowtype; v grillad_private.sales%rowtype;expense_row grillad_private.expenses%rowtype;
 item_id uuid; qty bigint; line jsonb; basket_total bigint; basket_count int; n bigint; cost bigint; new_cost_value bigint; component_total bigint;component_unknown boolean;component_value bigint;label text; reason text; v_expected bigint; result jsonb; d date;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_event is null or p_action is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>8192 then raise exception 'GRILLAD_INPUT' using errcode='22023';end if;
 if r='seller' and p_action not in ('sell','sell_basket','prepare','attendance_request') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
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
 if p_action in ('sell','sell_basket','expense','cancel_expense','close_cash','cancel_sale','cancel_basket') then
  select * into c from grillad_private.cash where org=p_org and site=p_site and closed_at is null;
  if not found then raise exception 'GRILLAD_CASH_CLOSED' using errcode='22023';end if;
 end if;
 case p_action
 when 'add_item' then
  label:=btrim(p_payload->>'name');n:=(p_payload->>'price')::bigint;cost:=(p_payload->>'cost')::bigint;
  if label is null or length(label) not between 1 and 160 or n is null or n not between 1 and 1000000000 or (cost is not null and cost not between 0 and 1000000000) then raise exception 'GRILLAD_ITEM' using errcode='22023';end if;
  insert into grillad_private.items(id,org,site,name,family,price,cost) values(p_event,p_org,p_site,label,p_payload->>'family',n,cost);
  result:=jsonb_build_object('id',p_event);
 when 'change_price' then
  item_id:=(p_payload->>'item')::uuid;n:=(p_payload->>'price')::bigint;reason:=btrim(p_payload->>'reason');
  if n is null or n not between 1 and 1000000000 or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_PRICE' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
  update grillad_private.items set price=n where id=x.id;
  result:=jsonb_build_object('id',x.id,'old_price',x.price,'new_price',n,'effective_at',now());
 when 'change_cost' then
  item_id:=(p_payload->>'item')::uuid;new_cost_value:=(p_payload->>'cost')::bigint;reason:=btrim(p_payload->>'reason');
  if not(p_payload?'cost') or (new_cost_value is not null and new_cost_value not between 0 and 1000000000) or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_COST' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
  update grillad_private.items set cost=new_cost_value,cost_basis='manual',cost_components=null where id=x.id;
  result:=jsonb_build_object('id',x.id,'old_cost',x.cost,'new_cost',new_cost_value,'effective_at',now());
 when 'set_cost_composition' then
  item_id:=(p_payload->>'item')::uuid;reason:=btrim(p_payload->>'reason');
  if jsonb_typeof(p_payload->'components') is distinct from 'array' or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_COST_COMPOSITION' using errcode='22023';end if;
  if jsonb_array_length(p_payload->'components') not between 1 and 30 then raise exception 'GRILLAD_COST_COMPOSITION' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
  component_total:=0;component_unknown:=false;
  for line in select value from jsonb_array_elements(p_payload->'components') loop
   if jsonb_typeof(line) is distinct from 'object' or jsonb_typeof(line->'label') is distinct from 'string' or length(btrim(line->>'label')) not between 1 and 160 or not(line?'amount') or jsonb_typeof(line->'amount') not in ('number','null') then raise exception 'GRILLAD_COST_COMPONENT' using errcode='22023';end if;
   if line->'amount'='null'::jsonb then component_unknown:=true;
   else
    if (line->>'amount') !~ '^[0-9]{1,10}$' then raise exception 'GRILLAD_COST_COMPONENT' using errcode='22023';end if;
    component_value:=(line->>'amount')::bigint;if component_value>1000000000 then raise exception 'GRILLAD_COST_COMPONENT' using errcode='22023';end if;
    component_total:=component_total+component_value;
   end if;
  end loop;
  if component_total>1000000000 then raise exception 'GRILLAD_COST_COMPONENT' using errcode='22023';end if;
  new_cost_value:=case when component_unknown then null else component_total end;
  update grillad_private.items set cost=new_cost_value,cost_basis='composition_estimate',cost_components=p_payload->'components' where id=x.id;
  result:=jsonb_build_object('id',x.id,'old_cost',x.cost,'new_cost',new_cost_value,'quality',case when component_unknown then 'incomplete' else 'estimated' end);
 when 'set_item_active' then
  item_id:=(p_payload->>'item')::uuid;reason:=btrim(p_payload->>'reason');
  if jsonb_typeof(p_payload->'active') is distinct from 'boolean' or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_ITEM_STATE' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
  if not (p_payload->>'active')::boolean and (x.prepared<>x.sold or x.connect_reserved<>0) then raise exception 'GRILLAD_ITEM_HAS_STOCK' using errcode='22023';end if;
  update grillad_private.items set active=(p_payload->>'active')::boolean where id=x.id;
  result:=jsonb_build_object('id',x.id,'active',(p_payload->>'active')::boolean,'old_active',x.active);
 when 'prepare' then
  update grillad_private.items set prepared=prepared+qty where id=x.id;
  insert into grillad_private.preparations values(p_event,p_org,p_site,x.id,qty,u,now());
  result:=jsonb_build_object('id',p_event,'remaining',x.prepared+qty-x.sold-x.connect_reserved);
 when 'adjust_stock' then
  item_id:=(p_payload->>'item')::uuid;n:=(p_payload->>'delta')::bigint;reason:=btrim(p_payload->>'reason');
  if n is null or n=0 or n not between -1000000 and 1000000 or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_ADJUSTMENT' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
  if x.prepared+n<x.sold+x.connect_reserved then raise exception 'GRILLAD_STOCK' using errcode='22023';end if;
  insert into grillad_private.stock_adjustments(id,org,site,item,delta,reason,actor) values(p_event,p_org,p_site,x.id,n,reason,u);
  update grillad_private.items set prepared=prepared+n,adjustment_net=adjustment_net+n where id=x.id;
  result:=jsonb_build_object('id',p_event,'delta',n,'remaining',x.prepared+n-x.sold-x.connect_reserved);
 when 'open_cash' then
  n:=(p_payload->>'opening')::bigint;if n is null or n not between 0 and 1000000000 then raise exception 'GRILLAD_AMOUNT' using errcode='22023';end if;
  insert into grillad_private.cash(id,org,site,opening,opened_by) values(p_event,p_org,p_site,n,u);
  result:=jsonb_build_object('id',p_event);
 when 'sell' then
  if qty>x.prepared-x.sold-x.connect_reserved then raise exception 'GRILLAD_STOCK' using errcode='22023';end if;
  insert into grillad_private.sales(id,org,site,item,cash,actor,qty,price,cost) values(p_event,p_org,p_site,x.id,c.id,u,qty,x.price,x.cost);
  update grillad_private.items set sold=sold+qty where id=x.id;
  result:=jsonb_build_object('id',p_event,'total',qty*x.price,'remaining',x.prepared-x.sold-x.connect_reserved-qty);
 when 'sell_basket' then
  if jsonb_typeof(p_payload->'lines') is distinct from 'array' then raise exception 'GRILLAD_BASKET' using errcode='22023';end if;
  basket_count:=jsonb_array_length(p_payload->'lines');
  if basket_count not between 1 and 20 or (select count(distinct z->>'item') from jsonb_array_elements(p_payload->'lines') z)<>basket_count then raise exception 'GRILLAD_BASKET' using errcode='22023';end if;
  basket_total:=0;
  for line in select value from jsonb_array_elements(p_payload->'lines') loop
   item_id:=(line->>'item')::uuid;qty:=(line->>'qty')::bigint;n:=(line->>'price')::bigint;
   if qty is null or qty not between 1 and 1000000 or n is null then raise exception 'GRILLAD_QTY' using errcode='22023';end if;
   select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
   if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
   if n<>x.price or qty>x.prepared-x.sold-x.connect_reserved then raise exception 'GRILLAD_PRICE_OR_STOCK' using errcode='22023';end if;
   insert into grillad_private.sales(id,org,site,item,cash,actor,qty,price,cost,direct_order) values(gen_random_uuid(),p_org,p_site,x.id,c.id,u,qty,x.price,x.cost,p_event);
   update grillad_private.items set sold=sold+qty where id=x.id;
   basket_total:=basket_total+qty*x.price;
  end loop;
  result:=jsonb_build_object('id',p_event,'total',basket_total,'lines',basket_count);
 when 'cancel_basket' then
  reason:=btrim(p_payload->>'reason');item_id:=(p_payload->>'sale')::uuid;
  if reason is null or length(reason) not between 1 and 300 or item_id is null then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  if not exists(select 1 from grillad_private.sales where org=p_org and site=p_site and direct_order=item_id and cash=c.id and cancelled_at is null) then raise exception 'GRILLAD_SALE' using errcode='22023';end if;
  for v in select * from grillad_private.sales where org=p_org and site=p_site and direct_order=item_id and cash=c.id and cancelled_at is null loop
   update grillad_private.sales set cancelled_at=now(),cancelled_by=u,cancel_reason=reason where id=v.id;
   update grillad_private.items set sold=sold-v.qty where id=v.item;
  end loop;
  result:=jsonb_build_object('id',item_id,'cancelled',true);
 when 'cancel_sale' then
  reason:=btrim(p_payload->>'reason');if reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  select * into v from grillad_private.sales where id=(p_payload->>'sale')::uuid and org=p_org and site=p_site and cash=c.id and cancelled_at is null and source='direct' and direct_order is null;
  if not found then raise exception 'GRILLAD_SALE' using errcode='22023';end if;
  update grillad_private.sales set cancelled_at=now(),cancelled_by=u,cancel_reason=reason where id=v.id;
  update grillad_private.items set sold=sold-v.qty where id=v.item;
  result:=jsonb_build_object('id',v.id,'cancelled',true);
 when 'expense' then
  label:=btrim(p_payload->>'label');n:=(p_payload->>'value')::bigint;
  if label is null or length(label) not between 1 and 160 or n is null or n not between 1 and 1000000000 then raise exception 'GRILLAD_EXPENSE' using errcode='22023';end if;
  insert into grillad_private.expenses(id,org,site,cash,actor,label,value) values(p_event,p_org,p_site,c.id,u,label,n);
  result:=jsonb_build_object('id',p_event);
 when 'cancel_expense' then
  item_id:=(p_payload->>'expense')::uuid;reason:=btrim(p_payload->>'reason');
  if reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  select * into expense_row from grillad_private.expenses where id=item_id and org=p_org and site=p_site and cash=c.id and cancelled_at is null;
  if not found then raise exception 'GRILLAD_EXPENSE' using errcode='22023';end if;
  update grillad_private.expenses set cancelled_at=now(),cancelled_by=u,cancel_reason=reason where id=expense_row.id;
  result:=jsonb_build_object('id',expense_row.id,'cancelled',true,'amount',expense_row.value);
 when 'close_cash' then
  n:=(p_payload->>'counted')::bigint;reason:=btrim(p_payload->>'reason');
  if n is null or n<0 then raise exception 'GRILLAD_AMOUNT' using errcode='22023';end if;
  v_expected:=c.opening+coalesce((select sum(total) from grillad_private.sales where cash=c.id and cancelled_at is null),0)-coalesce((select sum(value) from grillad_private.expenses where cash=c.id and cancelled_at is null),0);
  if n<>v_expected and (reason is null or length(reason) not between 1 and 300) then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  update grillad_private.cash set counted=n,expected=v_expected,closed_at=now(),close_reason=reason where id=c.id;
  result:=jsonb_build_object('id',c.id,'expected',v_expected,'counted',n,'difference',n-v_expected);
 when 'create_site' then
  if r<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  label:=btrim(p_payload->>'name');reason:=btrim(p_payload->>'reason');
  if label is null or length(label) not between 1 and 160 or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_SITE_INPUT' using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended('grillad-network:'||p_org::text,0));
  if not exists(select 1 from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id join famille_core.applications a on a.id=s.app_id where s.organization_id=p_org and a.code='grillad' and p.status='active' and ((s.status='active' and (s.starts_at is null or s.starts_at<=now()) and (s.ends_at is null or s.ends_at>=now())) or (s.status='past_due' and s.grace_until>=now())) and ((p.code='grillad_premium_month' and p.amount_fcfa=6000 and p.billing_period='monthly') or (p.code='grillad_premium_year' and p.amount_fcfa=60000 and p.billing_period='yearly'))) then raise exception 'GRILLAD_PREMIUM_REQUIRED' using errcode='42501';end if;
  if exists(select 1 from grillad_private.enabled_sites e join famille_core.locations l on l.id=e.site and l.organization_id=e.org where e.org=p_org and lower(l.name)=lower(label)) then raise exception 'GRILLAD_SITE_DUPLICATE' using errcode='22023';end if;
  insert into famille_core.locations(id,organization_id,name) values(p_event,p_org,label);
  insert into grillad_private.enabled_sites(org,site) values(p_org,p_event);
  result:=jsonb_build_object('id',p_event,'name',label,'enabled',true);
 when 'set_network_mode' then
  if r<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  reason:=btrim(p_payload->>'reason');
  if jsonb_typeof(p_payload->'centralized') is distinct from 'boolean' or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_NETWORK_INPUT' using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended('grillad-network:'||p_org::text,0));
  insert into grillad_private.pilotage_policy(org,centralized) values(p_org,(p_payload->>'centralized')::boolean) on conflict(org) do update set centralized=excluded.centralized;
  result:=jsonb_build_object('centralized',(p_payload->>'centralized')::boolean);
 when 'set_service_hours' then
  if r<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  n:=(p_payload->>'start_minute')::bigint;d:=(p_payload->>'effective_from')::date;reason:=btrim(p_payload->>'reason');
  if n is null or n not between 0 and 1439 or d is null or d<(now() at time zone 'Africa/Douala')::date or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_SERVICE_INPUT' using errcode='22023';end if;
  if exists(select 1 from grillad_private.service_policy where org=p_org and site=p_site) then raise exception 'GRILLAD_SERVICE_ALREADY_CONFIGURED' using errcode='22023';end if;
  insert into grillad_private.service_policy(org,site,start_minute,effective_from,enabled) values(p_org,p_site,n::integer,d,true);
  result:=jsonb_build_object('start_minute',n,'effective_from',d,'enabled',true);
 when 'attendance_request' then
  result:=grillad_private.attendance_correct(p_org,p_site,p_event,p_action,p_payload);
 when 'attendance_decide' then
  result:=grillad_private.attendance_correct(p_org,p_site,p_event,p_action,p_payload);
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
declare r text;u uuid:=auth.uid();v_items jsonb;v_sales jsonb;v_finance jsonb;v_cash jsonb;v_expenses jsonb;v_forecasts jsonb;v_target bigint;v_notices jsonb;v_inactive_items jsonb;v_cash_history jsonb;v_adjustments jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'GRILLAD_PERIOD' using errcode='22023';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'family',i.family,'price',i.price,'prepared',i.prepared-i.adjustment_net,'adjustment_net',i.adjustment_net,'sold',i.sold,'remaining',i.prepared-i.sold-i.connect_reserved)||case when r='seller' then '{}'::jsonb else jsonb_build_object('cost',i.cost,'cost_basis',i.cost_basis,'cost_components',i.cost_components,'cost_quality',case when i.cost is null then 'incomplete' else 'estimated' end) end order by i.name),'[]'::jsonb) into v_items from grillad_private.items i where org=p_org and site=p_site and active;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'item',s.item,'qty',s.qty,'total',s.total,'actor',s.actor,'at',s.created_at,'cancelled',s.cancelled_at is not null,'source',s.source,'direct_order',s.direct_order) order by s.created_at desc),'[]'::jsonb) into v_sales from (select * from grillad_private.sales where org=p_org and site=p_site and (r<>'seller' or actor=u) and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) s;
 if r<>'seller' then
 select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc),'[]'::jsonb) into v_adjustments from (select id,item,delta,reason,actor,created_at from grillad_private.stock_adjustments where org=p_org and site=p_site and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) a;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'family',i.family,'price',i.price) order by i.name),'[]'::jsonb) into v_inactive_items from grillad_private.items i where i.org=p_org and i.site=p_site and not i.active;
 select coalesce(jsonb_agg(to_jsonb(h) order by h.closed_at desc),'[]'::jsonb) into v_cash_history from (select c.id,c.opened_at,c.closed_at,c.opening,c.expected,c.counted,c.counted-c.expected as difference,c.close_reason from grillad_private.cash c where c.org=p_org and c.site=p_site and c.closed_at is not null and (c.closed_at at time zone 'Africa/Douala')::date between p_from and p_to order by c.closed_at desc limit 200) h;
 select jsonb_build_object('ca',coalesce(sum(total),0),'sales_count',count(distinct (site,coalesce(direct_order,id))) filter(where source='direct')+count(distinct connect_order) filter(where source='connect'),'direct_ca',coalesce(sum(total) filter(where source='direct'),0),'connect_ca',coalesce(sum(total) filter(where source='connect'),0),'cost',case when count(*) filter(where cost is null)>0 then null else coalesce(sum(qty*cost),0) end,'charges',(select coalesce(sum(value),0) from grillad_private.expenses where org=p_org and site=p_site and cancelled_at is null and (created_at at time zone 'Africa/Douala')::date between p_from and p_to)) into v_finance from grillad_private.sales where org=p_org and site=p_site and cancelled_at is null and (created_at at time zone 'Africa/Douala')::date between p_from and p_to;
 select jsonb_build_object('id',c.id,'opening',c.opening,'expected',c.opening+coalesce((select sum(total) from grillad_private.sales where cash=c.id and cancelled_at is null),0)-coalesce((select sum(value) from grillad_private.expenses where cash=c.id and cancelled_at is null),0)) into v_cash from grillad_private.cash c where org=p_org and site=p_site and closed_at is null;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]'::jsonb) into v_expenses from (select id,label,value,cash,created_at,cancelled_at,cancelled_by,cancel_reason from grillad_private.expenses where org=p_org and site=p_site and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) e;
 select amount into v_target from grillad_private.targets where org=p_org and site=p_site and day=p_to;
 select coalesce(jsonb_agg(jsonb_build_object('item',i.id,'name',i.name,'quantity',case when d.observed>=3 then ceil(d.mean)::bigint else null end,'days',d.observed)),'[]'::jsonb) into v_forecasts
 from grillad_private.items i cross join lateral (select count(*) observed,avg(q) mean from (select sum(s.qty) q from grillad_private.sales s where s.org=p_org and s.site=p_site and s.item=i.id and s.cancelled_at is null and (s.created_at at time zone 'Africa/Douala')::date<(now() at time zone 'Africa/Douala')::date and (s.created_at at time zone 'Africa/Douala')::date>=(now() at time zone 'Africa/Douala')::date-7 group by (s.created_at at time zone 'Africa/Douala')::date) daily) d
 where i.org=p_org and i.site=p_site and i.active;
 select coalesce(jsonb_agg(z),'[]'::jsonb) into v_notices from (select 'stock:'||id id,name||' : quantité épuisée' text from grillad_private.items where org=p_org and site=p_site and active and prepared=sold+connect_reserved union all select 'cash:'||id,'Écart de caisse à vérifier' from grillad_private.cash where org=p_org and site=p_site and closed_at is not null and counted<>expected and (closed_at at time zone 'Africa/Douala')::date=p_to) z;
 else select jsonb_build_object('id',c.id) into v_cash from grillad_private.cash c where org=p_org and site=p_site and closed_at is null;
 end if;
 return jsonb_build_object('role',r,'items',v_items,'sales',v_sales,'finance',v_finance,'cash',v_cash,'cash_history',coalesce(v_cash_history,'[]'::jsonb),'inactive_items',coalesce(v_inactive_items,'[]'::jsonb),'stock_adjustments',coalesce(v_adjustments,'[]'::jsonb),'expenses',coalesce(v_expenses,'[]'::jsonb),'forecasts',coalesce(v_forecasts,'[]'::jsonb),'notices',coalesce(v_notices,'[]'::jsonb),'target',v_target,'from',p_from,'to',p_to,'generated_at',now());
end $$;
-- Server-derived workspace list. No arbitrary organization/site values from login.
create function grillad_private.workspace() returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare s record;r text;out jsonb:='[]'::jsonb;
begin
 if auth.uid() is null or not exists(select 1 from famille_core.applications where code='grillad' and id=famille_core.current_app_id()) then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 for s in select e.org,e.site,l.name,o.legal_name from grillad_private.enabled_sites e join famille_core.locations l on l.id=e.site and l.organization_id=e.org join famille_core.organizations o on o.id=e.org where e.enabled and exists(select 1 from famille_core.memberships m where m.user_id=auth.uid() and m.organization_id=e.org and m.app_id=famille_core.current_app_id() and m.status='active') order by l.name,e.site loop
  begin r:=grillad_private.scope(s.org,s.site);out:=out||jsonb_build_array(jsonb_build_object('org',s.org,'site',s.site,'name',s.name,'organization',s.legal_name,'role',r));exception when insufficient_privilege then null;end;
 end loop;
 return out;
end $$;
create function public.grillad_workspace() returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.workspace()$$;
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
-- Complete direct-sale receipt, independent of the 200-row history window.
create function grillad_private.receipt(p_org uuid,p_site uuid,p_sale uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text; u uuid:=auth.uid(); out jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 select jsonb_build_object('id',p_sale,'organization',o.legal_name,'site',l.name,
 'at',min(s.created_at),'currency','FCFA','cancelled',bool_or(s.cancelled_at is not null),
 'total',sum(s.total),'net_total',coalesce(sum(s.total) filter(where s.cancelled_at is null),0),
 'lines',jsonb_agg(jsonb_build_object('name',i.name,'qty',s.qty,'price',s.price,'total',s.total) order by s.id))
 into out from grillad_private.sales s join grillad_private.items i on i.id=s.item and i.org=s.org and i.site=s.site
 join famille_core.locations l on l.id=s.site and l.organization_id=s.org
 join famille_core.organizations o on o.id=s.org
 where s.org=p_org and s.site=p_site and s.source='direct' and coalesce(s.direct_order,s.id)=p_sale
 and (r<>'seller' or s.actor=u) group by o.legal_name,l.name;
 if out is null then raise exception 'GRILLAD_RECEIPT' using errcode='42501';end if;
 return out;
end $$;
create function public.grillad_receipt(p_org uuid,p_site uuid,p_sale uuid) returns jsonb
language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.receipt(p_org,p_site,p_sale)$$;
revoke all on function grillad_private.receipt(uuid,uuid,uuid),public.grillad_receipt(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function grillad_private.receipt(uuid,uuid,uuid),public.grillad_receipt(uuid,uuid,uuid) to authenticated;

commit;
