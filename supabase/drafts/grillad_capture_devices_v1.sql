begin;
create or replace function grillad_private.payment_prepare(p_request uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;sub uuid;i uuid;amount bigint;intent famille_core.payment_intents%rowtype;
begin
 if p_channel is null or p_channel not in ('mtn_momo','orange_money','bank') then raise exception 'GRILLAD_CHANNEL' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' and status='pending' for update;
 if not found then raise exception 'GRILLAD_REQUEST' using errcode='22023';end if;
 select intent_id into i from grillad_private.renewal_payment_links where request_id=q.id;
 if found then select * into intent from famille_core.payment_intents where id=i;return jsonb_build_object('intent',i,'amount',intent.expected_amount_fcfa,'channel',intent.channel,'status',case when intent.status='pending' and intent.expires_at<=now() then 'expired' else intent.status end,'expires_at',intent.expires_at);end if;
 select id into strict sub from famille_core.subscriptions s where s.organization_id=q.org and s.app_id=(select id from famille_core.applications where code='grillad') and s.status in ('active','expired','past_due','pending');
 amount:=(q.details->>'amount')::bigint;
 insert into famille_core.payment_intents(subscription_id,expected_amount_fcfa,channel,expires_at) values(sub,amount,p_channel,now()+interval '30 minutes') returning * into intent;
 i:=intent.id;
 insert into grillad_private.renewal_payment_links(request_id,intent_id) values(q.id,i);
 return jsonb_build_object('intent',i,'amount',amount,'channel',intent.channel,'status','pending','expires_at',intent.expires_at);
end $fn$;
create or replace function grillad_private.payment_reissue(p_event uuid,p_request uuid,p_operator uuid,p_channel text,p_proof text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_core.payment_intents%rowtype;old grillad_private.payment_reissues%rowtype;n uuid;
begin
 if p_event is null or p_channel is null or p_channel not in ('mtn_momo','orange_money','bank') or p_proof is null or p_proof!~'^[0-9a-f]{64}$' or not exists(select 1 from auth.users where id=p_operator) then raise exception 'GRILLAD_REISSUE_INPUT' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' for update;
 if not found then raise exception 'GRILLAD_REQUEST' using errcode='22023';end if;
 select * into old from grillad_private.payment_reissues where event_id=p_event;
 if found then
  if old.request_id<>p_request or old.operator_id<>p_operator or old.proof_hash<>p_proof or not exists(select 1 from famille_core.payment_intents where id=old.next_intent and channel=p_channel) then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023';end if;
  return jsonb_build_object('intent',old.next_intent,'previous',old.previous_intent,'status','reissued');
 end if;
 select pi.* into i from famille_core.payment_intents pi join grillad_private.renewal_payment_links l on l.intent_id=pi.id where l.request_id=q.id for update of pi;
 if i.id is null or q.status<>'pending' or i.status not in ('pending','expired') or i.expires_at is null or i.expires_at>now() or exists(select 1 from famille_core.payment_matches where payment_intent_id=i.id) then raise exception 'GRILLAD_REISSUE_DENIED' using errcode='22023';end if;
 update famille_core.payment_intents set status='expired' where id=i.id;
 insert into famille_core.payment_intents(subscription_id,expected_amount_fcfa,channel,expires_at) values(i.subscription_id,i.expected_amount_fcfa,p_channel,now()+interval '30 minutes') returning id into n;
 update grillad_private.renewal_payment_links set intent_id=n where request_id=q.id;
 insert into grillad_private.payment_reissues(event_id,request_id,previous_intent,next_intent,operator_id,proof_hash) values(p_event,q.id,i.id,n,p_operator,p_proof);
 return jsonb_build_object('intent',n,'previous',i.id,'status','reissued');
end $fn$;
create table grillad_private.subscription_capture_devices(
 id uuid primary key,actor uuid not null references auth.users(id),token_hash text not null unique check(token_hash~'^[0-9a-f]{64}$'),
 channel text not null check(channel in ('mtn_momo','orange_money')),destination text not null,
 consent_at timestamptz not null default now(),revoked_at timestamptz,created_at timestamptz not null default now()
);
alter table grillad_private.subscription_capture_devices enable row level security;
revoke all on grillad_private.subscription_capture_devices from public,anon,authenticated;
create function grillad_private.capture_device_set(p_device uuid,p_actor uuid,p_hash text,p_channel text,p_destination text,p_enabled boolean) returns boolean
language plpgsql security definer set search_path=pg_catalog as $fn$
declare old grillad_private.subscription_capture_devices%rowtype;
begin
 if p_device is null or p_actor is null or p_hash is null or p_hash!~'^[0-9a-f]{64}$' or p_enabled is null or not exists(select 1 from auth.users where id=p_actor) then raise exception 'GRILLAD_DEVICE_INPUT' using errcode='22023';end if;
 select * into old from grillad_private.subscription_capture_devices where id=p_device for update;
 if found and (old.actor,old.channel,old.destination,old.token_hash) is distinct from (p_actor,p_channel,p_destination,p_hash) then raise exception 'GRILLAD_DEVICE_CONFLICT' using errcode='22023';end if;
 if not p_enabled then update grillad_private.subscription_capture_devices set revoked_at=coalesce(revoked_at,now()) where id=p_device;return found;end if;
 if not exists(select 1 from grillad_private.subscription_destinations where channel=p_channel and reference=p_destination and enabled) or (old.id is not null and old.revoked_at is not null) then raise exception 'GRILLAD_DESTINATION_DENIED' using errcode='42501';end if;
 insert into grillad_private.subscription_capture_devices(id,actor,token_hash,channel,destination) values(p_device,p_actor,p_hash,p_channel,p_destination) on conflict(id) do nothing;return true;
end $fn$;
create function grillad_private.capture_context(p_request uuid,p_actor uuid,p_session uuid,p_device uuid,p_hash text,p_level smallint) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_core.payment_intents%rowtype;d grillad_private.subscription_intent_destinations%rowtype;
begin
 if p_level is null or p_level not in (1,2) or not exists(select 1 from auth.sessions where id=p_session and user_id=p_actor) then raise exception 'GRILLAD_CAPTURE_SESSION' using errcode='42501';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' and status='pending';
 if not found then raise exception 'GRILLAD_REQUEST_DENIED' using errcode='42501';end if;
 select pi.* into i from famille_core.payment_intents pi join grillad_private.renewal_payment_links l on l.intent_id=pi.id where l.request_id=q.id;
 select * into d from grillad_private.subscription_intent_destinations where intent=i.id;
 if not found or i.status<>'pending' or i.expires_at<=now() or not exists(select 1 from grillad_private.subscription_destinations x where x.channel=d.channel and x.reference=d.reference and x.enabled) then raise exception 'GRILLAD_CAPTURE_INTENT' using errcode='42501';end if;
 if p_level=1 then
  if q.actor<>p_actor or not exists(select 1 from famille_private.account_devices where user_id=p_actor and app_code='grillad' and auth_session_id=p_session and platform='android' and status='active') or not exists(select 1 from famille_private.account_app_access where user_id=p_actor and organization_id=q.org and app_code='grillad' and role_code='owner' and status='active' and starts_at<=now() and (ends_at is null or ends_at>now())) then raise exception 'GRILLAD_PAYER_DEVICE' using errcode='42501';end if;
 else
  if q.actor=p_actor or not exists(select 1 from grillad_private.subscription_capture_devices where id=p_device and actor=p_actor and token_hash=p_hash and channel=d.channel and destination=d.reference and revoked_at is null) then raise exception 'GRILLAD_ADMIN_DEVICE' using errcode='42501';end if;
 end if;
 return jsonb_build_object('channel',d.channel,'destination',d.reference,'beneficiary',d.beneficiary,'amount',i.expected_amount_fcfa,'created_at',i.created_at,'expires_at',i.expires_at);
end $fn$;
create function grillad_private.capture_submit(p_request uuid,p_actor uuid,p_session uuid,p_device uuid,p_hash text,p_level smallint,p_reference text,p_amount bigint,p_payer text,p_destination text,p_occurred timestamptz,p_evidence text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 perform grillad_private.capture_context(p_request,p_actor,p_session,p_device,p_hash,p_level);
 return grillad_private.subscription_proof(p_request,p_level,p_actor,p_reference,p_amount,p_payer,p_destination,p_occurred,p_evidence);
end $fn$;
create function public.grillad_capture_device_set(p_device uuid,p_actor uuid,p_hash text,p_channel text,p_destination text,p_enabled boolean) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.capture_device_set(p_device,p_actor,p_hash,p_channel,p_destination,p_enabled)$fn$;
revoke all on function grillad_private.capture_device_set(uuid,uuid,text,text,text,boolean),public.grillad_capture_device_set(uuid,uuid,text,text,text,boolean) from public,anon,authenticated;
grant execute on function grillad_private.capture_device_set(uuid,uuid,text,text,text,boolean),public.grillad_capture_device_set(uuid,uuid,text,text,text,boolean) to service_role;
create function public.grillad_capture_context(p_request uuid,p_actor uuid,p_session uuid,p_device uuid,p_hash text,p_level smallint) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.capture_context(p_request,p_actor,p_session,p_device,p_hash,p_level)$fn$;
revoke all on function grillad_private.capture_context(uuid,uuid,uuid,uuid,text,smallint),public.grillad_capture_context(uuid,uuid,uuid,uuid,text,smallint) from public,anon,authenticated;
grant execute on function grillad_private.capture_context(uuid,uuid,uuid,uuid,text,smallint),public.grillad_capture_context(uuid,uuid,uuid,uuid,text,smallint) to service_role;
create function public.grillad_capture_submit(p_request uuid,p_actor uuid,p_session uuid,p_device uuid,p_hash text,p_level smallint,p_reference text,p_amount bigint,p_payer text,p_destination text,p_occurred timestamptz,p_evidence text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.capture_submit(p_request,p_actor,p_session,p_device,p_hash,p_level,p_reference,p_amount,p_payer,p_destination,p_occurred,p_evidence)$fn$;
revoke all on function grillad_private.capture_submit(uuid,uuid,uuid,uuid,text,smallint,text,bigint,text,text,timestamptz,text),public.grillad_capture_submit(uuid,uuid,uuid,uuid,text,smallint,text,bigint,text,text,timestamptz,text) from public,anon,authenticated;
grant execute on function grillad_private.capture_submit(uuid,uuid,uuid,uuid,text,smallint,text,bigint,text,text,timestamptz,text),public.grillad_capture_submit(uuid,uuid,uuid,uuid,text,smallint,text,bigint,text,text,timestamptz,text) to service_role;
commit;
