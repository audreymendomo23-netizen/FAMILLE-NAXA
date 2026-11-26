-- Candidate ZIPPLE only. Requires N1 schema. No deployment implied.
begin;
create table public.zp_plan_catalog(plan text not null check(plan in ('ACCESS','PREMIUM')),cadence text not null check(cadence in ('monthly','annual')),amount_xaf int not null check(amount_xaf>0),months int not null check(months in (1,12)),primary key(plan,cadence));
insert into public.zp_plan_catalog values ('ACCESS','monthly',5000,1),('ACCESS','annual',50000,12),('PREMIUM','monthly',18000,1),('PREMIUM','annual',180000,12);
create table public.zp_subscription_periods(id uuid primary key default gen_random_uuid(),org_id uuid not null references public.zp_organizations(id),plan text not null,cadence text not null,starts_at timestamptz not null,ends_at timestamptz not null,source_ref text not null unique,check(ends_at>starts_at),foreign key(plan,cadence) references public.zp_plan_catalog(plan,cadence));
create table public.zp_subscription_intents(id uuid primary key default gen_random_uuid(),org_id uuid not null references public.zp_organizations(id),member_id uuid not null,request_id uuid not null,plan text not null,cadence text not null,amount_xaf int not null check(amount_xaf>0),provider text not null check(provider in ('mtn_momo','orange_money')),status text not null default 'pending' check(status in ('pending','confirmed')),provider_reference text,period_id uuid references public.zp_subscription_periods(id),created_at timestamptz not null default now(),unique(member_id,request_id),unique(provider,provider_reference),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(plan,cadence) references public.zp_plan_catalog(plan,cadence));
create table public.zp_referral_links(referred_org uuid primary key references public.zp_organizations(id),referrer_org uuid not null references public.zp_organizations(id),qualified_intent uuid unique references public.zp_subscription_intents(id),check(referred_org<>referrer_org));
create table public.zp_referral_rewards(org_id uuid not null references public.zp_organizations(id),wave int not null check(wave>0),period_id uuid not null unique references public.zp_subscription_periods(id),primary key(org_id,wave));
create table public.zp_site_modes(site_id uuid primary key,org_id uuid not null,space text not null check(space in ('restaurant','snack_bar')),bar_enabled boolean not null default false,delivery_enabled boolean not null default false,check(space='restaurant' or (not bar_enabled and not delivery_enabled)),unique(site_id,org_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id));
create table public.zp_menu_items(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,name text not null check(length(trim(name)) between 1 and 160),post text not null check(post in ('kitchen','bar','snack')),price_xaf int not null check(price_xaf>0),available_qty int not null check(available_qty>=0),active boolean not null default true,unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
create table public.zp_tables(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,label text not null check(length(trim(label)) between 1 and 80),qr_hash text not null unique check(qr_hash~'^[0-9a-f]{64}$'),unique(id,org_id,site_id),unique(site_id,label),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
create table public.zp_table_sessions(id uuid primary key default gen_random_uuid(),table_id uuid not null,org_id uuid not null,site_id uuid not null,opened_at timestamptz not null default now(),closed_at timestamptz,unique(id,org_id,site_id),foreign key(table_id,org_id,site_id) references public.zp_tables(id,org_id,site_id));
create unique index zp_one_open_table on public.zp_table_sessions(table_id) where closed_at is null;
create table public.zp_guest_sessions(id uuid primary key default gen_random_uuid(),table_session_id uuid not null,org_id uuid not null,site_id uuid not null,token_hash text not null unique check(token_hash~'^[0-9a-f]{64}$'),expires_at timestamptz not null,unique(id,org_id,site_id),foreign key(table_session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id));
create table public.zp_orders(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid,guest_id uuid,table_session_id uuid,request_id uuid not null,request_body jsonb not null,channel text not null check(channel in ('table','counter','takeaway','delivery')),status text not null default 'received' check(status in ('received','preparing','ready','served','cancelled')),total_xaf bigint not null default 0 check(total_xaf>=0),created_at timestamptz not null default now(),check((member_id is null)<>(guest_id is null)),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(guest_id,org_id,site_id) references public.zp_guest_sessions(id,org_id,site_id),foreign key(table_session_id,org_id,site_id) references public.zp_table_sessions(id,org_id,site_id));
create unique index zp_order_staff_idem on public.zp_orders(member_id,request_id) where member_id is not null;
create unique index zp_order_guest_idem on public.zp_orders(guest_id,request_id) where guest_id is not null;
create table public.zp_order_lines(order_id uuid not null,org_id uuid not null,site_id uuid not null,item_id uuid not null,qty int not null check(qty>0),unit_xaf int not null check(unit_xaf>0),post text not null,primary key(order_id,item_id),foreign key(order_id,org_id,site_id) references public.zp_orders(id,org_id,site_id),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id));
-- NAXA Services pattern: server authority, member/site scope, no direct browser writes.
create function public.zp_actor(p_access text,p_site uuid) returns public.zp_members language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members; begin
 select x.* into m from public.zp_sessions a join public.zp_members x on x.id=a.member_id join public.zp_organizations o on o.id=x.org_id join public.zp_site_scopes sc on sc.member_id=x.id and sc.org_id=x.org_id join public.zp_sites s on s.id=sc.site_id and s.org_id=sc.org_id
 where a.access_hash=p_access and not a.revoked and a.access_until>now() and x.active and not x.reset_pending and o.active and s.active and s.id=p_site;
 if m.id is null then raise exception 'DENIED'; end if;return m;end $$;
create function public.zp_paid_plan(p_org uuid) returns text language sql stable security invoker set search_path=pg_catalog,public as $$
 select plan from public.zp_subscription_periods where org_id=p_org and starts_at<=now() and ends_at>now() order by starts_at desc limit 1
$$;
create function public.zp_business_actor(p_access text,p_site uuid) returns public.zp_members language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;p text;begin m:=public.zp_actor(p_access,p_site);p:=public.zp_paid_plan(m.org_id);if p is null or (p='ACCESS' and m.role_code<>'promoteur') then raise exception 'SUBSCRIPTION_OR_ROLE_REQUIRED';end if;return m;end $$;
create function public.zp_quote_intent(p_access text,p_site uuid,p_plan text,p_cadence text,p_provider text,p_request uuid) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members; c public.zp_plan_catalog; i public.zp_subscription_intents;begin
 m:=public.zp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 select * into c from public.zp_plan_catalog where plan=p_plan and cadence=p_cadence;if c.amount_xaf is null then raise exception 'OFFER_DENIED';end if;
 insert into public.zp_subscription_intents(org_id,member_id,request_id,plan,cadence,amount_xaf,provider) values(m.org_id,m.id,p_request,p_plan,p_cadence,c.amount_xaf,p_provider) on conflict(member_id,request_id) do nothing;
 select * into i from public.zp_subscription_intents where member_id=m.id and request_id=p_request;
 if (i.plan,i.cadence,i.provider) is distinct from (p_plan,p_cadence,p_provider) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 return jsonb_build_object('id',i.id,'plan',i.plan,'cadence',i.cadence,'amount_xaf',i.amount_xaf,'status',i.status,'currency','XAF');end $$;
-- Internal service only: caller MUST have independently authenticated operator confirmation.
-- Never expose this RPC or a caller-supplied verified flag through a client endpoint.
create function public.zp_confirm_subscription(p_intent uuid,p_provider text,p_reference text,p_amount int,p_currency text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare i public.zp_subscription_intents;c public.zp_plan_catalog;st timestamptz;pid uuid;first_paid boolean;begin
 select * into i from public.zp_subscription_intents where id=p_intent for update;
 if i.id is null or i.provider is distinct from p_provider or i.amount_xaf is distinct from p_amount or p_currency is distinct from 'XAF' or length(trim(coalesce(p_reference,'')))<4 then raise exception 'PAYMENT_MISMATCH';end if;
 p_reference:=trim(p_reference);
 if i.status='confirmed' then if i.provider_reference<>p_reference then raise exception 'PAYMENT_MISMATCH';end if;return i.period_id;end if;
 perform 1 from public.zp_organizations where id=i.org_id and active for update;if not found then raise exception 'DENIED';end if;
 select not exists(select 1 from public.zp_subscription_intents where org_id=i.org_id and status='confirmed') into first_paid;
 select * into c from public.zp_plan_catalog where plan=i.plan and cadence=i.cadence;
 select greatest(now(),coalesce(max(ends_at),now())) into st from public.zp_subscription_periods where org_id=i.org_id;
 insert into public.zp_subscription_periods(org_id,plan,cadence,starts_at,ends_at,source_ref) values(i.org_id,i.plan,i.cadence,st,((st at time zone 'Africa/Douala')+make_interval(months=>c.months)) at time zone 'Africa/Douala','payment:'||i.id) returning id into pid;
 update public.zp_subscription_intents set status='confirmed',provider_reference=p_reference,period_id=pid where id=i.id;
 if first_paid then update public.zp_referral_links set qualified_intent=i.id where referred_org=i.org_id and qualified_intent is null;end if;
 return pid;end $$;
create function public.zp_claim_referral(p_access text,p_site uuid) returns int language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members; n int;w int;granted int:=0;last_period public.zp_subscription_periods;pid uuid;st timestamptz;begin
 m:=public.zp_actor(p_access,p_site);if m.role_code<>'promoteur' or public.zp_paid_plan(m.org_id) is null then raise exception 'DENIED';end if;
 perform 1 from public.zp_organizations where id=m.org_id for update;
 select count(*)/5 into n from public.zp_referral_links where referrer_org=m.org_id and qualified_intent is not null;
 for w in 1..n loop
 if exists(select 1 from public.zp_referral_rewards where org_id=m.org_id and wave=w) then continue;end if;
 select * into last_period from public.zp_subscription_periods where org_id=m.org_id order by ends_at desc limit 1;
 st:=last_period.ends_at;
 insert into public.zp_subscription_periods(org_id,plan,cadence,starts_at,ends_at,source_ref) values(m.org_id,last_period.plan,last_period.cadence,st,((st at time zone 'Africa/Douala')+interval '1 month') at time zone 'Africa/Douala','referral:'||m.org_id||':'||w) returning id into pid;
 insert into public.zp_referral_rewards values(m.org_id,w,pid);granted:=granted+1;
 end loop;return granted;end $$;
create function public.zp_site_mode(p_access text,p_site uuid,p_space text,p_bar boolean,p_delivery boolean) returns void language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_actor(p_access,p_site);if m.role_code<>'promoteur' or public.zp_paid_plan(m.org_id) is null then raise exception 'DENIED';end if;
 -- No mode switch with existing catalog; migrations of operational data need a separate workflow.
 insert into public.zp_site_modes values(p_site,m.org_id,p_space,p_bar,p_delivery) on conflict(site_id) do nothing;
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space=p_space and bar_enabled=p_bar and delivery_enabled=p_delivery) then raise exception 'MODE_CHANGE_REQUIRES_MIGRATION';end if;end $$;
create function public.zp_add_menu_item(p_access text,p_site uuid,p_name text,p_post text,p_price int,p_qty int) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;s public.zp_site_modes;i uuid;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;
 select * into s from public.zp_site_modes where site_id=p_site and org_id=m.org_id;
 if s.site_id is null or not ((s.space='restaurant' and (p_post='kitchen' or (p_post='bar' and s.bar_enabled))) or (s.space='snack_bar' and p_post='snack')) then raise exception 'POST_DENIED';end if;
 insert into public.zp_menu_items(org_id,site_id,name,post,price_xaf,available_qty) values(m.org_id,p_site,trim(p_name),p_post,p_price,p_qty) returning id into i;return i;end $$;
create function public.zp_open_guest(p_qr_hash text,p_guest_hash text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare s public.zp_table_sessions;g uuid;begin
 select x.* into s from public.zp_table_sessions x join public.zp_tables t on t.id=x.table_id join public.zp_sites site on site.id=x.site_id join public.zp_organizations o on o.id=x.org_id where t.qr_hash=p_qr_hash and x.closed_at is null and site.active and o.active for update of x;
 if s.id is null or public.zp_paid_plan(s.org_id) is null then raise exception 'DENIED';end if;
 insert into public.zp_guest_sessions(table_session_id,org_id,site_id,token_hash,expires_at) values(s.id,s.org_id,s.site_id,p_guest_hash,now()+interval '4 hours') returning id into g;return g;end $$;
create function public.zp_create_order(p_access text,p_guest_hash text,p_site uuid,p_channel text,p_table_session uuid,p_request uuid,p_lines jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;g public.zp_guest_sessions;s public.zp_site_modes;org uuid;oid uuid;old public.zp_orders;line record;item public.zp_menu_items;total bigint:=0;body jsonb;begin
 if (p_access is null)=(p_guest_hash is null) then raise exception 'DENIED';end if;
 if p_guest_hash is not null then
 select x.* into g from public.zp_guest_sessions x join public.zp_table_sessions ts on ts.id=x.table_session_id join public.zp_sites si on si.id=x.site_id join public.zp_organizations o on o.id=x.org_id where x.token_hash=p_guest_hash and x.expires_at>now() and ts.closed_at is null and si.active and o.active for update of ts;
 if g.id is null or g.site_id<>p_site or p_channel<>'table' or p_table_session is distinct from g.table_session_id then raise exception 'DENIED';end if;org:=g.org_id;
 else m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;org:=m.org_id;end if;
 if public.zp_paid_plan(org) is null then raise exception 'SUBSCRIPTION_REQUIRED';end if;
 select * into s from public.zp_site_modes where site_id=p_site and org_id=org;
 if s.site_id is null or p_channel is null or p_channel not in ('table','counter','takeaway','delivery') or p_channel='delivery' then raise exception 'CHANNEL_DENIED';end if;
 if p_channel='table' then perform 1 from public.zp_table_sessions where id=p_table_session and org_id=org and site_id=p_site and closed_at is null for update;if not found then raise exception 'TABLE_CLOSED';end if;elsif p_table_session is not null then raise exception 'INVALID_TABLE';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) not between 1 and 50 then raise exception 'INVALID_LINES';end if;
 if exists(select 1 from jsonb_to_recordset(p_lines) as x(item_id uuid,qty int) where x.item_id is null or x.qty is null or x.qty not between 1 and 1000) then raise exception 'INVALID_QUANTITY';end if;
 -- Serializes duplicate submissions before stock changes, even for different requests.
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 body:=jsonb_build_object('site',p_site,'channel',p_channel,'table_session',p_table_session,'lines',p_lines);
 select * into old from public.zp_orders where request_id=p_request and ((m.id is not null and member_id=m.id) or (g.id is not null and guest_id=g.id));
 if old.id is not null then if old.request_body<>body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return jsonb_build_object('id',old.id,'total_xaf',old.total_xaf,'status',old.status);end if;
 insert into public.zp_orders(org_id,site_id,member_id,guest_id,table_session_id,request_id,request_body,channel) values(org,p_site,m.id,g.id,p_table_session,p_request,body,p_channel) returning id into oid;
 for line in select x.item_id,sum(x.qty)::bigint qty from jsonb_to_recordset(p_lines) as x(item_id uuid,qty int) group by x.item_id order by x.item_id loop
 if line.item_id is null or line.qty is null or line.qty not between 1 and 1000 then raise exception 'INVALID_QUANTITY';end if;
 update public.zp_menu_items set available_qty=available_qty-line.qty::int where id=line.item_id and org_id=org and site_id=p_site and active and available_qty>=line.qty returning * into item;
 if not found then raise exception 'ITEM_UNAVAILABLE';end if;
 insert into public.zp_order_lines values(oid,org,p_site,item.id,line.qty::int,item.price_xaf,item.post);
 total:=total+line.qty*item.price_xaf;
 end loop;
 update public.zp_orders set total_xaf=total where id=oid;
 return jsonb_build_object('id',oid,'total_xaf',total,'status','received');end $$;
-- Guest can read only own order and no operational data.
create function public.zp_guest_order(p_guest_hash text,p_order uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select jsonb_build_object('id',o.id,'status',o.status,'total_xaf',o.total_xaf,'created_at',o.created_at) from public.zp_orders o join public.zp_guest_sessions g on g.id=o.guest_id join public.zp_table_sessions ts on ts.id=g.table_session_id join public.zp_sites si on si.id=o.site_id join public.zp_organizations org on org.id=o.org_id where o.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and ts.closed_at is null and si.active and org.active
$$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_plan_catalog','zp_subscription_periods','zp_subscription_intents','zp_referral_links','zp_referral_rewards','zp_site_modes','zp_menu_items','zp_tables','zp_table_sessions','zp_guest_sessions','zp_orders','zp_order_lines'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);
 end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_actor','zp_paid_plan','zp_business_actor','zp_quote_intent','zp_confirm_subscription','zp_claim_referral','zp_site_mode','zp_add_menu_item','zp_open_guest','zp_create_order','zp_guest_order') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
