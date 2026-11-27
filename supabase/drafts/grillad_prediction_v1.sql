-- Deterministic forecast of observed sales, not a guarantee of demand. Candidate only.
begin;
create function grillad_private.prediction(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;out jsonb;total bigint;known int;active_count int;today date:=(now() at time zone 'Africa/Douala')::date; family_totals jsonb; service_start timestamptz; service_end timestamptz; service_day date; current_ca bigint; projection bigint; elapsed numeric; baseline_days int; partial boolean;
begin
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 with services as (
 select distinct on(service_day) service_day,starts_at,ends_at from grillad_private.daily_summary
 where org=p_org and site=p_site and service_day<today and service_day>=today-14 order by service_day desc,version desc
 ), observations as (
 select i.id,i.name,i.family,i.price,i.prepared-i.sold-i.connect_reserved remaining,d.service_day,
 coalesce(s.qty,0) sold,greatest(0,coalesce(p.qty,0)+coalesce(adj.qty,0)) prepared
 from grillad_private.items i cross join services d
 left join lateral(select sum(qty) qty from grillad_private.sales where org=p_org and site=p_site and item=i.id and cancelled_at is null and created_at>=d.starts_at and created_at<d.ends_at)s on true
 left join lateral(select sum(qty) qty from grillad_private.preparations where org=p_org and site=p_site and item=i.id and created_at>=d.starts_at and created_at<d.ends_at)p on true
 left join lateral(select sum(delta) qty from grillad_private.stock_adjustments where org=p_org and site=p_site and item=i.id and created_at>=d.starts_at and created_at<d.ends_at)adj on true
 where i.org=p_org and i.site=p_site and i.active
 ), estimates as (
 select id,count(*) filter(where prepared>0 or sold>0) observed,
 count(*) filter(where prepared>0 and sold>=prepared) possible_shortages,
 ceil(avg(sold) filter(where prepared>0 or sold>0))::bigint estimate
 from observations group by id
 ), details as (
 select i.id item,i.name,i.family,i.price,i.prepared-i.sold-i.connect_reserved remaining,coalesce(e.observed,0) days,coalesce(e.possible_shortages,0) possible_shortages,
 case when e.observed>=3 then e.estimate else null end quantity
 from grillad_private.items i left join estimates e on e.id=i.id where i.org=p_org and i.site=p_site and i.active
 )
 select coalesce(jsonb_agg(jsonb_build_object('item',item,'name',name,'family',family,'quantity',quantity,'observed_days',days,'possible_shortages',possible_shortages,'remaining',remaining,'ca_estimate',quantity*price,
 'additional_preparation',case when quantity is null then null else greatest(quantity-remaining,0) end,'quality',case when quantity is null then 'insufficient' when possible_shortages>0 then 'limited_stock' else 'indicative' end) order by family,name),'[]'::jsonb),
 sum(quantity*price),count(quantity),count(*) into out,total,known,active_count from details;
 select coalesce(jsonb_agg(jsonb_build_object('family',q.family,'estimated_quantity',case when q.known=q.total then q.qty else null end,'ca_estimate',case when q.known=q.total then q.ca else null end,'known_items',q.known,'active_items',q.total) order by q.family),'[]'::jsonb) into family_totals from (select x->>'family' family,count(*) total,count(x->>'quantity') known,sum((x->>'quantity')::bigint) qty,sum((x->>'ca_estimate')::bigint) ca from jsonb_array_elements(out)x group by x->>'family')q;
 select count(*) into baseline_days from (select distinct on(service_day) service_day,data from grillad_private.daily_summary where org=p_org and site=p_site and service_day<today and service_day>=today-14 order by service_day desc,version desc) q where not coalesce((q.data->>'provisional')::boolean,true) and (q.data->>'sales_count')::bigint>0;
 select q.d,q.lo,q.hi into service_day,service_start,service_end from (select d::date d,grillad_private.service_boundary(p_org,p_site,d::date) lo,grillad_private.service_boundary(p_org,p_site,d::date+1) hi from generate_series(today-1,today,interval '1 day')d)q where now()>=q.lo and now()<q.hi limit 1;
 if service_start is not null then
  select coalesce(sum(total),0) into current_ca from grillad_private.sales where org=p_org and site=p_site and cancelled_at is null and created_at>=service_start and created_at<=now();
  elapsed:=extract(epoch from now()-service_start)/nullif(extract(epoch from service_end-service_start),0);
  partial:=baseline_days<3 or elapsed<0.25 or current_ca=0;
  if not partial then projection:=greatest(current_ca,round(current_ca/elapsed)::bigint);end if;
 end if;
 return jsonb_build_object('families',family_totals,'current_service',jsonb_build_object('day',service_day,'starts_at',service_start,'ends_at',service_end,'realized_ca',current_ca,'projection',projection,'elapsed_fraction',elapsed,'reference_days',baseline_days,'method','linear_confirmed_sales_pace','quality',case when projection is null then 'insufficient' else 'indicative' end),'items',out,'ca_estimate',case when known=active_count and known>0 then total else null end,'known_items',known,'active_items',active_count,'partial_ca_estimate',total,'from',today-14,'to',today-1,'method','mean_observed_completed_service_days','generated_at',now(),'warning','Estimation de ventes observées, pas de demande garantie; ruptures possibles et jours sans activité excluant toute certitude.');
end $$;
create function public.grillad_prediction(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.prediction(p_org,p_site)$$;
revoke all on function grillad_private.prediction(uuid,uuid),public.grillad_prediction(uuid,uuid) from public,anon,authenticated;
grant execute on function grillad_private.prediction(uuid,uuid),public.grillad_prediction(uuid,uuid) to authenticated;
commit;
