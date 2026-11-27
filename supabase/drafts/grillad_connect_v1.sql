-- GRILLAD side only, local candidate. Do not activate links before the bilateral contract is reviewed.
begin;
create table grillad_private.connect_links(
 id uuid primary key default gen_random_uuid(),org uuid not null,site uuid not null,zipple_org uuid not null,zipple_site uuid not null,
 token_hash text not null unique check(token_hash~'^[0-9a-f]{64}$'),enabled boolean not null default false,
 grillad_approved boolean not null default false,zipple_approved boolean not null default false,expires_at timestamptz not null,
 foreign key(org,site) references grillad_private.enabled_sites(org,site),foreign key(zipple_site,zipple_org) references famille_core.locations(id,organization_id),
 unique(id,org,site)
);
create table grillad_private.connect_catalog(
 link uuid not null,org uuid not null,site uuid not null,item uuid not null,
 primary key(link,item),foreign key(link,org,site) references grillad_private.connect_links(id,org,site),
 foreign key(item,org,site) references grillad_private.items(id,org,site)
);
create table grillad_private.connect_orders(
 id uuid primary key,link uuid not null,org uuid not null,site uuid not null,
 status text not null default 'submitted' check(status in ('submitted','accepted','preparing','ready','handed','refused','cancelled')),
 request jsonb not null,total bigint not null check(total>0),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(link,org,site) references grillad_private.connect_links(id,org,site),unique(id,org,site)
);
create table grillad_private.connect_lines(
 order_id uuid not null,org uuid not null,site uuid not null,item uuid not null,qty bigint not null check(qty>0),
 price bigint not null check(price>0),cost bigint,primary key(order_id,item),
 foreign key(order_id,org,site) references grillad_private.connect_orders(id,org,site),
 foreign key(item,org,site) references grillad_private.items(id,org,site)
);
create table grillad_private.connect_history(
 order_id uuid not null references grillad_private.connect_orders(id),event uuid not null,actor uuid not null,
 status text not null,request jsonb not null,created_at timestamptz not null default now(),primary key(order_id,event)
);
alter table grillad_private.connect_links enable row level security;
alter table grillad_private.connect_catalog enable row level security;
alter table grillad_private.connect_orders enable row level security;
alter table grillad_private.connect_lines enable row level security;
alter table grillad_private.connect_history enable row level security;
revoke all on grillad_private.connect_links,grillad_private.connect_catalog,grillad_private.connect_orders,grillad_private.connect_lines,grillad_private.connect_history from public,anon,authenticated;
-- No authorization by QR alone beyond the limited public catalogue/order/status routes.
create function grillad_private.connect_active(p_link uuid) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select exists(select 1 from grillad_private.connect_links l
 join grillad_private.enabled_sites e on e.org=l.org and e.site=l.site and e.enabled
 join famille_core.locations zs on zs.id=l.zipple_site and zs.organization_id=l.zipple_org and zs.status='active'
 join famille_core.applications za on za.code='zipple' and za.status='active'
 join famille_core.organization_apps zo on zo.organization_id=l.zipple_org and zo.app_id=za.id and zo.status='active'
 join famille_core.applications ga on ga.code='grillad' and ga.status='active'
 join famille_core.organization_apps goa on goa.organization_id=l.org and goa.app_id=ga.id and goa.status='active'
 where l.id=p_link and l.enabled and l.grillad_approved and l.zipple_approved and l.expires_at>now()
 and exists(select 1 from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id where s.organization_id=l.org and s.app_id=ga.id and s.status='active' and (s.starts_at is null or s.starts_at<=now()) and s.ends_at>now() and p.status='active' and ((p.code='grillad_premium_month' and p.amount_fcfa=6000 and p.billing_period='monthly') or (p.code='grillad_premium_year' and p.amount_fcfa=60000 and p.billing_period='yearly')))
 and exists(select 1 from famille_core.subscriptions s where s.organization_id=l.zipple_org and s.app_id=za.id and s.status='active' and (s.starts_at is null or s.starts_at<=now()) and s.ends_at>now()))
$$;
create function grillad_private.connect_qr(p_hash text) returns grillad_private.connect_links language plpgsql stable security definer set search_path=pg_catalog as $$
declare l grillad_private.connect_links%rowtype;
begin
 select * into l from grillad_private.connect_links where token_hash=p_hash;
 if not found or not grillad_private.connect_active(l.id) then raise exception 'GRILLAD_PARTNER_UNAVAILABLE' using errcode='42501';end if;
 return l;
end $$;
create function grillad_private.connect_public_catalog(p_hash text) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare l grillad_private.connect_links%rowtype;v jsonb;
begin
 l:=grillad_private.connect_qr(p_hash);
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'family',i.family,'price',i.price,'available',i.prepared-i.sold-i.connect_reserved>0) order by i.name),'[]'::jsonb) into v from grillad_private.connect_catalog c join grillad_private.items i on i.id=c.item and i.org=c.org and i.site=c.site where c.link=l.id and i.active;
 return jsonb_build_object('merchant','GRILLAD','currency','FCFA','payment','separate_cash_candidate','items',v);
end $$;
create function grillad_private.connect_submit(p_hash text,p_order uuid,p_lines jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare l grillad_private.connect_links%rowtype;o grillad_private.connect_orders%rowtype;i grillad_private.items%rowtype;line jsonb;item_id uuid;q bigint;t bigint:=0;
begin
 l:=grillad_private.connect_qr(p_hash);
 if p_order is null or p_lines is null or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines) not between 1 and 20 or octet_length(p_lines::text)>10000 then raise exception 'GRILLAD_ORDER' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(l.org::text||':'||l.site::text,0));
 l:=grillad_private.connect_qr(p_hash);
 select * into o from grillad_private.connect_orders where id=p_order;
 if found then
  if o.link<>l.id or o.request<>p_lines then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023';end if;
  return jsonb_build_object('id',o.id,'status',o.status,'total',o.total);
 end if;
 -- Abuse guard on unconfirmed QR requests, not a commercial point/seller limit.
 if (select count(*) from grillad_private.connect_orders where link=l.id and status='submitted')>=50 or (select count(*) from grillad_private.connect_orders where link=l.id and created_at>now()-interval '1 minute')>=10 then raise exception 'GRILLAD_QUEUE_BUSY' using errcode='22023';end if;
 for line in select value from jsonb_array_elements(p_lines) loop
  item_id:=(line->>'item')::uuid;q:=(line->>'qty')::bigint;
  if q is null or q not between 1 and 1000 or (select count(*) from jsonb_array_elements(p_lines) z where z->>'item'=item_id::text)<>1 then raise exception 'GRILLAD_ORDER_LINE' using errcode='22023';end if;
  select x.* into i from grillad_private.items x join grillad_private.connect_catalog c on c.item=x.id and c.org=x.org and c.site=x.site where c.link=l.id and x.id=item_id and x.active;
  if not found or q>i.prepared-i.sold-i.connect_reserved then raise exception 'GRILLAD_NOT_AVAILABLE' using errcode='22023';end if;
  t:=t+q*i.price;
 end loop;
 insert into grillad_private.connect_orders(id,link,org,site,request,total) values(p_order,l.id,l.org,l.site,p_lines,t);
 for line in select value from jsonb_array_elements(p_lines) loop
  item_id:=(line->>'item')::uuid;q:=(line->>'qty')::bigint;
  select * into i from grillad_private.items where id=item_id and org=l.org and site=l.site;
  insert into grillad_private.connect_lines values(p_order,l.org,l.site,i.id,q,i.price,i.cost);
 end loop;
 return jsonb_build_object('id',p_order,'status','submitted','total',t,'reserved',false);
end $$;
create function grillad_private.connect_public_status(p_hash text,p_order uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare l grillad_private.connect_links%rowtype;o grillad_private.connect_orders%rowtype;
begin
 l:=grillad_private.connect_qr(p_hash);select * into o from grillad_private.connect_orders where id=p_order and link=l.id;
 if not found then raise exception 'GRILLAD_ORDER_DENIED' using errcode='42501';end if;
 return jsonb_build_object('id',o.id,'status',o.status,'total',o.total);
end $$;
create function grillad_private.connect_list(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;v jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v from (
 select o.id,o.status,o.total,o.created_at,o.updated_at,(select coalesce(jsonb_agg(jsonb_build_object('name',i.name,'qty',c.qty,'price',c.price)),'[]'::jsonb) from grillad_private.connect_lines c join grillad_private.items i on i.id=c.item where c.order_id=o.id) lines
 from grillad_private.connect_orders o where o.org=p_org and o.site=p_site order by o.created_at desc limit 100) x;
 return jsonb_build_object('available',exists(select 1 from grillad_private.connect_links l where org=p_org and site=p_site and grillad_private.connect_active(l.id)),'orders',v);
end $$;
create function grillad_private.connect_transition(p_org uuid,p_site uuid,p_order uuid,p_event uuid,p_next text,p_received bigint,p_reason text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;o grillad_private.connect_orders%rowtype;c grillad_private.cash%rowtype;x record;prev grillad_private.connect_history%rowtype;req jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 if p_event is null or p_next not in ('accepted','preparing','ready','handed','refused','cancelled') or p_next is null then raise exception 'GRILLAD_STATUS' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 select * into o from grillad_private.connect_orders where id=p_order and org=p_org and site=p_site;
 if not found then raise exception 'GRILLAD_ORDER_DENIED' using errcode='42501';end if;
 req:=jsonb_build_object('next',p_next,'received',p_received,'reason',p_reason);
 select * into prev from grillad_private.connect_history where order_id=p_order and event=p_event;
 if found then
  if prev.actor<>auth.uid() or prev.request<>req then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023';end if;
  return jsonb_build_object('id',p_order,'status',prev.status);
 end if;
 if p_next='accepted' and o.status='submitted' then
  if not grillad_private.connect_active(o.link) then raise exception 'GRILLAD_PARTNER_UNAVAILABLE' using errcode='42501';end if;
  for x in select l.*,i.prepared-i.sold-i.connect_reserved remaining,i.price current_price,i.active from grillad_private.connect_lines l join grillad_private.items i on i.id=l.item where l.order_id=p_order loop
   if not x.active or x.qty>x.remaining or x.price<>x.current_price then raise exception 'GRILLAD_STOCK_OR_PRICE_CHANGED' using errcode='22023';end if;
   update grillad_private.items set connect_reserved=connect_reserved+x.qty where id=x.item;
  end loop;
 elsif p_next='preparing' and o.status='accepted' then null;
 elsif p_next='ready' and o.status='preparing' then null;
 elsif p_next='handed' and o.status='ready' then
  if p_received is null or p_received<>o.total then raise exception 'GRILLAD_SEPARATE_CASH_REQUIRED' using errcode='22023';end if;
  select * into c from grillad_private.cash where org=p_org and site=p_site and closed_at is null;
  if not found then raise exception 'GRILLAD_CASH_CLOSED' using errcode='22023';end if;
  for x in select * from grillad_private.connect_lines where order_id=p_order loop
   update grillad_private.items set connect_reserved=connect_reserved-x.qty,sold=sold+x.qty where id=x.item;
   insert into grillad_private.sales(id,org,site,item,cash,actor,qty,price,cost,source,connect_order) values(gen_random_uuid(),p_org,p_site,x.item,c.id,auth.uid(),x.qty,x.price,x.cost,'connect',p_order);
  end loop;
 elsif (p_next='refused' and o.status='submitted') or (p_next='cancelled' and o.status in ('submitted','accepted','preparing','ready')) then
  if p_reason is null or length(btrim(p_reason)) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  if o.status in ('accepted','preparing','ready') then
   for x in select * from grillad_private.connect_lines where order_id=p_order loop update grillad_private.items set connect_reserved=connect_reserved-x.qty where id=x.item;end loop;
  end if;
 else raise exception 'GRILLAD_STATUS' using errcode='22023';end if;
 update grillad_private.connect_orders set status=p_next,updated_at=now() where id=p_order;
 insert into grillad_private.connect_history(order_id,event,actor,status,request) values(p_order,p_event,auth.uid(),p_next,req);
 return jsonb_build_object('id',p_order,'status',p_next);
end $$;
create function public.grillad_connect_catalog(p_hash text) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.connect_public_catalog(p_hash)$$;
create function public.grillad_connect_submit(p_hash text,p_order uuid,p_lines jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.connect_submit(p_hash,p_order,p_lines)$$;
create function public.grillad_connect_status(p_hash text,p_order uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.connect_public_status(p_hash,p_order)$$;
create function public.grillad_connect_list(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.connect_list(p_org,p_site)$$;
create function public.grillad_connect_transition(p_org uuid,p_site uuid,p_order uuid,p_event uuid,p_next text,p_received bigint,p_reason text) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.connect_transition(p_org,p_site,p_order,p_event,p_next,p_received,p_reason)$$;
revoke all on function grillad_private.connect_active(uuid),grillad_private.connect_qr(text),grillad_private.connect_public_catalog(text),grillad_private.connect_submit(text,uuid,jsonb),grillad_private.connect_public_status(text,uuid),grillad_private.connect_list(uuid,uuid),grillad_private.connect_transition(uuid,uuid,uuid,uuid,text,bigint,text),public.grillad_connect_catalog(text),public.grillad_connect_submit(text,uuid,jsonb),public.grillad_connect_status(text,uuid),public.grillad_connect_list(uuid,uuid),public.grillad_connect_transition(uuid,uuid,uuid,uuid,text,bigint,text) from public,anon,authenticated;
grant execute on function grillad_private.connect_public_catalog(text),grillad_private.connect_submit(text,uuid,jsonb),grillad_private.connect_public_status(text,uuid),public.grillad_connect_catalog(text),public.grillad_connect_submit(text,uuid,jsonb),public.grillad_connect_status(text,uuid) to service_role;
grant execute on function grillad_private.connect_list(uuid,uuid),grillad_private.connect_transition(uuid,uuid,uuid,uuid,text,bigint,text),public.grillad_connect_list(uuid,uuid),public.grillad_connect_transition(uuid,uuid,uuid,uuid,text,bigint,text) to authenticated;
commit;
