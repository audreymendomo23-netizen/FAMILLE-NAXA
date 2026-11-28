begin;
create function grillad_private.connect_transition_method(p_org uuid,p_site uuid,p_order uuid,p_event uuid,p_next text,p_received bigint,p_reason text,p_method text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text;o grillad_private.connect_orders%rowtype;c grillad_private.cash%rowtype;x record;prev grillad_private.connect_history%rowtype;req jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 if p_event is null or p_next not in ('accepted','preparing','ready','handed','refused','cancelled') or p_next is null then raise exception 'GRILLAD_STATUS' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 select * into o from grillad_private.connect_orders where id=p_order and org=p_org and site=p_site;
 if not found then raise exception 'GRILLAD_ORDER_DENIED' using errcode='42501';end if;
 if p_method is null or p_method not in ('cash','mtn_momo','orange_money') or (p_next<>'handed' and p_method<>'cash') then raise exception 'GRILLAD_PAYMENT_METHOD' using errcode='22023';end if;
 req:=jsonb_build_object('next',p_next,'received',p_received,'reason',p_reason)||case when p_method='cash' then '{}'::jsonb else jsonb_build_object('method',p_method) end;
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
  insert into grillad_private.cash_receipts(id,org,site,cash,actor,source,amount,method) values(p_order,p_org,p_site,c.id,auth.uid(),'connect',p_received,p_method);
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
create function public.grillad_connect_transition_method(p_org uuid,p_site uuid,p_order uuid,p_event uuid,p_next text,p_received bigint,p_reason text,p_method text) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.connect_transition_method(p_org,p_site,p_order,p_event,p_next,p_received,p_reason,p_method)$$;
revoke all on function grillad_private.connect_transition_method(uuid,uuid,uuid,uuid,text,bigint,text,text),public.grillad_connect_transition_method(uuid,uuid,uuid,uuid,text,bigint,text,text) from public,anon,authenticated;
grant execute on function grillad_private.connect_transition_method(uuid,uuid,uuid,uuid,text,bigint,text,text),public.grillad_connect_transition_method(uuid,uuid,uuid,uuid,text,bigint,text,text) to authenticated;
create or replace function grillad_private.connect_transition(p_org uuid,p_site uuid,p_order uuid,p_event uuid,p_next text,p_received bigint,p_reason text) returns jsonb language sql security definer set search_path=pg_catalog as $$select grillad_private.connect_transition_method(p_org,p_site,p_order,p_event,p_next,p_received,p_reason,'cash')$$;
commit;
