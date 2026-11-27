-- Candidate, no production migration. Independent by default, consolidation explicitly provisioned.
begin;
create table grillad_private.pilotage_policy(org uuid primary key references famille_core.organizations(id),centralized boolean not null default false);
alter table grillad_private.pilotage_policy enable row level security;
revoke all on grillad_private.pilotage_policy from public,anon,authenticated;
create function grillad_private.report(p_org uuid,p_site uuid,p_from date,p_to date,p_network boolean,p_family text,p_actor uuid,p_item uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;site_ids uuid[];v jsonb;detail jsonb;lo timestamptz;hi timestamptz;
begin
 r:=grillad_private.scope(p_org,p_site);
 if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 or p_network is null or (p_family is not null and p_family not in ('Porc','Poulet','Poisson','Brochettes','Omelettes')) then raise exception 'GRILLAD_REPORT_FILTER' using errcode='22023';end if;
 if p_network then
  if r<>'owner' or not exists(select 1 from grillad_private.pilotage_policy where org=p_org and centralized) then raise exception 'GRILLAD_NETWORK_DENIED' using errcode='42501';end if;
  select array_agg((x->>'site')::uuid) into site_ids from jsonb_array_elements(grillad_private.workspace()) x where (x->>'org')::uuid=p_org and x->>'role'='owner';
 else site_ids:=array[p_site];end if;
 if coalesce(cardinality(site_ids),0)=0 then raise exception 'GRILLAD_SCOPE' using errcode='42501';end if;
 lo:=p_from::timestamp at time zone 'Africa/Douala';hi:=(p_to+1)::timestamp at time zone 'Africa/Douala';
 -- Costs of a filtered slice may be known; site expenses are not attributed to articles/sellers without a rule.
 with selected as (
 select s.*,i.family from grillad_private.sales s join grillad_private.items i on i.id=s.item and i.org=s.org and i.site=s.site
 where s.org=p_org and s.site=any(site_ids) and not(s.cancelled_at is not null) and s.created_at>=lo and s.created_at<hi
 and (p_family is null or i.family=p_family) and (p_actor is null or s.actor=p_actor) and (p_item is null or s.item=p_item))
 select jsonb_build_object('ca',coalesce(sum(total),0),'sales_count',count(distinct (site,coalesce(direct_order,id))) filter(where source='direct')+count(distinct connect_order) filter(where source='connect'),'quantity',coalesce(sum(qty),0),
 'direct_ca',coalesce(sum(total) filter(where source='direct'),0),'connect_ca',coalesce(sum(total) filter(where source='connect'),0),
 'cost',case when count(*) filter(where cost is null)>0 then null else coalesce(sum(qty*cost),0) end,
 'expenses',case when p_family is not null or p_actor is not null or p_item is not null then null else (select coalesce(sum(e.value),0) from grillad_private.expenses e where e.cancelled_at is null and e.org=p_org and e.site=any(site_ids) and e.created_at>=lo and e.created_at<hi) end,
 'by_family',coalesce((select jsonb_agg(to_jsonb(q) order by q.family) from (select family,coalesce(sum(total),0) ca,sum(qty) quantity from selected group by family)q),'[]'::jsonb),
 'by_seller',coalesce((select jsonb_agg(to_jsonb(q) order by q.actor) from (select actor,coalesce(sum(total),0) ca,sum(qty) quantity from selected group by actor)q),'[]'::jsonb)) into v from selected;
 select coalesce(jsonb_agg(jsonb_build_object('site',l.id,'name',l.name,'ca',coalesce(s.ca,0),'expenses',case when p_family is not null or p_actor is not null or p_item is not null then null else coalesce(e.charges,0) end) order by l.name,l.id),'[]'::jsonb) into detail
 from famille_core.locations l left join lateral(select sum(a.total) ca from grillad_private.sales a join grillad_private.items i on i.id=a.item where a.org=p_org and a.site=l.id and a.cancelled_at is null and a.created_at>=lo and a.created_at<hi and (p_family is null or i.family=p_family) and (p_actor is null or a.actor=p_actor) and (p_item is null or a.item=p_item))s on true
 left join lateral(select sum(value) charges from grillad_private.expenses where cancelled_at is null and org=p_org and site=l.id and created_at>=lo and created_at<hi)e on true where l.organization_id=p_org and l.id=any(site_ids);
 return v||jsonb_build_object('sites',detail,'network',p_network,'from',p_from,'to',p_to,'generated_at',now(),'basis','confirmed_server_only','cash_assumption','cash_candidate_only');
end $$;
create function grillad_private.pilotage_status(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;plan text;v jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 select p.code into plan from famille_core.subscriptions s join famille_core.plans p on p.id=s.plan_id and p.app_id=s.app_id join famille_core.applications a on a.id=s.app_id where a.code='grillad' and s.organization_id=p_org and ((s.status='active' and (s.starts_at is null or s.starts_at<=now()) and (s.ends_at is null or s.ends_at>=now())) or (s.status='past_due' and s.grace_until>=now())) and p.status='active' and p.code in ('grillad_access_month','grillad_access_year','grillad_premium_month','grillad_premium_year') limit 1;
 if r='seller' then return jsonb_build_object('role',r,'network_allowed',false);end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'role',ra.role_code) order by m.user_id),'[]'::jsonb) into v from famille_core.memberships m join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id and ra.organization_id=m.organization_id where m.organization_id=p_org and m.app_id=famille_core.current_app_id() and m.status='active' and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now()) and (ra.location_id=p_site or (ra.role_code='owner' and ra.location_id is null));
 return jsonb_build_object('role',r,'plan',plan,'network_allowed',r='owner' and coalesce((select centralized from grillad_private.pilotage_policy where org=p_org),false),'team',v);
end $$;
create function public.grillad_report(p_org uuid,p_site uuid,p_from date,p_to date,p_network boolean,p_family text,p_actor uuid,p_item uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.report(p_org,p_site,p_from,p_to,p_network,p_family,p_actor,p_item)$$;
create function public.grillad_pilotage_status(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.pilotage_status(p_org,p_site)$$;
revoke all on function grillad_private.report(uuid,uuid,date,date,boolean,text,uuid,uuid),public.grillad_report(uuid,uuid,date,date,boolean,text,uuid,uuid),grillad_private.pilotage_status(uuid,uuid),public.grillad_pilotage_status(uuid,uuid) from public,anon,authenticated;
grant execute on function grillad_private.report(uuid,uuid,date,date,boolean,text,uuid,uuid),public.grillad_report(uuid,uuid,date,date,boolean,text,uuid,uuid),grillad_private.pilotage_status(uuid,uuid),public.grillad_pilotage_status(uuid,uuid) to authenticated;
commit;
