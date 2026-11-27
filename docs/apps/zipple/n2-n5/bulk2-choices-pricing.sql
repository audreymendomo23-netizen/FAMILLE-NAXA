-- Configurable formula substitutions and catalogue restrictions; all price decisions at server time.
begin;
alter table public.zp_menu_items add column sale_limit int check(sale_limit is null or sale_limit>=0),add column sale_limit_epoch uuid not null default gen_random_uuid(),add column sku text not null default '' check(length(sku)<=80),add column sale_unit text not null default 'portion' check(length(trim(sale_unit)) between 1 and 80);
alter table public.zp_order_lines add column sale_limit_epoch uuid;
create unique index zp_menu_sku_site_unique on public.zp_menu_items(site_id,lower(sku)) where sku<>'';
alter table public.zp_menu_items add column available_channels text[] not null default array['table','counter','takeaway']::text[] check(cardinality(available_channels) between 1 and 3 and available_channels <@ array['table','counter','takeaway']::text[]);
create table public.zp_category_controls(org_id uuid not null,site_id uuid not null,category text not null,active boolean not null,member_id uuid not null,updated_at timestamptz not null default now(),primary key(site_id,category),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_category_events(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,category text not null,active boolean not null,member_id uuid not null,created_at timestamptz not null default now(),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_price_rules(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,item_id uuid not null,member_id uuid not null,channel text not null check(channel in ('all','table','counter','takeaway')),price_xaf int not null check(price_xaf>0),starts_at timestamptz not null,ends_at timestamptz not null,reason text not null check(length(trim(reason)) between 5 and 500),check(ends_at>starts_at),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_formula_groups(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,formula_id uuid not null,name text not null check(length(trim(name)) between 1 and 80),required boolean not null,qty int not null check(qty between 1 and 100),unique(id,org_id,site_id),unique(formula_id,name),foreign key(formula_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id));
create table public.zp_formula_options(group_id uuid not null,org_id uuid not null,site_id uuid not null,component_id uuid not null,delta_xaf int not null check(delta_xaf between -1000000 and 1000000),primary key(group_id,component_id),foreign key(group_id,org_id,site_id) references public.zp_formula_groups(id,org_id,site_id),foreign key(component_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id));
create function public.zp_current_price(p_item uuid,p_channel text) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select coalesce((select r.price_xaf from public.zp_price_rules r where r.item_id=i.id and r.channel in ('all',p_channel) and r.starts_at<=now() and r.ends_at>now() order by (r.channel=p_channel) desc,r.starts_at desc limit 1),i.price_xaf) from public.zp_menu_items i where i.id=p_item
$$;
create function public.zp_item_open(p_item uuid,p_channel text) returns boolean language sql stable security invoker set search_path=pg_catalog,public as $$
 select i.active and p_channel=any(i.available_channels) and public.zp_item_in_window(i.available_from,i.available_until,now()) and coalesce((select c.active from public.zp_category_controls c where c.site_id=i.site_id and c.category=i.category),true) from public.zp_menu_items i where i.id=p_item
$$;
create function public.zp_component_capacity(p_item uuid,p_channel text,p_qty int) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select case when i.kind<>'formula' and public.zp_item_open(i.id,p_channel) then least(i.available_qty,coalesce(i.sale_limit,i.available_qty))/p_qty else 0 end from public.zp_menu_items i where i.id=p_item
$$;
create function public.zp_sellable_channel_qty(p_item uuid,p_channel text) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select case when not public.zp_item_open(i.id,p_channel) then 0 when i.kind<>'formula' then least(i.available_qty,coalesce(i.sale_limit,i.available_qty)) else
 least(coalesce((select min(public.zp_component_capacity(f.component_id,p_channel,f.qty)) from public.zp_formula_components f where f.formula_id=i.id),0),
 coalesce((select min(coalesce((select max(public.zp_component_capacity(o.component_id,p_channel,g.qty)) from public.zp_formula_options o where o.group_id=g.id),0)) from public.zp_formula_groups g where g.formula_id=i.id and g.required),2147483647)) end
 from public.zp_menu_items i where i.id=p_item
$$;
create or replace function public.zp_sellable_qty(p_item uuid) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select greatest(public.zp_sellable_channel_qty(p_item,'table'),public.zp_sellable_channel_qty(p_item,'counter'),public.zp_sellable_channel_qty(p_item,'takeaway'))
$$;
create function public.zp_category_set(p_access text,p_site uuid,p_category text,p_active boolean) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 if m.role_code not in ('promoteur','manager') and exists(select 1 from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id and i.category=p_category and not public.zp_can_prepare(m.id,p_site,i.post,i.substation_id)) then raise exception 'DENIED';end if;
 if p_active is null or not exists(select 1 from public.zp_menu_items where site_id=p_site and org_id=m.org_id and category=p_category) then raise exception 'DENIED';end if;
 insert into public.zp_category_controls values(m.org_id,p_site,p_category,p_active,m.id,now()) on conflict(site_id,category) do update set active=excluded.active,member_id=excluded.member_id,updated_at=excluded.updated_at;
 insert into public.zp_category_events(org_id,site_id,category,active,member_id) values(m.org_id,p_site,p_category,p_active,m.id);return true;end $$;
create function public.zp_catalog_channels(p_access text,p_site uuid,p_item uuid,p_channels text[]) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_menu_items;y public.zp_menu_items;begin m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if p_channels is null or cardinality(p_channels) not between 1 and 3 or not p_channels <@ array['table','counter','takeaway']::text[] or array_position(p_channels,null) is not null then raise exception 'CHANNEL_DENIED';end if;
 update public.zp_menu_items set available_channels=p_channels where id=x.id returning * into y;
 insert into public.zp_catalog_events(org_id,site_id,item_id,member_id,before_value,after_value) values(m.org_id,p_site,x.id,m.id,to_jsonb(x),to_jsonb(y));return true;end $$;
create function public.zp_price_schedule(p_access text,p_site uuid,p_item uuid,p_channel text,p_price int,p_start timestamptz,p_end timestamptz,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;st timestamptz:=coalesce(p_start,now());begin m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 if not exists(select 1 from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 if st<now()-interval '1 second' or p_end is null or p_end<=st or p_price is null or p_price<=0 or p_channel is null or p_channel not in ('all','table','counter','takeaway') then raise exception 'INVALID_PRICE_RULE';end if;
 if exists(select 1 from public.zp_price_rules where item_id=p_item and channel=p_channel and starts_at<p_end and ends_at>st) then raise exception 'PRICE_RULE_OVERLAP';end if;
 insert into public.zp_price_rules(org_id,site_id,item_id,member_id,channel,price_xaf,starts_at,ends_at,reason) values(m.org_id,p_site,p_item,m.id,p_channel,p_price,st,p_end,trim(p_reason)) returning id into i;return i;end $$;
create function public.zp_catalog_rules(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('categories',coalesce((select jsonb_agg(jsonb_build_object('category',x.category,'active',coalesce(c.active,true))) from (select distinct category from public.zp_menu_items where org_id=m.org_id and site_id=p_site)x left join public.zp_category_controls c on c.site_id=p_site and c.category=x.category),'[]'::jsonb),'prices',coalesce((select jsonb_agg(to_jsonb(r) order by r.starts_at desc) from (select id,item_id,channel,price_xaf,starts_at,ends_at,reason from public.zp_price_rules where org_id=m.org_id and site_id=p_site order by starts_at desc limit 200)r),'[]'::jsonb));end $$;
create function public.zp_formula_groups_define(p_access text,p_site uuid,p_formula uuid,p_groups jsonb) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g record;o record;gid uuid;begin m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 if not exists(select 1 from public.zp_menu_items where id=p_formula and org_id=m.org_id and site_id=p_site and kind='formula' and not active) or not exists(select 1 from public.zp_formula_components where formula_id=p_formula) or exists(select 1 from public.zp_orders where org_id=m.org_id and site_id=p_site and commercial_lines @> jsonb_build_array(jsonb_build_object('item_id',p_formula))) or exists(select 1 from public.zp_formula_groups where formula_id=p_formula) then raise exception 'FORMULA_VERSION_REQUIRED';end if;
 if jsonb_typeof(p_groups) is distinct from 'array' or jsonb_array_length(p_groups) not between 1 and 10 then raise exception 'INVALID_COMPONENTS';end if;
 for g in select * from jsonb_to_recordset(p_groups) as x(name text,required boolean,qty int,options jsonb) loop
 if g.name is null or g.required is null or g.qty is null or g.qty not between 1 and 100 or jsonb_typeof(g.options) is distinct from 'array' or jsonb_array_length(g.options) not between 1 and 20 then raise exception 'INVALID_COMPONENTS';end if;
 insert into public.zp_formula_groups(org_id,site_id,formula_id,name,required,qty) values(m.org_id,p_site,p_formula,trim(g.name),g.required,g.qty) returning id into gid;
 for o in select * from jsonb_to_recordset(g.options) as y(component_id uuid,delta_xaf int) loop
 if o.component_id is null or o.delta_xaf is null or not exists(select 1 from public.zp_menu_items where id=o.component_id and org_id=m.org_id and site_id=p_site and kind<>'formula') or exists(select 1 from public.zp_formula_components where formula_id=p_formula and component_id=o.component_id) or exists(select 1 from public.zp_formula_options opt join public.zp_formula_groups grp on grp.id=opt.group_id where grp.formula_id=p_formula and opt.component_id=o.component_id) then raise exception 'INVALID_COMPONENTS';end if;
 insert into public.zp_formula_options values(gid,m.org_id,p_site,o.component_id,o.delta_xaf);
 end loop;end loop;return true;end $$;
create function public.zp_formula_groups_view(p_item uuid,p_channel text) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'required',g.required,'qty',g.qty,'options',coalesce((select jsonb_agg(jsonb_build_object('component_id',o.component_id,'name',i.name,'delta_xaf',o.delta_xaf,'available',public.zp_component_capacity(i.id,p_channel,g.qty)>0) order by i.name) from public.zp_formula_options o join public.zp_menu_items i on i.id=o.component_id where o.group_id=g.id),'[]'::jsonb)) order by g.name),'[]'::jsonb) from public.zp_formula_groups g where g.formula_id=p_item
$$;
create function public.zp_resolve_selection(p_item uuid,p_channel text,p_choices jsonb) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare i public.zp_menu_items;g public.zp_formula_groups;o record;choice_count int;chosen uuid;resolved jsonb:='[]';names jsonb:='[]';price bigint;begin
 select * into i from public.zp_menu_items where id=p_item;price:=public.zp_current_price(p_item,p_channel);p_choices:=coalesce(p_choices,'[]'::jsonb);
 if jsonb_typeof(p_choices) is distinct from 'array' or jsonb_array_length(p_choices)>10 then raise exception 'INVALID_FORMULA_CHOICES';end if;
 if i.kind<>'formula' then if jsonb_array_length(p_choices)<>0 then raise exception 'INVALID_FORMULA_CHOICES';end if;return jsonb_build_object('price_xaf',price,'components',jsonb_build_array(jsonb_build_object('item_id',p_item,'qty',1)),'choices',names);end if;
 if exists(select 1 from jsonb_to_recordset(p_choices) as x(group_id uuid,component_id uuid) where not exists(select 1 from public.zp_formula_groups fg where fg.id=x.group_id and fg.formula_id=p_item)) then raise exception 'INVALID_FORMULA_CHOICES';end if;
 select coalesce(jsonb_agg(jsonb_build_object('item_id',component_id,'qty',qty)),'[]'::jsonb) into resolved from public.zp_formula_components where formula_id=p_item;
 for g in select * from public.zp_formula_groups where formula_id=p_item order by id loop
 select count(*),min(x.component_id::text)::uuid into choice_count,chosen from jsonb_to_recordset(p_choices) as x(group_id uuid,component_id uuid) where x.group_id=g.id;
 if choice_count=0 and not g.required then continue;end if;
 if choice_count<>1 or chosen is null then raise exception 'INVALID_FORMULA_CHOICES';end if;
 select opt.*,c.name into o from public.zp_formula_options opt join public.zp_menu_items c on c.id=opt.component_id where opt.group_id=g.id and opt.component_id=chosen;
 if o.component_id is null or public.zp_component_capacity(chosen,p_channel,g.qty)<=0 then raise exception 'ITEM_UNAVAILABLE';end if;
 resolved:=resolved||jsonb_build_array(jsonb_build_object('item_id',chosen,'qty',g.qty));names:=names||jsonb_build_array(jsonb_build_object('group',g.name,'name',o.name,'delta_xaf',o.delta_xaf));price:=price+o.delta_xaf;
 end loop;
 if price not between 1 and 2147483647 then raise exception 'INVALID_PRICE_RULE';end if;
 return jsonb_build_object('price_xaf',price,'components',resolved,'choices',names);end $$;
create or replace function public.zp_formula_stock_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin
 if exists(select 1 from public.zp_formula_components where formula_id=old.id) and (new.kind<>'formula' or new.available_qty<>0) then raise exception 'FORMULA_STOCK_MANAGED_BY_COMPONENTS';end if;
 if new.kind='formula' and (exists(select 1 from public.zp_formula_components where component_id=old.id) or exists(select 1 from public.zp_formula_options where component_id=old.id)) then raise exception 'INVALID_COMPONENTS';end if;
 return new;end $$;
create or replace function public.zp_create_order(p_access text,p_guest_hash text,p_site uuid,p_channel text,p_table_session uuid,p_request uuid,p_lines jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g public.zp_guest_sessions;s public.zp_site_modes;org uuid;oid uuid;old public.zp_orders;line record;item public.zp_menu_items;total bigint:=0;body jsonb;commercial jsonb:='[]';guest_channel text;selection jsonb;req record;begin
 if (p_access is null)=(p_guest_hash is null) then raise exception 'DENIED';end if;
 if p_guest_hash is not null then
 select x.* into g from public.zp_guest_sessions x join public.zp_table_sessions ts on ts.id=x.table_session_id join public.zp_sites si on si.id=x.site_id join public.zp_organizations o on o.id=x.org_id where x.token_hash=p_guest_hash and x.expires_at>now() and ts.closed_at is null and si.active and o.active for update of ts;
 select case when t.kind='pickup' then 'counter' else 'table' end into guest_channel from public.zp_table_sessions ts join public.zp_tables t on t.id=ts.table_id where ts.id=g.table_session_id;
 if g.id is null or g.site_id<>p_site or p_channel is distinct from guest_channel or p_table_session is distinct from g.table_session_id then raise exception 'DENIED';end if;org:=g.org_id;
 else m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;org:=m.org_id;end if;
 if public.zp_operational_plan(org) is null then raise exception 'SUBSCRIPTION_REQUIRED';end if;
 select * into s from public.zp_site_modes where site_id=p_site and org_id=org;
 if s.site_id is null or p_channel is null or p_channel not in ('table','counter','takeaway','delivery') or p_channel='delivery' then raise exception 'CHANNEL_DENIED';end if;
 if p_channel='table' or g.id is not null then perform 1 from public.zp_table_sessions where id=p_table_session and org_id=org and site_id=p_site and closed_at is null for update;if not found then raise exception 'TABLE_CLOSED';end if;elsif p_table_session is not null then raise exception 'INVALID_TABLE';end if;
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
 update public.zp_menu_items set available_qty=available_qty-line.qty::int where id=line.item_id and org_id=org and site_id=p_site and kind<>'formula' and public.zp_item_open(id,p_channel) and available_qty>=line.qty returning * into item;
 if not found then raise exception 'ITEM_UNAVAILABLE';end if;
 insert into public.zp_order_lines(order_id,org_id,site_id,item_id,qty,unit_xaf,post,line_total_xaf,instructions) values(oid,org,p_site,item.id,line.qty::int,public.zp_current_price(item.id,p_channel),item.post,line.allocation,line.instructions);
 end loop;
 if (select coalesce(sum(line_total_xaf),0) from public.zp_order_lines where order_id=oid)<>total then raise exception 'FORMULA_ALLOCATION_MISMATCH';end if;
 update public.zp_orders set total_xaf=total,commercial_lines=commercial where id=oid;
 return jsonb_build_object('id',oid,'total_xaf',total,'status','received');end $$;
create or replace function public.zp_guest_menu(p_guest_hash text) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('site_id',g.site_id,'table_session_id',g.table_session_id,'site_name',s.name,'space',(select space from public.zp_site_modes where site_id=g.site_id and org_id=g.org_id),'table_label',(select label from public.zp_tables where id=t.table_id),'channel',(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id),'menu',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'price_xaf',public.zp_current_price(i.id,(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id)),'groups',public.zp_formula_groups_view(i.id,(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id)),'available',public.zp_sellable_channel_qty(i.id,(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id))>0,'low',public.zp_sellable_channel_qty(i.id,(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id))>0 and public.zp_sellable_channel_qty(i.id,(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id))<=i.low_threshold,'category',i.category,'subcategory',i.subcategory,'description',i.description,'variant',i.variant,'sale_unit',i.sale_unit,'kind',i.kind,'components',coalesce((select jsonb_agg(jsonb_build_object('name',c.name,'qty',f.qty,'variant',c.variant)) from public.zp_formula_components f join public.zp_menu_items c on c.id=f.component_id where f.formula_id=i.id),'[]'::jsonb),'prep_minutes',i.prep_minutes,'post',i.post) order by i.name) from public.zp_menu_items i where i.site_id=g.site_id and i.org_id=g.org_id),'[]'::jsonb))
 from public.zp_guest_sessions g join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=g.site_id join public.zp_organizations o on o.id=g.org_id where g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and o.active and public.zp_operational_plan(g.org_id) is not null
$$;
create or replace function public.zp_business_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;mode jsonb;items jsonb;orders jsonb;tables jsonb;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 select to_jsonb(s) into mode from public.zp_site_modes s where s.site_id=p_site and s.org_id=m.org_id;
 select coalesce(jsonb_agg(to_jsonb(i)||jsonb_build_object('sellable_qty',public.zp_sellable_qty(i.id),'channels',jsonb_build_object('table',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'table'),'qty',public.zp_sellable_channel_qty(i.id,'table'),'groups',public.zp_formula_groups_view(i.id,'table')),'counter',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'counter'),'qty',public.zp_sellable_channel_qty(i.id,'counter'),'groups',public.zp_formula_groups_view(i.id,'counter')),'takeaway',jsonb_build_object('price_xaf',public.zp_current_price(i.id,'takeaway'),'qty',public.zp_sellable_channel_qty(i.id,'takeaway'),'groups',public.zp_formula_groups_view(i.id,'takeaway')))) order by i.name),'[]'::jsonb) into items from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id;
 select coalesce(jsonb_agg(x.data),'[]'::jsonb) into orders from (select jsonb_build_object('id',o.id,'number',o.service_number,'table_session_id',o.table_session_id,'initial_promised_at',o.initial_promised_at,'channel',o.channel,'status',o.status,'total_xaf',o.total_xaf,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id),'promised_at',o.promised_at,'served_at',o.served_at,'created_at',o.created_at,'commercial_lines',o.commercial_lines,'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state,'line_total_xaf',l.line_total_xaf,'instructions',l.instructions)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id)) data from public.zp_orders o where o.site_id=p_site and o.org_id=m.org_id order by o.created_at desc limit 100) x;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.label,'kind',t.kind,'session_id',(select id from public.zp_table_sessions s where s.table_id=t.id and s.closed_at is null))),'[]'::jsonb) into tables from public.zp_tables t where t.site_id=p_site and t.org_id=m.org_id;
 return jsonb_build_object('mode',mode,'items',items,'orders',orders,'tables',tables,'cash_session',(select jsonb_build_object('id',c.id,'opening_xaf',c.opening_xaf,'opened_at',c.opened_at) from public.zp_cash_sessions c where c.org_id=m.org_id and c.site_id=p_site and c.closed_at is null),'plan',public.zp_paid_plan(m.org_id),'server_now',now());end $$;

do $$ declare t text;f record;begin
 foreach t in array array['zp_category_controls','zp_category_events','zp_price_rules','zp_formula_groups','zp_formula_options'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_current_price','zp_item_open','zp_component_capacity','zp_sellable_channel_qty','zp_sellable_qty','zp_category_set','zp_catalog_channels','zp_price_schedule','zp_catalog_rules','zp_formula_groups_define','zp_formula_groups_view','zp_resolve_selection','zp_formula_stock_guard','zp_create_order','zp_guest_menu','zp_business_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
