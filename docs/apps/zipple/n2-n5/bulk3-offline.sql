begin;
create table public.zp_erp_sync_receipts(
 event_id uuid primary key,org_id uuid not null,site_id uuid not null,member_id uuid not null,
 action text not null,payload jsonb not null,state text not null check(state in ('acknowledged','conflict','rejected')),
 outcome jsonb,created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.zp_sites(id,org_id)
);
alter table public.zp_erp_sync_receipts enable row level security;
revoke all on public.zp_erp_sync_receipts from public,anon,authenticated;
grant select,insert on public.zp_erp_sync_receipts to service_role;
create function public.zp_offline_erp_apply(p_access text,p_site uuid,p_org uuid,p_member uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;old public.zp_erp_sync_receipts;st text:='acknowledged';outcome jsonb;v int;item uuid;servings int;begin
 m:=public.zp_erp_actor(p_access,p_site);
 if m.org_id is distinct from p_org or m.id is distinct from p_member then raise exception 'DENIED';end if;
 if p_event is null or (p_action is null or p_action not in ('produce','lot_receive','expense_record','count_lot')) or p_payload is null or jsonb_typeof(p_payload)<>'object' or length(p_payload::text)>2000 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into old from public.zp_erp_sync_receipts where event_id=p_event;
 if old.event_id is not null then
  if (old.org_id,old.site_id,old.member_id) is distinct from (p_org,p_site,p_member) then raise exception 'DENIED';end if;
  if (old.action,old.payload) is distinct from (p_action,p_payload) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return jsonb_build_object('app_id','ZIPPLE','event_id',p_event,'organization_id',p_org,'site_id',p_site,'state',old.state,'outcome',old.outcome);
 end if;
 begin
  if p_action='produce' then
  item:=(p_payload->>'item_id')::uuid;servings:=(p_payload->>'servings')::int;v:=(p_payload->>'expected_version')::int;
  if item is null or servings is null or servings not between 1 and 10000 or v is null or v<1 or p_payload<>jsonb_build_object('item_id',item,'servings',servings,'expected_version',v) then raise exception 'INVALID_INPUT';end if;
  if not exists(select 1 from public.zp_menu_items where id=item and org_id=p_org and site_id=p_site) then raise exception 'DENIED';end if;
  if v is distinct from (select max(version) from public.zp_recipe_versions where item_id=item and org_id=p_org and site_id=p_site) then raise exception 'STALE_RECIPE_VERSION';end if;
  outcome:=public.zp_produce(p_access,p_site,item,p_event,servings);
  elsif p_action='lot_receive' then
   outcome:=jsonb_build_object('id',public.zp_receive_lot(p_access,p_site,(p_payload->>'ingredient_id')::uuid,p_event,p_payload->>'label',p_payload->>'supplier',(p_payload->>'qty_milli')::bigint,(p_payload->>'cost_xaf')::bigint,(p_payload->>'expires_on')::date));
  elsif p_action='expense_record' then
   outcome:=jsonb_build_object('id',public.zp_record_expense(p_access,p_site,p_event,p_payload->>'category',p_payload->>'label',(p_payload->>'amount_xaf')::bigint,p_payload->>'method',p_payload->>'reference',(p_payload->>'expense_date')::date));
  elsif p_action='count_lot' then
   outcome:=jsonb_build_object('id',public.zp_count_lot(p_access,p_site,(p_payload->>'lot_id')::uuid,p_event,(p_payload->>'expected_milli')::bigint,(p_payload->>'counted_milli')::bigint,p_payload->>'reason'));
  end if;
 exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow or check_violation or not_null_violation then st:='rejected';outcome:=jsonb_build_object('code','INVALID_INPUT');
 when unique_violation then st:='conflict';outcome:=jsonb_build_object('code','DUPLICATE_RECORD');
 when raise_exception then
  if sqlerrm in ('EXPENSE_APPROVAL_REQUIRED','STALE_RECIPE_VERSION','INGREDIENT_SHORTAGE','IDEMPOTENCY_CONFLICT','STALE_INVENTORY_COUNT','DIRECT_STOCK_RESERVED','LEDGER_PERIOD_CLOSED','COUNT_REQUIRES_REVIEW','EXPIRED_LOT','WEIGHED_PRODUCTION_REQUIRED') then st:='conflict';outcome:=jsonb_build_object('code',sqlerrm);
  elsif sqlerrm in ('INVALID_INPUT','INVALID_PRODUCTION','DENIED','INVALID_EXPENSE_DATE') then st:='rejected';outcome:=jsonb_build_object('code',sqlerrm);else raise;end if;
 end;
 insert into public.zp_erp_sync_receipts(event_id,org_id,site_id,member_id,action,payload,state,outcome) values(p_event,p_org,p_site,p_member,p_action,p_payload,st,outcome);
 return jsonb_build_object('app_id','ZIPPLE','event_id',p_event,'organization_id',p_org,'site_id',p_site,'state',st,'outcome',outcome);
end $$;
revoke all on function public.zp_offline_erp_apply(text,uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.zp_offline_erp_apply(text,uuid,uuid,uuid,uuid,text,jsonb) to service_role;

-- NAXA family APPEND_ONLY_REVIEW: preserve the original conflict, never acknowledge a failed mutation.
create table public.zp_erp_sync_reviews(
 event_id uuid primary key references public.zp_erp_sync_receipts(event_id),
 org_id uuid not null,site_id uuid not null,member_id uuid not null,
 reason text not null check(length(reason) between 5 and 500),
 created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.zp_sites(id,org_id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id));
alter table public.zp_erp_sync_reviews enable row level security;
revoke all on public.zp_erp_sync_reviews from public,anon,authenticated;
grant select,insert on public.zp_erp_sync_reviews to service_role;
create function public.zp_erp_review_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $review$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('events',coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at,e.event_id) from (select r.event_id,r.action,r.payload,r.state,r.outcome,r.created_at,v.reason review_reason,v.created_at reviewed_at from public.zp_erp_sync_receipts r left join public.zp_erp_sync_reviews v on v.event_id=r.event_id where r.org_id=m.org_id and r.site_id=p_site and r.member_id=m.id and r.state in ('conflict','rejected') order by (v.event_id is not null),r.created_at desc limit 300)e),'[]'::jsonb));end $review$;
create function public.zp_erp_review_discard(p_access text,p_site uuid,p_event uuid,p_reason text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $review$
declare m public.zp_members;r public.zp_erp_sync_receipts;v public.zp_erp_sync_reviews;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 if length(why) not between 5 and 500 then raise exception 'INVALID_REVIEW_REASON';end if;
 select * into r from public.zp_erp_sync_receipts where event_id=p_event and org_id=m.org_id and site_id=p_site and member_id=m.id;
 if r.event_id is null or r.state not in ('conflict','rejected') then raise exception 'DENIED';end if;
 insert into public.zp_erp_sync_reviews(event_id,org_id,site_id,member_id,reason) values(p_event,m.org_id,p_site,m.id,why) on conflict(event_id) do nothing;
 select * into v from public.zp_erp_sync_reviews where event_id=p_event;
 if v.reason<>why then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 return jsonb_build_object('app_id','ZIPPLE','event_id',p_event,'organization_id',m.org_id,'site_id',p_site,'member_id',m.id,'state','reviewed','original_state',r.state,'reason',v.reason);end $review$;
revoke all on function public.zp_erp_review_snapshot(text,uuid),public.zp_erp_review_discard(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.zp_erp_review_snapshot(text,uuid),public.zp_erp_review_discard(text,uuid,uuid,text) to service_role;

commit;
