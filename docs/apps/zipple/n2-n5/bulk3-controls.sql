-- ERP governance: port NAXA Services append-only decisions and NAXA atomic receipt.
-- Optional owner-configured thresholds; no invented commercial defaults.
begin;
create table public.zp_erp_control_policies(
 org_id uuid not null,site_id uuid not null,version integer not null check(version>0),
 purchase_threshold bigint check(purchase_threshold between 0 and 2147483647),
 expense_threshold bigint check(expense_threshold between 0 and 2147483647),
 quality_required boolean not null,separate_approver boolean not null,
 member_id uuid not null,reason text not null check(length(reason) between 5 and 500),
 created_at timestamptz not null default now(),primary key(site_id,version),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_purchase_decisions(
 purchase_id uuid primary key,org_id uuid not null,site_id uuid not null,member_id uuid not null,
 decision text not null check(decision in ('approved','rejected')),reason text not null check(length(reason) between 5 and 500),
 created_at timestamptz not null default now(),
 foreign key(purchase_id,org_id,site_id) references public.zp_purchases(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_purchase_quality(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,purchase_id uuid not null,member_id uuid not null,request_id uuid not null,
 qty_milli bigint not null check(qty_milli between 1 and 1000000000),lot_label text not null check(length(lot_label) between 1 and 100),expires_on date,conversion_id uuid,input_milli bigint not null,
 decision text not null check(decision in ('accepted','rejected')),reason text not null check(length(reason) between 5 and 500),
 created_at timestamptz not null default now(),unique(member_id,request_id),
 foreign key(purchase_id,org_id,site_id) references public.zp_purchases(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_expense_requests(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,
 category text not null check(category in ('rent','utilities','transport','staff','maintenance','other')),label text not null check(length(label) between 1 and 160),
 amount_xaf bigint not null check(amount_xaf between 1 and 2147483647),method text not null check(method in ('cash','mtn_momo','orange_money','bank','card')),
 reference text not null check(length(reference) between 4 and 160),expense_date date not null,created_at timestamptz not null default now(),
 unique(member_id,request_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_expense_decisions(
 expense_request_id uuid primary key references public.zp_expense_requests(id),org_id uuid not null,site_id uuid not null,member_id uuid not null,
 decision text not null check(decision in ('approved','rejected')),reason text not null check(length(reason) between 5 and 500),
 created_at timestamptz not null default now(),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
do $grants$ declare n text;begin
 foreach n in array array['zp_erp_control_policies','zp_purchase_decisions','zp_purchase_quality','zp_expense_requests','zp_expense_decisions'] loop
 execute format('alter table public.%I enable row level security',n);
 execute format('revoke all on public.%I from public,anon,authenticated',n);
 execute format('grant select,insert on public.%I to service_role',n);
 end loop;
end $grants$;
create function public.zp_erp_control_set(p_access text,p_site uuid,p_expected integer,p_purchase bigint,p_expense bigint,p_quality boolean,p_separate boolean,p_reason text) returns integer language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;v integer;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_expected is null or p_expected<0 or p_purchase<0 or p_purchase>2147483647 or p_expense<0 or p_expense>2147483647 or p_quality is null or p_separate is null or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 select coalesce(max(version),0) into v from public.zp_erp_control_policies where site_id=p_site and org_id=m.org_id;
 if p_expected<>v then raise exception 'STALE_CONTROL_POLICY';end if;
 insert into public.zp_erp_control_policies(org_id,site_id,version,purchase_threshold,expense_threshold,quality_required,separate_approver,member_id,reason) values(m.org_id,p_site,v+1,p_purchase,p_expense,p_quality,p_separate,m.id,why);return v+1;
end $f$;
create function public.zp_purchase_decide(p_access text,p_site uuid,p_purchase uuid,p_decision text,p_reason text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;p public.zp_purchases;d public.zp_purchase_decisions;c public.zp_erp_control_policies;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_decision is null or p_decision not in ('approved','rejected') or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 select * into p from public.zp_purchases where id=p_purchase and site_id=p_site and org_id=m.org_id for update;if p.id is null then raise exception 'DENIED';end if;
 select * into d from public.zp_purchase_decisions where purchase_id=p.id;
 if d.purchase_id is not null then if (d.member_id,d.decision,d.reason) is distinct from (m.id,p_decision,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return d.decision;end if;
 select * into c from public.zp_erp_control_policies where site_id=p_site and org_id=m.org_id order by version desc limit 1;
 if c.separate_approver and p.member_id=m.id then raise exception 'DENIED';end if;
 if p.received_milli<>0 then raise exception 'INVALID_TRANSITION';end if;
 insert into public.zp_purchase_decisions values(p.id,m.org_id,p_site,m.id,p_decision,why,now());return p_decision;
end $f$;
create function public.zp_purchase_receipt_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare p public.zp_purchases;d public.zp_purchase_decisions;c public.zp_erp_control_policies;total bigint;begin
 select * into p from public.zp_purchases where id=new.purchase_id and site_id=new.site_id and org_id=new.org_id;
 select * into c from public.zp_erp_control_policies where site_id=new.site_id and org_id=new.org_id order by version desc limit 1;
 select * into d from public.zp_purchase_decisions where purchase_id=p.id;
 -- A rejected order cannot later be received even if the threshold changes.
 if d.decision='rejected' then raise exception 'PURCHASE_APPROVAL_REQUIRED';end if;
 total:=p.total_xaf;
 select greatest(total,coalesce(max((select sum(q.total_xaf) from public.zp_purchases q where q.id=any(b.purchase_ids) and q.site_id=new.site_id and q.org_id=new.org_id)),0)) into total from public.zp_purchase_batches b where p.id=any(b.purchase_ids) and b.site_id=new.site_id and b.org_id=new.org_id;
 if c.purchase_threshold is not null and total>=c.purchase_threshold and (d.decision is distinct from 'approved' or (c.separate_approver and d.member_id=p.member_id)) then raise exception 'PURCHASE_APPROVAL_REQUIRED';end if;
 if c.quality_required and not exists(select 1 from public.zp_purchase_quality q where q.org_id=new.org_id and q.site_id=new.site_id and q.member_id=new.member_id and q.request_id=new.request_id and q.purchase_id=new.purchase_id and q.qty_milli=new.qty_milli and q.lot_label=new.lot_label and q.expires_on is not distinct from new.expires_on and q.decision='accepted') then raise exception 'PURCHASE_QUALITY_REQUIRED';end if;
 return new;
end $f$;
create trigger zp_purchase_receipt_control before insert on public.zp_purchase_receipts for each row execute function public.zp_purchase_receipt_guard();
create function public.zp_purchase_receive_checked(p_access text,p_site uuid,p_purchase uuid,p_request uuid,p_qty bigint,p_label text,p_expires date,p_conversion uuid,p_decision text,p_reason text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;p public.zp_purchases;q public.zp_purchase_quality;qty bigint;i uuid;receipt uuid;why text:=trim(coalesce(p_reason,''));lbl text:=trim(coalesce(p_label,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_request is null or p_qty is null or p_qty not between 1 and 1000000000 or length(lbl) not between 1 and 100 or p_decision is null or p_decision not in ('accepted','rejected') or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 select * into p from public.zp_purchases where id=p_purchase and org_id=m.org_id and site_id=p_site for update;if p.id is null then raise exception 'DENIED';end if;
 qty:=case when p_conversion is null then p_qty else public.zp_purchase_conversion_quantity(m.org_id,p_site,p.ingredient_id,p_conversion,p_qty) end;
 select * into q from public.zp_purchase_quality where member_id=m.id and request_id=p_request;
 if q.id is not null then
  if (q.org_id,q.site_id,q.purchase_id,q.qty_milli,q.lot_label,q.expires_on,q.conversion_id,q.input_milli,q.decision,q.reason) is distinct from (m.org_id,p_site,p_purchase,qty,lbl,p_expires,p_conversion,p_qty,p_decision,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;i:=q.id;
 else
  if exists(select 1 from public.zp_purchase_receipts where member_id=m.id and request_id=p_request) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  if qty>p.qty_milli-p.received_milli then raise exception 'RECEIPT_EXCEEDS_PURCHASE';end if;
  insert into public.zp_purchase_quality(org_id,site_id,purchase_id,member_id,request_id,qty_milli,lot_label,expires_on,conversion_id,input_milli,decision,reason) values(m.org_id,p_site,p_purchase,m.id,p_request,qty,lbl,p_expires,p_conversion,p_qty,p_decision,why) returning id into i;
 end if;
 if p_decision='accepted' then
  if p_conversion is null then receipt:=public.zp_purchase_receive(p_access,p_site,p_purchase,p_request,p_qty,lbl,p_expires);
  else receipt:=public.zp_purchase_receive_converted(p_access,p_site,p_purchase,p_conversion,p_request,p_qty,lbl,p_expires);end if;
 end if;
 return jsonb_build_object('quality_id',i,'decision',p_decision,'receipt_id',receipt);
end $f$;
-- A rejected quality inspection must never be replayed via the old direct API.
create function public.zp_purchase_reject_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $f$
begin
 if exists(select 1 from public.zp_purchase_quality q where q.member_id=new.member_id and q.request_id=new.request_id and q.decision='rejected') then raise exception 'PURCHASE_QUALITY_REQUIRED';end if;return new;
end $f$;
create trigger zp_purchase_rejected_quality before insert on public.zp_purchase_receipts for each row execute function public.zp_purchase_reject_guard();
create function public.zp_expense_submit(p_access text,p_site uuid,p_request uuid,p_category text,p_label text,p_amount bigint,p_method text,p_reference text,p_date date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;x public.zp_expense_requests;i uuid;lbl text:=trim(coalesce(p_label,''));ref text:=trim(coalesce(p_reference,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_request is null or p_date is null or p_date>(now() at time zone 'Africa/Douala')::date or p_amount is null or p_amount not between 1 and 2147483647 or length(lbl) not between 1 and 160 or length(ref) not between 4 and 160 or p_category is null or p_category not in ('rent','utilities','transport','staff','maintenance','other') or p_method is null or p_method not in ('cash','mtn_momo','orange_money','bank','card') then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 select * into x from public.zp_expense_requests where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.org_id,x.site_id,x.category,x.label,x.amount_xaf,x.method,x.reference,x.expense_date) is distinct from (m.org_id,p_site,p_category,lbl,p_amount,p_method,ref,p_date) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if exists(select 1 from public.zp_expenses where org_id=m.org_id and site_id=p_site and method=p_method and reference=ref) or exists(select 1 from public.zp_expense_requests q left join public.zp_expense_decisions d on d.expense_request_id=q.id where q.org_id=m.org_id and q.site_id=p_site and q.method=p_method and q.reference=ref and d.decision is distinct from 'rejected') then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 insert into public.zp_expense_requests(org_id,site_id,member_id,request_id,category,label,amount_xaf,method,reference,expense_date) values(m.org_id,p_site,m.id,p_request,p_category,lbl,p_amount,p_method,ref,p_date) returning id into i;return i;
end $f$;
create function public.zp_expense_decide(p_access text,p_site uuid,p_id uuid,p_decision text,p_reason text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;x public.zp_expense_requests;d public.zp_expense_decisions;c public.zp_erp_control_policies;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_decision is null or p_decision not in ('approved','rejected') or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 select * into x from public.zp_expense_requests where id=p_id and site_id=p_site and org_id=m.org_id;if x.id is null then raise exception 'DENIED';end if;
 select * into d from public.zp_expense_decisions where expense_request_id=x.id;
 if d.expense_request_id is not null then if (d.member_id,d.decision,d.reason) is distinct from (m.id,p_decision,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return d.decision;end if;
 select * into c from public.zp_erp_control_policies where site_id=p_site and org_id=m.org_id order by version desc limit 1;
 if c.separate_approver and x.member_id=m.id then raise exception 'DENIED';end if;
 insert into public.zp_expense_decisions values(x.id,m.org_id,p_site,m.id,p_decision,why,now());return p_decision;
end $f$;
create function public.zp_expense_insert_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare c public.zp_erp_control_policies;x public.zp_expense_requests;d public.zp_expense_decisions;begin
 select * into c from public.zp_erp_control_policies where site_id=new.site_id and org_id=new.org_id order by version desc limit 1;
 select * into x from public.zp_expense_requests where member_id=new.member_id and request_id=new.request_id;
 if x.id is not null or (c.expense_threshold is not null and new.amount_xaf>=c.expense_threshold) then
  select * into d from public.zp_expense_decisions where expense_request_id=x.id;
  if x.id is null or (x.org_id,x.site_id,x.category,x.label,x.amount_xaf,x.method,x.reference,x.expense_date) is distinct from (new.org_id,new.site_id,new.category,new.label,new.amount_xaf,new.method,new.reference,new.expense_date) or d.decision is distinct from 'approved' or (c.separate_approver and d.member_id=new.member_id) then raise exception 'EXPENSE_APPROVAL_REQUIRED';end if;
 end if;
 if exists(select 1 from public.zp_expense_requests q left join public.zp_expense_decisions d2 on d2.expense_request_id=q.id where q.org_id=new.org_id and q.site_id=new.site_id and q.method=new.method and q.reference=new.reference and q.id is distinct from x.id and d2.decision is distinct from 'rejected') then raise exception 'EXPENSE_APPROVAL_REQUIRED';end if;
 return new;
end $f$;
create trigger zp_expense_control before insert on public.zp_expenses for each row execute function public.zp_expense_insert_guard();
create function public.zp_expense_apply(p_access text,p_site uuid,p_id uuid) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;x public.zp_expense_requests;begin
 m:=public.zp_erp_actor(p_access,p_site);
 select * into x from public.zp_expense_requests where id=p_id and org_id=m.org_id and site_id=p_site and member_id=m.id;
 if x.id is null then raise exception 'DENIED';end if;
 return public.zp_record_expense(p_access,p_site,x.request_id,x.category,x.label,x.amount_xaf,x.method,x.reference,x.expense_date);
end $f$;
create function public.zp_erp_control_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('member_id',m.id,'can_decide',m.role_code='promoteur',
 'policy',coalesce((select to_jsonb(c) from public.zp_erp_control_policies c where c.org_id=m.org_id and c.site_id=p_site order by version desc limit 1),jsonb_build_object('version',0,'purchase_threshold',null,'expense_threshold',null,'quality_required',false,'separate_approver',false)),
 'purchases',coalesce((select jsonb_agg(to_jsonb(z)) from (select p.id,p.reference,p.total_xaf,p.received_milli,p.member_id,coalesce(d.decision,'pending') state from public.zp_purchases p left join public.zp_purchase_decisions d on d.purchase_id=p.id where p.org_id=m.org_id and p.site_id=p_site order by p.created_at desc limit 200)z),'[]'::jsonb),
 'quality',coalesce((select jsonb_agg(to_jsonb(q)) from (select id,purchase_id,qty_milli,lot_label,decision,reason,created_at from public.zp_purchase_quality where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)q),'[]'::jsonb),
 'expenses',coalesce((select jsonb_agg(to_jsonb(z)) from (select x.id,x.member_id,x.label,x.amount_xaf,x.reference,x.expense_date,case when e.id is not null then 'recorded' else coalesce(d.decision,'pending') end state from public.zp_expense_requests x left join public.zp_expense_decisions d on d.expense_request_id=x.id left join public.zp_expenses e on e.member_id=x.member_id and e.request_id=x.request_id where x.org_id=m.org_id and x.site_id=p_site order by x.created_at desc limit 200)z),'[]'::jsonb));
end $f$;
do $grants$ declare n record;begin for n in select p.oid::regprocedure as sig from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public' and p.proname in ('zp_erp_control_set','zp_purchase_decide','zp_purchase_receipt_guard','zp_purchase_receive_checked','zp_purchase_reject_guard','zp_expense_submit','zp_expense_decide','zp_expense_insert_guard','zp_expense_apply','zp_erp_control_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',n.sig);execute format('grant execute on function %s to service_role',n.sig);end loop;end $grants$;
commit;
