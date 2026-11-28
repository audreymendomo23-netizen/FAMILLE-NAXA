begin;
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
 insert into famille_core.payment_intents(subscription_id,expected_amount_fcfa,channel,expires_at) values(sub,amount,p_channel,now()+interval '2 days') returning * into intent;
 i:=intent.id;
 insert into grillad_private.renewal_payment_links(request_id,intent_id) values(q.id,i);
 return jsonb_build_object('intent',i,'amount',amount,'channel',intent.channel,'status','pending','expires_at',intent.expires_at);
end $fn$;
create or replace function grillad_private.payment_quote(p_org uuid,p_site uuid,p_request uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare v jsonb;
begin
 begin
  if grillad_private.scope(p_org,p_site)<>'owner' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 exception when insufficient_privilege then perform grillad_private.renewal_guard(p_org,p_site);
 end;
 if not exists(select 1 from grillad_private.central_requests where id=p_request and org=p_org and kind='renewal' and status='pending') then raise exception 'GRILLAD_REQUEST_DENIED' using errcode='42501';end if;
 v:=grillad_private.payment_prepare(p_request,p_channel);
 return v||jsonb_build_object('currency','FCFA','provider_connected',false,'instruction','CENTRAL_VERIFICATION_REQUIRED');
end $fn$;
commit;
