-- DRAFT: explicit promoter reconciliation, single service sale, no external payment.
begin;
create table public.ns_commission_settlements (
 org_id uuid not null references public.ns_organizations(id),
 site_id uuid not null,
 appointment_id uuid not null unique references public.ns_appointments(id),
 sale_id uuid not null unique references public.ns_sales(id),
 entry_id uuid not null unique references public.ns_commission_entries(id),
 created_by uuid not null,
 created_at timestamptz not null default now(),
 primary key(org_id,appointment_id),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(created_by,org_id) references public.ns_members(id,org_id)
);
alter table public.ns_commission_settlements enable row level security;
revoke all on public.ns_commission_settlements from public,anon,authenticated;
grant select,insert on public.ns_commission_settlements to service_role;
-- Same organization lock as v24; amounts and assigned executor derived server-side.
create function public.ns_prepare_settled_commission(p_org uuid,p_site uuid,p_appointment uuid,p_sale uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare a public.ns_appointments%rowtype; s public.ns_sales%rowtype;
 actor uuid; profile text; completion_day date; paid numeric; n integer; policy public.ns_commission_policy_versions%rowtype;
 receipt public.ns_commission_settlements%rowtype; eid uuid; commission bigint;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN'; end if;
 select activity_profile into profile from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN'; end if;
 select * into receipt from public.ns_commission_settlements where appointment_id=p_appointment or sale_id=p_sale;
 if found then
  if receipt.org_id<>p_org or receipt.site_id<>p_site or receipt.appointment_id<>p_appointment or receipt.sale_id<>p_sale then raise exception 'NS_COMMISSION_SETTLEMENT_CONFLICT'; end if;
  return jsonb_build_object('status','existing','entry_id',receipt.entry_id);
 end if;
 if not exists(select 1 from public.ns_automatic_commission_settings where org_id=p_org and enabled) then return jsonb_build_object('status','disabled'); end if;
 select * into a from public.ns_appointments where id=p_appointment and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_SCOPE'; end if;
 select * into s from public.ns_sales where id=p_sale and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_SCOPE'; end if;
 if a.status<>'completed' or s.status<>'posted' then return jsonb_build_object('status','awaiting_completed_and_confirmed'); end if;
 if a.customer_id is null or a.customer_id is distinct from s.customer_id or a.service_id is null or a.assigned_member_id is null
 or not exists(select 1 from public.ns_services where id=a.service_id and org_id=p_org and (site_id is null or site_id=p_site))
 or not exists(select 1 from public.ns_members where id=a.assigned_member_id and org_id=p_org and status='active')
 then raise exception 'NS_COMMISSION_SETTLEMENT_SCOPE'; end if;
 select (max(occurred_at) at time zone 'Africa/Douala')::date into completion_day from public.ns_appointment_status_events where appointment_id=a.id and org_id=p_org and site_id=p_site and to_status='completed';
 if completion_day is null then raise exception 'NS_COMMISSION_COMPLETION_PROOF_REQUIRED'; end if;
 perform 1 from public.ns_sale_lines where sale_id=s.id and org_id=p_org and site_id=p_site for update;
 select count(*) into n from public.ns_sale_lines where sale_id=s.id;
 if n<>1 or not exists(select 1 from public.ns_sale_lines where sale_id=s.id and org_id=p_org and site_id=p_site and item_type='service' and quantity=1 and unit_price_xaf-discount_xaf=s.total_xaf)
 then return jsonb_build_object('status','unsupported_sale_allocation'); end if;
 perform 1 from public.ns_payments where sale_id=s.id for update;
 if exists(select 1 from public.ns_payments where sale_id=s.id and (org_id<>p_org or site_id<>p_site or status in ('refunded','reversed'))) then return jsonb_build_object('status','refund_review_required'); end if;
 select coalesce(sum(amount_xaf),0) into paid from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status='confirmed' and confirmed_at is not null;
 if paid<>s.total_xaf or paid<=0 then return jsonb_build_object('status','awaiting_completed_and_confirmed'); end if;
 select count(*) into n from public.ns_commission_policy_versions p where p.org_id=p_org and p.automatic_scope and p.status='approved' and (p.site_id is null or p.site_id=p_site) and (p.member_id is null or p.member_id=a.assigned_member_id) and (p.service_id is null or p.service_id=a.service_id) and (p.activity_profile is null or p.activity_profile=profile) and completion_day>=p.effective_from and (p.effective_until is null or completion_day<=p.effective_until);
 if n=0 then return jsonb_build_object('status','no_applicable_policy'); end if;
 if n<>1 then return jsonb_build_object('status','blocked_ambiguous_policy'); end if;
 select * into policy from public.ns_commission_policy_versions p where p.org_id=p_org and p.automatic_scope and p.status='approved' and (p.site_id is null or p.site_id=p_site) and (p.member_id is null or p.member_id=a.assigned_member_id) and (p.service_id is null or p.service_id=a.service_id) and (p.activity_profile is null or p.activity_profile=profile) and completion_day>=p.effective_from and (p.effective_until is null or completion_day<=p.effective_until);
 if exists(select 1 from public.ns_commission_entries where sale_id=s.id or appointment_id=a.id) then raise exception 'NS_COMMISSION_EXISTING_LEDGER_REVIEW'; end if;
 commission:=case when policy.method='percent_bps' then trunc(paid*policy.rate_bps/10000)::bigint else policy.fixed_amount_xaf end;
 if commission=0 then return jsonb_build_object('status','no_commission'); end if;
 eid:=gen_random_uuid();
 insert into public.ns_commission_entries(id,org_id,site_id,member_id,sale_id,appointment_id,base_amount_xaf,commission_xaf,status,policy_version_id,source_event_id,idempotency_key,calculation_snapshot)
 values(eid,p_org,p_site,a.assigned_member_id,s.id,a.id,paid::bigint,commission,'pending_approval',policy.id,a.id,eid,jsonb_build_object('source','explicit_single_service_reconciliation','completion_day',completion_day,'policy_version',policy.version,'confirmed_paid_xaf',paid));
 insert into public.ns_commission_settlements(org_id,site_id,appointment_id,sale_id,entry_id,created_by) values(p_org,p_site,a.id,s.id,eid,actor);
 return jsonb_build_object('status','pending_approval','entry_id',eid,'commission_xaf',commission);
end $fn$;
revoke all on function public.ns_prepare_settled_commission(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_prepare_settled_commission(uuid,uuid,uuid,uuid) to authenticated;
rollback;
