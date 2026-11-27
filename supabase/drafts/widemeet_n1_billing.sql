-- N1 billing draft: no payment provider, transfer, or production activation.
-- Adapted from NAXA SERVICES intent/cancel/verified settlement separation.
-- Load after widemeet_n2_n3_rooms.sql because entitlement is defined there.
begin;
create table public.wm_billing_intents(
 id uuid primary key default gen_random_uuid(),
 request_id uuid not null,
 workspace_id uuid not null references public.wm_workspaces(id),
 payer_id uuid not null references public.wm_accounts(id),
 offer text not null check(offer in ('access','premium','pass')),
 period text not null check(period in ('month','year','once')),
 capacity integer not null check(capacity between 1 and 100),
 channel text not null check(channel in ('OM','MOMO')),
 amount integer not null check(amount>0),
 currency text not null default 'XAF' check(currency='XAF'),
 status text not null default 'pending' check(status in ('pending','cancelled','confirmed')),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '24 hours'),
 provider_ref text,
 proof_hash text check(proof_hash is null or proof_hash ~ '^[a-f0-9]{64}$'),
 confirmed_at timestamptz,
 unique(workspace_id,request_id),
 unique(channel,provider_ref),
 check((status='confirmed')=(provider_ref is not null and proof_hash is not null and confirmed_at is not null)),
 check(expires_at>created_at)
);
create table public.wm_paid_passes(
 intent_id uuid primary key references public.wm_billing_intents(id),
 workspace_id uuid not null references public.wm_workspaces(id),
 capacity integer not null check(capacity between 1 and 100),
 issued_at timestamptz not null,
 -- A paid pass is atomically bound to a single room by wm_pass_room_create.
 consumed_room_id uuid unique references public.wm_rooms(id),
 consumed_at timestamptz,
 valid_until timestamptz,
 check((consumed_at is null)=(consumed_room_id is null)),
 check((consumed_at is null)=(valid_until is null)),
 check(valid_until is null or (valid_until>consumed_at and valid_until<=consumed_at+interval '24 hours'))
);
alter table public.wm_billing_intents enable row level security;
alter table public.wm_paid_passes enable row level security;
revoke all on public.wm_billing_intents,public.wm_paid_passes from public,anon,authenticated;
grant select,insert,update on public.wm_billing_intents,public.wm_paid_passes to service_role;
create function public.wm_quote(p_kind text,p_offer text,p_period text,p_capacity integer)
returns integer language sql immutable security invoker set search_path=pg_catalog,public as $wm$
 select case
 when p_kind='enterprise' and p_offer='access' and p_capacity=20 and p_period='month' then 5000
 when p_kind='enterprise' and p_offer='access' and p_capacity=20 and p_period='year' then 50000
 when p_kind='enterprise' and p_offer='premium' and p_capacity=50 and p_period='month' then 10000
 when p_kind='enterprise' and p_offer='premium' and p_capacity=50 and p_period='year' then 100000
 when p_kind='individual' and p_offer='pass' and p_period='once' and p_capacity in (20,50,100) then case p_capacity when 20 then 1000 when 50 then 3000 else 5000 end
 else null end
$wm$;
revoke all on function public.wm_quote(text,text,text,integer) from public,anon,authenticated;
grant execute on function public.wm_quote(text,text,text,integer) to service_role;

create function public.wm_billing_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; w public.wm_workspaces%rowtype; x public.wm_billing_intents%rowtype; v_role text; v_amount integer; v_capacity integer; v_request uuid; v_result jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for update;
 if not found then return null;end if;
 if not exists(select 1 from public.wm_session_context(p_hash) c where c.session_id=s.session_id and not c.password_change_required) then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-billing:'||s.workspace_id::text,0));
 select * into w from public.wm_workspaces where id=s.workspace_id and enabled;
 if not found then return null;end if;
 select role into v_role from public.wm_memberships where account_id=s.account_id and workspace_id=w.id and enabled;
 if not found or (w.kind='enterprise' and v_role<>'promoteur') or (w.kind='individual' and v_role<>'owner') then return null;end if;
 if p_action='billing-list' then
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into v_result from (
   select id,offer,period,capacity,channel,amount,currency,status,created_at,expires_at,confirmed_at from public.wm_billing_intents where workspace_id=w.id order by created_at desc limit 100
  ) q;
  return jsonb_build_object('intents',v_result);
 elsif p_action='billing-create' then
  if jsonb_typeof(p_data->'capacity') is distinct from 'number' or coalesce(p_data->>'capacity','') !~ '^[0-9]{1,3}$' or coalesce(p_data->>'channel','') not in ('OM','MOMO') then return null;end if;
  v_capacity:=(p_data->>'capacity')::integer;v_request:=(p_data->>'request_id')::uuid;
  if v_request is null then return null;end if;
  v_amount:=public.wm_quote(w.kind,p_data->>'offer',p_data->>'period',v_capacity);
  if v_amount is null then return null;end if;
  -- Exact replay returns the existing intent, never a second payable order.
  select * into x from public.wm_billing_intents where workspace_id=w.id and request_id=v_request;
  if found then
   if x.payer_id<>s.account_id or x.offer is distinct from p_data->>'offer' or x.period is distinct from p_data->>'period' or x.capacity<>v_capacity or x.channel is distinct from p_data->>'channel' then return null;end if;
  else
   if (select count(*) from public.wm_billing_intents where workspace_id=w.id and status='pending' and expires_at>clock_timestamp())>=3 then return null;end if;
   insert into public.wm_billing_intents(request_id,workspace_id,payer_id,offer,period,capacity,channel,amount)
   values(v_request,w.id,s.account_id,p_data->>'offer',p_data->>'period',v_capacity,p_data->>'channel',v_amount) returning * into x;
  end if;
  return jsonb_build_object('id',x.id,'amount',x.amount,'currency',x.currency,'status',x.status,'expires_at',x.expires_at);
 elsif p_action='billing-cancel' then
  select * into x from public.wm_billing_intents where id=(p_data->>'id')::uuid and workspace_id=w.id and payer_id=s.account_id for update;
  if not found or x.status='confirmed' then return null;end if;
  update public.wm_billing_intents set status='cancelled' where id=x.id and status='pending';
  return jsonb_build_object('id',x.id,'status','cancelled');
 end if;
 return null;
end $wm$;
revoke all on function public.wm_billing_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_billing_action(text,text,jsonb) to service_role;

-- Internal adapter boundary. No public/client Edge action calls this function.
-- Only a future qualified central payment verifier may supply an independently
-- authenticated receipt, never client-declared SMS or a client success boolean.
create function public.wm_settle_verified_receipt(p_id uuid,p_channel text,p_reference text,p_amount integer,p_currency text,p_proof_hash text,p_paid_at timestamptz)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare x public.wm_billing_intents%rowtype; e public.wm_room_entitlements%rowtype; w uuid; t timestamptz:=clock_timestamp(); start_at timestamptz;
begin
 if p_reference is null or length(p_reference) not between 5 and 160 or p_proof_hash is null or p_proof_hash !~ '^[a-f0-9]{64}$' or p_currency is distinct from 'XAF' or p_paid_at is null or p_paid_at>t+interval '5 minutes' then return false;end if;
 select workspace_id into w from public.wm_billing_intents where id=p_id;
 if not found then return false;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-billing:'||w::text,0));
 select * into x from public.wm_billing_intents where id=p_id for update;
 if not found or x.channel is distinct from p_channel or x.amount is distinct from p_amount or p_paid_at<x.created_at-interval '5 minutes' or p_paid_at>x.expires_at then return false;end if;
 if x.status='confirmed' then return x.provider_ref=p_reference and x.proof_hash=p_proof_hash and x.confirmed_at=p_paid_at;end if;
 if x.status<>'pending' then return false;end if;
 if not exists(select 1 from public.wm_accounts a join public.wm_memberships m on m.account_id=a.id and m.enabled join public.wm_workspaces ws on ws.id=m.workspace_id and ws.enabled where a.id=x.payer_id and a.enabled and ws.id=x.workspace_id and ((ws.kind='enterprise' and m.role='promoteur') or (ws.kind='individual' and m.role='owner'))) then return false;end if;
 if exists(select 1 from public.wm_billing_intents b where b.channel=p_channel and b.provider_ref=p_reference and b.id<>x.id) then return false;end if;
 if x.offer='pass' then
  insert into public.wm_paid_passes(intent_id,workspace_id,capacity,issued_at) values(x.id,x.workspace_id,x.capacity,p_paid_at);
 else
  if (select count(*) from public.wm_memberships m where m.workspace_id=x.workspace_id and m.enabled and m.role<>'promoteur')>x.capacity then return false;end if;
  select * into e from public.wm_room_entitlements where workspace_id=x.workspace_id for update;
  if found and e.enabled and e.valid_until>t and e.plan<>x.offer then return false;end if;
  start_at:=greatest(t,coalesce(e.valid_until,t));
  insert into public.wm_room_entitlements(workspace_id,plan,valid_until,enabled)
  values(x.workspace_id,x.offer,start_at+case when x.period='year' then interval '1 year' else interval '1 month' end,true)
  on conflict(workspace_id) do update set plan=excluded.plan,valid_until=excluded.valid_until,enabled=true;
 end if;
 update public.wm_billing_intents set status='confirmed',provider_ref=p_reference,proof_hash=p_proof_hash,confirmed_at=p_paid_at where id=x.id;
 return true;
exception when unique_violation then return false;
end $wm$;
revoke all on function public.wm_settle_verified_receipt(uuid,text,text,integer,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.wm_settle_verified_receipt(uuid,text,text,integer,text,text,timestamptz) to service_role;

-- Enforce paid enterprise collaborator capacity on membership activation,
-- including direct trusted writes. The promoter is excluded from "added members".
create function public.wm_guard_member_capacity()
returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare lim integer;
begin
 if not new.enabled or new.role in ('owner','promoteur') then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-billing:'||new.workspace_id::text,0));
 select case when e.plan='access' then 20 else 50 end into lim
 from public.wm_room_entitlements e join public.wm_workspaces w on w.id=e.workspace_id and w.kind='enterprise'
 where e.workspace_id=new.workspace_id and e.enabled and e.valid_until>clock_timestamp();
 if found and (select count(*) from public.wm_memberships m where m.workspace_id=new.workspace_id and m.enabled and m.role not in ('owner','promoteur') and m.account_id<>new.account_id)>=lim then
  raise exception 'workspace collaborator capacity reached' using errcode='23514';
 end if;
 return new;
end $wm$;
revoke all on function public.wm_guard_member_capacity() from public,anon,authenticated;
grant execute on function public.wm_guard_member_capacity() to service_role;
create trigger wm_membership_capacity_guard before insert or update of enabled,role,workspace_id on public.wm_memberships for each row execute function public.wm_guard_member_capacity();
-- A paid individual pass is bound to exactly one room at creation, not to an
-- unrestricted workspace entitlement. Clock starts at binding (conservative).
create function public.wm_pass_list(p_hash text)
returns jsonb language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select coalesce(jsonb_agg(jsonb_build_object('id',p.intent_id,'capacity',p.capacity,'room_id',p.consumed_room_id,'valid_until',p.valid_until) order by p.issued_at),'[]'::jsonb)
 from public.wm_session_context(p_hash) s join public.wm_workspaces w on w.id=s.workspace_id and w.kind='individual' and w.enabled
 join public.wm_memberships m on m.account_id=s.account_id and m.workspace_id=w.id and m.role='owner' and m.enabled
 join public.wm_paid_passes p on p.workspace_id=w.id
 where not s.password_change_required and (p.consumed_at is null or p.valid_until>now())
$wm$;
revoke all on function public.wm_pass_list(text) from public,anon,authenticated;
grant execute on function public.wm_pass_list(text) to service_role;
create function public.wm_pass_actor(p_hash text,p_intent uuid)
returns table(account_id uuid,workspace_id uuid,role text,plan text,entitlement_end_ms bigint,capacity integer)
language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select s.account_id,s.workspace_id,m.role,'premium'::text,floor(extract(epoch from now()+interval '24 hours')*1000)::bigint,p.capacity
 from public.wm_session_context(p_hash) s join public.wm_workspaces w on w.id=s.workspace_id and w.kind='individual' and w.enabled
 join public.wm_memberships m on m.account_id=s.account_id and m.workspace_id=w.id and m.role='owner' and m.enabled
 join public.wm_paid_passes p on p.workspace_id=w.id and p.intent_id=p_intent and p.consumed_at is null
 where not s.password_change_required
$wm$;
revoke all on function public.wm_pass_actor(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_pass_actor(text,uuid) to service_role;
create function public.wm_pass_room_create(p_hash text,p_intent uuid,p_state jsonb)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; p public.wm_paid_passes%rowtype; rid uuid; t timestamptz; until_at timestamptz;
begin
 select * into a from public.wm_pass_actor(p_hash,p_intent);
 if not found then return false;end if;
 perform 1 from public.wm_accounts where id=a.account_id and enabled and not password_change_required for share;
 if not found then return false;end if;
 perform 1 from public.wm_workspaces where id=a.workspace_id and enabled and kind='individual' for share;
 if not found then return false;end if;
 perform 1 from public.wm_memberships where account_id=a.account_id and workspace_id=a.workspace_id and role='owner' and enabled for share;
 if not found then return false;end if;
 perform 1 from public.wm_device_sessions where token_hash=p_hash and revoked_at is null and expires_at>clock_timestamp() for share;
 if not found then return false;end if;
 select * into p from public.wm_paid_passes where intent_id=p_intent and workspace_id=a.workspace_id for update;
 if not found or p.consumed_at is not null then return false;end if;
 t:=clock_timestamp();until_at:=to_timestamp((p_state->>'hardEndMs')::bigint/1000.0);
 if p_state is null or p_state->>'workspaceId' is distinct from a.workspace_id::text or p_state->>'hostId' is distinct from a.account_id::text or p_state->>'status' is distinct from 'scheduled' or p_state->>'revision' is distinct from '1' or jsonb_typeof(p_state->'participants') is distinct from 'array' or until_at is null or until_at<=t or until_at>t+interval '24 hours' then return false;end if;
 if jsonb_array_length(p_state->'participants')>p.capacity or not exists(select 1 from jsonb_array_elements(p_state->'participants') x where x->>'memberId'=a.account_id::text and x->>'response'='accepted') then return false;end if;
 if exists(select 1 from jsonb_array_elements(p_state->'participants') x where not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and m.account_id::text=x->>'memberId')) then return false;end if;
 rid:=(p_state->>'id')::uuid;
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(rid,a.workspace_id,a.account_id,1,p_state) on conflict(id) do nothing;
 if not found then return false;end if;
 update public.wm_paid_passes set consumed_room_id=rid,consumed_at=t,valid_until=until_at where intent_id=p_intent;
 return true;
end $wm$;
revoke all on function public.wm_pass_room_create(text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.wm_pass_room_create(text,uuid,jsonb) to service_role;
create or replace function public.wm_room_actor_for(p_hash text,p_room uuid)
returns table(account_id uuid,workspace_id uuid,role text,plan text,entitlement_end_ms bigint)
language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select a.* from public.wm_room_actor(p_hash) a join public.wm_workspaces w on w.id=a.workspace_id and w.kind='enterprise' where p_room is null or not public.wm_external_guest_valid(p_room,a.account_id) or exists(select 1 from public.wm_rooms rr where rr.id=p_room and rr.workspace_id=a.workspace_id)
 union all
 select s.account_id,s.workspace_id,m.role,'premium'::text,floor(extract(epoch from p.valid_until)*1000)::bigint
 from public.wm_session_context(p_hash) s join public.wm_workspaces w on w.id=s.workspace_id and w.kind='individual' and w.enabled
 join public.wm_memberships m on m.account_id=s.account_id and m.workspace_id=w.id and m.enabled
 join public.wm_paid_passes p on p.workspace_id=w.id and p.consumed_room_id=p_room and p.valid_until>now()
 where not s.password_change_required and m.role='owner'
 union all
 select s.account_id,r.workspace_id,'staff'::text,case when w.kind='individual' then 'premium' else e.plan end,
 floor(extract(epoch from case when w.kind='individual' then p.valid_until else e.valid_until end)*1000)::bigint
 from public.wm_session_context(p_hash) s join public.wm_rooms r on r.id=p_room
 join public.wm_workspaces w on w.id=r.workspace_id and w.enabled
 join public.wm_accounts h on h.id=r.host_id and h.enabled and not h.password_change_required
 join public.wm_memberships hm on hm.account_id=r.host_id and hm.workspace_id=r.workspace_id and hm.enabled and hm.role in ('owner','promoteur','manager')
 left join public.wm_room_entitlements e on e.workspace_id=w.id and e.enabled and e.valid_until>now()
 left join public.wm_paid_passes p on p.consumed_room_id=r.id and p.valid_until>now()
 where not s.password_change_required and public.wm_external_guest_valid(r.id,s.account_id)
 and ((w.kind='enterprise' and e.workspace_id is not null) or (w.kind='individual' and p.intent_id is not null))
$wm$;
revoke all on function public.wm_room_actor_for(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_room_actor_for(text,uuid) to service_role;
-- Exact replay of a creation that was committed before a network response was lost.
-- No new charge or pass consumption. A changed request cannot read a previous creation.
create function public.wm_room_creation_replay(p_hash text,p_room uuid,p_digest text,p_intent uuid)
returns jsonb language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select r.state from public.wm_rooms r join lateral public.wm_room_actor_for(p_hash,r.id) a on a.workspace_id=r.workspace_id and a.account_id=r.host_id
 where r.id=p_room and a.role in ('owner','promoteur','manager') and p_digest~'^[a-f0-9]{64}$' and r.state->>'creationDigest'=p_digest
 and (p_intent is null and not exists(select 1 from public.wm_paid_passes p where p.consumed_room_id=r.id) or p_intent is not null and exists(select 1 from public.wm_paid_passes p where p.consumed_room_id=r.id and p.intent_id=p_intent))
$wm$;
revoke all on function public.wm_room_creation_replay(text,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.wm_room_creation_replay(text,uuid,text,uuid) to service_role;
commit;
