begin;
alter table grillad_private.cash_receipts drop constraint cash_receipts_method_check;
alter table grillad_private.cash_receipts add constraint cash_receipts_method_check check(method in ('cash','mtn_momo','orange_money'));
alter table grillad_private.cash_receipts add column reconciliation_reference text,add column reconciled_at timestamptz,add column reconciled_by uuid;
alter table grillad_private.cash_receipts add constraint grillad_mobile_reconciliation_shape check((reconciled_at is null and reconciled_by is null and reconciliation_reference is null) or (method<>'cash' and reconciled_at is not null and reconciled_by is not null and length(reconciliation_reference) between 4 and 160));
create unique index grillad_unique_mobile_reference on grillad_private.cash_receipts(org,method,lower(reconciliation_reference)) where reconciliation_reference is not null;
create or replace function grillad_private.run(p_org uuid,p_site uuid,p_event uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r text; u uuid:=auth.uid(); old grillad_private.events%rowtype; x grillad_private.items%rowtype; c grillad_private.cash%rowtype; v grillad_private.sales%rowtype;expense_row grillad_private.expenses%rowtype;
 item_id uuid; qty bigint; line jsonb; basket_total bigint; basket_count int; n bigint; cost bigint; new_cost_value bigint; component_total bigint;component_unknown boolean;component_value bigint;label text; reason text; v_expected bigint; result jsonb; d date;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_event is null or p_action is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>8192 then raise exception 'GRILLAD_INPUT' using errcode='22023';end if;
 if r='seller' and p_action not in ('sell','sell_basket','prepare','attendance_request','missing_departure_request','missing_arrival_request') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 -- Serialize all mutations for the same site; no cross-site stock or drawer race.
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 r:=grillad_private.scope(p_org,p_site);
 if r='seller' and p_action not in ('sell','sell_basket','prepare','attendance_request','missing_departure_request','missing_arrival_request') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
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
 if p_action in ('sell','sell_basket') and coalesce(p_payload->>'method','cash') not in ('cash','mtn_momo','orange_money') then raise exception 'GRILLAD_PAYMENT_METHOD' using errcode='22023';end if;
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
  update grillad_private.items set cost=new_cost_value,cost_basis='manual',cost_components=null,cost_batch_units=1 where id=x.id;
  result:=jsonb_build_object('id',x.id,'old_cost',x.cost,'new_cost',new_cost_value,'effective_at',now());
 when 'set_cost_composition' then
  item_id:=(p_payload->>'item')::uuid;reason:=btrim(p_payload->>'reason');
  if jsonb_typeof(p_payload->'components') is distinct from 'array' or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_COST_COMPOSITION' using errcode='22023';end if;
  if jsonb_array_length(p_payload->'components') not between 1 and 30 then raise exception 'GRILLAD_COST_COMPOSITION' using errcode='22023';end if;
  select * into x from grillad_private.items where id=item_id and org=p_org and site=p_site and active;
  if not found then raise exception 'GRILLAD_ITEM' using errcode='42501';end if;
  qty:=1;if p_payload?'batch_units' then if jsonb_typeof(p_payload->'batch_units') is distinct from 'number' or (p_payload->>'batch_units') !~ '^[0-9]{1,7}$' then raise exception 'GRILLAD_COST_BATCH' using errcode='22023';end if;qty:=(p_payload->>'batch_units')::bigint;end if;
  if qty not between 1 and 1000000 then raise exception 'GRILLAD_COST_BATCH' using errcode='22023';end if;
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
  new_cost_value:=case when component_unknown then null else (component_total+qty-1)/qty end;
  update grillad_private.items set cost=new_cost_value,cost_basis='composition_estimate',cost_components=p_payload->'components',cost_batch_units=qty::integer where id=x.id;
  result:=jsonb_build_object('id',x.id,'old_cost',x.cost,'new_cost',new_cost_value,'batch_units',qty,'batch_total',case when component_unknown then null else component_total end,'quality',case when component_unknown then 'incomplete' else 'estimated' end);
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
  if (p_payload->>'price')::bigint is distinct from x.price or (p_payload->>'received')::bigint is distinct from qty*x.price then raise exception 'GRILLAD_CASH_DECLARATION' using errcode='22023';end if;
  if qty>x.prepared-x.sold-x.connect_reserved then raise exception 'GRILLAD_STOCK' using errcode='22023';end if;
  insert into grillad_private.sales(id,org,site,item,cash,actor,qty,price,cost) values(p_event,p_org,p_site,x.id,c.id,u,qty,x.price,x.cost);
  update grillad_private.items set sold=sold+qty where id=x.id;
  insert into grillad_private.cash_receipts(id,org,site,cash,actor,source,amount,method) values(p_event,p_org,p_site,c.id,u,'direct',qty*x.price,coalesce(p_payload->>'method','cash'));
  result:=jsonb_build_object('id',p_event,'total',qty*x.price,'received',qty*x.price,'remaining',x.prepared-x.sold-x.connect_reserved-qty);
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
  if (p_payload->>'received')::bigint is distinct from basket_total then raise exception 'GRILLAD_CASH_DECLARATION' using errcode='22023';end if;
  insert into grillad_private.cash_receipts(id,org,site,cash,actor,source,amount,method) values(p_event,p_org,p_site,c.id,u,'direct',basket_total,coalesce(p_payload->>'method','cash'));
  result:=jsonb_build_object('id',p_event,'total',basket_total,'received',basket_total,'lines',basket_count);
 when 'cancel_basket' then
  reason:=btrim(p_payload->>'reason');item_id:=(p_payload->>'sale')::uuid;
  if reason is null or length(reason) not between 1 and 300 or item_id is null then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  if not exists(select 1 from grillad_private.sales where org=p_org and site=p_site and direct_order=item_id and cash=c.id and cancelled_at is null) then raise exception 'GRILLAD_SALE' using errcode='22023';end if;
  for v in select * from grillad_private.sales where org=p_org and site=p_site and direct_order=item_id and cash=c.id and cancelled_at is null loop
   update grillad_private.sales set cancelled_at=now(),cancelled_by=u,cancel_reason=reason where id=v.id;
   update grillad_private.items set sold=sold-v.qty where id=v.item;
  end loop;
  update grillad_private.cash_receipts set reversed_at=now(),reversed_by=u,reverse_reason=reason where id=item_id and org=p_org and site=p_site and source='direct' and cash=c.id and reversed_at is null;
  if not found then raise exception 'GRILLAD_CASH_RECEIPT_MISSING' using errcode='22023';end if;
  result:=jsonb_build_object('id',item_id,'cancelled',true);
 when 'cancel_sale' then
  reason:=btrim(p_payload->>'reason');if reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  select * into v from grillad_private.sales where id=(p_payload->>'sale')::uuid and org=p_org and site=p_site and cash=c.id and cancelled_at is null and source='direct' and direct_order is null;
  if not found then raise exception 'GRILLAD_SALE' using errcode='22023';end if;
  update grillad_private.sales set cancelled_at=now(),cancelled_by=u,cancel_reason=reason where id=v.id;
  update grillad_private.items set sold=sold-v.qty where id=v.item;
  update grillad_private.cash_receipts set reversed_at=now(),reversed_by=u,reverse_reason=reason where id=v.id and org=p_org and site=p_site and source='direct' and cash=c.id and reversed_at is null;
  if not found then raise exception 'GRILLAD_CASH_RECEIPT_MISSING' using errcode='22023';end if;
  result:=jsonb_build_object('id',v.id,'cancelled',true);
 when 'record_purchase' then
  label:=btrim(p_payload->>'supplier');reason:=btrim(p_payload->>'input_name');n:=(p_payload->>'amount')::bigint;
  if label is null or length(label) not between 1 and 160 or reason is null or length(reason) not between 1 and 160 or length(coalesce(btrim(p_payload->>'unit'),'')) not between 1 and 40 or n is null or n not between 1 and 1000000000 or length(btrim(p_payload->>'receipt_reference'))>160 or jsonb_typeof(p_payload->'quantity') is distinct from 'number' or (p_payload->>'quantity') !~ '^[0-9]{1,9}(\.[0-9]{1,3})?$' or (p_payload->>'quantity')::numeric<=0 then raise exception 'GRILLAD_PURCHASE_INPUT' using errcode='22023';end if;
  insert into grillad_private.purchases(id,org,site,actor,supplier,input_name,unit,quantity,amount,receipt_reference) values(p_event,p_org,p_site,u,label,reason,btrim(p_payload->>'unit'),(p_payload->>'quantity')::numeric,n,nullif(btrim(p_payload->>'receipt_reference'),''));
  result:=jsonb_build_object('id',p_event,'status','received','unit_cost_estimate',round(n/(p_payload->>'quantity')::numeric,2));
 when 'cancel_purchase' then
  item_id:=(p_payload->>'purchase')::uuid;reason:=btrim(p_payload->>'reason');
  if reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  update grillad_private.purchases set cancelled_at=now(),cancelled_by=u,cancel_reason=btrim(p_payload->>'reason') where id=item_id and org=p_org and site=p_site and cancelled_at is null;
  if not found then raise exception 'GRILLAD_PURCHASE_DENIED' using errcode='42501';end if;
  result:=jsonb_build_object('id',item_id,'status','cancelled');
 when 'expense' then
  label:=btrim(p_payload->>'label');n:=(p_payload->>'value')::bigint;
  if label is null or length(label) not between 1 and 160 or n is null or n not between 1 and 1000000000 then raise exception 'GRILLAD_EXPENSE' using errcode='22023';end if;
  reason:=coalesce(nullif(btrim(p_payload->>'category'),''),'Autres');
  if length(reason)>80 or length(btrim(p_payload->>'receipt_reference'))>160 then raise exception 'GRILLAD_EXPENSE_DETAIL' using errcode='22023';end if;
  insert into grillad_private.expenses(id,org,site,cash,actor,label,value,category,receipt_reference) values(p_event,p_org,p_site,c.id,u,label,n,reason,nullif(btrim(p_payload->>'receipt_reference'),''));
  result:=jsonb_build_object('id',p_event,'category',reason,'status','paid');
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
  v_expected:=c.opening+coalesce((select sum(amount) from grillad_private.cash_receipts where cash=c.id and reversed_at is null and method='cash'),0)-coalesce((select sum(value) from grillad_private.expenses where cash=c.id and cancelled_at is null),0);
  if n<>v_expected and (reason is null or length(reason) not between 1 and 300) then raise exception 'GRILLAD_REASON' using errcode='22023';end if;
  update grillad_private.cash set counted=n,expected=v_expected,closed_at=now(),close_reason=reason where id=c.id;
  result:=jsonb_build_object('id',c.id,'expected',v_expected,'counted',n,'difference',n-v_expected);
 when 'reconcile_mobile' then
  if r not in ('owner','manager') then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  item_id:=(p_payload->>'receipt')::uuid;label:=p_payload->>'source';reason:=btrim(p_payload->>'reference');n:=(p_payload->>'amount')::bigint;
  if label is null or label not in ('direct','connect') or reason is null or length(reason) not between 4 and 160 or n is null or n<=0 then raise exception 'GRILLAD_RECONCILE_INPUT' using errcode='22023';end if;
  if not exists(select 1 from grillad_private.cash_receipts cr where cr.org=p_org and cr.site=p_site and cr.id=item_id and cr.source=label and cr.method in ('mtn_momo','orange_money') and cr.reversed_at is null and cr.amount=n and cr.reconciled_at is null) then raise exception 'GRILLAD_RECONCILE_DENIED' using errcode='42501';end if;
  update grillad_private.cash_receipts set reconciliation_reference=reason,reconciled_at=now(),reconciled_by=u where org=p_org and site=p_site and id=item_id and source=label;
  result:=jsonb_build_object('id',item_id,'status','reconciled');
 when 'cash_recount_request' then
  item_id:=(p_payload->>'cash')::uuid;n:=(p_payload->>'counted')::bigint;reason:=btrim(p_payload->>'reason');
  select * into c from grillad_private.cash where id=item_id and org=p_org and site=p_site and closed_at is not null;
  if not found then raise exception 'GRILLAD_CLOSED_CASH_DENIED' using errcode='42501';end if;
  if n is null or n<0 or n>1000000000000 or n=c.counted or reason is null or length(reason) not between 1 and 300 or exists(select 1 from grillad_private.cash_recounts cr where cr.cash=c.id and cr.status in ('pending','approved')) then raise exception 'GRILLAD_RECOUNT_INPUT' using errcode='22023';end if;
  insert into grillad_private.cash_recounts(id,org,site,cash,requester,proposed_count,reason) values(p_event,p_org,p_site,c.id,u,n,reason);
  result:=jsonb_build_object('id',p_event,'status','pending');
 when 'cash_recount_decide' then
  if r<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  item_id:=(p_payload->>'request')::uuid;label:=p_payload->>'decision';reason:=btrim(p_payload->>'reason');
  if label is null or label not in ('approved','rejected') or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_RECOUNT_DECISION' using errcode='22023';end if;
  if not exists(select 1 from grillad_private.cash_recounts cr where cr.id=item_id and cr.org=p_org and cr.site=p_site and cr.requester<>u) then raise exception 'GRILLAD_RECOUNT_DENIED' using errcode='42501';end if;
  update grillad_private.cash_recounts set status=label,decided_by=u,decided_at=now(),decision_reason=btrim(p_payload->>'reason') where id=item_id and org=p_org and site=p_site and status='pending';
  if not found then raise exception 'GRILLAD_RECOUNT_CLOSED' using errcode='22023';end if;
  result:=jsonb_build_object('id',item_id,'status',label);
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
 when 'set_site_enabled' then
  result:=grillad_private.set_site_enabled(p_org,p_site,p_payload);
 when 'set_team_assignment' then
  result:=grillad_private.set_team_assignment(p_org,p_site,p_payload);
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
 when 'employee_request' then
  result:=grillad_private.central_request(p_org,p_site,p_event,p_action,p_payload);
 when 'renewal_request' then
  result:=grillad_private.central_request(p_org,p_site,p_event,p_action,p_payload);
 when 'central_request_cancel' then
  result:=grillad_private.central_request(p_org,p_site,p_event,p_action,p_payload);
 when 'schedule_service_hours' then
  if r<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
  n:=(p_payload->>'start_minute')::bigint;d:=(p_payload->>'effective_from')::date;reason:=btrim(p_payload->>'reason');
  if n is null or n not between 0 and 1439 or d is null or d<=(now() at time zone 'Africa/Douala')::date or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_SERVICE_INPUT' using errcode='22023';end if;
  if not exists(select 1 from grillad_private.service_policy p where p.org=p_org and p.site=p_site and p.enabled and p.effective_from<d) or exists(select 1 from grillad_private.service_revisions sr where sr.org=p_org and sr.site=p_site and sr.effective_from>=d) or exists(select 1 from grillad_private.daily_summary ds where ds.org=p_org and ds.site=p_site and ds.service_day>=d-1) then raise exception 'GRILLAD_SERVICE_HISTORY' using errcode='22023';end if;
  insert into grillad_private.service_revisions(org,site,effective_from,start_minute,reason,actor) values(p_org,p_site,d,n::integer,reason,u);
  result:=jsonb_build_object('start_minute',n,'effective_from',d,'scheduled',true);
 when 'connect_item_set' then
  result:=grillad_private.connect_configure(p_org,p_site,p_action,p_payload);
 when 'connect_link_set' then
  result:=grillad_private.connect_configure(p_org,p_site,p_action,p_payload);
 when 'set_attendance_policy' then
  result:=grillad_private.set_attendance_policy(p_org,p_site,p_payload);
 when 'missing_arrival_request' then
  result:=grillad_private.missing_arrival(p_org,p_site,p_event,p_action,p_payload);
 when 'missing_arrival_decide' then
  result:=grillad_private.missing_arrival(p_org,p_site,p_event,p_action,p_payload);
 when 'missing_departure_request' then
  result:=grillad_private.missing_departure(p_org,p_site,p_event,p_action,p_payload);
 when 'missing_departure_decide' then
  result:=grillad_private.missing_departure(p_org,p_site,p_event,p_action,p_payload);
 when 'attendance_request' then
  result:=grillad_private.attendance_correct(p_org,p_site,p_event,p_action,p_payload);
 when 'attendance_decide' then
  result:=grillad_private.attendance_correct(p_org,p_site,p_event,p_action,p_payload);
 when 'dimension_target' then
  d:=(p_payload->>'day')::date;n:=(p_payload->>'amount')::bigint;label:=p_payload->>'kind';reason:=btrim(p_payload->>'reason');
  if d is null or n is null or n not between 0 and 1000000000 or label is null or label not in ('seller','family','item') or reason is null or length(reason) not between 1 and 300 then raise exception 'GRILLAD_TARGET_INPUT' using errcode='22023';end if;
  if label='family' then
   if coalesce(p_payload->>'subject','') not in ('Porc','Poulet','Poisson','Brochettes','Omelettes') then raise exception 'GRILLAD_TARGET_SUBJECT' using errcode='22023';end if;
  elsif label='item' then
   if not exists(select 1 from grillad_private.items i where i.id=(p_payload->>'subject')::uuid and i.org=p_org and i.site=p_site and i.active) then raise exception 'GRILLAD_TARGET_SUBJECT' using errcode='42501';end if;
  else
   if not exists(select 1 from famille_core.memberships m join famille_core.role_assignments a on a.membership_id=m.id and a.app_id=m.app_id and a.organization_id=m.organization_id join famille_core.client_app_access ca on ca.user_id=m.user_id and ca.app_id=m.app_id and ca.status='granted' where m.user_id=(p_payload->>'subject')::uuid and m.organization_id=p_org and m.app_id=famille_core.current_app_id() and m.status='active' and a.status='active' and a.starts_at<=now() and (a.expires_at is null or a.expires_at>now()) and a.location_id=p_site and a.role_code='seller') then raise exception 'GRILLAD_TARGET_SUBJECT' using errcode='42501';end if;
  end if;
  insert into grillad_private.dimension_targets(org,site,day,kind,subject,amount,changed_by) values(p_org,p_site,d,label,case when label='family' then p_payload->>'subject' else ((p_payload->>'subject')::uuid)::text end,n,u) on conflict(org,site,day,kind,subject) do update set amount=excluded.amount,changed_by=excluded.changed_by,changed_at=now();
  result:=jsonb_build_object('day',d,'kind',label,'subject',p_payload->>'subject','amount',n);
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
create or replace function grillad_private.snapshot(p_org uuid,p_site uuid,p_from date,p_to date)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();v_items jsonb;v_sales jsonb;v_finance jsonb;v_cash jsonb;v_expenses jsonb;v_forecasts jsonb;v_target bigint;v_notices jsonb;v_inactive_items jsonb;v_cash_history jsonb;v_adjustments jsonb;v_dimensions jsonb;v_receipts jsonb;v_purchases jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'GRILLAD_PERIOD' using errcode='22023';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'family',i.family,'price',i.price,'prepared',i.prepared-i.adjustment_net,'adjustment_net',i.adjustment_net,'sold',i.sold,'remaining',i.prepared-i.sold-i.connect_reserved)||case when r='seller' then '{}'::jsonb else jsonb_build_object('cost',i.cost,'cost_basis',i.cost_basis,'cost_components',i.cost_components,'cost_batch_units',i.cost_batch_units,'cost_quality',case when i.cost is null then 'incomplete' else 'estimated' end) end order by i.name),'[]'::jsonb) into v_items from grillad_private.items i where org=p_org and site=p_site and active;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'item',s.item,'qty',s.qty,'total',s.total,'actor',s.actor,'at',s.created_at,'cancelled',s.cancelled_at is not null,'source',s.source,'direct_order',s.direct_order) order by s.created_at desc),'[]'::jsonb) into v_sales from (select * from grillad_private.sales where org=p_org and site=p_site and (r<>'seller' or actor=u) and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) s;
 if r<>'seller' then
 select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc),'[]'::jsonb) into v_adjustments from (select id,item,delta,reason,actor,created_at from grillad_private.stock_adjustments where org=p_org and site=p_site and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) a;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'family',i.family,'price',i.price) order by i.name),'[]'::jsonb) into v_inactive_items from grillad_private.items i where i.org=p_org and i.site=p_site and not i.active;
 select coalesce(jsonb_agg(to_jsonb(h) order by h.closed_at desc),'[]'::jsonb) into v_cash_history from (select c.id,c.opened_at,c.closed_at,c.opening,c.expected,c.counted,c.counted-c.expected as difference,c.close_reason,coalesce((select cr.proposed_count from grillad_private.cash_recounts cr where cr.cash=c.id and cr.status='approved'),c.counted) as reviewed_counted,coalesce((select cr.proposed_count from grillad_private.cash_recounts cr where cr.cash=c.id and cr.status='approved'),c.counted)-c.expected as reviewed_difference,coalesce((select jsonb_agg(jsonb_build_object('id',cr.id,'requester',cr.requester,'proposed_count',cr.proposed_count,'reason',cr.reason,'status',cr.status,'decision_reason',cr.decision_reason) order by cr.created_at desc) from grillad_private.cash_recounts cr where cr.cash=c.id),'[]'::jsonb) as recounts from grillad_private.cash c where c.org=p_org and c.site=p_site and c.closed_at is not null and (c.closed_at at time zone 'Africa/Douala')::date between p_from and p_to order by c.closed_at desc limit 200) h;
 select jsonb_build_object('ca',coalesce(sum(total),0),'encaissements',(select coalesce(sum(amount),0) from grillad_private.cash_receipts where org=p_org and site=p_site and reversed_at is null and method='cash' and (recorded_at at time zone 'Africa/Douala')::date between p_from and p_to),'sales_count',count(distinct (site,coalesce(direct_order,id))) filter(where source='direct')+count(distinct connect_order) filter(where source='connect'),'direct_ca',coalesce(sum(total) filter(where source='direct'),0),'connect_ca',coalesce(sum(total) filter(where source='connect'),0),'cost',case when count(*) filter(where cost is null)>0 then null else coalesce(sum(qty*cost),0) end,'charges',(select coalesce(sum(value),0) from grillad_private.expenses where org=p_org and site=p_site and cancelled_at is null and (created_at at time zone 'Africa/Douala')::date between p_from and p_to)) into v_finance from grillad_private.sales where org=p_org and site=p_site and cancelled_at is null and (created_at at time zone 'Africa/Douala')::date between p_from and p_to;
 select jsonb_build_object('id',c.id,'opening',c.opening,'expected',c.opening+coalesce((select sum(amount) from grillad_private.cash_receipts where cash=c.id and reversed_at is null and method='cash'),0)-coalesce((select sum(value) from grillad_private.expenses where cash=c.id and cancelled_at is null),0)) into v_cash from grillad_private.cash c where org=p_org and site=p_site and closed_at is null;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]'::jsonb) into v_expenses from (select id,label,value,cash,actor,category,receipt_reference,case when cancelled_at is null then 'paid' else 'cancelled' end status,created_at,cancelled_at,cancelled_by,cancel_reason from grillad_private.expenses where org=p_org and site=p_site and (created_at at time zone 'Africa/Douala')::date between p_from and p_to order by created_at desc limit 200) e;
 v_finance:=v_finance||jsonb_build_object('mtn_declared',(select coalesce(sum(amount),0) from grillad_private.cash_receipts where org=p_org and site=p_site and reversed_at is null and method='mtn_momo' and (recorded_at at time zone 'Africa/Douala')::date between p_from and p_to),'orange_declared',(select coalesce(sum(amount),0) from grillad_private.cash_receipts where org=p_org and site=p_site and reversed_at is null and method='orange_money' and (recorded_at at time zone 'Africa/Douala')::date between p_from and p_to),'mobile_pending',(select coalesce(sum(amount),0) from grillad_private.cash_receipts where org=p_org and site=p_site and reversed_at is null and method<>'cash' and reconciled_at is null and (recorded_at at time zone 'Africa/Douala')::date between p_from and p_to));
 select coalesce(jsonb_agg(to_jsonb(q) order by q.recorded_at desc),'[]'::jsonb) into v_receipts from (select id,source,amount,method,cash,actor,recorded_at,reversed_at,reverse_reason,reconciled_at from grillad_private.cash_receipts where org=p_org and site=p_site and (recorded_at at time zone 'Africa/Douala')::date between p_from and p_to order by recorded_at desc limit 200) q;
 if r<>'seller' then select coalesce(jsonb_agg(to_jsonb(q) order by q.received_at desc),'[]'::jsonb) into v_purchases from (select id,supplier,input_name,unit,quantity,amount,round(amount/quantity,2) unit_cost_estimate,actor,receipt_reference,received_at,cancelled_at,cancel_reason from grillad_private.purchases where org=p_org and site=p_site and (received_at at time zone 'Africa/Douala')::date between p_from and p_to order by received_at desc limit 200)q;end if;
 select amount into v_target from grillad_private.targets where org=p_org and site=p_site and day=p_to;
 select coalesce(jsonb_agg(jsonb_build_object('kind',t.kind,'subject',t.subject,'day',t.day,'amount',t.amount,'actual',coalesce(a.actual,0),'label',case when t.kind='item' then coalesce((select i.name from grillad_private.items i where i.org=p_org and i.site=p_site and i.id::text=t.subject),t.subject) else t.subject end) order by t.kind,t.subject),'[]'::jsonb) into v_dimensions from grillad_private.dimension_targets t left join lateral(select sum(s.total) actual from grillad_private.sales s join grillad_private.items i on i.id=s.item and i.org=s.org and i.site=s.site where s.org=t.org and s.site=t.site and s.cancelled_at is null and (s.created_at at time zone 'Africa/Douala')::date=t.day and ((t.kind='item' and s.item::text=t.subject) or (t.kind='family' and i.family=t.subject) or (t.kind='seller' and s.actor::text=t.subject))) a on true where t.org=p_org and t.site=p_site and t.day=p_to;
 select coalesce(jsonb_agg(jsonb_build_object('item',i.id,'name',i.name,'quantity',case when d.observed>=3 then ceil(d.mean)::bigint else null end,'days',d.observed)),'[]'::jsonb) into v_forecasts
 from grillad_private.items i cross join lateral (select count(*) observed,avg(q) mean from (select sum(s.qty) q from grillad_private.sales s where s.org=p_org and s.site=p_site and s.item=i.id and s.cancelled_at is null and (s.created_at at time zone 'Africa/Douala')::date<(now() at time zone 'Africa/Douala')::date and (s.created_at at time zone 'Africa/Douala')::date>=(now() at time zone 'Africa/Douala')::date-7 group by (s.created_at at time zone 'Africa/Douala')::date) daily) d
 where i.org=p_org and i.site=p_site and i.active;
 select coalesce(jsonb_agg(z),'[]'::jsonb) into v_notices from (select 'stock:'||id id,name||' : quantité épuisée' text from grillad_private.items where org=p_org and site=p_site and active and prepared=sold+connect_reserved union all select 'cash:'||id,'Écart de caisse à vérifier' from grillad_private.cash where org=p_org and site=p_site and closed_at is not null and counted<>expected and (closed_at at time zone 'Africa/Douala')::date=p_to) z;
 else select jsonb_build_object('id',c.id) into v_cash from grillad_private.cash c where org=p_org and site=p_site and closed_at is null;
 end if;
 return jsonb_build_object('role',r,'items',v_items,'sales',v_sales,'finance',v_finance,'cash',v_cash,'cash_receipts',coalesce(v_receipts,'[]'::jsonb),'purchases',coalesce(v_purchases,'[]'::jsonb),'cash_history',coalesce(v_cash_history,'[]'::jsonb),'inactive_items',coalesce(v_inactive_items,'[]'::jsonb),'stock_adjustments',coalesce(v_adjustments,'[]'::jsonb),'expenses',coalesce(v_expenses,'[]'::jsonb),'forecasts',coalesce(v_forecasts,'[]'::jsonb),'notices',coalesce(v_notices,'[]'::jsonb),'target',v_target,'dimension_targets',coalesce(v_dimensions,'[]'::jsonb),'from',p_from,'to',p_to,'generated_at',now());
end $$;
create or replace function grillad_private.report(p_org uuid,p_site uuid,p_from date,p_to date,p_network boolean,p_family text,p_actor uuid,p_item uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;site_ids uuid[];v jsonb;detail jsonb;lo timestamptz;hi timestamptz;
begin
 r:=grillad_private.scope(p_org,p_site);
 if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 or p_network is null or (p_family is not null and p_family not in ('Porc','Poulet','Poisson','Brochettes','Omelettes')) then raise exception 'GRILLAD_REPORT_FILTER' using errcode='22023';end if;
 if p_network then
  if r<>'owner' or not exists(select 1 from grillad_private.pilotage_policy where org=p_org and centralized) then raise exception 'GRILLAD_NETWORK_DENIED' using errcode='42501';end if;
  select array_agg(q.site) into site_ids from (select (x->>'site')::uuid site from jsonb_array_elements(grillad_private.workspace()) x where (x->>'org')::uuid=p_org and x->>'role'='owner'
  union select e.site from grillad_private.enabled_sites e where e.org=p_org and not e.enabled and famille_core.can_access_outlet(p_org,famille_core.current_app_id(),e.site) and exists(select 1 from famille_private.account_app_access g where g.user_id=auth.uid() and g.app_code='grillad' and g.organization_id=p_org and (g.location_id is null or g.location_id=e.site) and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())) and exists(select 1 from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id where s.organization_id=p_org and s.app_id=famille_core.current_app_id() and ((s.status='active' and (s.starts_at is null or s.starts_at<=now()) and s.ends_at>=now()) or (s.status='past_due' and s.grace_until>=now())) and p.code in ('grillad_premium_month','grillad_premium_year') and p.status='active'))q;
 else site_ids:=array[p_site];end if;
 if coalesce(cardinality(site_ids),0)=0 then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 lo:=p_from::timestamp at time zone 'Africa/Douala';hi:=(p_to+1)::timestamp at time zone 'Africa/Douala';
 -- Costs of a filtered slice may be known; site expenses are not attributed to articles/sellers without a rule.
 with selected as (
 select s.*,i.family from grillad_private.sales s join grillad_private.items i on i.id=s.item and i.org=s.org and i.site=s.site
 where s.org=p_org and s.site=any(site_ids) and not(s.cancelled_at is not null) and s.created_at>=lo and s.created_at<hi
 and (p_family is null or i.family=p_family) and (p_actor is null or s.actor=p_actor) and (p_item is null or s.item=p_item))
 select jsonb_build_object('ca',coalesce(sum(total),0),'encaissements',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=any(site_ids) and c.reversed_at is null and c.method='cash' and c.recorded_at>=lo and c.recorded_at<hi) end,'sales_count',count(distinct (site,coalesce(direct_order,id))) filter(where source='direct')+count(distinct connect_order) filter(where source='connect'),'quantity',coalesce(sum(qty),0),
 'direct_ca',coalesce(sum(total) filter(where source='direct'),0),'connect_ca',coalesce(sum(total) filter(where source='connect'),0),
 'cost',case when count(*) filter(where cost is null)>0 then null else coalesce(sum(qty*cost),0) end,
 'expenses',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(sum(e.value),0) from grillad_private.expenses e where e.cancelled_at is null and e.org=p_org and e.site=any(site_ids) and e.created_at>=lo and e.created_at<hi) end,
 'expenses_by_category',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(jsonb_agg(to_jsonb(q) order by q.category),'[]'::jsonb) from (select category,sum(value) amount,count(*) count from grillad_private.expenses e where e.org=p_org and e.site=any(site_ids) and e.cancelled_at is null and e.created_at>=lo and e.created_at<hi group by category)q) end,
 'purchase_amount',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(sum(p.amount),0) from grillad_private.purchases p where p.org=p_org and p.site=any(site_ids) and p.cancelled_at is null and p.received_at>=lo and p.received_at<hi) end,
 'purchases_by_supplier',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(jsonb_agg(to_jsonb(q) order by q.supplier),'[]'::jsonb) from (select supplier,sum(amount) amount,count(*) count from grillad_private.purchases p where p.org=p_org and p.site=any(site_ids) and p.cancelled_at is null and p.received_at>=lo and p.received_at<hi group by supplier)q) end,
 'by_family',coalesce((select jsonb_agg(to_jsonb(q) order by q.family) from (select family,coalesce(sum(total),0) ca,sum(qty) quantity from selected group by family)q),'[]'::jsonb),
 'by_seller',coalesce((select jsonb_agg(to_jsonb(q) order by q.actor) from (select actor,coalesce(sum(total),0) ca,sum(qty) quantity from selected group by actor)q),'[]'::jsonb)) into v from selected;
 select coalesce(jsonb_agg(jsonb_build_object('site',l.id,'name',l.name,'enabled',(select e.enabled from grillad_private.enabled_sites e where e.org=p_org and e.site=l.id),'ca',coalesce(s.ca,0),'expenses',case when p_family is not null or p_actor is not null or p_item is not null then null else coalesce(e.charges,0) end) order by l.name,l.id),'[]'::jsonb) into detail
 from famille_core.locations l left join lateral(select sum(a.total) ca from grillad_private.sales a join grillad_private.items i on i.id=a.item where a.org=p_org and a.site=l.id and a.cancelled_at is null and a.created_at>=lo and a.created_at<hi and (p_family is null or i.family=p_family) and (p_actor is null or a.actor=p_actor) and (p_item is null or a.item=p_item))s on true
 left join lateral(select sum(value) charges from grillad_private.expenses where cancelled_at is null and org=p_org and site=l.id and created_at>=lo and created_at<hi)e on true where l.organization_id=p_org and l.id=any(site_ids);
 return v||jsonb_build_object('sites',detail,'network',p_network,'from',p_from,'to',p_to,'generated_at',now(),'basis','confirmed_server_only','cash_assumption','physical_cash_only','mtn_declared',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=any(site_ids) and c.reversed_at is null and c.method='mtn_momo' and c.recorded_at>=lo and c.recorded_at<hi) end,'orange_declared',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=any(site_ids) and c.reversed_at is null and c.method='orange_money' and c.recorded_at>=lo and c.recorded_at<hi) end);
end $$;
create or replace function grillad_private.generate_daily(p_org uuid,p_site uuid,p_day date) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare p grillad_private.service_policy%rowtype;old grillad_private.daily_summary%rowtype;lo timestamptz;hi timestamptz;v jsonb;n integer;
begin
 select * into p from grillad_private.service_policy where org=p_org and site=p_site and enabled and effective_from<=p_day;
 if not found then raise exception 'GRILLAD_SERVICE_POLICY_REQUIRED' using errcode='22023';end if;
 lo:=grillad_private.service_boundary(p_org,p_site,p_day);hi:=grillad_private.service_boundary(p_org,p_site,p_day+1);
 if hi>now() then raise exception 'GRILLAD_SERVICE_OPEN' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 select * into old from grillad_private.daily_summary where org=p_org and site=p_site and service_day=p_day order by version desc limit 1;
 select jsonb_build_object('ca',coalesce(sum(s.total),0),'sales_count',count(distinct (s.site,coalesce(s.direct_order,s.id))) filter(where s.source='direct')+count(distinct s.connect_order) filter(where s.source='connect'),'sold',coalesce(sum(s.qty),0),
 'encaissements',(select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=p_site and c.reversed_at is null and c.method='cash' and c.recorded_at>=lo and c.recorded_at<hi),
 'mtn_declared',(select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=p_site and c.reversed_at is null and c.method='mtn_momo' and c.recorded_at>=lo and c.recorded_at<hi),
 'orange_declared',(select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=p_site and c.reversed_at is null and c.method='orange_money' and c.recorded_at>=lo and c.recorded_at<hi),
 'cost',case when count(*) filter(where s.cost is null)>0 then null else coalesce(sum(s.qty*s.cost),0) end,
 'expenses',(select coalesce(sum(e.value),0) from grillad_private.expenses e where e.cancelled_at is null and e.org=p_org and e.site=p_site and e.created_at>=lo and e.created_at<hi),
 'prepared',(select coalesce(sum(a.qty),0) from grillad_private.preparations a where a.org=p_org and a.site=p_site and a.created_at>=lo and a.created_at<hi),
 'stock_adjustments',(select coalesce(sum(a.delta),0) from grillad_private.stock_adjustments a where a.org=p_org and a.site=p_site and a.created_at>=lo and a.created_at<hi),
 'cash_difference',(select coalesce(sum(c.counted-c.expected),0) from grillad_private.cash c where c.org=p_org and c.site=p_site and c.closed_at>=lo and c.closed_at<hi),
 'reviewed_cash_difference',(select coalesce(sum(coalesce(cr.proposed_count,c.counted)-c.expected),0) from grillad_private.cash c left join grillad_private.cash_recounts cr on cr.cash=c.id and cr.status='approved' where c.org=p_org and c.site=p_site and c.closed_at>=lo and c.closed_at<hi),
 'open_cash_count',(select count(*) from grillad_private.cash c where c.org=p_org and c.site=p_site and c.opened_at<hi and (c.closed_at is null or c.closed_at>=hi)),
 'unpaired_arrivals',(select count(*) from grillad_private.attendance a where a.org=p_org and a.site=p_site and a.kind='arrival' and a.captured_at<hi and a.captured_at>=lo and not exists(select 1 from grillad_private.attendance b where b.paired_arrival=a.id and b.captured_at<hi) and not exists(select 1 from grillad_private.missing_departures m where m.arrival=a.id and m.status='approved' and m.proposed_at<hi)),
 'manual_arrivals',(select count(*) from grillad_private.missing_arrivals m join grillad_private.attendance a on a.id=m.departure where m.org=p_org and m.site=p_site and m.status='approved' and a.captured_at>=lo and a.captured_at<hi),
 'unpaired_departures',(select count(*) from grillad_private.attendance a where a.org=p_org and a.site=p_site and a.kind='departure_without_arrival' and a.captured_at>=lo and a.captured_at<hi and not exists(select 1 from grillad_private.missing_arrivals m where m.departure=a.id and m.status='approved')),
 'manual_departures',(select count(*) from grillad_private.missing_departures m where m.org=p_org and m.site=p_site and m.status='approved' and m.proposed_at>=lo and m.proposed_at<hi),
 'target',(select amount from grillad_private.targets where org=p_org and site=p_site and day=p_day),
 'direct_ca',coalesce(sum(s.total) filter(where s.source='direct'),0),'connect_ca',coalesce(sum(s.total) filter(where s.source='connect'),0),'basis','server_confirmed_only') into v from grillad_private.sales s where s.org=p_org and s.site=p_site and s.created_at>=lo and s.created_at<hi and s.cancelled_at is null;
 v:=v||jsonb_build_object('provisional',((v->>'open_cash_count')::bigint>0 or (v->>'unpaired_arrivals')::bigint>0 or (v->>'unpaired_departures')::bigint>0),'margin',case when v->'cost'='null'::jsonb then null else (v->>'ca')::bigint-(v->>'cost')::bigint end,'operating_result',case when v->'cost'='null'::jsonb then null else (v->>'ca')::bigint-(v->>'cost')::bigint-(v->>'expenses')::bigint end);
 if old.version is not null and old.data=v and old.starts_at=lo and old.ends_at=hi then return jsonb_build_object('version',old.version,'changed',false);end if;
 n:=coalesce(old.version,0)+1;
 insert into grillad_private.daily_summary(org,site,service_day,version,starts_at,ends_at,data) values(p_org,p_site,p_day,n,lo,hi,v);
 return jsonb_build_object('version',n,'changed',true);
end $$;
commit;
