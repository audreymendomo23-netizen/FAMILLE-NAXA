begin;
create table grillad_private.subscription_proofs(
 intent uuid not null references famille_core.payment_intents(id),level smallint not null check(level in (1,2,3)),
 actor uuid not null references auth.users(id),channel text not null check(channel in ('mtn_momo','orange_money')),
 reference text not null check(length(reference) between 5 and 160),
 normalized_reference text generated always as (upper(regexp_replace(reference,'[^A-Za-z0-9]','','g'))) stored,
 amount bigint not null check(amount>0),payer_tail text not null check(payer_tail~'^[0-9]{9}$'),
 destination text not null check(length(destination) between 5 and 160),occurred_at timestamptz not null,
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),created_at timestamptz not null default now(),
 primary key(intent,level),check(length(normalized_reference)>=5)
);
alter table grillad_private.subscription_proofs enable row level security;
revoke all on grillad_private.subscription_proofs from public,anon,authenticated;
create unique index grillad_subscription_reference_once on grillad_private.subscription_proofs(channel,normalized_reference,level);
create unique index grillad_subscription_evidence_once on grillad_private.subscription_proofs(evidence_hash);
-- Merchant destination is configured centrally for subscription receipts only. Never a collection API.
create table grillad_private.subscription_destinations(channel text primary key check(channel in ('mtn_momo','orange_money')),beneficiary text not null,reference text not null,enabled boolean not null default false);
alter table grillad_private.subscription_destinations enable row level security;
revoke all on grillad_private.subscription_destinations from public,anon,authenticated;
create table grillad_private.subscription_intent_destinations(intent uuid primary key references famille_core.payment_intents(id),channel text not null,beneficiary text not null,reference text not null);
alter table grillad_private.subscription_intent_destinations enable row level security;
revoke all on grillad_private.subscription_intent_destinations from public,anon,authenticated;
create function grillad_private.subscription_destination_set(p_channel text,p_beneficiary text,p_reference text,p_enabled boolean) returns boolean
language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if p_channel not in ('mtn_momo','orange_money') or length(coalesce(btrim(p_beneficiary),'')) not between 2 and 100 or length(coalesce(btrim(p_reference),'')) not between 5 and 160 or p_enabled is null then raise exception 'GRILLAD_DESTINATION' using errcode='22023';end if;
 insert into grillad_private.subscription_destinations values(p_channel,btrim(p_beneficiary),btrim(p_reference),p_enabled) on conflict(channel) do update set beneficiary=excluded.beneficiary,reference=excluded.reference,enabled=excluded.enabled;return true;
end $fn$;
-- Freeze the destination of the intent; never trust a destination supplied by the payer.
create function grillad_private.subscription_destination(p_intent uuid) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare i famille_core.payment_intents%rowtype;d grillad_private.subscription_intent_destinations%rowtype;
begin
 select * into i from famille_core.payment_intents where id=p_intent;
 if not found or i.channel not in ('mtn_momo','orange_money') then return null;end if;
 insert into grillad_private.subscription_intent_destinations select i.id,x.channel,x.beneficiary,x.reference from grillad_private.subscription_destinations x where x.channel=i.channel and x.enabled on conflict(intent) do nothing;
 select * into d from grillad_private.subscription_intent_destinations where intent=i.id;
 if not found then return null;end if;
 return jsonb_build_object('beneficiary',d.beneficiary,'reference',d.reference);
end $fn$;
revoke all on function grillad_private.subscription_destination(uuid) from public,anon,authenticated;
-- Level 3 manual declaration from the authenticated owner is not proof of payment.
create function grillad_private.subscription_declare(p_org uuid,p_site uuid,p_request uuid,p_reference text,p_amount bigint,p_payer text,p_occurred timestamptz) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_core.payment_intents%rowtype;d grillad_private.subscription_intent_destinations%rowtype;u uuid:=auth.uid();h text;old grillad_private.subscription_proofs%rowtype;
begin
 begin if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;exception when insufficient_privilege then perform grillad_private.renewal_guard(p_org,p_site);end;
 select * into q from grillad_private.central_requests where id=p_request and org=p_org and kind='renewal' and status='pending' for update;
 if not found then raise exception 'GRILLAD_REQUEST_DENIED' using errcode='42501';end if;
 select pi.* into i from famille_core.payment_intents pi join grillad_private.renewal_payment_links l on l.intent_id=pi.id where l.request_id=q.id;
 select * into d from grillad_private.subscription_intent_destinations where intent=i.id;
 if not found or i.status<>'pending' or i.expires_at<=now() or p_amount is distinct from i.expected_amount_fcfa or p_payer is null or p_payer!~'^[0-9]{9}$' or p_reference is null or length(regexp_replace(p_reference,'[^A-Za-z0-9]','','g'))<5 or length(p_reference)>160 or p_occurred is null or p_occurred<i.created_at or p_occurred>now()+interval '2 minutes' then raise exception 'GRILLAD_DECLARATION_INPUT' using errcode='22023';end if;
 h:=encode(sha256(convert_to(jsonb_build_array(i.id,u,p_reference,p_amount,p_payer,p_occurred)::text,'UTF8')),'hex');
 select * into old from grillad_private.subscription_proofs where intent=i.id and level=3;
 if found then if old.evidence_hash<>h then raise exception 'GRILLAD_DECLARATION_CONFLICT' using errcode='22023';end if;else
 insert into grillad_private.subscription_proofs(intent,level,actor,channel,reference,amount,payer_tail,destination,occurred_at,evidence_hash) values(i.id,3,u,i.channel,btrim(p_reference),p_amount,p_payer,d.reference,p_occurred,h);
 end if;
 return jsonb_build_object('status','manual_review','level',3);
end $fn$;
-- Only a trusted central ingestion service can attest extracted SMS evidence. No raw message persisted.
create function grillad_private.subscription_proof(p_request uuid,p_level smallint,p_actor uuid,p_reference text,p_amount bigint,p_payer text,p_destination text,p_occurred timestamptz,p_hash text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_core.payment_intents%rowtype;d grillad_private.subscription_intent_destinations%rowtype;old grillad_private.subscription_proofs%rowtype;debit grillad_private.subscription_proofs%rowtype;credit grillad_private.subscription_proofs%rowtype;
begin
 if p_level is null or p_level not in (1,2) or p_hash is null or p_hash!~'^[0-9a-f]{64}$' or not exists(select 1 from auth.users where id=p_actor) then raise exception 'GRILLAD_PROOF_INPUT' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' for update;
 if not found then raise exception 'GRILLAD_REQUEST' using errcode='22023';end if;
 select pi.* into i from famille_core.payment_intents pi join grillad_private.renewal_payment_links l on l.intent_id=pi.id where l.request_id=q.id;
 select * into d from grillad_private.subscription_intent_destinations where intent=i.id;
 if not found or i.status<>'pending' or q.status<>'pending' or i.expires_at<=now() or p_amount is distinct from i.expected_amount_fcfa or p_destination is distinct from d.reference or p_payer is null or p_payer!~'^[0-9]{9}$' or p_reference is null or length(regexp_replace(p_reference,'[^A-Za-z0-9]','','g'))<5 or length(p_reference)>160 or p_occurred is null or p_occurred<i.created_at or p_occurred>now()+interval '2 minutes' or (p_level=1 and p_actor<>q.actor) or (p_level=2 and p_actor=q.actor) then raise exception 'GRILLAD_PROOF_MISMATCH' using errcode='22023';end if;
 select * into old from grillad_private.subscription_proofs where intent=i.id and level=p_level;
 if found then if old.evidence_hash<>p_hash or old.actor<>p_actor or old.reference<>btrim(p_reference) or old.amount<>p_amount or old.payer_tail<>p_payer or old.occurred_at<>p_occurred then raise exception 'GRILLAD_PROOF_CONFLICT' using errcode='22023';end if;else
 insert into grillad_private.subscription_proofs(intent,level,actor,channel,reference,amount,payer_tail,destination,occurred_at,evidence_hash) values(i.id,p_level,p_actor,i.channel,btrim(p_reference),p_amount,p_payer,d.reference,p_occurred,p_hash);end if;
 select * into debit from grillad_private.subscription_proofs where intent=i.id and level=1;
 select * into credit from grillad_private.subscription_proofs where intent=i.id and level=2;
 if debit.intent is null or credit.intent is null then return jsonb_build_object('status','awaiting_independent_proof','level',p_level);end if;
 -- NAXA permits distinct debit/credit IDs; do not match only by amount. Require same payer, channel, destination, close timestamps.
 if debit.actor=credit.actor or debit.payer_tail<>credit.payer_tail or debit.channel<>credit.channel or debit.destination<>credit.destination or abs(extract(epoch from debit.occurred_at-credit.occurred_at))>300 then return jsonb_build_object('status','manual_review','level',3);end if;
 return grillad_private.payment_confirm(q.id,credit.actor,credit.reference,credit.amount,credit.occurred_at,credit.evidence_hash);
end $fn$;
create function public.grillad_subscription_destination_set(p_channel text,p_beneficiary text,p_reference text,p_enabled boolean) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.subscription_destination_set(p_channel,p_beneficiary,p_reference,p_enabled)$fn$;
revoke all on function grillad_private.subscription_destination_set(text,text,text,boolean),public.grillad_subscription_destination_set(text,text,text,boolean) from public,anon,authenticated;
grant execute on function grillad_private.subscription_destination_set(text,text,text,boolean),public.grillad_subscription_destination_set(text,text,text,boolean) to service_role;
create function public.grillad_subscription_declare(p_org uuid,p_site uuid,p_request uuid,p_reference text,p_amount bigint,p_payer text,p_occurred timestamptz) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.subscription_declare(p_org,p_site,p_request,p_reference,p_amount,p_payer,p_occurred)$fn$;
revoke all on function grillad_private.subscription_declare(uuid,uuid,uuid,text,bigint,text,timestamptz),public.grillad_subscription_declare(uuid,uuid,uuid,text,bigint,text,timestamptz) from public,anon,authenticated;
grant execute on function grillad_private.subscription_declare(uuid,uuid,uuid,text,bigint,text,timestamptz),public.grillad_subscription_declare(uuid,uuid,uuid,text,bigint,text,timestamptz) to authenticated;
create function public.grillad_subscription_proof(p_request uuid,p_level smallint,p_actor uuid,p_reference text,p_amount bigint,p_payer text,p_destination text,p_occurred timestamptz,p_hash text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.subscription_proof(p_request,p_level,p_actor,p_reference,p_amount,p_payer,p_destination,p_occurred,p_hash)$fn$;
revoke all on function grillad_private.subscription_proof(uuid,smallint,uuid,text,bigint,text,text,timestamptz,text),public.grillad_subscription_proof(uuid,smallint,uuid,text,bigint,text,text,timestamptz,text) from public,anon,authenticated;
grant execute on function grillad_private.subscription_proof(uuid,smallint,uuid,text,bigint,text,text,timestamptz,text),public.grillad_subscription_proof(uuid,smallint,uuid,text,bigint,text,text,timestamptz,text) to service_role;
-- Keep the authenticated quote scope and freeze destination before displaying it.
create or replace function grillad_private.payment_quote(p_org uuid,p_site uuid,p_request uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare v jsonb;d jsonb;
begin
 begin if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;exception when insufficient_privilege then perform grillad_private.renewal_guard(p_org,p_site);end;
 if p_channel not in ('mtn_momo','orange_money') or not exists(select 1 from grillad_private.central_requests where id=p_request and org=p_org and kind='renewal' and status='pending') then raise exception 'GRILLAD_REQUEST_DENIED' using errcode='42501';end if;
 v:=grillad_private.payment_prepare(p_request,p_channel);d:=grillad_private.subscription_destination((v->>'intent')::uuid);
 return v||jsonb_build_object('currency','FCFA','provider_connected',false,'destination',d,'instruction','EXTERNAL_PAYMENT_AND_INDEPENDENT_PROOF');
end $fn$;
commit;
