-- Diagnostic lifecycle only: no remote physical action. Correlation preserves source alarms.
begin;
create table public.sec_diagnostic_requests(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,device_id uuid not null,
 requester_id uuid not null references auth.users(id),reviewer_id uuid references auth.users(id),
 reason text not null check(length(trim(reason)) between 1 and 500),
 state text not null default 'requested' check(state in ('requested','authorized','completed','expired')),
 created_at timestamptz not null default now(),expires_at timestamptz not null,
 authorized_at timestamptz,completed_at timestamptz,observation_id uuid references public.sec_device_observations(id),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 check(reviewer_id is null or reviewer_id<>requester_id),
 check(expires_at>created_at and expires_at<=created_at+interval '5 minutes')
);
alter table public.sec_diagnostic_requests enable row level security;
revoke all on public.sec_diagnostic_requests from public,anon,authenticated,sec_gateway_ingest;
grant select on public.sec_diagnostic_requests to authenticated;
create policy sec_diag_read on public.sec_diagnostic_requests for select to authenticated using(sec_private.field_role(organization_id,site_id) in ('owner','manager') or (requester_id=auth.uid() and sec_private.field_role(organization_id,site_id)='operator'));
create function sec_private.request_diagnostic(p_org uuid,p_site uuid,p_id uuid,p_device uuid,p_reason text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $fn$
declare d public.sec_diagnostic_requests%rowtype;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 if p_id is null or p_reason is null or length(trim(p_reason)) not between 1 and 500 or p_reason ~ '[[:cntrl:]]' then raise exception 'invalid diagnostic' using errcode='22023';end if;
 if not exists(select 1 from public.sec_devices where organization_id=p_org and site_id=p_site and id=p_device) then raise exception 'device denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,6));
 select * into d from public.sec_diagnostic_requests where id=p_id;
 if found then
  if d.organization_id<>p_org or d.site_id<>p_site or d.device_id<>p_device or d.requester_id<>auth.uid() or d.reason<>trim(p_reason) then raise exception 'id conflict' using errcode='23505';end if;
 else insert into public.sec_diagnostic_requests(id,organization_id,site_id,device_id,requester_id,reason,expires_at) values(p_id,p_org,p_site,p_device,auth.uid(),trim(p_reason),now()+interval '5 minutes') returning * into d;end if;
 return to_jsonb(d)||jsonb_build_object('physical_action',false);
end $fn$;
create function sec_private.authorize_diagnostic(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $fn$
declare d public.sec_diagnostic_requests%rowtype;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'denied' using errcode='42501';end if;
 select * into d from public.sec_diagnostic_requests where id=p_id and organization_id=p_org and site_id=p_site for update;
 if not found or d.requester_id=auth.uid() then raise exception 'review denied' using errcode='42501';end if;
 if d.expires_at<=now() then raise exception 'expired' using errcode='22023';end if;
 if d.state='requested' then update public.sec_diagnostic_requests set state='authorized',reviewer_id=auth.uid(),authorized_at=now() where id=p_id returning * into d;
 elsif d.state<>'authorized' or d.reviewer_id<>auth.uid() then raise exception 'already decided' using errcode='23505';end if;
 return to_jsonb(d)||jsonb_build_object('physical_action',false);
end $fn$;
-- Trusted transport may only complete using a real observation already ingested for this device.
create function sec_private.complete_diagnostic(p_gateway uuid,p_org uuid,p_site uuid,p_id uuid,p_event uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $fn$
declare d public.sec_diagnostic_requests%rowtype; obs public.sec_device_observations%rowtype;
begin
 select * into d from public.sec_diagnostic_requests where id=p_id and organization_id=p_org and site_id=p_site for update;
 if not found or d.state not in ('authorized','completed') or d.expires_at<=now() then raise exception 'diagnostic denied' using errcode='42501';end if;
 if not exists(select 1 from sec_private.gateway_bindings where gateway_id=p_gateway and organization_id=p_org and site_id=p_site and device_id=d.device_id and enabled) then raise exception 'gateway denied' using errcode='42501';end if;
 if not exists(select 1 from public.sec_memberships m join public.sec_site_memberships sm using(organization_id,user_id) join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id where m.organization_id=p_org and sm.site_id=p_site and m.user_id=d.requester_id and m.active and sm.active and s.active and o.active and m.role in ('owner','manager','operator')) then raise exception 'requester revoked' using errcode='42501';end if;
 select o.* into obs from public.sec_device_observations o join sec_private.gateway_receipts g on g.event_id=o.source_event_id and g.gateway_id=p_gateway and g.organization_id=o.organization_id and g.site_id=o.site_id and g.device_id=o.device_id where o.source_event_id=p_event and o.organization_id=p_org and o.site_id=p_site and o.device_id=d.device_id and o.observed_at>=d.authorized_at and o.observed_at<=now() and o.observed_at>=now()-interval '120 seconds';
 if not found then raise exception 'observation denied' using errcode='42501';end if;
 if d.state='completed' then if d.observation_id<>obs.id then raise exception 'receipt conflict' using errcode='23505';end if;
 else update public.sec_diagnostic_requests set state='completed',observation_id=obs.id,completed_at=now() where id=p_id returning * into d;end if;
 return to_jsonb(d)||jsonb_build_object('physical_action',false,'observed_status',obs.status);
end $fn$;
revoke all on function sec_private.complete_diagnostic(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.complete_diagnostic(uuid,uuid,uuid,uuid,uuid) to sec_gateway_ingest;
revoke all on function sec_private.request_diagnostic(uuid,uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function sec_private.request_diagnostic(uuid,uuid,uuid,uuid,text) to authenticated;
create function public.sec_request_diagnostic(p_org uuid,p_site uuid,p_id uuid,p_device uuid,p_reason text) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.request_diagnostic(p_org,p_site,p_id,p_device,p_reason)$rpc$;
revoke all on function public.sec_request_diagnostic(uuid,uuid,uuid,uuid,text) from public,anon;
grant execute on function public.sec_request_diagnostic(uuid,uuid,uuid,uuid,text) to authenticated;
revoke all on function sec_private.authorize_diagnostic(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.authorize_diagnostic(uuid,uuid,uuid) to authenticated;
create function public.sec_authorize_diagnostic(p_org uuid,p_site uuid,p_id uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.authorize_diagnostic(p_org,p_site,p_id)$rpc$;
revoke all on function public.sec_authorize_diagnostic(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_authorize_diagnostic(uuid,uuid,uuid) to authenticated;
-- Temporal association, not a causal or AI-certified determination. Keep every fire source signal visible.
create view public.sec_signal_correlations with(security_invoker=true) as
 select f.id,f.organization_id,f.site_id,f.device_id,f.observed_at,f.source_state,
 count(a.id)::integer as nearby_warnings,
 count(distinct a.device_id)::integer as nearby_devices,
 case when count(a.id)>0 then 'temporal_association' else 'source_only' end as association,
 true as human_review_required
 from public.sec_fire_events f left join public.sec_observation_alerts a on a.organization_id=f.organization_id and a.site_id=f.site_id and a.observed_at between f.observed_at-interval '2 minutes' and f.observed_at+interval '2 minutes'
 group by f.id,f.organization_id,f.site_id,f.device_id,f.observed_at,f.source_state;
revoke all on public.sec_signal_correlations from public,anon,authenticated;
grant select on public.sec_signal_correlations to authenticated;
commit;
