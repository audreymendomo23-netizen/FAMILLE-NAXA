-- Candidate only; service hours must be configured by authorized provisioning.
begin;
create table grillad_private.service_policy(
 org uuid not null,site uuid not null,start_minute integer not null check(start_minute between 0 and 1439),
 effective_from date not null,enabled boolean not null default false,primary key(org,site),
 foreign key(org,site) references grillad_private.enabled_sites(org,site)
);
create table grillad_private.service_revisions(
 org uuid not null,site uuid not null,effective_from date not null,start_minute integer not null check(start_minute between 0 and 1439),reason text not null check(length(reason) between 1 and 300),actor uuid not null,created_at timestamptz not null default now(),
 primary key(org,site,effective_from),foreign key(org,site) references grillad_private.service_policy(org,site));
alter table grillad_private.service_revisions enable row level security;
revoke all on grillad_private.service_revisions from public,anon,authenticated;
create function grillad_private.service_boundary(p_org uuid,p_site uuid,p_day date) returns timestamptz language sql stable security invoker set search_path=pg_catalog as $$
 select (p_day::timestamp+make_interval(mins=>coalesce((select r.start_minute from grillad_private.service_revisions r where r.org=p_org and r.site=p_site and r.effective_from<=p_day order by r.effective_from desc limit 1),p.start_minute))) at time zone 'Africa/Douala'
 from grillad_private.service_policy p where p.org=p_org and p.site=p_site and p.enabled and p.effective_from<=p_day
$$;
revoke all on function grillad_private.service_boundary(uuid,uuid,date) from public,anon,authenticated;
create table grillad_private.daily_summary(
 org uuid not null,site uuid not null,service_day date not null,version integer not null check(version>0),
 starts_at timestamptz not null,ends_at timestamptz not null,data jsonb not null,generated_at timestamptz not null default now(),
 primary key(org,site,service_day,version),foreign key(org,site) references grillad_private.enabled_sites(org,site)
);
create table grillad_private.notice_read(
 org uuid not null,site uuid not null,actor uuid not null,notice_id text not null,read_at timestamptz not null default now(),
 primary key(org,site,actor,notice_id),foreign key(org,site) references grillad_private.enabled_sites(org,site)
);
create table grillad_private.notice_preference(
 org uuid not null,site uuid not null,actor uuid not null,category text not null check(category in ('sales','stock','cash','daily','attendance','connect','security')),
 enabled boolean not null,primary key(org,site,actor,category),foreign key(org,site) references grillad_private.enabled_sites(org,site)
);
alter table grillad_private.service_policy enable row level security;
alter table grillad_private.daily_summary enable row level security;
alter table grillad_private.notice_read enable row level security;
alter table grillad_private.notice_preference enable row level security;
revoke all on grillad_private.service_policy,grillad_private.daily_summary,grillad_private.notice_read,grillad_private.notice_preference from public,anon,authenticated;
create function grillad_private.generate_daily(p_org uuid,p_site uuid,p_day date) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare p grillad_private.service_policy%rowtype;old grillad_private.daily_summary%rowtype;lo timestamptz;hi timestamptz;v jsonb;n integer;
begin
 select * into p from grillad_private.service_policy where org=p_org and site=p_site and enabled and effective_from<=p_day;
 if not found then raise exception 'GRILLAD_SERVICE_POLICY_REQUIRED' using errcode='22023';end if;
 lo:=grillad_private.service_boundary(p_org,p_site,p_day);hi:=grillad_private.service_boundary(p_org,p_site,p_day+1);
 if hi>now() then raise exception 'GRILLAD_SERVICE_OPEN' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,0));
 select * into old from grillad_private.daily_summary where org=p_org and site=p_site and service_day=p_day order by version desc limit 1;
 select jsonb_build_object('ca',coalesce(sum(s.total),0),'sales_count',count(distinct (s.site,coalesce(s.direct_order,s.id))) filter(where s.source='direct')+count(distinct s.connect_order) filter(where s.source='connect'),'sold',coalesce(sum(s.qty),0),
 'encaissements',(select coalesce(sum(c.amount),0) from grillad_private.cash_receipts c where c.org=p_org and c.site=p_site and c.reversed_at is null and c.recorded_at>=lo and c.recorded_at<hi),
 'cost',case when count(*) filter(where s.cost is null)>0 then null else coalesce(sum(s.qty*s.cost),0) end,
 'expenses',(select coalesce(sum(e.value),0) from grillad_private.expenses e where e.cancelled_at is null and e.org=p_org and e.site=p_site and e.created_at>=lo and e.created_at<hi),
 'prepared',(select coalesce(sum(a.qty),0) from grillad_private.preparations a where a.org=p_org and a.site=p_site and a.created_at>=lo and a.created_at<hi),
 'stock_adjustments',(select coalesce(sum(a.delta),0) from grillad_private.stock_adjustments a where a.org=p_org and a.site=p_site and a.created_at>=lo and a.created_at<hi),
 'cash_difference',(select coalesce(sum(c.counted-c.expected),0) from grillad_private.cash c where c.org=p_org and c.site=p_site and c.closed_at>=lo and c.closed_at<hi),
 'reviewed_cash_difference',(select coalesce(sum(coalesce(cr.proposed_count,c.counted)-c.expected),0) from grillad_private.cash c left join grillad_private.cash_recounts cr on cr.cash=c.id and cr.status='approved' where c.org=p_org and c.site=p_site and c.closed_at>=lo and c.closed_at<hi),
 'open_cash_count',(select count(*) from grillad_private.cash c where c.org=p_org and c.site=p_site and c.opened_at<hi and (c.closed_at is null or c.closed_at>=hi)),
 'unpaired_arrivals',(select count(*) from grillad_private.attendance a where a.org=p_org and a.site=p_site and a.kind='arrival' and a.captured_at<hi and a.captured_at>=lo and not exists(select 1 from grillad_private.attendance b where b.paired_arrival=a.id and b.captured_at<hi) and not exists(select 1 from grillad_private.missing_departures m where m.arrival=a.id and m.status='approved' and m.proposed_at<hi)),
 'manual_arrivals',(select count(*) from grillad_private.missing_arrivals m join grillad_private.attendance a on a.id=m.departure where m.org=p_org and m.site=p_site and m.status='approved' and a.captured_at>=lo and a.captured_at<hi),
 'unpaired_departures',(select count(*) from grillad_private.attendance a where a.org=p_org and a.site=p_site and a.kind='departure_without_arrival' and a.captured_at>=lo and a.captured_at<hi and not exists(select 1 from grillad_private.missing_arrivals m where m.departure=a.id and m.status='approved')),
 'manual_departures',(select count(*) from grillad_private.missing_departures m where m.org=p_org and m.site=p_site and m.status='approved' and m.proposed_at>=lo and m.proposed_at<hi),
 'target',(select amount from grillad_private.targets where org=p_org and site=p_site and day=p_day),
 'direct_ca',coalesce(sum(s.total) filter(where s.source='direct'),0),'connect_ca',coalesce(sum(s.total) filter(where s.source='connect'),0),'basis','server_confirmed_only') into v from grillad_private.sales s where s.org=p_org and s.site=p_site and s.created_at>=lo and s.created_at<hi and s.cancelled_at is null;
 v:=v||jsonb_build_object('provisional',((v->>'open_cash_count')::bigint>0 or (v->>'unpaired_arrivals')::bigint>0 or (v->>'unpaired_departures')::bigint>0),'margin',case when v->'cost'='null'::jsonb then null else (v->>'ca')::bigint-(v->>'cost')::bigint end,'operating_result',case when v->'cost'='null'::jsonb then null else (v->>'ca')::bigint-(v->>'cost')::bigint-(v->>'expenses')::bigint end);
 if old.version is not null and old.data=v and old.starts_at=lo and old.ends_at=hi then return jsonb_build_object('version',old.version,'changed',false);end if;
 n:=coalesce(old.version,0)+1;
 insert into grillad_private.daily_summary(org,site,service_day,version,starts_at,ends_at,data) values(p_org,p_site,p_day,n,lo,hi,v);
 return jsonb_build_object('version',n,'changed',true);
end $$;
create function grillad_private.daily_tick(p_limit integer default 100) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare s record;n int:=0;changed int:=0;v jsonb;
begin
 if p_limit is null or p_limit not between 1 and 500 then raise exception 'GRILLAD_LIMIT';end if;
 -- Seven-day revision sweep; older missing services are processed before recent ones.
 for s in select p.org,p.site,d::date service_day from grillad_private.service_policy p
 join grillad_private.enabled_sites e on e.org=p.org and e.site=p.site and e.enabled
 cross join lateral generate_series(p.effective_from::timestamp,(now() at time zone 'Africa/Douala')::date::timestamp,interval '1 day') d
 where p.enabled and grillad_private.service_boundary(p.org,p.site,d::date+1)<=now()
 and (d::date>=(now() at time zone 'Africa/Douala')::date-7 or not exists(select 1 from grillad_private.daily_summary x where x.org=p.org and x.site=p.site and x.service_day=d::date))
 order by d,p.org,p.site limit p_limit loop
  v:=grillad_private.generate_daily(s.org,s.site,s.service_day);n:=n+1;if (v->>'changed')::boolean then changed:=changed+1;end if;
 end loop;
 return jsonb_build_object('processed',n,'changed',changed);
end $$;
create function grillad_private.daily_list(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;out jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.service_day desc),'[]'::jsonb) into out from (select distinct on(service_day) service_day,version,starts_at,ends_at,data,generated_at from grillad_private.daily_summary where org=p_org and site=p_site order by service_day desc,version desc limit 30) x;
 return out;
end $$;
create function grillad_private.notice_feed(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;u uuid:=auth.uid();out jsonb;preferences jsonb;security_events jsonb:='[]'::jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);
 if r in ('owner','manager') then security_events:=coalesce(grillad_private.security_list(p_org,p_site)->'incidents','[]'::jsonb);end if;
 with all_events as (
 select 'event:'||e.id as id,case when action in ('sell','sell_basket') then 'sales' when action in ('prepare','adjust_stock') then 'stock' else 'cash' end as category,
 case when action in ('sell','sell_basket') then 'Vente confirmée' when action='prepare' then 'Préparation enregistrée' when action='adjust_stock' then 'Ajustement de stock enregistré' when action='cancel_expense' then 'Dépense annulée' when action='cash_recount_request' then 'Demande de recomptage enregistrée' when action='cash_recount_decide' then 'Décision de recomptage enregistrée' when action='close_cash' then 'Clôture de caisse enregistrée' else 'Dépense enregistrée' end as text,e.created_at at
 from grillad_private.events e where org=p_org and site=p_site and action in ('sell','sell_basket','prepare','adjust_stock','close_cash','expense','cancel_expense','cash_recount_request','cash_recount_decide') and (r<>'seller' or (e.actor=u and action in ('sell','sell_basket','prepare')))
 union all select 'daily:'||service_day,'daily','Point journalier disponible',max(generated_at) from grillad_private.daily_summary where org=p_org and site=p_site and r<>'seller' group by service_day
 union all select 'attendance:'||a.id,'attendance','Pointage confirmé',a.received_at from grillad_private.attendance a where org=p_org and site=p_site and (r<>'seller' or a.actor=u)
 union all select 'correction:'||c.id,'attendance','Régularisation de pointage demandée',c.requested_at from grillad_private.attendance_corrections c where c.org=p_org and c.site=p_site and (r<>'seller' or c.requester=u)
 union all select 'decision:'||c.id,'attendance',case when c.status='approved' then 'Régularisation approuvée' else 'Régularisation refusée' end,c.decided_at from grillad_private.attendance_corrections c where c.org=p_org and c.site=p_site and c.status<>'pending' and (r<>'seller' or c.requester=u)
 union all select 'missing-arrival:'||m.id,'attendance','Arrivée manquante déclarée',m.requested_at from grillad_private.missing_arrivals m where m.org=p_org and m.site=p_site and (r<>'seller' or m.requester=u)
 union all select 'missing-arrival-decision:'||m.id,'attendance','Décision arrivée manquante',m.decided_at from grillad_private.missing_arrivals m where m.org=p_org and m.site=p_site and m.status<>'pending' and (r<>'seller' or m.requester=u)
 union all select 'missing:'||m.id,'attendance','Départ manquant déclaré',m.requested_at from grillad_private.missing_departures m where m.org=p_org and m.site=p_site and (r<>'seller' or m.requester=u)
 union all select 'missing-decision:'||m.id,'attendance',case when m.status='approved' then 'Départ manuel approuvé' else 'Départ manuel refusé' end,m.decided_at from grillad_private.missing_departures m where m.org=p_org and m.site=p_site and m.status<>'pending' and (r<>'seller' or m.requester=u)
 union all select 'connect:'||o.id,'connect','Commande GRILLAD Connect reçue',o.created_at from grillad_private.connect_orders o where o.org=p_org and o.site=p_site and r<>'seller'
 union all select 'connect:'||h.order_id||':'||h.event,'connect','Statut GRILLAD Connect actualisé',h.created_at from grillad_private.connect_history h join grillad_private.connect_orders o on o.id=h.order_id where o.org=p_org and o.site=p_site and r<>'seller'
 union all select 'security:'||(i->>'id'),'security','Incident de sécurité signalé',(i->>'observed_at')::timestamptz from jsonb_array_elements(security_events) i where r<>'seller'
 ),recent as(select e.* from all_events e left join grillad_private.notice_preference p on p.org=p_org and p.site=p_site and p.actor=u and p.category=e.category where coalesce(p.enabled,true) order by e.at desc,e.id limit 100)
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'category',e.category,'text',e.text,'at',e.at,'read',rr.read_at is not null) order by e.at desc,e.id),'[]'::jsonb) into out from recent e left join grillad_private.notice_read rr on rr.org=p_org and rr.site=p_site and rr.actor=u and rr.notice_id=e.id;
 select coalesce(jsonb_object_agg(category,enabled),'{}'::jsonb) into preferences from grillad_private.notice_preference where org=p_org and site=p_site and actor=u;
 return jsonb_build_object('items',out,'preferences',preferences);
end $$;
create function grillad_private.notice_ack(p_org uuid,p_site uuid,p_id text) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
begin
 if p_id is null or not exists(select 1 from jsonb_array_elements(grillad_private.notice_feed(p_org,p_site)->'items') a where a->>'id'=p_id) then raise exception 'GRILLAD_NOTICE' using errcode='42501';end if;
 insert into grillad_private.notice_read(org,site,actor,notice_id) values(p_org,p_site,auth.uid(),p_id) on conflict do nothing;return true;
end $$;
create function grillad_private.notice_set(p_org uuid,p_site uuid,p_category text,p_enabled boolean) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
begin
 perform grillad_private.scope(p_org,p_site);
 insert into grillad_private.notice_preference values(p_org,p_site,auth.uid(),p_category,p_enabled) on conflict(org,site,actor,category) do update set enabled=excluded.enabled;
 return true;
end $$;
create function public.grillad_daily_tick(p_limit integer) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.daily_tick(p_limit)$$;
create function public.grillad_daily_list(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.daily_list(p_org,p_site)$$;
create function public.grillad_notice_feed(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.notice_feed(p_org,p_site)$$;
create function public.grillad_notice_ack(p_org uuid,p_site uuid,p_id text) returns boolean language sql security invoker set search_path=pg_catalog as $$select grillad_private.notice_ack(p_org,p_site,p_id)$$;
create function public.grillad_notice_set(p_org uuid,p_site uuid,p_category text,p_enabled boolean) returns boolean language sql security invoker set search_path=pg_catalog as $$select grillad_private.notice_set(p_org,p_site,p_category,p_enabled)$$;
revoke all on function grillad_private.generate_daily(uuid,uuid,date),grillad_private.daily_tick(integer),public.grillad_daily_tick(integer),grillad_private.daily_list(uuid,uuid),public.grillad_daily_list(uuid,uuid),grillad_private.notice_feed(uuid,uuid),public.grillad_notice_feed(uuid,uuid),grillad_private.notice_ack(uuid,uuid,text),public.grillad_notice_ack(uuid,uuid,text),grillad_private.notice_set(uuid,uuid,text,boolean),public.grillad_notice_set(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function grillad_private.daily_tick(integer),public.grillad_daily_tick(integer) to service_role;
grant execute on function grillad_private.daily_list(uuid,uuid),public.grillad_daily_list(uuid,uuid),grillad_private.notice_feed(uuid,uuid),public.grillad_notice_feed(uuid,uuid),grillad_private.notice_ack(uuid,uuid,text),public.grillad_notice_ack(uuid,uuid,text),grillad_private.notice_set(uuid,uuid,text,boolean),public.grillad_notice_set(uuid,uuid,text,boolean) to authenticated;
commit;
