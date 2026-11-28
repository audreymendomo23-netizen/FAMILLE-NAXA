-- GRILLAD isolated operations. Service role is a trusted central operator boundary.
begin;
create table grillad_private.central_operations(
 id uuid primary key, kind text not null, operator_id uuid not null references auth.users(id),
 payload jsonb not null, result jsonb not null, created_at timestamptz not null default now()
);
alter table grillad_private.central_operations enable row level security;
revoke all on grillad_private.central_operations from public,anon,authenticated;
create table grillad_private.renewal_payment_links(
 request_id uuid primary key references grillad_private.central_requests(id),
 intent_id uuid not null unique references famille_core.payment_intents(id),
 evidence_hash text, check(evidence_hash is null or evidence_hash~'^[0-9a-f]{64}$')
);
alter table grillad_private.renewal_payment_links enable row level security;
revoke all on grillad_private.renewal_payment_links from public,anon,authenticated;
-- Existing verified Auth identity only; never creates credentials or modifies other applications.
create function grillad_private.central_provision(p_event uuid,p_operator uuid,p_user uuid,p_phone text,p_org_name text,p_site_name text,p_plan text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid; pl uuid; amount bigint; o uuid; s uuid; m uuid; sub uuid; old grillad_private.central_operations%rowtype; v jsonb; data jsonb;
begin
 if p_event is null or not exists(select 1 from auth.users where id=p_operator) or p_user is null or p_phone is null or p_phone!~'^\+[1-9][0-9]{7,14}$' or length(coalesce(btrim(p_org_name),'')) not between 2 and 160 or length(coalesce(btrim(p_site_name),'')) not between 2 and 160 then raise exception 'GRILLAD_PROVISION_INPUT' using errcode='22023';end if;
 data:=jsonb_build_object('user',p_user,'phone',p_phone,'org',btrim(p_org_name),'site',btrim(p_site_name),'plan',p_plan);
 perform pg_advisory_xact_lock(hashtextextended('grillad-central:'||p_user::text,0));
 select * into old from grillad_private.central_operations where id=p_event;
 if found then if old.kind<>'owner' or old.operator_id<>p_operator or old.payload<>data then raise exception 'GRILLAD_CENTRAL_REPLAY' using errcode='22023';end if;return old.result;end if;
 if not exists(select 1 from auth.users u where id=p_user and ltrim(to_jsonb(u)->>'phone','+')=ltrim(p_phone,'+') and to_jsonb(u)->>'phone_confirmed_at' is not null) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status in ('planned','active') for update;
 select id,amount_fcfa into pl,amount from famille_core.plans where app_id=a and code=p_plan and status='active' and code in ('grillad_access_month','grillad_access_year','grillad_premium_month','grillad_premium_year');
 if pl is null then raise exception 'GRILLAD_PLAN' using errcode='22023';end if;
 if exists(select 1 from famille_core.memberships where user_id=p_user and app_id=a and status in ('active','invited','suspended')) or exists(select 1 from famille_core.client_app_access where user_id=p_user and app_id=a and status<>'granted') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='22023';end if;
 update famille_core.applications set status='active' where id=a and status='planned';
 insert into famille_core.organizations(legal_name,organization_type,status,created_by) values(btrim(p_org_name),'retail','active',p_operator) returning id into o;
 insert into famille_core.organization_apps(organization_id,app_id,status,activated_at) values(o,a,'active',now());
 insert into famille_core.locations(organization_id,name) values(o,btrim(p_site_name)) returning id into s;
 insert into grillad_private.enabled_sites(org,site) values(o,s);
 insert into famille_core.memberships(user_id,organization_id,app_id,status,invited_by,joined_at) values(p_user,o,a,'active',p_operator,now()) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,granted_by) values(m,a,o,'owner',p_operator);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(p_user,a,'granted',p_operator) on conflict(user_id,app_id) do nothing;
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,role_code,granted_by) values(p_user,'grillad','professional',o,'owner',p_operator);
 -- No trial or free activation: the initial workspace is billing-only until payment confirmation.
 insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,ends_at) values(o,a,pl,'expired',now()-interval '1 second') returning id into sub;
 insert into grillad_private.central_requests(id,org,site,actor,kind,details) values(p_event,o,s,p_user,'renewal',jsonb_build_object('plan',p_plan,'amount',amount,'currency','FCFA'));
 v:=jsonb_build_object('org',o,'site',s,'subscription',sub,'request',p_event,'status','billing_only');
 insert into grillad_private.central_operations values(p_event,'owner',p_operator,data,v,now());return v;
end $fn$;
-- An invitation is issued by the central operator; only the invitee can accept it.
create function grillad_private.central_employee(p_request uuid,p_operator uuid,p_user uuid,p_acceptance_hash text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_private.account_invites%rowtype;
begin
 if p_request is null or not exists(select 1 from auth.users where id=p_operator) or p_acceptance_hash is null or p_acceptance_hash!~'^[0-9a-f]{64}$' then raise exception 'GRILLAD_EMPLOYEE_PROOF' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='employee' for update;
 if not found or p_user=q.actor or not exists(select 1 from auth.users u where id=p_user and ltrim(to_jsonb(u)->>'phone','+')=ltrim(q.details->>'phone','+') and to_jsonb(u)->>'phone_confirmed_at' is not null) then raise exception 'GRILLAD_IDENTITY_UNVERIFIED' using errcode='42501';end if;
 select * into i from famille_private.account_invites where request_id=q.id;
 if found then if i.user_id<>p_user or i.created_by<>p_operator or i.token_hash<>decode(p_acceptance_hash,'hex') then raise exception 'GRILLAD_INVITE_CONFLICT' using errcode='22023';end if;return jsonb_build_object('request',q.id,'invite',i.id,'status',i.status);end if;
 if q.status<>'pending' or q.details->>'role' not in ('seller','manager') or not exists(select 1 from grillad_private.enabled_sites where org=q.org and site=q.site and enabled) then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 insert into famille_private.account_invites(request_id,user_id,token_hash,app_code,account_kind,organization_id,location_id,role_code,created_by,expires_at)
 values(q.id,p_user,decode(p_acceptance_hash,'hex'),'grillad','employee',q.org,q.site,q.details->>'role',p_operator,now()+interval '1 day') returning * into i;
 return jsonb_build_object('request',q.id,'invite',i.id,'status','pending');
end $fn$;
create function grillad_private.employee_accept(p_request uuid,p_token text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_private.account_invites%rowtype;a uuid;m uuid;u uuid:=auth.uid();sid uuid;v jsonb;
begin
 if u is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' or p_token is null or p_token!~'^[A-Za-z0-9_-]{32,128}$' then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid;exception when invalid_text_representation then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end;
 if not exists(select 1 from auth.sessions where id=sid and user_id=u and (tag is null or tag='famille:grillad')) then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='employee' for update;
 select * into i from famille_private.account_invites where request_id=p_request and app_code='grillad' and user_id=u and token_hash=sha256(convert_to(p_token,'UTF8')) for update;
 if not found or q.id is null or i.expires_at<=now() or i.organization_id<>q.org or i.location_id<>q.site or i.role_code<>q.details->>'role' or not exists(select 1 from auth.users x where x.id=u and ltrim(to_jsonb(x)->>'phone','+')=ltrim(q.details->>'phone','+') and to_jsonb(x)->>'phone_confirmed_at' is not null) then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end if;
 v:=jsonb_build_object('request',q.id,'status','processed');
 if i.status='accepted' and q.status='processed' and q.resolution=i.id::text then return v;end if;
 if i.status<>'pending' or q.status<>'pending' then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad' and status='active';
 if a is null or not exists(select 1 from grillad_private.enabled_sites where org=q.org and site=q.site and enabled) or not exists(select 1 from famille_core.organization_apps where organization_id=q.org and app_id=a and status='active') then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 if exists(select 1 from famille_core.memberships where user_id=u and organization_id=q.org and app_id=a) or exists(select 1 from famille_core.client_app_access where user_id=u and app_id=a and status<>'granted') then raise exception 'GRILLAD_EXISTING_ACCOUNT' using errcode='22023';end if;
 insert into famille_core.memberships(user_id,organization_id,app_id,status,invited_by,joined_at) values(u,q.org,a,'active',i.created_by,now()) returning id into m;
 insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id,granted_by) values(m,a,q.org,i.role_code,q.site,i.created_by);
 insert into famille_core.client_app_access(user_id,app_id,status,granted_by) values(u,a,'granted',i.created_by) on conflict(user_id,app_id) do nothing;
 insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,location_id,role_code,granted_by) values(u,'grillad','employee',q.org,q.site,i.role_code,i.created_by);
 update famille_private.account_invites set status='accepted',accepted_at=now(),accepted_by=u where id=i.id;
 if not grillad_private.central_resolve(q.id,'processed',i.id::text) then raise exception 'GRILLAD_RESOLVE';end if;
 return v;
end $fn$;
-- A payment intent does not debit any wallet. A verified external receipt is mandatory for activation.
create function grillad_private.payment_prepare(p_request uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;sub uuid;i uuid;amount bigint;
begin
 if p_channel is null or p_channel not in ('mtn_momo','orange_money','bank') then raise exception 'GRILLAD_CHANNEL' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' and status='pending' for update;
 if not found then raise exception 'GRILLAD_REQUEST' using errcode='22023';end if;
 select intent_id into i from grillad_private.renewal_payment_links where request_id=q.id;
 if found then if not exists(select 1 from famille_core.payment_intents where id=i and channel=p_channel) then raise exception 'GRILLAD_CHANNEL_CONFLICT' using errcode='22023';end if;return jsonb_build_object('intent',i,'amount',q.details->'amount','status','pending');end if;
 select id into strict sub from famille_core.subscriptions s where s.organization_id=q.org and s.app_id=(select id from famille_core.applications where code='grillad') and s.status in ('active','expired','past_due','pending');
 amount:=(q.details->>'amount')::bigint;
 insert into famille_core.payment_intents(subscription_id,expected_amount_fcfa,channel,expires_at) values(sub,amount,p_channel,now()+interval '2 days') returning id into i;
 insert into grillad_private.renewal_payment_links(request_id,intent_id) values(q.id,i);
 return jsonb_build_object('intent',i,'amount',amount,'status','pending');
end $fn$;
create function grillad_private.payment_confirm(p_request uuid,p_operator uuid,p_reference text,p_amount bigint,p_occurred timestamptz,p_evidence_hash text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_core.payment_intents%rowtype;s famille_core.subscriptions%rowtype;pl famille_core.plans%rowtype;v jsonb;proof uuid;h text;old grillad_private.central_operations%rowtype;data jsonb;until_at timestamptz;
begin
 if not exists(select 1 from auth.users where id=p_operator) or length(coalesce(btrim(p_reference),'')) not between 4 and 160 or p_amount is null or p_occurred is null or p_occurred>now()+interval '2 minutes' or p_evidence_hash is null or p_evidence_hash!~'^[0-9a-f]{64}$' then raise exception 'GRILLAD_PAYMENT_EVIDENCE' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' for update;
 if not found then raise exception 'GRILLAD_REQUEST' using errcode='22023';end if;
 select pi.* into i from famille_core.payment_intents pi join grillad_private.renewal_payment_links l on l.intent_id=pi.id where l.request_id=q.id;
 if i.id is null then raise exception 'GRILLAD_INTENT' using errcode='22023';end if;
 select evidence_hash into h from grillad_private.renewal_payment_links where request_id=q.id;
 if q.status='processed' then
  if h=p_evidence_hash and exists(select 1 from famille_core.payment_matches pm where pm.payment_intent_id=i.id and pm.id::text=q.resolution and pm.transaction_reference=btrim(p_reference) and pm.amount_fcfa=p_amount and pm.occurred_at=p_occurred and pm.verified_by=p_operator) then return jsonb_build_object('request',q.id,'status','processed');end if;
  raise exception 'GRILLAD_PAYMENT_REPLAY' using errcode='22023';
 end if;
 if q.status<>'pending' or i.status<>'pending' or i.expires_at<now() or p_occurred<i.created_at or p_amount<>i.expected_amount_fcfa or p_amount<>(q.details->>'amount')::bigint then raise exception 'GRILLAD_PAYMENT_MISMATCH' using errcode='22023';end if;
 select * into s from famille_core.subscriptions where id=i.subscription_id for update;
 select * into pl from famille_core.plans where app_id=s.app_id and code=q.details->>'plan' and status='active' and amount_fcfa=p_amount;
 if s.organization_id<>q.org or s.status not in ('active','expired','past_due','pending') or pl.id is null or not exists(select 1 from famille_core.applications where id=s.app_id and code='grillad' and status='active') or (pl.code like 'grillad_access_%' and (select count(*) from grillad_private.enabled_sites where org=q.org and enabled)<>1) then raise exception 'GRILLAD_PLAN_SCOPE' using errcode='22023';end if;
 until_at:=greatest(now(),coalesce(s.ends_at,now()))+case pl.billing_period when 'monthly' then interval '1 month' else interval '1 year' end;
 insert into famille_core.payment_matches(payment_intent_id,provider,transaction_reference,amount_fcfa,occurred_at,verified_by,verified_at,status) values(i.id,i.channel,btrim(p_reference),p_amount,p_occurred,p_operator,now(),'confirmed') returning id into proof;
 update famille_core.payment_intents set status='matched' where id=i.id;
 update famille_core.subscriptions set plan_id=pl.id,status='active',starts_at=least(now(),coalesce(s.starts_at,now())),ends_at=until_at,grace_until=null,updated_at=now() where id=s.id;
 update grillad_private.renewal_payment_links set evidence_hash=p_evidence_hash where request_id=q.id;
 if not grillad_private.central_resolve(q.id,'processed',proof::text) then raise exception 'GRILLAD_RESOLVE';end if;
 return jsonb_build_object('request',q.id,'status','processed');
end $fn$;
-- Atomic replay batch. Financial events must retain the same cash register and local day.
create function grillad_private.offline_batch(p_org uuid,p_site uuid,p_event uuid,p_day date,p_cash uuid,p_lines jsonb) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare u uuid:=auth.uid();old grillad_private.events%rowtype;line jsonb;payload jsonb;results jsonb:='[]';v jsonb;action_name text;eid uuid;
begin
 perform grillad_private.scope(p_org,p_site);
 if p_event is null or p_day is null or jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) not between 1 and 30 or octet_length(p_lines::text)>40000 then raise exception 'GRILLAD_BATCH' using errcode='22023';end if;
 payload:=jsonb_build_object('day',p_day,'cash',p_cash,'lines',p_lines);
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 select * into old from grillad_private.events where org=p_org and site=p_site and id=p_event;
 if found then if old.actor<>u or old.action<>'offline_batch' or old.payload<>payload then raise exception 'GRILLAD_REPLAY_CONFLICT' using errcode='22023';end if;return old.result;end if;
 if p_day<>(now() at time zone 'Africa/Douala')::date then raise exception 'GRILLAD_BATCH_DAY_CONFLICT' using errcode='22023';end if;
 if (select count(distinct x->>'event') from jsonb_array_elements(p_lines) x)<>jsonb_array_length(p_lines) then raise exception 'GRILLAD_BATCH_DUPLICATE' using errcode='22023';end if;
 for line in select * from jsonb_array_elements(p_lines) loop
  action_name:=line->>'operation';eid:=(line->>'event')::uuid;
  if eid is null or eid=p_event or action_name is null or action_name not in ('prepare','sell','sell_basket') or jsonb_typeof(line->'payload') is distinct from 'object' then raise exception 'GRILLAD_BATCH_ACTION' using errcode='22023';end if;
  if action_name<>'prepare' and (p_cash is null or not exists(select 1 from grillad_private.cash where org=p_org and site=p_site and id=p_cash and closed_at is null)) then raise exception 'GRILLAD_BATCH_CASH_CONFLICT' using errcode='22023';end if;
  if exists(select 1 from grillad_private.events where org=p_org and site=p_site and id=eid) then raise exception 'GRILLAD_BATCH_EVENT_ALREADY_USED' using errcode='22023';end if;
  v:=grillad_private.run(p_org,p_site,eid,action_name,line->'payload');results:=results||jsonb_build_array(v);
 end loop;
 v:=jsonb_build_object('id',p_event,'results',results,'count',jsonb_array_length(results));
 insert into grillad_private.events(org,site,id,actor,action,payload,result) values(p_org,p_site,p_event,u,'offline_batch',payload,v);return v;
end $fn$;
-- Partner onboarding is explicit; the central service attests both consents and never enables an invalid link.
create function grillad_private.partner_zipple(p_id uuid,p_org uuid,p_site uuid,p_zipple_org uuid,p_zipple_site uuid,p_hash text,p_expires timestamptz) returns boolean
language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if p_id is null or p_hash is null or p_hash!~'^[0-9a-f]{64}$' or p_expires is null or p_expires<=now() or p_expires>now()+interval '1 year' then raise exception 'GRILLAD_PARTNER_INPUT' using errcode='22023';end if;
 if not exists(select 1 from grillad_private.partner_approvals where kind='zipple' and org=p_org and site=p_site and partner_org=p_zipple_org and partner_site=p_zipple_site) then raise exception 'GRILLAD_PARTNER_PROOF' using errcode='42501';end if;
 insert into grillad_private.connect_links(id,org,site,zipple_org,zipple_site,token_hash,enabled,grillad_approved,zipple_approved,expires_at) values(p_id,p_org,p_site,p_zipple_org,p_zipple_site,p_hash,true,true,true,p_expires) on conflict(id) do nothing;
 if not exists(select 1 from grillad_private.connect_links where id=p_id and org=p_org and site=p_site and zipple_org=p_zipple_org and zipple_site=p_zipple_site and token_hash=p_hash and expires_at=p_expires) or not grillad_private.connect_active(p_id) then raise exception 'GRILLAD_PARTNER_UNAVAILABLE' using errcode='22023';end if;return true;
end $fn$;
-- Central approval evidence is tracked separately from partner state.
create table grillad_private.partner_approvals(
 kind text not null check(kind in ('zipple','security')), org uuid not null,site uuid not null,partner_org uuid not null,partner_site uuid not null,
 operator_id uuid not null references auth.users(id),grillad_evidence text not null check(grillad_evidence~'^[0-9a-f]{64}$'),
 partner_evidence text not null check(partner_evidence~'^[0-9a-f]{64}$'),created_at timestamptz not null default now(),
 primary key(kind,org,site,partner_org,partner_site),foreign key(org,site) references grillad_private.enabled_sites(org,site)
);
alter table grillad_private.partner_approvals enable row level security;
revoke all on grillad_private.partner_approvals from public,anon,authenticated;
create function grillad_private.partner_approval(p_kind text,p_org uuid,p_site uuid,p_partner_org uuid,p_partner_site uuid,p_operator uuid,p_grillad_proof text,p_partner_proof text) returns boolean
language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if p_kind not in ('zipple','security') or not exists(select 1 from auth.users where id=p_operator) or p_grillad_proof is null or p_grillad_proof!~'^[0-9a-f]{64}$' or p_partner_proof is null or p_partner_proof!~'^[0-9a-f]{64}$' or p_grillad_proof=p_partner_proof then raise exception 'GRILLAD_PARTNER_PROOF' using errcode='22023';end if;
 if not exists(select 1 from grillad_private.enabled_sites where org=p_org and site=p_site and enabled) then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 insert into grillad_private.partner_approvals(kind,org,site,partner_org,partner_site,operator_id,grillad_evidence,partner_evidence) values(p_kind,p_org,p_site,p_partner_org,p_partner_site,p_operator,p_grillad_proof,p_partner_proof) on conflict do nothing;
 if not exists(select 1 from grillad_private.partner_approvals where kind=p_kind and org=p_org and site=p_site and partner_org=p_partner_org and partner_site=p_partner_site and operator_id=p_operator and grillad_evidence=p_grillad_proof and partner_evidence=p_partner_proof) then raise exception 'GRILLAD_PARTNER_CONFLICT' using errcode='22023';end if;
 return true;
end $fn$;
-- No physical camera command or streaming URL. Explicit same-site mapping between the two independent schemas.
create table grillad_private.security_source_map(
 org uuid not null,site uuid not null,source_org uuid not null,source_site uuid not null,
 primary key(org,site),foreign key(org,site) references grillad_private.security_links(org,site)
);
alter table grillad_private.security_source_map enable row level security;
revoke all on grillad_private.security_source_map from public,anon,authenticated;
create function grillad_private.security_project(p_org uuid,p_site uuid,p_source_org uuid,p_source_site uuid) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare n bigint; m bigint;
begin
 if not exists(select 1 from grillad_private.partner_approvals where kind='security' and org=p_org and site=p_site and partner_org=p_source_org and partner_site=p_source_site) then raise exception 'GRILLAD_PARTNER_PROOF' using errcode='42501';end if;
 -- Explicit pre-approved family link; never infer equivalence from site names.
 if not exists(select 1 from grillad_private.security_links l join famille_core.applications a on a.code='naxa_security' and a.status='active' join famille_core.organization_apps o on o.organization_id=l.security_org and o.app_id=a.id and o.status='active' join famille_core.subscriptions b on b.organization_id=l.security_org and b.app_id=a.id and b.status='active' and b.ends_at>now() where l.org=p_org and l.site=p_site and l.enabled) then raise exception 'GRILLAD_SECURITY_LINK' using errcode='42501';end if;
 if not exists(select 1 from public.sec_sites s join public.sec_organizations o on o.id=s.organization_id and o.active where s.id=p_source_site and s.organization_id=p_source_org and s.active) then raise exception 'GRILLAD_SECURITY_SOURCE' using errcode='42501';end if;
 insert into grillad_private.security_source_map values(p_org,p_site,p_source_org,p_source_site) on conflict(org,site) do nothing;
 if not exists(select 1 from grillad_private.security_source_map where org=p_org and site=p_site and source_org=p_source_org and source_site=p_source_site) then raise exception 'GRILLAD_SECURITY_MAPPING' using errcode='22023';end if;
 -- Donor exposes observations, not an authoritative online/health field.
 insert into grillad_private.camera_inventory(org,site,camera,label,health,observed_at)
 select p_org,p_site,d.id,left(d.label,120),'unknown',d.observed_at from public.sec_devices d where d.organization_id=p_source_org and d.site_id=p_source_site and d.kind='camera' and d.observed_at is not null and length(btrim(d.label))>0
 on conflict(org,site,camera) do update set label=excluded.label,health='unknown',observed_at=excluded.observed_at where camera_inventory.observed_at<=excluded.observed_at;
 get diagnostics n=row_count;
 insert into grillad_private.security_incidents(org,site,id,camera,category,observed_at)
 select p_org,p_site,i.id,case when d.kind='camera' then d.id else null end,'other',i.occurred_at from public.sec_incidents i left join public.sec_devices d on d.id=i.device_id and d.organization_id=i.organization_id and d.site_id=i.site_id where i.organization_id=p_source_org and i.site_id=p_source_site and i.occurred_at is not null
 on conflict(org,site,id) do nothing;
 get diagnostics m=row_count;
 return jsonb_build_object('cameras',n,'incidents',m,'live_available',false);
end $fn$;
create function public.grillad_central_provision(p_event uuid,p_operator uuid,p_user uuid,p_phone text,p_org_name text,p_site_name text,p_plan text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.central_provision(p_event,p_operator,p_user,p_phone,p_org_name,p_site_name,p_plan)$fn$;
revoke all on function grillad_private.central_provision(uuid,uuid,uuid,text,text,text,text),public.grillad_central_provision(uuid,uuid,uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function grillad_private.central_provision(uuid,uuid,uuid,text,text,text,text),public.grillad_central_provision(uuid,uuid,uuid,text,text,text,text) to service_role;
create function public.grillad_central_employee(p_request uuid,p_operator uuid,p_user uuid,p_acceptance_hash text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.central_employee(p_request,p_operator,p_user,p_acceptance_hash)$fn$;
revoke all on function grillad_private.central_employee(uuid,uuid,uuid,text),public.grillad_central_employee(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function grillad_private.central_employee(uuid,uuid,uuid,text),public.grillad_central_employee(uuid,uuid,uuid,text) to service_role;
create function public.grillad_payment_prepare(p_request uuid,p_channel text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.payment_prepare(p_request,p_channel)$fn$;
revoke all on function grillad_private.payment_prepare(uuid,text),public.grillad_payment_prepare(uuid,text) from public,anon,authenticated;
grant execute on function grillad_private.payment_prepare(uuid,text),public.grillad_payment_prepare(uuid,text) to service_role;
create function public.grillad_payment_confirm(p_request uuid,p_operator uuid,p_reference text,p_amount bigint,p_occurred timestamptz,p_evidence_hash text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.payment_confirm(p_request,p_operator,p_reference,p_amount,p_occurred,p_evidence_hash)$fn$;
revoke all on function grillad_private.payment_confirm(uuid,uuid,text,bigint,timestamptz,text),public.grillad_payment_confirm(uuid,uuid,text,bigint,timestamptz,text) from public,anon,authenticated;
grant execute on function grillad_private.payment_confirm(uuid,uuid,text,bigint,timestamptz,text),public.grillad_payment_confirm(uuid,uuid,text,bigint,timestamptz,text) to service_role;
create function public.grillad_offline_batch(p_org uuid,p_site uuid,p_event uuid,p_day date,p_cash uuid,p_lines jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.offline_batch(p_org,p_site,p_event,p_day,p_cash,p_lines)$fn$;
revoke all on function grillad_private.offline_batch(uuid,uuid,uuid,date,uuid,jsonb),public.grillad_offline_batch(uuid,uuid,uuid,date,uuid,jsonb) from public,anon,authenticated;
grant execute on function grillad_private.offline_batch(uuid,uuid,uuid,date,uuid,jsonb),public.grillad_offline_batch(uuid,uuid,uuid,date,uuid,jsonb) to authenticated;
create function public.grillad_partner_zipple(p_id uuid,p_org uuid,p_site uuid,p_zipple_org uuid,p_zipple_site uuid,p_hash text,p_expires timestamptz) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.partner_zipple(p_id,p_org,p_site,p_zipple_org,p_zipple_site,p_hash,p_expires)$fn$;
revoke all on function grillad_private.partner_zipple(uuid,uuid,uuid,uuid,uuid,text,timestamptz),public.grillad_partner_zipple(uuid,uuid,uuid,uuid,uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function grillad_private.partner_zipple(uuid,uuid,uuid,uuid,uuid,text,timestamptz),public.grillad_partner_zipple(uuid,uuid,uuid,uuid,uuid,text,timestamptz) to service_role;
create function public.grillad_security_project(p_org uuid,p_site uuid,p_source_org uuid,p_source_site uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.security_project(p_org,p_site,p_source_org,p_source_site)$fn$;
revoke all on function grillad_private.security_project(uuid,uuid,uuid,uuid),public.grillad_security_project(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function grillad_private.security_project(uuid,uuid,uuid,uuid),public.grillad_security_project(uuid,uuid,uuid,uuid) to service_role;
create function public.grillad_employee_accept(p_request uuid,p_token text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.employee_accept(p_request,p_token)$fn$;
revoke all on function grillad_private.employee_accept(uuid,text),public.grillad_employee_accept(uuid,text) from public,anon,authenticated;
grant execute on function grillad_private.employee_accept(uuid,text),public.grillad_employee_accept(uuid,text) to authenticated;
create function public.grillad_partner_approval(p_kind text,p_org uuid,p_site uuid,p_partner_org uuid,p_partner_site uuid,p_operator uuid,p_grillad_proof text,p_partner_proof text) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.partner_approval(p_kind,p_org,p_site,p_partner_org,p_partner_site,p_operator,p_grillad_proof,p_partner_proof)$fn$;
revoke all on function grillad_private.partner_approval(text,uuid,uuid,uuid,uuid,uuid,text,text),public.grillad_partner_approval(text,uuid,uuid,uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function grillad_private.partner_approval(text,uuid,uuid,uuid,uuid,uuid,text,text),public.grillad_partner_approval(text,uuid,uuid,uuid,uuid,uuid,text,text) to service_role;
-- Owner can prepare a reference but cannot attest receipt or debit a wallet.
create function grillad_private.payment_quote(p_org uuid,p_site uuid,p_request uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare v jsonb;
begin
 begin
  if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 exception when insufficient_privilege then perform grillad_private.renewal_guard(p_org,p_site);
 end;
 if not exists(select 1 from grillad_private.central_requests where id=p_request and org=p_org and kind='renewal' and status='pending') then raise exception 'GRILLAD_REQUEST_DENIED' using errcode='42501';end if;
 v:=grillad_private.payment_prepare(p_request,p_channel);
 return v||jsonb_build_object('channel',p_channel,'currency','FCFA','provider_connected',false,'instruction','CENTRAL_VERIFICATION_REQUIRED');
end $fn$;
create function public.grillad_payment_quote(p_org uuid,p_site uuid,p_request uuid,p_channel text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.payment_quote(p_org,p_site,p_request,p_channel)$fn$;
revoke all on function grillad_private.payment_quote(uuid,uuid,uuid,text),public.grillad_payment_quote(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function grillad_private.payment_quote(uuid,uuid,uuid,text),public.grillad_payment_quote(uuid,uuid,uuid,text) to authenticated;
-- Explicit common-schema partner mapping; both source and family IDs must be approved.
create function grillad_private.security_bind(p_org uuid,p_site uuid,p_security_org uuid,p_security_site uuid,p_source_org uuid,p_source_site uuid) returns boolean
language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if not exists(select 1 from grillad_private.partner_approvals where kind='security' and org=p_org and site=p_site and partner_org=p_source_org and partner_site=p_source_site) or not exists(select 1 from grillad_private.partner_approvals where kind='security' and org=p_org and site=p_site and partner_org=p_security_org and partner_site=p_security_site) then raise exception 'GRILLAD_PARTNER_PROOF' using errcode='42501';end if;
 insert into grillad_private.security_links(org,site,security_org,security_site,enabled) values(p_org,p_site,p_security_org,p_security_site,true) on conflict(org,site) do nothing;
 if not exists(select 1 from grillad_private.security_links where org=p_org and site=p_site and security_org=p_security_org and security_site=p_security_site and enabled) then raise exception 'GRILLAD_SECURITY_MAPPING' using errcode='22023';end if;
 perform grillad_private.security_project(p_org,p_site,p_source_org,p_source_site);return true;
end $fn$;
create function public.grillad_security_bind(p_org uuid,p_site uuid,p_security_org uuid,p_security_site uuid,p_source_org uuid,p_source_site uuid) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.security_bind(p_org,p_site,p_security_org,p_security_site,p_source_org,p_source_site)$fn$;
revoke all on function grillad_private.security_bind(uuid,uuid,uuid,uuid,uuid,uuid),public.grillad_security_bind(uuid,uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function grillad_private.security_bind(uuid,uuid,uuid,uuid,uuid,uuid),public.grillad_security_bind(uuid,uuid,uuid,uuid,uuid,uuid) to service_role;
commit;
