-- Commercial scope fixed by approved specification: one organization timeline, Essentiel one site.
-- This endpoint informs entitlements; it does not disable local protective devices on expiry.
begin;
create function sec_private.billing_status(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $f$
declare r text;current_plan public.sec_subscriptions%rowtype;next_plan public.sec_subscriptions%rowtype;last_end timestamptz;status text;covered boolean;history jsonb;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 select * into current_plan from public.sec_subscriptions where organization_id=p_org and starts_at<=now() and ends_at>now() order by starts_at desc limit 1;
 select * into next_plan from public.sec_subscriptions where organization_id=p_org and starts_at>now() order by starts_at limit 1;
 select max(ends_at) into last_end from public.sec_subscriptions where organization_id=p_org;
 covered:=current_plan.id is not null and (current_plan.plan<>'Essentiel' or current_plan.site_id=p_site);
 status:=case when current_plan.id is not null then case when covered then 'active' else 'site_not_covered' end when last_end is null then 'not_subscribed' when last_end<=now() then 'expired' else 'scheduled' end;
 if r in ('owner','manager') then
 select coalesce(jsonb_agg(to_jsonb(h) order by h.starts_at desc),'[]'::jsonb) into history from (
  select s.id,s.plan,s.period,s.starts_at,s.ends_at,p.amount_fcfa,p.provider_confirmed_at from public.sec_subscriptions s join public.sec_payment_receipts p on p.id=s.receipt_id and p.organization_id=s.organization_id and p.site_id=s.site_id where s.organization_id=p_org order by s.starts_at desc limit 100) h;
 else history:='[]'::jsonb;end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'status',status,'covered',covered,
 'current_plan',current_plan.plan,'current_ends_at',current_plan.ends_at,'next_plan',next_plan.plan,'next_starts_at',next_plan.starts_at,
 'erp_entitled',covered and current_plan.plan='Professional','multisite_entitled',covered and current_plan.plan in ('Business','Professional'),
 'history',history,'can_allocate',r='owner','local_protection_unchanged',true,'quotas_defined',false);
end $f$;
revoke all on function sec_private.billing_status(uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.billing_status(uuid,uuid) to authenticated;
create function public.sec_billing_status(p_org uuid,p_site uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.billing_status(p_org,p_site)$r$;
revoke all on function public.sec_billing_status(uuid,uuid) from public,anon;
grant execute on function public.sec_billing_status(uuid,uuid) to authenticated;
commit;
