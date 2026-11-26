-- Bulk 2 composite formulas: priced commercial selections and actual station components.
-- Existing stock/cash/CMV contracts stay authoritative. No phantom formula stock.
begin;
alter table public.zp_order_lines add column line_total_xaf bigint not null default 0 check(line_total_xaf>=0),add column instructions jsonb not null default '[]'::jsonb;
alter table public.zp_orders add column commercial_lines jsonb not null default '[]'::jsonb;
create table public.zp_formula_components(org_id uuid not null,site_id uuid not null,formula_id uuid not null,component_id uuid not null,qty int not null check(qty between 1 and 100),primary key(formula_id,component_id),check(formula_id<>component_id),foreign key(formula_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(component_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id));
create function public.zp_formula_define(p_access text,p_site uuid,p_formula uuid,p_components jsonb) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;v public.zp_menu_items;c record;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into v from public.zp_menu_items where id=p_formula and org_id=m.org_id and site_id=p_site for update;
 if v.id is null or v.kind<>'formula' or v.available_qty<>0 or exists(select 1 from public.zp_order_lines where item_id=v.id) or exists(select 1 from public.zp_recipe_components where item_id=v.id) or exists(select 1 from public.zp_formula_components where component_id=v.id) then raise exception 'FORMULA_REQUIRES_EMPTY_ITEM';end if;
 if exists(select 1 from public.zp_formula_components where formula_id=v.id) then raise exception 'FORMULA_VERSION_REQUIRED';end if;
 if jsonb_typeof(p_components) is distinct from 'array' or jsonb_array_length(p_components) not between 1 and 20 then raise exception 'INVALID_COMPONENTS';end if;
 for c in select * from jsonb_to_recordset(p_components) as x(component_id uuid,qty int) loop
 if c.component_id is null or c.qty is null or c.qty not between 1 and 100 or not exists(select 1 from public.zp_menu_items where id=c.component_id and org_id=m.org_id and site_id=p_site and kind<>'formula') then raise exception 'INVALID_COMPONENTS';end if;
 insert into public.zp_formula_components values(m.org_id,p_site,v.id,c.component_id,c.qty);
 end loop;return true;end $$;
create function public.zp_formula_stock_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin
 if exists(select 1 from public.zp_formula_components where formula_id=old.id) and (new.kind<>'formula' or new.available_qty<>0) then raise exception 'FORMULA_STOCK_MANAGED_BY_COMPONENTS';end if;
 if new.kind='formula' and exists(select 1 from public.zp_formula_components where component_id=old.id) then raise exception 'INVALID_COMPONENTS';end if;
 return new;end $$;
create trigger zp_formula_stock_guard before update on public.zp_menu_items for each row execute function public.zp_formula_stock_guard();
create function public.zp_sellable_qty(p_item uuid) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select case when not i.active or not public.zp_item_in_window(i.available_from,i.available_until,now()) then 0
 when i.kind='formula' then coalesce((select min(case when c.active and public.zp_item_in_window(c.available_from,c.available_until,now()) then c.available_qty/f.qty else 0 end) from public.zp_formula_components f join public.zp_menu_items c on c.id=f.component_id where f.formula_id=i.id),0)
 else i.available_qty end from public.zp_menu_items i where i.id=p_item
$$;
create function public.zp_formula_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return coalesce((select jsonb_agg(jsonb_build_object('formula_id',formula_id,'component_id',component_id,'qty',qty)) from public.zp_formula_components where org_id=m.org_id and site_id=p_site),'[]'::jsonb);end $$;
create or replace function public.zp_create_order(p_access text,p_guest_hash text,p_site uuid,p_channel text,p_table_session uuid,p_request uuid,p_lines jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g public.zp_guest_sessions;s public.zp_site_modes;org uuid;oid uuid;old public.zp_orders;line record;item public.zp_menu_items;total bigint:=0;body jsonb;commercial jsonb;guest_channel text;begin
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
 -- Check commercial selections under the same site lock; each physical component is then deducted once.
 if exists(select 1 from jsonb_to_recordset(p_lines) as x(item_id uuid,qty int) left join public.zp_menu_items i on i.id=x.item_id and i.org_id=org and i.site_id=p_site where i.id is null or public.zp_sellable_qty(i.id)<x.qty) then raise exception 'ITEM_UNAVAILABLE';end if;
 select jsonb_agg(jsonb_build_object('item_id',i.id,'name',i.name,'qty',x.qty,'price_xaf',i.price_xaf,'note',coalesce(x.note,'')) order by q.ordinality),sum(x.qty::bigint*i.price_xaf) into commercial,total
 from jsonb_array_elements(p_lines) with ordinality as q(value,ordinality) cross join lateral jsonb_to_record(q.value) as x(item_id uuid,qty int,note text) join public.zp_menu_items i on i.id=x.item_id and i.org_id=org and i.site_id=p_site;
 for line in
 with requests as (select x.item_id,x.qty,x.note,q.ordinality,i.kind,i.price_xaf from jsonb_array_elements(p_lines) with ordinality as q(value,ordinality) cross join lateral jsonb_to_record(q.value) as x(item_id uuid,qty int,note text) join public.zp_menu_items i on i.id=x.item_id),
 expanded as (
 select r.ordinality,r.item_id,r.qty::bigint qty,r.qty::bigint*r.price_xaf allocation,coalesce(r.note,'') note from requests r where r.kind<>'formula'
 union all
 select z.ordinality,z.component_id,z.qty,z.allocation,z.note from (
 select r.ordinality,f.component_id,r.qty::bigint*f.qty qty,coalesce(r.note,'') note,
 (floor(r.qty::numeric*r.price_xaf*sum(f.qty::numeric*c.price_xaf) over(partition by r.ordinality order by f.component_id)/sum(f.qty::numeric*c.price_xaf) over(partition by r.ordinality))-
 floor(r.qty::numeric*r.price_xaf*(sum(f.qty::numeric*c.price_xaf) over(partition by r.ordinality order by f.component_id)-f.qty::numeric*c.price_xaf)/sum(f.qty::numeric*c.price_xaf) over(partition by r.ordinality)))::bigint allocation
 from requests r join public.zp_formula_components f on f.formula_id=r.item_id join public.zp_menu_items c on c.id=f.component_id where r.kind='formula')z
 )
 select item_id,sum(qty)::bigint qty,sum(allocation)::bigint allocation,coalesce(jsonb_agg(jsonb_build_object('qty',qty,'note',note)) filter(where note<>''),'[]'::jsonb) instructions from expanded group by item_id order by item_id
 loop
 if line.qty not between 1 and 100000 then raise exception 'INVALID_QUANTITY';end if;
 update public.zp_menu_items set available_qty=available_qty-line.qty::int where id=line.item_id and org_id=org and site_id=p_site and kind<>'formula' and active and public.zp_item_in_window(available_from,available_until,now()) and available_qty>=line.qty returning * into item;
 if not found then raise exception 'ITEM_UNAVAILABLE';end if;
 insert into public.zp_order_lines(order_id,org_id,site_id,item_id,qty,unit_xaf,post,line_total_xaf,instructions) values(oid,org,p_site,item.id,line.qty::int,item.price_xaf,item.post,line.allocation,line.instructions);
 end loop;
 if (select coalesce(sum(line_total_xaf),0) from public.zp_order_lines where order_id=oid)<>total then raise exception 'FORMULA_ALLOCATION_MISMATCH';end if;
 update public.zp_orders set total_xaf=total,commercial_lines=commercial where id=oid;
 return jsonb_build_object('id',oid,'total_xaf',total,'status','received');end $$;
create or replace function public.zp_guest_menu(p_guest_hash text) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('site_id',g.site_id,'table_session_id',g.table_session_id,'site_name',s.name,'table_label',(select label from public.zp_tables where id=t.table_id),'channel',(select case when kind='pickup' then 'counter' else 'table' end from public.zp_tables where id=t.table_id),'menu',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'price_xaf',i.price_xaf,'available',public.zp_sellable_qty(i.id)>0,'low',public.zp_sellable_qty(i.id)>0 and public.zp_sellable_qty(i.id)<=i.low_threshold,'category',i.category,'subcategory',i.subcategory,'description',i.description,'variant',i.variant,'kind',i.kind,'components',coalesce((select jsonb_agg(jsonb_build_object('name',c.name,'qty',f.qty,'variant',c.variant)) from public.zp_formula_components f join public.zp_menu_items c on c.id=f.component_id where f.formula_id=i.id),'[]'::jsonb),'prep_minutes',i.prep_minutes,'post',i.post) order by i.name) from public.zp_menu_items i where i.site_id=g.site_id and i.org_id=g.org_id and i.active),'[]'::jsonb))
 from public.zp_guest_sessions g join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=g.site_id join public.zp_organizations o on o.id=g.org_id where g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and o.active and public.zp_operational_plan(g.org_id) is not null
$$;
create or replace function public.zp_business_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;mode jsonb;items jsonb;orders jsonb;tables jsonb;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 select to_jsonb(s) into mode from public.zp_site_modes s where s.site_id=p_site and s.org_id=m.org_id;
 select coalesce(jsonb_agg(to_jsonb(i)||jsonb_build_object('sellable_qty',public.zp_sellable_qty(i.id)) order by i.name),'[]'::jsonb) into items from public.zp_menu_items i where i.site_id=p_site and i.org_id=m.org_id;
 select coalesce(jsonb_agg(x.data),'[]'::jsonb) into orders from (select jsonb_build_object('id',o.id,'number',o.service_number,'table_session_id',o.table_session_id,'initial_promised_at',o.initial_promised_at,'channel',o.channel,'status',o.status,'total_xaf',o.total_xaf,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id),'promised_at',o.promised_at,'served_at',o.served_at,'created_at',o.created_at,'commercial_lines',o.commercial_lines,'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'post',l.post,'state',l.state,'line_total_xaf',l.line_total_xaf,'instructions',l.instructions)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id)) data from public.zp_orders o where o.site_id=p_site and o.org_id=m.org_id order by o.created_at desc limit 100) x;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.label,'kind',t.kind,'session_id',(select id from public.zp_table_sessions s where s.table_id=t.id and s.closed_at is null))),'[]'::jsonb) into tables from public.zp_tables t where t.site_id=p_site and t.org_id=m.org_id;
 return jsonb_build_object('mode',mode,'items',items,'orders',orders,'tables',tables,'cash_session',(select jsonb_build_object('id',c.id,'opening_xaf',c.opening_xaf,'opened_at',c.opened_at) from public.zp_cash_sessions c where c.org_id=m.org_id and c.site_id=p_site and c.closed_at is null),'plan',public.zp_paid_plan(m.org_id),'server_now',now());end $$;
create or replace function public.zp_guest_order(p_guest_hash text,p_order uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('id',o.id,'number',o.service_number,'channel',o.channel,'initial_promised_at',o.initial_promised_at,'commercial_lines',o.commercial_lines,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id),'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'unit_xaf',l.unit_xaf,'line_total_xaf',l.line_total_xaf,'post',l.post)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id),'status',o.status,'total_xaf',o.total_xaf,'created_at',o.created_at,'promised_at',o.promised_at,'served_at',o.served_at,'guest_served_at',o.guest_served_at,'server_now',now(),'service_delta_seconds',case when o.guest_served_at is not null and o.promised_at is not null then extract(epoch from o.guest_served_at-o.promised_at)::bigint else null end) from public.zp_orders o join public.zp_guest_sessions g on g.id=o.guest_id join public.zp_table_sessions ts on ts.id=g.table_session_id join public.zp_sites si on si.id=o.site_id join public.zp_organizations org on org.id=o.org_id where o.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and ts.closed_at is null and si.active and org.active and public.zp_operational_plan(o.org_id) is not null
$$;
create or replace function public.zp_pilotage(p_access text,p_site uuid,p_start date,p_end date) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;today date:=(now() at time zone 'Africa/Douala')::date;lo timestamptz;hi timestamptz;revenue bigint;cost bigint;unknown_count bigint;receipt_count bigint;history jsonb;first_day date;expense bigint;low_count bigint;late_count bigint;feedback_count bigint;feedback_avg numeric;variance bigint;post_metrics jsonb;begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_start is null or p_end is null or p_start>p_end or p_end>today or p_end-p_start>365 then raise exception 'INVALID_PERIOD';end if;
 lo:=p_start::timestamp at time zone 'Africa/Douala';hi:=(p_end+1)::timestamp at time zone 'Africa/Douala';
 select coalesce(sum(r.amount_xaf),0),count(*) into revenue,receipt_count from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;
 select count(*) into unknown_count from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi and exists(select 1 from public.zp_order_lines l left join public.zp_sale_costs c on c.receipt_id=r.id and c.item_id=l.item_id where l.order_id=r.order_id and c.cost_xaf is null);
 if receipt_count>0 and unknown_count=0 then select coalesce(sum(c.cost_xaf),0) into cost from public.zp_sale_costs c join public.zp_cash_receipts r on r.id=c.receipt_id where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;end if;
 select coalesce(sum(amount_xaf),0) into expense from public.zp_expenses where org_id=m.org_id and site_id=p_site and expense_date between p_start and p_end;
 select count(*) into low_count from public.zp_ingredients i where i.org_id=m.org_id and i.site_id=p_site and i.reorder_milli>=coalesce((select sum(l.remaining_milli) from public.zp_ingredient_lots l where l.ingredient_id=i.id and (l.expires_on is null or l.expires_on>=today)),0);
 select count(*) into late_count from public.zp_orders o where o.org_id=m.org_id and o.site_id=p_site and o.status not in ('served','cancelled') and o.guest_served_at is null and o.promised_at<now();
 select count(*),round(avg(rating),2) into feedback_count,feedback_avg from public.zp_feedback where org_id=m.org_id and site_id=p_site and created_at>=lo and created_at<hi;
 select coalesce(sum(abs(counted_xaf-expected_xaf)),0) into variance from public.zp_cash_sessions where org_id=m.org_id and site_id=p_site and closed_at>=lo and closed_at<hi;
 select min((created_at at time zone 'Africa/Douala')::date) into first_day from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site;
 select coalesce(jsonb_agg(jsonb_build_object('day',x.receipt_day,'recorded_xaf',x.amount) order by x.receipt_day),'[]'::jsonb) into history from (select (created_at at time zone 'Africa/Douala')::date as receipt_day,sum(amount_xaf) as amount from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site and created_at>=((today-28)::timestamp at time zone 'Africa/Douala') and created_at<(today::timestamp at time zone 'Africa/Douala') group by 1)x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.post),'[]'::jsonb) into post_metrics from (select l.post,sum(l.qty) portions,sum(l.line_total_xaf) recorded_xaf from public.zp_cash_receipts r join public.zp_order_lines l on l.order_id=r.order_id where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi group by l.post)x;
 return jsonb_build_object('start',p_start,'end',p_end,'as_of',now(),'today',today,'first_recorded_sale_day',first_day,'recorded_xaf',revenue,'receipts',receipt_count,'uncosted_receipts',unknown_count,'known_cost_xaf',cost,'gross_margin_xaf',case when cost is not null then revenue-cost else null end,'expenses_xaf',expense,'current_low_stock',low_count,'current_late_orders',late_count,'feedback_count',feedback_count,'feedback_average',feedback_avg,'absolute_cash_variance_xaf',variance,'history_28',history,'posts',post_metrics);
end $$;

alter table public.zp_formula_components enable row level security;
revoke all on public.zp_formula_components from public,anon,authenticated;
grant select,insert,update,delete on public.zp_formula_components to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_formula_define','zp_formula_stock_guard','zp_sellable_qty','zp_formula_snapshot','zp_create_order','zp_guest_menu','zp_business_snapshot','zp_guest_order','zp_pilotage') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
