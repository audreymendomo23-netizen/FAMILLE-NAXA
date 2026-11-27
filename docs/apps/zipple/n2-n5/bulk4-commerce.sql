-- Explicit commercial policy, opaque referral identifiers, verified sales and append-only reward reversal.
-- NAXA Services v5 referral principles adapted to ZIPPLE's confirmed receipts and optional CRM links.
begin;
create table public.zp_loyalty_policies(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,version integer not null check(version>0),
 step_xaf int not null check(step_xaf>0),points_per_step int not null check(points_per_step between 0 and 10000),
 referrer_points int not null check(referrer_points between 0 and 1000000),new_customer_points int not null check(new_customer_points between 0 and 1000000),
 enabled boolean not null,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default clock_timestamp(),
 unique(site_id,version),foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_loyalty_codes(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,customer_id uuid not null,created_at timestamptz not null default now(),revoked_at timestamptz,
 foreign key(customer_id,org_id) references public.zp_customers(id,org_id));
create unique index zp_loyalty_one_active_code on public.zp_loyalty_codes(customer_id) where revoked_at is null;
create table public.zp_loyalty_referrals(
 org_id uuid not null,site_id uuid not null,referred_id uuid primary key,referrer_id uuid not null,code_id uuid not null references public.zp_loyalty_codes(id),member_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 check(referred_id<>referrer_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(referred_id,org_id) references public.zp_customers(id,org_id),foreign key(referrer_id,org_id) references public.zp_customers(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_loyalty_awards(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,receipt_id uuid not null,beneficiary_id uuid not null,policy_id uuid not null references public.zp_loyalty_policies(id),
 kind text not null check(kind in ('purchase','referrer','referred')),points bigint not null check(points>0),created_at timestamptz not null default now(),
 unique(receipt_id,kind),foreign key(receipt_id,org_id,site_id) references public.zp_cash_receipts(id,org_id,site_id),foreign key(beneficiary_id,org_id) references public.zp_customers(id,org_id));
create table public.zp_loyalty_reversals(
 award_id uuid primary key references public.zp_loyalty_awards(id),reason text not null check(reason in ('refund','credit_note','return')),created_at timestamptz not null default now());
create table public.zp_loyalty_benefits(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,label text not null check(length(label) between 1 and 120),
 points int not null check(points between 1 and 1000000),enabled boolean not null,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default clock_timestamp(),
 foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_loyalty_redemptions(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,customer_id uuid not null,receipt_id uuid not null unique,benefit_id uuid not null references public.zp_loyalty_benefits(id),
 member_id uuid not null,points int not null check(points>0),proof text not null check(length(proof) between 5 and 500),created_at timestamptz not null default clock_timestamp(),
 foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(customer_id,org_id) references public.zp_customers(id,org_id),foreign key(receipt_id,org_id,site_id) references public.zp_cash_receipts(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_loyalty_redemption_reviews(
 redemption_id uuid primary key references public.zp_loyalty_redemptions(id),reason text not null,created_at timestamptz not null default clock_timestamp());
create table public.zp_loyalty_redemption_restores(
 redemption_id uuid primary key references public.zp_loyalty_redemptions(id),member_id uuid not null references public.zp_members(id),reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default clock_timestamp());
do $g$ declare n text;begin foreach n in array array['zp_loyalty_benefits','zp_loyalty_redemptions','zp_loyalty_redemption_reviews','zp_loyalty_redemption_restores','zp_loyalty_policies','zp_loyalty_codes','zp_loyalty_referrals','zp_loyalty_awards','zp_loyalty_reversals'] loop
 execute format('alter table public.%I enable row level security',n);execute format('revoke all on public.%I from public,anon,authenticated',n);execute format('grant select,insert on public.%I to service_role',n);end loop;end $g$;
grant update(revoked_at) on public.zp_loyalty_codes to service_role;
create function public.zp_loyalty_eligible(p_receipt uuid) returns boolean language sql stable security invoker set search_path=pg_catalog,public as $f$
 select exists(select 1 from public.zp_cash_receipts r join public.zp_orders o on o.id=r.order_id where r.id=p_receipt and o.status='served' and r.amount_xaf>0
 and (r.method<>'credit' or exists(select 1 from public.zp_credit_sales s where s.receipt_id=r.id and s.balance_xaf=0 and s.paid_xaf=s.amount_xaf and s.credit_note_xaf=0 and s.refunded_xaf=0))
 and not exists(select 1 from public.zp_cash_outflows x where x.kind='refund' and x.source_id=r.id)
 and not exists(select 1 from public.zp_sale_returns x where x.receipt_id=r.id)
 and not exists(select 1 from public.zp_credit_notes n join public.zp_credit_sales s on s.id=n.sale_id where s.receipt_id=r.id));
$f$;
create function public.zp_loyalty_reverse() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare receipt uuid;why text;begin
 if tg_table_name='zp_cash_outflows' then if new.kind<>'refund' then return new;end if;receipt:=new.source_id;why:='refund';
 elsif tg_table_name='zp_credit_notes' then select receipt_id into receipt from public.zp_credit_sales where id=new.sale_id;why:='credit_note';
 else receipt:=new.receipt_id;why:='return';end if;
 perform 1 from public.zp_organizations where id=new.org_id for update;
 insert into public.zp_loyalty_redemption_reviews(redemption_id,reason) select id,why from public.zp_loyalty_redemptions where receipt_id=receipt on conflict do nothing;
 insert into public.zp_loyalty_reversals(award_id,reason) select id,why from public.zp_loyalty_awards where receipt_id=receipt on conflict do nothing;return new;
end $f$;
create trigger zp_loyalty_refund_reverse after insert on public.zp_cash_outflows for each row execute function public.zp_loyalty_reverse();
create trigger zp_loyalty_credit_reverse after insert on public.zp_credit_notes for each row execute function public.zp_loyalty_reverse();
create trigger zp_loyalty_return_reverse after insert on public.zp_sale_returns for each row execute function public.zp_loyalty_reverse();
create function public.zp_loyalty_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('can_configure',m.role_code='promoteur',
 'policy',(select to_jsonb(p) from public.zp_loyalty_policies p where p.org_id=m.org_id and p.site_id=p_site order by p.version desc limit 1),
 'customers',coalesce((select jsonb_agg(to_jsonb(x) order by x.label) from (select c.id,c.display_name label,(select id from public.zp_loyalty_codes k where k.customer_id=c.id and k.revoked_at is null) code,coalesce((select sum(a.points) from public.zp_loyalty_awards a where a.beneficiary_id=c.id and a.org_id=m.org_id and not exists(select 1 from public.zp_loyalty_reversals z where z.award_id=a.id)),0)::text earned_points,(coalesce((select sum(a.points) from public.zp_loyalty_awards a where a.beneficiary_id=c.id and a.org_id=m.org_id and not exists(select 1 from public.zp_loyalty_reversals z where z.award_id=a.id)),0)-coalesce((select sum(r.points) from public.zp_loyalty_redemptions r where r.customer_id=c.id and r.org_id=m.org_id and not exists(select 1 from public.zp_loyalty_redemption_restores z where z.redemption_id=r.id)),0))::text points from public.zp_customers c where c.org_id=m.org_id order by c.display_name limit 300)x),'[]'),
 'receipts',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select r.id,r.amount_xaf,r.created_at,c.display_name label from public.zp_cash_receipts r join public.zp_customer_order_links l on l.order_id=r.order_id join public.zp_customers c on c.id=l.customer_id where r.org_id=m.org_id and r.site_id=p_site and public.zp_loyalty_eligible(r.id) and not exists(select 1 from public.zp_loyalty_awards a where a.receipt_id=r.id) order by r.created_at desc limit 200)x),'[]'),
 'referrals',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select q.referred_id id,q.created_at,c.display_name label,p.display_name referrer,exists(select 1 from public.zp_loyalty_awards a join public.zp_customer_order_links l on l.order_id=(select order_id from public.zp_cash_receipts where id=a.receipt_id) where a.org_id=m.org_id and l.customer_id=q.referred_id and a.kind in ('referrer','referred') and not exists(select 1 from public.zp_loyalty_reversals z where z.award_id=a.id)) qualified from public.zp_loyalty_referrals q join public.zp_customers c on c.id=q.referred_id join public.zp_customers p on p.id=q.referrer_id where q.org_id=m.org_id order by q.created_at desc limit 200)x),'[]'),
 'benefits',coalesce((select jsonb_agg(to_jsonb(q) order by q.label) from (select distinct on (label) id,label,points,enabled from public.zp_loyalty_benefits where org_id=m.org_id and site_id=p_site order by label,created_at desc,id desc limit 200)q),'[]'),
 'redeemable_receipts',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select r.id,r.amount_xaf,r.created_at,l.customer_id,c.display_name label from public.zp_cash_receipts r join public.zp_customer_order_links l on l.order_id=r.order_id join public.zp_customers c on c.id=l.customer_id where r.org_id=m.org_id and r.site_id=p_site and public.zp_loyalty_eligible(r.id) and not exists(select 1 from public.zp_loyalty_redemptions z where z.receipt_id=r.id) order by r.created_at desc limit 200)q),'[]'),
 'redemptions',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select z.id,z.points,z.created_at,c.display_name label,b.label benefit,z.proof,v.reason review_reason,y.reason restore_reason from public.zp_loyalty_redemptions z join public.zp_customers c on c.id=z.customer_id join public.zp_loyalty_benefits b on b.id=z.benefit_id left join public.zp_loyalty_redemption_reviews v on v.redemption_id=z.id left join public.zp_loyalty_redemption_restores y on y.redemption_id=z.id where z.org_id=m.org_id and z.site_id=p_site order by z.created_at desc limit 200)q),'[]'),
 'awards',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select a.id,a.kind,a.points::text points,a.created_at,c.display_name label,z.reason reversal from public.zp_loyalty_awards a join public.zp_customers c on c.id=a.beneficiary_id left join public.zp_loyalty_reversals z on z.award_id=a.id where a.org_id=m.org_id and a.site_id=p_site order by a.created_at desc limit 200)x),'[]'));
end $f$;
create function public.zp_loyalty_write(p_access text,p_site uuid,p_action text,p_request uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;old public.zp_workspace_requests;pol public.zp_loyalty_policies;code public.zp_loyalty_codes;ref public.zp_loyalty_referrals;r public.zp_cash_receipts;cid uuid;rid uuid;first_receipt uuid;v int;step int;pts int;bonus int;newpts int;why text;enabled boolean;outcome jsonb;earned bigint;benefit public.zp_loyalty_benefits;redemption public.zp_loyalty_redemptions;label_text text;available bigint;historical bigint;spent bigint;begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or length(p_payload::text)>4000 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 perform 1 from public.zp_organizations where id=m.org_id for update;
 select * into old from public.zp_workspace_requests where member_id=m.id and request_id=p_request;
 if old.request_id is not null then if (old.site_id,old.action,old.payload) is distinct from (p_site,'loyalty:'||p_action,p_payload) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.outcome;end if;
 select * into pol from public.zp_loyalty_policies where org_id=m.org_id and site_id=p_site order by version desc limit 1;
 if p_action='configure' then
 if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 v:=(p_payload->>'expected_version')::int;step:=(p_payload->>'step_xaf')::int;pts:=(p_payload->>'points_per_step')::int;bonus:=(p_payload->>'referrer_points')::int;newpts:=(p_payload->>'new_customer_points')::int;why:=trim(coalesce(p_payload->>'reason',''));enabled:=(p_payload->>'enabled')::boolean;
 if v is distinct from coalesce(pol.version,0) then raise exception 'STALE_LOYALTY_POLICY';end if;
 if step is null or step<1 or pts is null or pts not between 0 and 10000 or bonus is null or bonus not between 0 and 1000000 or newpts is null or newpts not between 0 and 1000000 or enabled is null or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 insert into public.zp_loyalty_policies(org_id,site_id,member_id,version,step_xaf,points_per_step,referrer_points,new_customer_points,enabled,reason) values(m.org_id,p_site,m.id,v+1,step,pts,bonus,newpts,enabled,why) returning id into rid;
 elsif p_action='benefit_configure' then
 if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 label_text:=trim(coalesce(p_payload->>'label',''));pts:=(p_payload->>'points')::int;enabled:=(p_payload->>'enabled')::boolean;why:=trim(coalesce(p_payload->>'reason',''));
 if length(label_text) not between 1 and 120 or pts is null or pts not between 1 and 1000000 or enabled is null or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 insert into public.zp_loyalty_benefits(org_id,site_id,member_id,label,points,enabled,reason) values(m.org_id,p_site,m.id,label_text,pts,enabled,why) returning id into rid;
 elsif p_action='redeem' then
 if pol.enabled is distinct from true then raise exception 'LOYALTY_DISABLED';end if;
 select * into benefit from public.zp_loyalty_benefits where id=(p_payload->>'benefit_id')::uuid and org_id=m.org_id and site_id=p_site;
 if benefit.id is null or not benefit.enabled or benefit.id is distinct from (select id from public.zp_loyalty_benefits z where z.org_id=m.org_id and z.site_id=p_site and z.label=benefit.label order by z.created_at desc,z.id desc limit 1) then raise exception 'STALE_LOYALTY_BENEFIT';end if;
 select * into r from public.zp_cash_receipts where id=(p_payload->>'receipt_id')::uuid and org_id=m.org_id and site_id=p_site;
 if r.id is null or not public.zp_loyalty_eligible(r.id) then raise exception 'DENIED';end if;
 select customer_id into cid from public.zp_customer_order_links where order_id=r.order_id and org_id=m.org_id and site_id=p_site;
 if cid is null then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_loyalty_redemptions z where z.receipt_id=r.id) then raise exception 'REWARD_ALREADY_USED';end if;
 why:=trim(coalesce(p_payload->>'proof',''));if length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 select coalesce(sum(a.points),0),coalesce(sum(a.points) filter(where a.created_at<r.created_at),0) into available,historical from public.zp_loyalty_awards a where a.org_id=m.org_id and a.beneficiary_id=cid and not exists(select 1 from public.zp_loyalty_reversals z where z.award_id=a.id);
 select coalesce(sum(z.points),0) into spent from public.zp_loyalty_redemptions z where z.org_id=m.org_id and z.customer_id=cid and not exists(select 1 from public.zp_loyalty_redemption_restores v where v.redemption_id=z.id);
 if least(available,historical)-spent<benefit.points then raise exception 'INSUFFICIENT_LOYALTY_POINTS';end if;
 insert into public.zp_loyalty_redemptions(org_id,site_id,customer_id,receipt_id,benefit_id,member_id,points,proof) values(m.org_id,p_site,cid,r.id,benefit.id,m.id,benefit.points,why) returning id into rid;
 elsif p_action='restore' then
 if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 select * into redemption from public.zp_loyalty_redemptions where id=(p_payload->>'redemption_id')::uuid and org_id=m.org_id and site_id=p_site;
 why:=trim(coalesce(p_payload->>'reason',''));
 if redemption.id is null or length(why) not between 5 and 500 or not exists(select 1 from public.zp_loyalty_redemption_reviews v where v.redemption_id=redemption.id) then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_loyalty_redemption_restores v where v.redemption_id=redemption.id) then raise exception 'INVALID_TRANSITION';end if;
 insert into public.zp_loyalty_redemption_restores(redemption_id,member_id,reason) values(redemption.id,m.id,why);rid:=redemption.id;
 elsif p_action in ('issue_code','revoke_code','apply_code') then
 cid:=(p_payload->>'customer_id')::uuid;if not exists(select 1 from public.zp_customers where id=cid and org_id=m.org_id) then raise exception 'DENIED';end if;
 if p_action='issue_code' then
 select id into rid from public.zp_loyalty_codes where customer_id=cid and revoked_at is null;
 if rid is null then insert into public.zp_loyalty_codes(org_id,customer_id) values(m.org_id,cid) returning id into rid;end if;
 elsif p_action='revoke_code' then
 if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 update public.zp_loyalty_codes set revoked_at=now() where customer_id=cid and revoked_at is null returning id into rid;
 else
 if pol.enabled is distinct from true then raise exception 'LOYALTY_DISABLED';end if;
 select * into code from public.zp_loyalty_codes where id=(p_payload->>'code')::uuid and org_id=m.org_id and revoked_at is null;
 if code.id is null or code.customer_id=cid then raise exception 'INVALID_REFERRAL';end if;
 if exists(select 1 from public.zp_loyalty_referrals where referred_id=cid) or exists(select 1 from public.zp_customer_order_links l join public.zp_cash_receipts r0 on r0.order_id=l.order_id where l.customer_id=cid and public.zp_loyalty_eligible(r0.id)) then raise exception 'INVALID_REFERRAL';end if;
 if exists(with recursive ancestors(id) as (select code.customer_id union select x.referrer_id from public.zp_loyalty_referrals x join ancestors a on a.id=x.referred_id where x.org_id=m.org_id) select 1 from ancestors where id=cid) then raise exception 'INVALID_REFERRAL';end if;
 insert into public.zp_loyalty_referrals(org_id,site_id,referred_id,referrer_id,code_id,member_id) values(m.org_id,p_site,cid,code.customer_id,code.id,m.id);rid:=cid;
 end if;
 elsif p_action='claim_receipt' then
 select * into r from public.zp_cash_receipts where id=(p_payload->>'receipt_id')::uuid and org_id=m.org_id and site_id=p_site;if r.id is null then raise exception 'DENIED';end if;
 select customer_id into cid from public.zp_customer_order_links where order_id=r.order_id and org_id=m.org_id and site_id=p_site;
 if cid is null or not public.zp_loyalty_eligible(r.id) then raise exception 'INVALID_REFERRAL';end if;
 select * into pol from public.zp_loyalty_policies where org_id=m.org_id and site_id=p_site and created_at<=r.created_at order by version desc limit 1;
 if pol.enabled is distinct from true then raise exception 'LOYALTY_DISABLED';end if;
 earned:=(r.amount_xaf/pol.step_xaf)*pol.points_per_step;
 if earned>0 then insert into public.zp_loyalty_awards(org_id,site_id,receipt_id,beneficiary_id,policy_id,kind,points) values(m.org_id,p_site,r.id,cid,pol.id,'purchase',earned) on conflict(receipt_id,kind) do nothing;end if;
 select r0.id into first_receipt from public.zp_cash_receipts r0 join public.zp_customer_order_links l on l.order_id=r0.order_id where l.org_id=m.org_id and l.customer_id=cid and public.zp_loyalty_eligible(r0.id) order by r0.created_at,r0.id limit 1;
 select * into ref from public.zp_loyalty_referrals where referred_id=cid and org_id=m.org_id and created_at<=r.created_at;
 if ref.referred_id is not null and first_receipt=r.id and not exists(select 1 from public.zp_loyalty_awards a join public.zp_customer_order_links l on l.order_id=(select order_id from public.zp_cash_receipts where id=a.receipt_id) where l.customer_id=cid and a.org_id=m.org_id and a.kind in ('referrer','referred') and a.receipt_id<>r.id) then
 if pol.referrer_points>0 then insert into public.zp_loyalty_awards(org_id,site_id,receipt_id,beneficiary_id,policy_id,kind,points) values(m.org_id,p_site,r.id,ref.referrer_id,pol.id,'referrer',pol.referrer_points) on conflict(receipt_id,kind) do nothing;end if;
 if pol.new_customer_points>0 then insert into public.zp_loyalty_awards(org_id,site_id,receipt_id,beneficiary_id,policy_id,kind,points) values(m.org_id,p_site,r.id,cid,pol.id,'referred',pol.new_customer_points) on conflict(receipt_id,kind) do nothing;end if;
 end if;rid:=r.id;
 else raise exception 'INVALID_INPUT';end if;
 outcome:=jsonb_build_object('id',rid,'confirmed',true);
 insert into public.zp_workspace_requests(member_id,org_id,site_id,request_id,action,payload,outcome) values(m.id,m.org_id,p_site,p_request,'loyalty:'||p_action,p_payload,outcome);return outcome;
end $f$;
-- Operational delivery preparation. No channel activation before a verified payment and fee contract.
create table public.zp_delivery_zones(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,label text not null check(length(label) between 1 and 120),
 instructions text not null check(length(instructions) between 1 and 500),fee_xaf int not null check(fee_xaf>=0),active boolean not null default true,created_at timestamptz not null default now(),
 unique(site_id,label),foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_delivery_couriers(
 org_id uuid not null,site_id uuid not null,member_id uuid not null,configured_by uuid not null,active boolean not null default true,updated_at timestamptz not null default now(),
 primary key(site_id,member_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(configured_by,org_id) references public.zp_members(id,org_id));
create table public.zp_partner_link_requests(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,
 partner text not null check(partner in ('naxa_security','naxa_hotel','grillad')),external_reference text not null check(length(external_reference) between 4 and 160),reason text not null check(length(reason) between 5 and 500),
 state text not null default 'requested' check(state in ('requested','cancelled')),created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create unique index zp_partner_one_pending on public.zp_partner_link_requests(site_id,partner) where state='requested';
do $g$ declare n text;begin foreach n in array array['zp_delivery_zones','zp_delivery_couriers','zp_partner_link_requests'] loop execute format('alter table public.%I enable row level security',n);execute format('revoke all on public.%I from public,anon,authenticated',n);execute format('grant select,insert,update on public.%I to service_role',n);end loop;end $g$;
create function public.zp_connection_snapshot(p_access text,p_site uuid,p_page text) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;restaurant boolean;begin m:=public.zp_erp_actor(p_access,p_site);
 if p_page='delivery' then
 select space='restaurant' into restaurant from public.zp_site_modes where site_id=p_site and org_id=m.org_id;
 return jsonb_build_object('can_configure',m.role_code='promoteur','restaurant',coalesce(restaurant,false),'service_active',false,
 'zones',coalesce((select jsonb_agg(to_jsonb(x) order by x.label) from (select id,label,instructions,fee_xaf,active from public.zp_delivery_zones where org_id=m.org_id and site_id=p_site limit 200)x),'[]'),
 'members',coalesce((select jsonb_agg(to_jsonb(x) order by x.label) from (select u.id,coalesce(d.display_name,u.login_id) label,coalesce(c.active,false) enabled from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id left join public.zp_profile_details d on d.member_id=u.id left join public.zp_delivery_couriers c on c.member_id=u.id and c.site_id=p_site where s.org_id=m.org_id and s.site_id=p_site and u.active and not u.reset_pending limit 200)x),'[]'));
 elsif p_page='connections' then return jsonb_build_object('can_configure',m.role_code='promoteur','rows',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select id,partner,external_reference,reason,state,created_at from public.zp_partner_link_requests where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)x),'[]'));
 else raise exception 'INVALID_INPUT';end if;
end $f$;
create function public.zp_connection_write(p_access text,p_site uuid,p_action text,p_request uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;old public.zp_workspace_requests;rid uuid;target uuid;name text;why text;partner_code text;fee int;enabled boolean;outcome jsonb;begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or length(p_payload::text)>4000 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id for update;
 select * into old from public.zp_workspace_requests where member_id=m.id and request_id=p_request;
 if old.request_id is not null then if (old.site_id,old.action,old.payload) is distinct from (p_site,'connection:'||p_action,p_payload) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.outcome;end if;
 if p_action in ('zone_save','courier_set') then
 if not exists(select 1 from public.zp_site_modes where site_id=p_site and org_id=m.org_id and space='restaurant') then raise exception 'CHANNEL_DENIED';end if;
 enabled:=(p_payload->>'enabled')::boolean;if enabled is null then raise exception 'INVALID_INPUT';end if;
 if p_action='zone_save' then
 name:=trim(coalesce(p_payload->>'label',''));why:=trim(coalesce(p_payload->>'instructions',''));fee:=(p_payload->>'fee_xaf')::int;
 if length(name) not between 1 and 120 or length(why) not between 1 and 500 or fee is null or fee<0 then raise exception 'INVALID_INPUT';end if;
 insert into public.zp_delivery_zones(org_id,site_id,member_id,label,instructions,fee_xaf,active) values(m.org_id,p_site,m.id,name,why,fee,enabled) on conflict(site_id,label) do update set instructions=excluded.instructions,fee_xaf=excluded.fee_xaf,active=excluded.active returning id into rid;
 else target:=(p_payload->>'member_id')::uuid;
 if not exists(select 1 from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id where s.org_id=m.org_id and s.site_id=p_site and s.member_id=target and u.active and not u.reset_pending) then raise exception 'DENIED';end if;
 insert into public.zp_delivery_couriers(org_id,site_id,member_id,configured_by,active) values(m.org_id,p_site,target,m.id,enabled) on conflict(site_id,member_id) do update set active=excluded.active,configured_by=excluded.configured_by,updated_at=now();rid:=target;
 end if;
 elsif p_action='request_link' then
 partner_code:=p_payload->>'partner';name:=trim(coalesce(p_payload->>'external_reference',''));why:=trim(coalesce(p_payload->>'reason',''));
 if partner_code is null or partner_code not in ('naxa_security','naxa_hotel','grillad') or length(name) not between 4 and 160 or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 if exists(select 1 from public.zp_partner_link_requests x where x.site_id=p_site and x.org_id=m.org_id and x.partner=partner_code and x.state='requested') then raise exception 'LINK_ALREADY_REQUESTED';end if;
 insert into public.zp_partner_link_requests(org_id,site_id,member_id,partner,external_reference,reason) values(m.org_id,p_site,m.id,partner_code,name,why) returning id into rid;
 elsif p_action='cancel_link' then
 update public.zp_partner_link_requests set state='cancelled' where id=(p_payload->>'link_id')::uuid and org_id=m.org_id and site_id=p_site and state='requested' returning id into rid;if rid is null then raise exception 'DENIED';end if;
 else raise exception 'INVALID_INPUT';end if;
 outcome:=jsonb_build_object('id',rid,'confirmed',true);
 insert into public.zp_workspace_requests(member_id,org_id,site_id,request_id,action,payload,outcome) values(m.id,m.org_id,p_site,p_request,'connection:'||p_action,p_payload,outcome);return outcome;
end $f$;
do $g$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_loyalty_eligible','zp_loyalty_reverse','zp_loyalty_snapshot','zp_loyalty_write','zp_connection_snapshot','zp_connection_write') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $g$;
commit;
