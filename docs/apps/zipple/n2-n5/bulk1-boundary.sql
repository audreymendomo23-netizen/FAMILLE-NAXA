-- Bulk 1: harden existing boundaries, reuse N1 rate-window table and service-only RPC convention.
-- Public opening limit is technical abuse protection, not a commercial quota.
begin;
create function public.zp_guest_open_guard(p_qr_hash text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare sid uuid;allowed boolean;begin
 select x.id into sid from public.zp_table_sessions x join public.zp_tables t on t.id=x.table_id and t.org_id=x.org_id and t.site_id=x.site_id join public.zp_sites s on s.id=x.site_id and s.org_id=x.org_id join public.zp_organizations o on o.id=x.org_id where t.qr_hash=p_qr_hash and x.closed_at is null and s.active and o.active and public.zp_operational_plan(x.org_id) is not null;
 if sid is null then return false;end if;
 insert into public.zp_rate_windows as w(bucket,window_start,attempts) values('ZIPPLE:guest-open:'||sid::text,now(),1)
 on conflict(bucket) do update set window_start=case when w.window_start<=now()-interval '5 minutes' then now() else w.window_start end,
 attempts=case when w.window_start<=now()-interval '5 minutes' then 1 else least(w.attempts+1,1000000) end returning attempts<=60 into allowed;
 return allowed;end $$;
revoke all on function public.zp_guest_open_guard(text) from public,anon,authenticated;
grant execute on function public.zp_guest_open_guard(text) to service_role;
-- Existing cancellation must not restore availability after a guest has attested service.
create or replace function public.zp_cancel_unprepared_order(p_access text,p_site uuid,p_order uuid,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') or length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;if o.id is null then raise exception 'DENIED';end if;
 if o.status='cancelled' then return false;end if;
 if o.status<>'received' or o.guest_served_at is not null or exists(select 1 from public.zp_cash_receipts where order_id=p_order) then raise exception 'CANCELLATION_REQUIRES_REVIEW';end if;
 update public.zp_menu_items i set available_qty=i.available_qty+l.qty from public.zp_order_lines l where l.order_id=p_order and l.item_id=i.id and i.org_id=m.org_id and i.site_id=p_site;
 update public.zp_orders set status='cancelled' where id=p_order;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'cancel',jsonb_build_object('reason',trim(p_reason)));return true;end $$;
revoke all on function public.zp_cancel_unprepared_order(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.zp_cancel_unprepared_order(text,uuid,uuid,text) to service_role;
commit;
