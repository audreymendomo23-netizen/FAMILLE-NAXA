-- Read-only scoped recorded metrics. No external AI calls, no autonomous mutations.
begin;
create function public.zp_pilotage(p_access text,p_site uuid,p_start date,p_end date) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;today date:=(now() at time zone 'Africa/Douala')::date;lo timestamptz;hi timestamptz;revenue bigint;cost bigint;unknown_count bigint;receipt_count bigint;history jsonb;first_day date;expense bigint;low_count bigint;late_count bigint;feedback_count bigint;feedback_avg numeric;variance bigint;post_metrics jsonb;begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_start is null or p_end is null or p_start>p_end or p_end>today or p_end-p_start>365 then raise exception 'INVALID_PERIOD';end if;
 lo:=p_start::timestamp at time zone 'Africa/Douala';hi:=(p_end+1)::timestamp at time zone 'Africa/Douala';
 select coalesce(sum(r.amount_xaf),0),count(*) into revenue,receipt_count from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;
 select count(*) into unknown_count from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi and exists(select 1 from public.zp_order_lines l left join public.zp_sale_costs c on c.receipt_id=r.id and c.item_id=l.item_id where l.order_id=r.order_id and c.cost_xaf is null);
 if receipt_count>0 and unknown_count=0 then select coalesce(sum(c.cost_xaf),0) into cost from public.zp_sale_costs c join public.zp_cash_receipts r on r.id=c.receipt_id where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;end if;
 select coalesce(sum(amount_xaf),0) into expense from public.zp_expenses where org_id=m.org_id and site_id=p_site and expense_date between p_start and p_end;
 select count(*) into low_count from public.zp_ingredients i where i.org_id=m.org_id and i.site_id=p_site and i.reorder_milli>=coalesce((select sum(l.remaining_milli) from public.zp_ingredient_lots l where l.ingredient_id=i.id and (l.expires_on is null or l.expires_on>=today)),0);
 select count(*) into late_count from public.zp_orders o where o.org_id=m.org_id and o.site_id=p_site and o.status not in ('served','cancelled') and o.guest_served_at is null and o.promised_at<now();
 select count(*),round(avg(rating),2) into feedback_count,feedback_avg from public.zp_feedback where org_id=m.org_id and site_id=p_site and created_at>=lo and created_at<hi;
 select coalesce(sum(abs(counted_xaf-expected_xaf)),0) into variance from public.zp_cash_sessions where org_id=m.org_id and site_id=p_site and closed_at>=lo and closed_at<hi;
 select min((created_at at time zone 'Africa/Douala')::date) into first_day from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site;
 select coalesce(jsonb_agg(jsonb_build_object('day',x.receipt_day,'recorded_xaf',x.amount) order by x.receipt_day),'[]'::jsonb) into history from (select (created_at at time zone 'Africa/Douala')::date as receipt_day,sum(amount_xaf) as amount from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site and created_at>=((today-28)::timestamp at time zone 'Africa/Douala') and created_at<(today::timestamp at time zone 'Africa/Douala') group by 1)x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.post),'[]'::jsonb) into post_metrics from (select l.post,sum(l.qty) portions,sum(l.qty::bigint*l.unit_xaf) recorded_xaf from public.zp_cash_receipts r join public.zp_order_lines l on l.order_id=r.order_id where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi group by l.post)x;
 return jsonb_build_object('start',p_start,'end',p_end,'as_of',now(),'today',today,'first_recorded_sale_day',first_day,'recorded_xaf',revenue,'receipts',receipt_count,'uncosted_receipts',unknown_count,'known_cost_xaf',cost,'gross_margin_xaf',case when cost is not null then revenue-cost else null end,'expenses_xaf',expense,'current_low_stock',low_count,'current_late_orders',late_count,'feedback_count',feedback_count,'feedback_average',feedback_avg,'absolute_cash_variance_xaf',variance,'history_28',history,'posts',post_metrics);
end $$;
revoke all on function public.zp_pilotage(text,uuid,date,date) from public,anon,authenticated;
grant execute on function public.zp_pilotage(text,uuid,date,date) to service_role;
commit;
