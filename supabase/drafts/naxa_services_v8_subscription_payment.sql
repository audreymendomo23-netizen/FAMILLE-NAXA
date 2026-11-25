-- NAXA SERVICES ONLY. Candidate, rollback by default; no hosted deployment.
-- Subscription payments never enter ns_payments (tenant ERP ledger).
begin;
create table public.ns_subscription_destinations (
 channel text primary key check(channel in ('mtn_momo','orange_money')),
 merchant_code text not null check(merchant_code ~ '^[0-9]{6}$'),
 beneficiary text not null check(length(trim(beneficiary)) between 2 and 160),
 destination_reference text not null check(destination_reference ~ '^[A-Z0-9]{4,80}$'),
 active boolean not null default false
);
create table public.ns_subscription_admin_devices (
 id uuid primary key default gen_random_uuid(),
 auth_user_id uuid not null references auth.users(id),
 channel text not null references public.ns_subscription_destinations(channel),
 session_id text not null check(length(session_id)>0),
 destination_reference text not null check(destination_reference ~ '^[A-Z0-9]{4,80}$'),
 sms_capture_allowed boolean not null default false,
 active boolean not null default false,
 unique(auth_user_id,session_id,channel)
);
create table public.ns_subscriptions (
 org_id uuid primary key references public.ns_organizations(id),
 plan_code text not null check(plan_code in ('ACCESS','PREMIUM')),
 status text not null check(status in ('active','cancelled')),
 period_start date not null, period_end_exclusive date not null,
 check(period_end_exclusive>period_start)
);
create table public.ns_subscription_intents (
 id uuid primary key default gen_random_uuid(),
 org_id uuid not null references public.ns_organizations(id),
 payer_auth_user uuid not null references auth.users(id),
 plan_code text not null check(plan_code in ('ACCESS','PREMIUM')),
 months integer not null check(months in (1,12)),
 channel text not null check(channel in ('mtn_momo','orange_money')),
 merchant_code text not null, beneficiary text not null, destination_reference text not null,
 amount_xaf bigint not null check(amount_xaf>0),
 quoted_period_start date not null,
 created_at timestamptz not null default now(), expires_at timestamptz not null,
 status text not null default 'pending' check(status in ('pending','submitted','confirmed','expired')),
 transaction_reference text, payer_number text, payer_occurred_at timestamptz,
 payer_sha256 text, submitted_at timestamptz, confirmed_at timestamptz,
 period_start date, period_end_exclusive date, receipt_number text unique,
 check(status<>'confirmed' or (confirmed_at is not null and receipt_number is not null and period_start is not null and period_end_exclusive>period_start))
);
create unique index ns_subscription_one_open_intent on public.ns_subscription_intents(org_id) where status in ('pending','submitted');
create unique index ns_subscription_reference_once on public.ns_subscription_intents(channel,transaction_reference) where transaction_reference is not null and status in ('submitted','confirmed');
create table public.ns_subscription_credit_proofs (
 id uuid primary key default gen_random_uuid(),
 intent_id uuid not null unique references public.ns_subscription_intents(id),
 admin_device_id uuid not null references public.ns_subscription_admin_devices(id),
 channel text not null, transaction_reference text not null, destination_reference text not null,
 amount_xaf bigint not null check(amount_xaf>0), payer_number text not null,
 occurred_at timestamptz not null, captured_at timestamptz not null,
 payload_sha256 text not null unique check(payload_sha256 ~ '^[0-9a-f]{64}$'),
 unique(channel,transaction_reference)
);
create table public.ns_subscription_credit_candidates (
 id uuid primary key default gen_random_uuid(),
 admin_device_id uuid not null references public.ns_subscription_admin_devices(id),
 channel text not null check(channel in ('mtn_momo','orange_money')),
 transaction_reference text not null check(length(transaction_reference) between 6 and 100),
 destination_reference text not null, amount_xaf bigint not null check(amount_xaf>0),
 payer_number text not null check(payer_number ~ '^6[0-9]{8}$'),
 occurred_at timestamptz not null, captured_at timestamptz not null,
 payload_sha256 text not null unique check(payload_sha256 ~ '^[0-9a-f]{64}$'),
 status text not null default 'pending' check(status in ('pending','matched','review')),
 intent_id uuid references public.ns_subscription_intents(id),
 unique(channel,transaction_reference)
);
alter table public.ns_subscription_credit_candidates enable row level security;
revoke all on public.ns_subscription_credit_candidates from public,anon,authenticated;
grant all on public.ns_subscription_credit_candidates to service_role;
alter table public.ns_subscription_destinations enable row level security;
alter table public.ns_subscription_admin_devices enable row level security;
alter table public.ns_subscriptions enable row level security;
alter table public.ns_subscription_intents enable row level security;
alter table public.ns_subscription_credit_proofs enable row level security;
revoke all on public.ns_subscription_destinations,public.ns_subscription_admin_devices,public.ns_subscriptions,public.ns_subscription_intents,public.ns_subscription_credit_proofs from public,anon,authenticated;
grant all on public.ns_subscription_destinations,public.ns_subscription_admin_devices,public.ns_subscriptions,public.ns_subscription_intents,public.ns_subscription_credit_proofs to service_role;

-- Mirrors the existing NAXA FAMILY catalogue; tested at the maturity boundary.
create function public.ns_subscription_amount(p_plan text,p_months integer,p_start date) returns bigint
language sql immutable set search_path='' as $f$
 select case when p_months in (1,12) then
  (case when p_plan='ACCESS' then case when p_start>=date '2027-05-01' then 5000 else 3000 end
        when p_plan='PREMIUM' then case when p_start>=date '2027-05-01' then 15000 else 10000 end end)
  * case when p_months=12 then 10 else 1 end end
$f$;
create function public.ns_subscription_public_intent(p_id uuid) returns jsonb
language sql stable set search_path='' as $f$
 select jsonb_build_object('id',i.id,'status',i.status,'plan_code',i.plan_code,'months',i.months,'channel',i.channel,'amount_xaf',i.amount_xaf,'beneficiary',i.beneficiary,'merchant_code',i.merchant_code,'expires_at',i.expires_at,'period_start',i.period_start,'period_end_exclusive',i.period_end_exclusive,'receipt_number',i.receipt_number)
 from public.ns_subscription_intents i where i.id=p_id
$f$;
create function public.ns_subscription_list(p_org uuid) returns jsonb
language plpgsql security definer set search_path='' as $f$
begin
 if auth.uid() is null or not public.ns_can_manage_org(p_org) then raise exception 'NS_SUBSCRIPTION_FORBIDDEN' using errcode='42501'; end if;
 perform public.ns_subscription_try_match(i.id) from public.ns_subscription_intents i where i.org_id=p_org and i.status='submitted';
 return jsonb_build_object('subscription',(select to_jsonb(s) from public.ns_subscriptions s where s.org_id=p_org),
 'destinations',coalesce((select jsonb_agg(jsonb_build_object('channel',d.channel)) from public.ns_subscription_destinations d where d.active),'[]'::jsonb),
 'intents',coalesce((select jsonb_agg(public.ns_subscription_public_intent(i.id) order by i.created_at desc) from (select * from public.ns_subscription_intents where org_id=p_org order by created_at desc limit 20) i),'[]'::jsonb));
end $f$;
create function public.ns_subscription_create(p_org uuid,p_plan text,p_months integer,p_channel text) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare d public.ns_subscription_destinations%rowtype; s public.ns_subscriptions%rowtype; i public.ns_subscription_intents%rowtype; v_start date; v_amount bigint;
begin
 if auth.uid() is null or not public.ns_can_manage_org(p_org) then raise exception 'NS_SUBSCRIPTION_FORBIDDEN' using errcode='42501'; end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_ORGANIZATION_INACTIVE'; end if;
 select * into d from public.ns_subscription_destinations where channel=p_channel and active;
 if not found then raise exception 'NS_DESTINATION_NOT_CONFIGURED'; end if;
 select * into s from public.ns_subscriptions where org_id=p_org;
 if s.status='cancelled' then raise exception 'NS_SUBSCRIPTION_CANCELLED'; end if;
 if s.period_end_exclusive>(now() at time zone 'Africa/Douala')::date and s.plan_code<>p_plan then raise exception 'NS_PLAN_CHANGE_REQUIRES_REVIEW'; end if;
 v_start:=greatest((now() at time zone 'Africa/Douala')::date,coalesce(s.period_end_exclusive,(now() at time zone 'Africa/Douala')::date));
 v_amount:=public.ns_subscription_amount(p_plan,p_months,v_start);
 if v_amount is null then raise exception 'NS_INVALID_PLAN_OR_DURATION'; end if;
 update public.ns_subscription_intents set status='expired' where org_id=p_org and status='pending' and expires_at<now();
 select * into i from public.ns_subscription_intents where org_id=p_org and status in ('pending','submitted');
 if found then
  if i.payer_auth_user=auth.uid() and i.plan_code=p_plan and i.months=p_months and i.channel=p_channel then return public.ns_subscription_public_intent(i.id); end if;
  raise exception 'NS_OPEN_PAYMENT_EXISTS';
 end if;
 insert into public.ns_subscription_intents(org_id,payer_auth_user,plan_code,months,channel,merchant_code,beneficiary,destination_reference,amount_xaf,quoted_period_start,expires_at)
 values(p_org,auth.uid(),p_plan,p_months,p_channel,d.merchant_code,d.beneficiary,d.destination_reference,v_amount,v_start,now()+interval '24 hours') returning * into i;
 return public.ns_subscription_public_intent(i.id);
end $f$;
create function public.ns_subscription_declare(p_id uuid,p_ref text,p_payer text,p_occurred timestamptz,p_sha text) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare i public.ns_subscription_intents%rowtype; v_ref text:=upper(regexp_replace(coalesce(p_ref,''),'[^A-Za-z0-9]','','g')); v_number text:=right(regexp_replace(coalesce(p_payer,''),'[^0-9]','','g'),9);
begin
 select * into i from public.ns_subscription_intents where id=p_id;
 if not found or auth.uid() is null or i.payer_auth_user<>auth.uid() or not public.ns_can_manage_org(i.org_id) then raise exception 'NS_SUBSCRIPTION_FORBIDDEN' using errcode='42501'; end if;
 perform 1 from public.ns_organizations where id=i.org_id and status='active' for update;
 if not found then raise exception 'NS_ORGANIZATION_INACTIVE'; end if;
 select * into i from public.ns_subscription_intents where id=p_id for update;
 if i.status='submitted' and i.transaction_reference=v_ref and i.payer_number=v_number and i.payer_sha256=p_sha and i.payer_occurred_at=p_occurred then return public.ns_subscription_public_intent(i.id); end if;
 if i.status<>'pending' or now()>i.expires_at or length(v_ref) not between 6 and 100 or v_number !~ '^6[0-9]{8}$' or coalesce(p_sha,'') !~ '^[0-9a-f]{64}$' or p_occurred is null or p_occurred<i.created_at-interval '15 minutes' or p_occurred>now()+interval '5 minutes' then raise exception 'NS_INVALID_PAYMENT_DECLARATION'; end if;
 update public.ns_subscription_intents set status='submitted',transaction_reference=v_ref,payer_number=v_number,payer_occurred_at=p_occurred,payer_sha256=p_sha,submitted_at=now() where id=i.id;
 return public.ns_subscription_public_intent(i.id);
end $f$;


-- The payer submits the actual debit SMS voluntarily, not a client-supplied hash.
-- Only recognised debit formats are accepted; unmatched formats require support review.
create function public.ns_subscription_declare_sms(p_id uuid,p_sms text,p_payer text,p_occurred timestamptz default null) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare i public.ns_subscription_intents%rowtype; t text; a text[]; r text[]; v_ref text; v_occurred timestamptz; v_amount bigint;
begin
 select * into i from public.ns_subscription_intents where id=p_id;
 if not found or auth.uid() is null or i.payer_auth_user<>auth.uid() or not public.ns_can_manage_org(i.org_id) then raise exception 'NS_SUBSCRIPTION_FORBIDDEN' using errcode='42501'; end if;
 if p_sms is null or length(p_sms) not between 12 and 8000 then raise exception 'NS_SMS_REVIEW_REQUIRED'; end if;
 t:=lower(translate(p_sms,'ÉÈÊËÀÂÄÎÏÔÖÙÛÜÇéèêëàâäîïôöùûüç','EEEEAAAIIOOUUUCeeeeaaaiioouuuc'));
 t:=regexp_replace(t,'[[:space:]]+',' ','g');
 if i.channel='mtn_momo' then
  a:=regexp_match(t,'(?:votre paiement|your payment) (?:de |of )?([0-9][0-9 .,]*)[ ]*(?:xaf|fcfa) (?:a|to) .+?\(([0-9]{8,15})\) (?:a ete finalise a|was (?:successfully )?completed at|was successful at) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})');
  r:=regexp_match(t,'(?:identifiant de transaction financiere|financial transaction id)[ ]*:[ ]*([a-z0-9-]+)');
  if a is null or r is null or right(a[2],9)<>right(i.destination_reference,9) then raise exception 'NS_SMS_REVIEW_REQUIRED'; end if;
  v_amount:=regexp_replace(a[1],'[^0-9]','','g')::bigint; v_ref:=r[1]; v_occurred:=a[3]::timestamp at time zone 'Africa/Douala';
 elsif i.channel='orange_money' then
  a:=regexp_match(t,'paiement de (.+?) reussi par ([0-9]{8,15}) .+?id transaction:[ ]*([a-z0-9.]+),[ ]*montant:[ ]*([0-9][0-9 .,]*)[ ]*fcfa');
  if a is null or right(a[2],9)<>right(regexp_replace(coalesce(p_payer,''),'[^0-9]','','g'),9) or regexp_replace(a[1],'[^a-z0-9]','','g')<>regexp_replace(lower(i.beneficiary),'[^a-z0-9]','','g') or p_occurred is null then raise exception 'NS_SMS_REVIEW_REQUIRED'; end if;
  v_amount:=regexp_replace(a[4],'[^0-9]','','g')::bigint; v_ref:=a[3]; v_occurred:=p_occurred;
 else raise exception 'NS_SMS_REVIEW_REQUIRED';
 end if;
 if v_amount is distinct from i.amount_xaf then raise exception 'NS_SMS_AMOUNT_MISMATCH'; end if;
 perform public.ns_subscription_declare(p_id,v_ref,p_payer,v_occurred,encode(extensions.digest(convert_to(p_sms,'UTF8'),'sha256'),'hex'));
 perform public.ns_subscription_try_match(p_id);
 return public.ns_subscription_public_intent(p_id);
end $f$;

-- Server-only ingress for the dedicated NAXA beneficiary SMS capture adapter.
-- A caller must first authenticate the enrolled central admin device and validate the raw
-- SMS origin/credit/success fields. Do not expose this service-role RPC to clients.
create function public.ns_subscription_confirm_credit(p_id uuid,p_device uuid,p_admin uuid,p_session text,p_channel text,p_ref text,p_destination text,p_amount bigint,p_payer text,p_occurred timestamptz,p_captured timestamptz,p_sha text,p_sender text) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare i public.ns_subscription_intents%rowtype; s public.ns_subscriptions%rowtype; v_start date; v_end date;
begin
 select * into i from public.ns_subscription_intents where id=p_id;
 if not found then raise exception 'NS_PAYMENT_NOT_FOUND'; end if;
 perform 1 from public.ns_organizations where id=i.org_id and status='active' for update;
 if not found then raise exception 'NS_ORGANIZATION_INACTIVE'; end if;
 select * into i from public.ns_subscription_intents where id=p_id for update;
 if not exists(select 1 from public.ns_subscription_admin_devices d where d.id=p_device and d.auth_user_id=p_admin and d.session_id=p_session and d.channel=i.channel and d.destination_reference=i.destination_reference and d.sms_capture_allowed and d.active) or p_admin=i.payer_auth_user then raise exception 'NS_CENTRAL_CAPTURE_FORBIDDEN' using errcode='42501'; end if;
 if i.status='confirmed' and exists(select 1 from public.ns_subscription_credit_proofs c where c.intent_id=i.id and c.payload_sha256=p_sha and c.admin_device_id=p_device) then return public.ns_subscription_public_intent(i.id); end if;
 if i.status<>'submitted' or p_channel is distinct from i.channel or p_sender is distinct from (case when i.channel='mtn_momo' then 'MobileMoney' else 'OrangeMoney' end) or upper(regexp_replace(coalesce(p_ref,''),'[^A-Za-z0-9]','','g')) is distinct from i.transaction_reference or p_destination is distinct from i.destination_reference or p_amount is distinct from i.amount_xaf or right(regexp_replace(coalesce(p_payer,''),'[^0-9]','','g'),9) is distinct from i.payer_number or p_occurred is null or p_occurred not between i.payer_occurred_at-interval '15 minutes' and i.payer_occurred_at+interval '30 minutes' or p_captured is null or p_captured not between i.created_at-interval '5 minutes' and i.submitted_at+interval '24 hours' or p_captured>now()+interval '5 minutes' or coalesce(p_sha,'') !~ '^[0-9a-f]{64}$' or p_sha=i.payer_sha256 then raise exception 'NS_CREDIT_PROOF_MISMATCH'; end if;
 perform 1 from public.ns_organizations where id=i.org_id and status='active' for update;
 if not found then raise exception 'NS_ORGANIZATION_INACTIVE'; end if;
 select * into s from public.ns_subscriptions where org_id=i.org_id for update;
 if s.status='cancelled' then raise exception 'NS_SUBSCRIPTION_CANCELLED'; end if;
 v_start:=greatest((now() at time zone 'Africa/Douala')::date,coalesce(s.period_end_exclusive,(now() at time zone 'Africa/Douala')::date));
 if public.ns_subscription_amount(i.plan_code,i.months,v_start) is distinct from i.amount_xaf then raise exception 'NS_PRICE_CHANGED_REVIEW_REQUIRED'; end if;
 v_end:=(v_start+make_interval(months=>i.months))::date;
 insert into public.ns_subscription_credit_proofs(intent_id,admin_device_id,channel,transaction_reference,destination_reference,amount_xaf,payer_number,occurred_at,captured_at,payload_sha256)
 values(i.id,p_device,i.channel,i.transaction_reference,i.destination_reference,i.amount_xaf,i.payer_number,p_occurred,p_captured,p_sha);
 insert into public.ns_subscriptions(org_id,plan_code,status,period_start,period_end_exclusive) values(i.org_id,i.plan_code,'active',v_start,v_end)
 on conflict(org_id) do update set plan_code=excluded.plan_code,status='active',period_start=case when public.ns_subscriptions.period_end_exclusive>(now() at time zone 'Africa/Douala')::date then public.ns_subscriptions.period_start else excluded.period_start end,period_end_exclusive=excluded.period_end_exclusive;
 update public.ns_subscription_intents set status='confirmed',confirmed_at=now(),period_start=v_start,period_end_exclusive=v_end,receipt_number='NS-'||upper(replace(i.id::text,'-','')) where id=i.id;
 return public.ns_subscription_public_intent(i.id);
end $f$;
-- Match stored central credit evidence only after the payer declaration exists.
create function public.ns_subscription_try_match(p_intent uuid) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare i public.ns_subscription_intents%rowtype; c public.ns_subscription_credit_candidates%rowtype; d public.ns_subscription_admin_devices%rowtype; v_result jsonb;
begin
 select * into i from public.ns_subscription_intents where id=p_intent;
 if not found then return null; end if;
 if i.status<>'submitted' then return public.ns_subscription_public_intent(i.id); end if;
 select * into c from public.ns_subscription_credit_candidates where channel=i.channel and transaction_reference=i.transaction_reference and status='pending';
 if not found then return public.ns_subscription_public_intent(i.id); end if;
 select * into d from public.ns_subscription_admin_devices where id=c.admin_device_id;
 begin
  v_result:=public.ns_subscription_confirm_credit(i.id,d.id,d.auth_user_id,d.session_id,c.channel,c.transaction_reference,c.destination_reference,c.amount_xaf,c.payer_number,c.occurred_at,c.captured_at,c.payload_sha256,case when c.channel='mtn_momo' then 'MobileMoney' else 'OrangeMoney' end);
  update public.ns_subscription_credit_candidates set status='matched',intent_id=i.id where id=c.id;
  return v_result;
 exception when raise_exception or insufficient_privilege or unique_violation then
  update public.ns_subscription_credit_candidates set status='review' where id=c.id and status='pending';
  return public.ns_subscription_public_intent(i.id);
 end;
end $f$;
create function public.ns_subscription_ingest_credit(p_device uuid,p_admin uuid,p_session text,p_channel text,p_ref text,p_destination text,p_amount bigint,p_payer text,p_occurred timestamptz,p_captured timestamptz,p_sha text,p_sender text) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare d public.ns_subscription_admin_devices%rowtype; c public.ns_subscription_credit_candidates%rowtype; i public.ns_subscription_intents%rowtype; v_ref text:=upper(regexp_replace(coalesce(p_ref,''),'[^A-Za-z0-9]','','g')); v_payer text:=right(regexp_replace(coalesce(p_payer,''),'[^0-9]','','g'),9);
begin
 select * into d from public.ns_subscription_admin_devices where id=p_device and auth_user_id=p_admin and session_id=p_session and channel=p_channel and destination_reference=p_destination and sms_capture_allowed and active;
 if not found then raise exception 'NS_CENTRAL_CAPTURE_FORBIDDEN' using errcode='42501'; end if;
 if p_sender is distinct from (case when p_channel='mtn_momo' then 'MobileMoney' else 'OrangeMoney' end) or length(v_ref) not between 6 and 100 or p_amount is null or p_amount<=0 or v_payer !~ '^6[0-9]{8}$' or p_occurred is null or p_captured is null or p_captured>now()+interval '5 minutes' or p_captured<now()-interval '24 hours' or p_occurred not between p_captured-interval '24 hours' and p_captured+interval '5 minutes' or coalesce(p_sha,'') !~ '^[0-9a-f]{64}$' then raise exception 'NS_CREDIT_PROOF_MISMATCH'; end if;
 insert into public.ns_subscription_credit_candidates(admin_device_id,channel,transaction_reference,destination_reference,amount_xaf,payer_number,occurred_at,captured_at,payload_sha256)
 values(d.id,p_channel,v_ref,p_destination,p_amount,v_payer,p_occurred,p_captured,p_sha) on conflict do nothing;
 select * into c from public.ns_subscription_credit_candidates where channel=p_channel and transaction_reference=v_ref;
 if not found or c.admin_device_id<>d.id or c.destination_reference<>p_destination or c.amount_xaf<>p_amount or c.payer_number<>v_payer or c.occurred_at<>p_occurred or c.payload_sha256<>p_sha then raise exception 'NS_CREDIT_REPLAY_MISMATCH'; end if;
 select * into i from public.ns_subscription_intents where channel=p_channel and transaction_reference=v_ref and status in ('submitted','confirmed');
 if found then perform public.ns_subscription_try_match(i.id); end if;
 select * into c from public.ns_subscription_credit_candidates where id=c.id;
 return jsonb_build_object('status',c.status,'intent_id',c.intent_id);
end $f$;
revoke all on function public.ns_subscription_try_match(uuid),public.ns_subscription_ingest_credit(uuid,uuid,text,text,text,text,bigint,text,timestamptz,timestamptz,text,text) from public,anon,authenticated;
grant execute on function public.ns_subscription_ingest_credit(uuid,uuid,text,text,text,text,bigint,text,timestamptz,timestamptz,text,text) to service_role;
revoke all on function public.ns_subscription_amount(text,integer,date),public.ns_subscription_public_intent(uuid),public.ns_subscription_list(uuid),public.ns_subscription_create(uuid,text,integer,text),public.ns_subscription_declare(uuid,text,text,timestamptz,text),public.ns_subscription_confirm_credit(uuid,uuid,uuid,text,text,text,text,bigint,text,timestamptz,timestamptz,text,text) from public,anon,authenticated;
grant execute on function public.ns_subscription_list(uuid),public.ns_subscription_create(uuid,text,integer,text),public.ns_subscription_declare_sms(uuid,text,text,timestamptz) to authenticated;
revoke all on function public.ns_subscription_declare_sms(uuid,text,text,timestamptz) from public,anon;
grant execute on function public.ns_subscription_confirm_credit(uuid,uuid,uuid,text,text,text,text,bigint,text,timestamptz,timestamptz,text,text) to service_role;
rollback;
