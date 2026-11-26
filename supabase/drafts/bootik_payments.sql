-- Candidate only. Separate payer/merchant proofs; no client can confirm a payment.
begin;
create table bootik.bk_payment_destinations (
 channel text primary key check(channel in ('mtn_momo','orange_money')),
 reference text not null check(length(reference) between 1 and 120), beneficiary text not null, instructions text not null default '',active boolean not null default true
);
create table bootik.bk_payment_intents (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,app_id uuid not null,user_id uuid not null,location_id uuid not null,
 universe text not null check(universe in ('retailer','distributor')),plan text not null check(plan in ('access','premium')),months integer not null check(months in (1,12)),
 amount_fcfa bigint not null check(amount_fcfa>0),channel text not null check(channel in ('mtn_momo','orange_money')),destination text not null,beneficiary text not null,instructions text not null,
 created_at timestamptz not null default now(),expires_at timestamptz not null,state text not null default 'awaiting_payment' check(state in ('awaiting_payment','awaiting_verification','confirmed','expired')),
 request_key uuid not null, paid_period_id uuid references bootik.bk_paid_periods(id),unique(organization_id,app_id,request_key),
 foreign key(organization_id,app_id,user_id,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
create table bootik.bk_payer_proofs (
 intent_id uuid primary key references bootik.bk_payment_intents(id),channel text not null,reference text not null check(reference ~ '^[A-Z0-9-]{5,80}$'),
 amount_fcfa bigint not null,destination text not null,provider_at timestamptz not null,evidence_sha text not null unique check(evidence_sha ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now(),unique(channel,reference)
);
create table bootik.bk_merchant_devices (
 id uuid primary key default gen_random_uuid(),token_hash text not null unique check(token_hash ~ '^[0-9a-f]{64}$'),
 channel text not null references bootik.bk_payment_destinations(channel),destination text not null,active boolean not null default true
);
create table bootik.bk_merchant_proofs (
 id uuid primary key default gen_random_uuid(),device_id uuid not null references bootik.bk_merchant_devices(id),channel text not null,
 reference text not null check(reference ~ '^[A-Z0-9-]{5,80}$'),amount_fcfa bigint not null check(amount_fcfa>0),destination text not null,
 provider_at timestamptz not null,evidence_sha text not null unique check(evidence_sha ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now(),unique(channel,reference)
);
create function bootik.bk_prepare_subscription(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_universe text,p_plan text,p_months int,p_channel text,p_key uuid)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare v uuid; d bootik.bk_payment_destinations%rowtype; old bootik.bk_payment_intents%rowtype;amount bigint;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_user,p_site,true);
 amount:=bootik.bk_quote(p_universe,p_plan,p_months);
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_universe,7));
 select * into old from bootik.bk_payment_intents where organization_id=p_org and app_id=p_app and request_key=p_key;
 if found then
  if (old.user_id,old.location_id,old.universe,old.plan,old.months,old.channel) is distinct from (p_user,p_site,p_universe,p_plan,p_months,p_channel) then raise exception 'BOOTIK_PAYMENT_INTENT_CONFLICT';end if;
  return old.id;
 end if;
 update bootik.bk_payment_intents set state='expired' where organization_id=p_org and app_id=p_app and universe=p_universe and ((state='awaiting_payment' and expires_at<=now()) or(state='awaiting_verification' and expires_at+interval '24 hours'<=now()));
 if exists(select 1 from bootik.bk_payment_intents where organization_id=p_org and app_id=p_app and universe=p_universe and state in ('awaiting_payment','awaiting_verification')) then raise exception 'BOOTIK_PAYMENT_PENDING';end if;
 select * into d from bootik.bk_payment_destinations where channel=p_channel and active;
 if not found then raise exception 'BOOTIK_DESTINATION_UNAVAILABLE';end if;
 insert into bootik.bk_payment_intents(organization_id,app_id,user_id,location_id,universe,plan,months,amount_fcfa,channel,destination,beneficiary,instructions,expires_at,request_key)
 values(p_org,p_app,p_user,p_site,p_universe,p_plan,p_months,amount,p_channel,d.reference,d.beneficiary,d.instructions,now()+interval '30 minutes',p_key) returning id into v;
 return v;
end $$;
create function bootik.bk_submit_debit(p_org uuid,p_app uuid,p_user uuid,p_site uuid,p_intent uuid,p_reference text,p_amount bigint,p_destination text,p_at timestamptz,p_sha text)
returns boolean language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare i bootik.bk_payment_intents%rowtype;old bootik.bk_payer_proofs%rowtype;r text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_user,p_site,true);
 select * into i from bootik.bk_payment_intents where id=p_intent and organization_id=p_org and app_id=p_app and user_id=p_user and location_id=p_site for update;
 if not found then raise exception 'BOOTIK_PAYMENT_DENIED';end if;
 r:=upper(btrim(p_reference));
 if r is null or r !~ '^[A-Z0-9-]{5,80}$' or p_sha is null or p_sha !~ '^[0-9a-f]{64}$' or p_amount is distinct from i.amount_fcfa or p_destination is distinct from i.destination or p_at is null or p_at<i.created_at-interval '5 minutes' or p_at>i.expires_at+interval '5 minutes' or p_at>now()+interval '5 minutes' then raise exception 'BOOTIK_DEBIT_MISMATCH';end if;
 select * into old from bootik.bk_payer_proofs where intent_id=p_intent;
 if found then
  if (old.reference,old.amount_fcfa,old.destination,old.provider_at,old.evidence_sha) is distinct from (r,p_amount,p_destination,p_at,p_sha) then raise exception 'BOOTIK_DEBIT_CONFLICT';end if;
  return true;
 end if;
 if i.state<>'awaiting_payment' or i.expires_at+interval '24 hours'<=now() then raise exception 'BOOTIK_PAYMENT_INTENT_EXPIRED';end if;
 insert into bootik.bk_payer_proofs(intent_id,channel,reference,amount_fcfa,destination,provider_at,evidence_sha) values(p_intent,i.channel,r,p_amount,p_destination,p_at,p_sha);
 update bootik.bk_payment_intents set state='awaiting_verification' where id=p_intent;
 return true;
end $$;
create function bootik.bk_capture_credit(p_token_hash text,p_channel text,p_reference text,p_amount bigint,p_destination text,p_at timestamptz,p_sha text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare d bootik.bk_merchant_devices%rowtype;old bootik.bk_merchant_proofs%rowtype;v uuid;r text;
begin
 select * into d from bootik.bk_merchant_devices where token_hash=p_token_hash and channel=p_channel and destination=p_destination and active;
 if not found then raise exception 'BOOTIK_DEVICE_DENIED' using errcode='42501';end if;
 r:=upper(btrim(p_reference));
 if r is null or r !~ '^[A-Z0-9-]{5,80}$' or p_sha is null or p_sha !~ '^[0-9a-f]{64}$' or p_amount is null or p_amount<=0 or p_at is null or p_at<now()-interval '24 hours' or p_at>now()+interval '5 minutes' then raise exception 'BOOTIK_CREDIT_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_channel||':'||r,8));
 select * into old from bootik.bk_merchant_proofs where channel=p_channel and reference=r;
 if found then
  if (old.device_id,old.amount_fcfa,old.destination,old.provider_at,old.evidence_sha) is distinct from (d.id,p_amount,p_destination,p_at,p_sha) then raise exception 'BOOTIK_CREDIT_CONFLICT';end if;
  return old.id;
 end if;
 insert into bootik.bk_merchant_proofs(device_id,channel,reference,amount_fcfa,destination,provider_at,evidence_sha) values(d.id,p_channel,r,p_amount,p_destination,p_at,p_sha) returning id into v;
 return v;
end $$;
create function bootik.bk_reconcile_subscription(p_intent uuid)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare i bootik.bk_payment_intents%rowtype;d bootik.bk_payer_proofs%rowtype;c bootik.bk_merchant_proofs%rowtype;v uuid;
begin
 select * into i from bootik.bk_payment_intents where id=p_intent for update;
 if not found then return null;end if;
 if i.state='confirmed' then return i.paid_period_id;end if;
 if i.state<>'awaiting_verification' or i.expires_at+interval '24 hours'<=now() then return null;end if;
 select * into d from bootik.bk_payer_proofs where intent_id=p_intent;
 if not found then return null;end if;
 select * into c from bootik.bk_merchant_proofs where channel=d.channel and reference=d.reference;
 if not found then return null;end if;
 if c.amount_fcfa<>d.amount_fcfa or c.destination<>d.destination or c.evidence_sha=d.evidence_sha or abs(extract(epoch from (c.provider_at-d.provider_at)))>1800 then return null;end if;
 v:=bootik.bk_confirm_paid_period(i.organization_id,i.app_id,i.universe,i.plan,i.months,i.amount_fcfa,i.channel||':'||d.reference);
 update bootik.bk_payment_intents set state='confirmed',paid_period_id=v where id=p_intent;
 return v;
end $$;
do $$ declare n text;begin foreach n in array array['bk_payment_destinations','bk_payment_intents','bk_payer_proofs','bk_merchant_devices','bk_merchant_proofs'] loop
 execute format('alter table bootik.%I enable row level security',n);
 execute format('alter table bootik.%I force row level security',n);
 execute format('revoke all on bootik.%I from public,anon,authenticated',n);
end loop;end $$;
revoke all on all functions in schema bootik from public,anon,authenticated;
commit;
