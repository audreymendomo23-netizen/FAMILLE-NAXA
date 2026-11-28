begin;
-- Replace an expired unpaid intent only after central review. Preserve the old intent and its evidence.
create table grillad_private.payment_reissues(
 event_id uuid primary key, request_id uuid not null references grillad_private.central_requests(id),
 previous_intent uuid not null unique references famille_core.payment_intents(id),
 next_intent uuid not null unique references famille_core.payment_intents(id),
 operator_id uuid not null references auth.users(id),proof_hash text not null check(proof_hash~'^[0-9a-f]{64}$'),created_at timestamptz not null default now()
);
alter table grillad_private.payment_reissues enable row level security;
revoke all on grillad_private.payment_reissues from public,anon,authenticated;
create function grillad_private.payment_reissue(p_event uuid,p_request uuid,p_operator uuid,p_channel text,p_proof text) returns jsonb
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
 insert into famille_core.payment_intents(subscription_id,expected_amount_fcfa,channel,expires_at) values(i.subscription_id,i.expected_amount_fcfa,p_channel,now()+interval '2 days') returning id into n;
 update grillad_private.renewal_payment_links set intent_id=n where request_id=q.id;
 insert into grillad_private.payment_reissues(event_id,request_id,previous_intent,next_intent,operator_id,proof_hash) values(p_event,q.id,i.id,n,p_operator,p_proof);
 return jsonb_build_object('intent',n,'previous',i.id,'status','reissued');
end $fn$;
-- Rotate a pending/expired invite, never an accepted invite. Verify the same phone at acceptance.
create function grillad_private.invite_rotate(p_request uuid,p_operator uuid,p_new_hash text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_private.account_invites%rowtype;
begin
 if p_new_hash is null or p_new_hash!~'^[0-9a-f]{64}$' or not exists(select 1 from auth.users where id=p_operator) then raise exception 'GRILLAD_INVITE_INPUT' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='employee' and status='pending' for update;
 if not found then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end if;
 select * into i from famille_private.account_invites where request_id=q.id and app_code='grillad' for update;
 if not found or i.status not in ('pending','expired') then raise exception 'GRILLAD_INVITE_DENIED' using errcode='42501';end if;
 if i.token_hash=decode(p_new_hash,'hex') then
  if i.expires_at<=now() then raise exception 'GRILLAD_INVITE_EXPIRED' using errcode='22023';end if;
  return jsonb_build_object('invite',i.id,'expires_at',i.expires_at);
 end if;
 update famille_private.account_invites set token_hash=decode(p_new_hash,'hex'),status='pending',expires_at=now()+interval '1 day' where id=i.id returning * into i;
 insert into famille_private.account_audit_log(actor_id,subject_user_id,app_code,event_code,outcome) values(p_operator,i.user_id,'grillad','invite.rotated','success');
 return jsonb_build_object('invite',i.id,'expires_at',i.expires_at);
end $fn$;
-- Bounded round-robin projection with failure isolation; no live video claims.
create table grillad_private.security_projection_runs(
 org uuid not null,site uuid not null,attempted_at timestamptz not null default now(),succeeded boolean not null,
 primary key(org,site),foreign key(org,site) references grillad_private.security_source_map(org,site)
);
alter table grillad_private.security_projection_runs enable row level security;
revoke all on grillad_private.security_projection_runs from public,anon,authenticated;
create function grillad_private.security_tick(p_limit integer) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare x record;good int:=0;bad int:=0;
begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception 'GRILLAD_LIMIT' using errcode='22023';end if;
 if not pg_try_advisory_xact_lock(hashtextextended('grillad-security-tick',0)) then return jsonb_build_object('processed',0,'failed',0,'busy',true);end if;
 for x in select m.* from grillad_private.security_source_map m join grillad_private.security_links l on l.org=m.org and l.site=m.site and l.enabled left join grillad_private.security_projection_runs r on r.org=m.org and r.site=m.site order by r.attempted_at nulls first,m.org,m.site limit p_limit loop
  begin
   perform grillad_private.security_project(x.org,x.site,x.source_org,x.source_site);
   delete from grillad_private.camera_inventory c where c.org=x.org and c.site=x.site and not exists(select 1 from public.sec_devices d where d.id=c.camera and d.organization_id=x.source_org and d.site_id=x.source_site and d.kind='camera');
   insert into grillad_private.security_projection_runs values(x.org,x.site,now(),true) on conflict(org,site) do update set attempted_at=excluded.attempted_at,succeeded=true;good:=good+1;
  exception when others then
   insert into grillad_private.security_projection_runs values(x.org,x.site,now(),false) on conflict(org,site) do update set attempted_at=excluded.attempted_at,succeeded=false;bad:=bad+1;
  end;
 end loop;
 return jsonb_build_object('processed',good,'failed',bad,'busy',false);
end $fn$;
create function public.grillad_payment_reissue(p_event uuid,p_request uuid,p_operator uuid,p_channel text,p_proof text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.payment_reissue(p_event,p_request,p_operator,p_channel,p_proof)$fn$;
revoke all on function grillad_private.payment_reissue(uuid,uuid,uuid,text,text),public.grillad_payment_reissue(uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function grillad_private.payment_reissue(uuid,uuid,uuid,text,text),public.grillad_payment_reissue(uuid,uuid,uuid,text,text) to service_role;
create function public.grillad_invite_rotate(p_request uuid,p_operator uuid,p_new_hash text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.invite_rotate(p_request,p_operator,p_new_hash)$fn$;
revoke all on function grillad_private.invite_rotate(uuid,uuid,text),public.grillad_invite_rotate(uuid,uuid,text) from public,anon,authenticated;
grant execute on function grillad_private.invite_rotate(uuid,uuid,text),public.grillad_invite_rotate(uuid,uuid,text) to service_role;
create function public.grillad_security_tick(p_limit integer) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.security_tick(p_limit)$fn$;
revoke all on function grillad_private.security_tick(integer),public.grillad_security_tick(integer) from public,anon,authenticated;
grant execute on function grillad_private.security_tick(integer),public.grillad_security_tick(integer) to service_role;
create or replace function grillad_private.security_list(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;linked boolean;multi boolean;mapping grillad_private.security_source_map%rowtype;cams jsonb;incidents jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 select exists(select 1 from famille_core.memberships m join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id and ra.organization_id=m.organization_id where m.organization_id=p_org and m.app_id=famille_core.current_app_id() and m.status='active' and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now()) and ra.role_code in ('manager','seller') and ra.location_id=p_site) or (select count(*) from grillad_private.enabled_sites where org=p_org and enabled)>1 into multi;
 if not multi then return jsonb_build_object('available',false,'reason','MULTILEVEL_REQUIRED','cameras','[]'::jsonb,'incidents','[]'::jsonb);end if;
 select exists(select 1 from grillad_private.security_links l join famille_core.applications a on a.code='naxa_security' and a.status='active' join famille_core.organization_apps o on o.organization_id=l.security_org and o.app_id=a.id and o.status='active' join famille_core.locations s on s.id=l.security_site and s.organization_id=l.security_org and s.status='active' where l.org=p_org and l.site=p_site and l.enabled and exists(select 1 from famille_core.subscriptions b where b.organization_id=l.security_org and b.app_id=a.id and b.status='active' and (b.starts_at is null or b.starts_at<=now()) and b.ends_at>now())) into linked;
 if not linked then return jsonb_build_object('available',false,'reason','PARTNER_NOT_LINKED','cameras','[]'::jsonb,'incidents','[]'::jsonb);end if;
 select * into mapping from grillad_private.security_source_map where org=p_org and site=p_site;
 if not found then return jsonb_build_object('available',false,'reason','SOURCE_NOT_MAPPED','cameras','[]'::jsonb,'incidents','[]'::jsonb);end if;
 if not exists(select 1 from public.sec_sites s join public.sec_organizations o on o.id=s.organization_id and o.active where s.id=mapping.source_site and s.organization_id=mapping.source_org and s.active) then return jsonb_build_object('available',false,'reason','SOURCE_INACTIVE','cameras','[]'::jsonb,'incidents','[]'::jsonb);end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',camera,'name',label,'status',case when observed_at<now()-interval '2 minutes' then 'unknown' else health end,'observed_at',observed_at) order by label),'[]'::jsonb) into cams from grillad_private.camera_inventory c where org=p_org and site=p_site and exists(select 1 from public.sec_devices d where d.id=c.camera and d.organization_id=mapping.source_org and d.site_id=mapping.source_site and d.kind='camera');
 select coalesce(jsonb_agg(to_jsonb(x) order by x.observed_at desc),'[]'::jsonb) into incidents from (select id,camera,category,observed_at from grillad_private.security_incidents where org=p_org and site=p_site order by observed_at desc limit 50)x;
 return jsonb_build_object('available',true,'live_available',false,'reason','VIDEO_GATEWAY_NOT_QUALIFIED','cameras',cams,'incidents',incidents);
end $$;
commit;
