-- Optional professional customer records, no customer login. Adapted NS CRM model.
begin;
create table public.zp_customers(id uuid primary key default gen_random_uuid(),org_id uuid not null references public.zp_organizations(id),display_name text not null check(length(trim(display_name)) between 1 and 160),phone text check(phone is null or phone~'^[0-9]{9,15}$'),created_by uuid not null,created_at timestamptz not null default now(),unique(id,org_id),foreign key(created_by,org_id) references public.zp_members(id,org_id));
create unique index zp_customer_org_phone on public.zp_customers(org_id,phone) where phone is not null;
create table public.zp_customer_order_links(order_id uuid primary key,org_id uuid not null,site_id uuid not null,customer_id uuid not null,member_id uuid not null,created_at timestamptz not null default now(),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),foreign key(customer_id,org_id) references public.zp_customers(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_customer_followups(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,customer_id uuid not null,member_id uuid not null,request_id uuid not null,title text not null check(length(trim(title)) between 1 and 160),channel text not null check(channel in ('telephone','whatsapp','in_person')),due_on date not null,completed_at timestamptz,completed_by uuid,unique(member_id,request_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(customer_id,org_id) references public.zp_customers(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(completed_by,org_id) references public.zp_members(id,org_id));
create function public.zp_customer_add(p_access text,p_site uuid,p_name text,p_phone text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 insert into public.zp_customers(org_id,display_name,phone,created_by) values(m.org_id,trim(p_name),nullif(p_phone,''),m.id) returning id into i;return i;
 exception when unique_violation then raise exception 'CUSTOMER_REVIEW_REQUIRED';end $$;
create function public.zp_customer_attach(p_access text,p_site uuid,p_customer uuid,p_order uuid) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site and status<>'cancelled' for update;if not found then raise exception 'DENIED';end if;
 if not exists(select 1 from public.zp_customers where id=p_customer and org_id=m.org_id) then raise exception 'DENIED';end if;
 select customer_id into x from public.zp_customer_order_links where order_id=p_order;
 if x is not null then if x<>p_customer then raise exception 'CUSTOMER_LINK_LOCKED';end if;return true;end if;
 if exists(select 1 from public.zp_cash_receipts where order_id=p_order) then raise exception 'CUSTOMER_LINK_LOCKED';end if;
 insert into public.zp_customer_order_links(order_id,org_id,site_id,customer_id,member_id) values(p_order,m.org_id,p_site,p_customer,m.id);return true;end $$;
create function public.zp_followup_create(p_access text,p_site uuid,p_customer uuid,p_request uuid,p_title text,p_channel text,p_due date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_customer_followups;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_customer_followups where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.customer_id,x.title,x.channel,x.due_on) is distinct from (p_site,p_customer,trim(p_title),p_channel,p_due) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if not exists(select 1 from public.zp_customers where id=p_customer and org_id=m.org_id) then raise exception 'DENIED';end if;
 insert into public.zp_customer_followups(org_id,site_id,customer_id,member_id,request_id,title,channel,due_on) values(m.org_id,p_site,p_customer,m.id,p_request,trim(p_title),p_channel,p_due) returning id into i;return i;end $$;
create function public.zp_followup_complete(p_access text,p_site uuid,p_followup uuid) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 update public.zp_customer_followups set completed_at=coalesce(completed_at,now()),completed_by=coalesce(completed_by,m.id) where id=p_followup and org_id=m.org_id and site_id=p_site;if not found then raise exception 'DENIED';end if;return true;end $$;
create function public.zp_crm_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('customers',coalesce((select jsonb_agg(to_jsonb(c) order by c.display_name) from (select id,display_name,phone from public.zp_customers where org_id=m.org_id order by display_name limit 200)c),'[]'::jsonb),'followups',coalesce((select jsonb_agg(to_jsonb(f) order by f.due_on) from (select id,customer_id,title,channel,due_on,completed_at from public.zp_customer_followups where org_id=m.org_id and site_id=p_site order by completed_at nulls first,due_on limit 200)f),'[]'::jsonb),'history',coalesce((select jsonb_agg(to_jsonb(h)) from (select l.customer_id,l.order_id,o.total_xaf,o.status,o.created_at,(r.id is not null) paid from public.zp_customer_order_links l join public.zp_orders o on o.id=l.order_id left join public.zp_cash_receipts r on r.order_id=o.id where l.org_id=m.org_id and l.site_id=p_site order by o.created_at desc limit 200)h),'[]'::jsonb),'rewards_status','policy_required');end $$;
-- Guest confirmation is a separate event, not a cash settlement or an employee state transition.
alter table public.zp_orders add column guest_served_at timestamptz;
create function public.zp_guest_served(p_guest_hash text,p_order uuid) returns timestamptz language plpgsql security invoker set search_path=pg_catalog,public as $$
declare o public.zp_orders;ts timestamptz;begin
 select x.* into o from public.zp_orders x join public.zp_guest_sessions g on g.id=x.guest_id join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=x.site_id join public.zp_organizations org on org.id=x.org_id where x.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and org.active and x.status<>'cancelled' and public.zp_operational_plan(x.org_id) is not null for update of x;
 if o.id is null then raise exception 'DENIED';end if;
 if o.guest_served_at is not null then return o.guest_served_at;end if;
 if o.channel='table' and o.status<>'served' and exists(select 1 from public.zp_site_modes sm where sm.site_id=o.site_id and sm.org_id=o.org_id and sm.space='snack_bar') then raise exception 'NOT_SERVED';end if;
 update public.zp_orders set guest_served_at=clock_timestamp() where id=o.id returning guest_served_at into ts;return ts;end $$;
create or replace function public.zp_guest_order(p_guest_hash text,p_order uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('id',o.id,'number',o.service_number,'initial_promised_at',o.initial_promised_at,'paid',exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id),'lines',(select jsonb_agg(jsonb_build_object('item_id',l.item_id,'name',i.name,'qty',l.qty,'unit_xaf',l.unit_xaf,'post',l.post)) from public.zp_order_lines l join public.zp_menu_items i on i.id=l.item_id where l.order_id=o.id),'status',o.status,'total_xaf',o.total_xaf,'created_at',o.created_at,'promised_at',o.promised_at,'served_at',o.served_at,'guest_served_at',o.guest_served_at,'server_now',now(),'service_delta_seconds',case when o.guest_served_at is not null and o.promised_at is not null then extract(epoch from o.guest_served_at-o.promised_at)::bigint else null end) from public.zp_orders o join public.zp_guest_sessions g on g.id=o.guest_id join public.zp_table_sessions ts on ts.id=g.table_session_id join public.zp_sites si on si.id=o.site_id join public.zp_organizations org on org.id=o.org_id where o.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and ts.closed_at is null and si.active and org.active and public.zp_operational_plan(o.org_id) is not null
$$;
create or replace function public.zp_submit_feedback(p_guest_hash text,p_order uuid,p_rating int,p_comment text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare o public.zp_orders;begin
 select x.* into o from public.zp_orders x join public.zp_guest_sessions g on g.id=x.guest_id join public.zp_table_sessions t on t.id=g.table_session_id join public.zp_sites s on s.id=x.site_id join public.zp_organizations org on org.id=x.org_id where x.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and t.closed_at is null and s.active and org.active and public.zp_operational_plan(x.org_id) is not null and x.status<>'cancelled' and (x.status='served' or x.guest_served_at is not null) for update of x;
 if o.id is null then raise exception 'DENIED';end if;
 insert into public.zp_feedback(order_id,guest_id,org_id,site_id,rating,comment) values(o.id,o.guest_id,o.org_id,o.site_id,p_rating,coalesce(p_comment,'')) on conflict(order_id) do nothing;return found;end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_customers','zp_customer_order_links','zp_customer_followups'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_customer_add','zp_customer_attach','zp_followup_create','zp_followup_complete','zp_crm_snapshot','zp_guest_served','zp_guest_order','zp_submit_feedback') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;

-- Bulk 4: bounded customer assistance, linked to one guest order, no guest account.
create table public.zp_order_support(
 order_id uuid primary key,org_id uuid not null,site_id uuid not null,guest_id uuid not null,
 message text not null check(length(trim(message)) between 3 and 500),created_at timestamptz not null default clock_timestamp(),
 reply text check(reply is null or length(trim(reply)) between 3 and 500),replied_by uuid,replied_at timestamptz,
 foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),
 foreign key(guest_id,org_id,site_id) references public.zp_guest_sessions(id,org_id,site_id),
 foreign key(replied_by,org_id) references public.zp_members(id,org_id),
 check((reply is null and replied_by is null and replied_at is null) or (reply is not null and replied_by is not null and replied_at is not null))
);
alter table public.zp_order_support enable row level security;
revoke all on public.zp_order_support from public,anon,authenticated;
grant select,insert,update on public.zp_order_support to service_role;
create function public.zp_guest_support_read(p_guest_hash text,p_order uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $
declare v jsonb;begin
 if public.zp_guest_order(p_guest_hash,p_order) is null then raise exception 'DENIED';end if;
 select jsonb_build_object('message',message,'reply',reply,'created_at',created_at,'replied_at',replied_at) into v from public.zp_order_support where order_id=p_order;
 return coalesce(v,'{}'::jsonb);end $;
create function public.zp_guest_support_create(p_guest_hash text,p_order uuid,p_message text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $
declare o public.zp_orders;v public.zp_order_support;begin
 if p_message is null or length(trim(p_message)) not between 3 and 500 then raise exception 'INVALID_INPUT';end if;
 select * into o from public.zp_orders where id=p_order for update;
 if o.id is null or o.status='cancelled' or public.zp_guest_order(p_guest_hash,p_order) is null then raise exception 'DENIED';end if;
 insert into public.zp_order_support(order_id,org_id,site_id,guest_id,message) values(o.id,o.org_id,o.site_id,o.guest_id,trim(p_message)) on conflict(order_id) do nothing;
 select * into v from public.zp_order_support where order_id=p_order;
 if v.message is distinct from trim(p_message) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 return public.zp_guest_support_read(p_guest_hash,p_order);end $;
create function public.zp_order_support_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);
 if not public.zp_can_operate(m.id,p_site,'serve') then raise exception 'DENIED';end if;
 return coalesce((select jsonb_agg(to_jsonb(x)) from (select q.order_id,o.service_number as number,q.message,q.created_at,q.reply,q.replied_at from public.zp_order_support q join public.zp_orders o on o.id=q.order_id and o.org_id=q.org_id and o.site_id=q.site_id where q.org_id=m.org_id and q.site_id=p_site order by (q.replied_at is not null),q.created_at desc limit 100)x),'[]'::jsonb);end $;
create function public.zp_order_support_reply(p_access text,p_site uuid,p_order uuid,p_reply text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $
declare m public.zp_members;v public.zp_order_support;begin m:=public.zp_business_actor(p_access,p_site);
 if not public.zp_can_operate(m.id,p_site,'serve') then raise exception 'DENIED';end if;
 if p_reply is null or length(trim(p_reply)) not between 3 and 500 then raise exception 'INVALID_INPUT';end if;
 select * into v from public.zp_order_support where order_id=p_order and org_id=m.org_id and site_id=p_site for update;
 if v.order_id is null then raise exception 'DENIED';end if;
 if v.reply is not null then if v.reply is distinct from trim(p_reply) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return true;end if;
 update public.zp_order_support set reply=trim(p_reply),replied_by=m.id,replied_at=clock_timestamp() where order_id=p_order;return true;end $;
do $ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_guest_support_read','zp_guest_support_create','zp_order_support_snapshot','zp_order_support_reply') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $;

commit;
