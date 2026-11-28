-- Extended reporting after all dependent candidate tables exist. Source RLS remains active.
begin;
create or replace function public.sec_site_report(p_org uuid,p_site uuid,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql security invoker set search_path=pg_catalog as $r$
declare out jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then raise exception 'report denied' using errcode='42501';end if;
 if p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '366 days' or p_end>now()+interval '1 minute' then raise exception 'invalid period' using errcode='22023';end if;
 select jsonb_build_object('organization_id',p_org,'site_id',p_site,'start',p_start,'end',p_end,'generated_at',now(),
 'incidents',(select jsonb_build_object('total',count(*),'open',count(*) filter(where state<>'closed'),'critical',count(*) filter(where priority='P1'),'closed',count(*) filter(where state='closed')) from public.sec_incidents where organization_id=p_org and site_id=p_site and occurred_at>=p_start and occurred_at<p_end),
 'attendance',(select jsonb_build_object('total',count(*),'reviewed',count(*) filter(where state='reviewed'),'rejected',count(*) filter(where state='rejected'),'pending',count(*) filter(where state='pending_review')) from public.sec_attendance_drafts where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'patrols',(select jsonb_build_object('total',count(*),'reviewed',count(*) filter(where state='reviewed'),'running',count(*) filter(where state='running'),'overdue',count(*) filter(where state in ('planned','running') and ends_at<now()),'anomalies',(select count(*) from public.sec_field_events e where e.organization_id=p_org and e.site_id=p_site and e.operation='patrol_anomaly' and e.created_at>=p_start and e.created_at<p_end)) from public.sec_patrols where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'work',(select jsonb_build_object('total',count(*),'completed',count(*) filter(where state='completed'),'open',count(*) filter(where state not in ('completed','cancelled'))) from public.sec_work_orders where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'passages',(select jsonb_build_object('entries',count(*) filter(where direction='entry'),'exits',count(*) filter(where direction='exit')) from public.sec_passage_logs where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'warnings',(select count(*) from public.sec_observation_alerts where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'fire_source_events',(select count(*) from public.sec_fire_events where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'devices',(select jsonb_build_object('total',count(*),'recent_contact',count(*) filter(where observed_at between now()-interval '120 seconds' and now()),'unknown_contact',count(*) filter(where observed_at is null or observed_at<now()-interval '120 seconds' or observed_at>now())) from public.sec_devices where organization_id=p_org and site_id=p_site),
 'audit_events',(select count(*) from public.sec_audit_timeline where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'shifts',(select jsonb_build_object('total',count(*),'accepted',count(*) filter(where state='accepted'),'completed',count(*) filter(where state='completed'),'cancelled',count(*) filter(where state='cancelled')) from public.sec_shifts where organization_id=p_org and site_id=p_site and starts_at>=p_start and starts_at<p_end),
 'maintenance',(select jsonb_build_object('reviewed',count(*),'reviewed_cost_fcfa',coalesce(sum(cost_fcfa),0)) from public.sec_maintenance_details where organization_id=p_org and site_id=p_site and reviewed_at>=p_start and reviewed_at<p_end),
 'safety',(select jsonb_build_object('total',count(*),'closed',count(*) filter(where state='closed')) from public.sec_internal_safety where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'visitor_passes',(select jsonb_build_object('issued',count(*),'used',count(*) filter(where used_at is not null),'revoked',count(*) filter(where revoked_at is not null)) from public.sec_visit_passes where organization_id=p_org and site_id=p_site and issued_at>=p_start and issued_at<p_end),
 'confirmed_payments',(select jsonb_build_object('count',count(*),'amount_fcfa',coalesce(sum(amount_fcfa),0)) from public.sec_payment_receipts where organization_id=p_org and site_id=p_site and provider_confirmed_at>=p_start and provider_confirmed_at<p_end),
 'subscriptions',(select jsonb_build_object('active_at_end',count(*) filter(where starts_at<=p_end and ends_at>p_end),'started',count(*) filter(where starts_at>=p_start and starts_at<p_end)) from public.sec_subscriptions where organization_id=p_org and site_id=p_site),
 'register',(select jsonb_build_object('visitors',count(*) filter(where kind='visitor'),'vehicles',count(*) filter(where kind='vehicle'),'partners',count(*) filter(where kind='partner'),'compatibility',count(*) filter(where kind='compatibility')) from public.sec_service_register where organization_id=p_org and site_id=p_site and recorded_at>=p_start and recorded_at<p_end),
 'visible_support_cases',(select count(*) from public.sec_support_cases where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'personal_notifications',(select count(*) from public.sec_activity_notifications where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'diagnostics',(select jsonb_build_object('total',count(*),'completed',count(*) filter(where state='completed'),'expired_or_overdue',count(*) filter(where state='expired' or (state in ('requested','authorized') and expires_at<=now()))) from public.sec_diagnostic_requests where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'fire_states',(select jsonb_build_object('alarm',count(*) filter(where source_state='alarm'),'prealarm',count(*) filter(where source_state='prealarm'),'evacuation',count(*) filter(where source_state='evacuation'),'fault',count(*) filter(where source_state='fault'),'restored',count(*) filter(where source_state='restored')) from public.sec_fire_events where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'telemetry',(select jsonb_build_object('total',count(*),'online',count(*) filter(where status='online'),'offline',count(*) filter(where status='offline'),'fault',count(*) filter(where status='fault')) from public.sec_device_observations where organization_id=p_org and site_id=p_site and observed_at>=p_start and observed_at<p_end),
 'geofences_created',(select count(*) from public.sec_geofences where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'personal_evidence',(select count(*) from public.sec_evidence_files where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end),
 'personal_media_grants',(select count(*) from public.sec_media_grants where organization_id=p_org and site_id=p_site and created_at>=p_start and created_at<p_end)
 ) into out;
 return out;
end $r$;
revoke all on function public.sec_site_report(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.sec_site_report(uuid,uuid,timestamptz,timestamptz) to authenticated;
-- Multi-site reporting over authorized sites only. No access granted by the aggregate.
create or replace function public.sec_org_report(p_org uuid,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql security invoker set search_path=pg_catalog as $r$
declare reports jsonb; totals jsonb; sites_count integer;
begin
 if p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '366 days' or p_end>now()+interval '1 minute' then raise exception 'invalid period' using errcode='22023';end if;
 select coalesce(jsonb_agg(public.sec_site_report(p_org,s.id,p_start,p_end)||jsonb_build_object('site_name',s.name) order by s.id),'[]'::jsonb) into reports
 from public.sec_sites s where s.organization_id=p_org and sec_private.field_role(p_org,s.id) in ('owner','manager');
 sites_count:=jsonb_array_length(reports);
 if sites_count=0 then raise exception 'report denied' using errcode='42501';end if;
 select jsonb_build_object('incidents_total',sum((x->'incidents'->>'total')::bigint),'incidents_open',sum((x->'incidents'->>'open')::bigint),'incidents_closed',sum((x->'incidents'->>'closed')::bigint),'attendance_total',sum((x->'attendance'->>'total')::bigint),'patrols_total',sum((x->'patrols'->>'total')::bigint),'work_open',sum((x->'work'->>'open')::bigint),'devices_total',sum((x->'devices'->>'total')::bigint),'warnings',sum((x->>'warnings')::bigint),'fire_source_events',sum((x->>'fire_source_events')::bigint),
 'shifts_total',sum((x->'shifts'->>'total')::bigint),'maintenance_reviewed',sum((x->'maintenance'->>'reviewed')::bigint),'maintenance_cost_fcfa',sum((x->'maintenance'->>'reviewed_cost_fcfa')::bigint),
 'safety_total',sum((x->'safety'->>'total')::bigint),'visitor_passes_issued',sum((x->'visitor_passes'->>'issued')::bigint),
 'confirmed_payments_count',sum((x->'confirmed_payments'->>'count')::bigint),'confirmed_payments_fcfa',sum((x->'confirmed_payments'->>'amount_fcfa')::bigint),
 'active_subscriptions',sum((x->'subscriptions'->>'active_at_end')::bigint),'audit_events_visible',sum((x->>'audit_events')::bigint),
 'incidents_critical',sum((x->'incidents'->>'critical')::bigint),
 'attendance_reviewed',sum((x->'attendance'->>'reviewed')::bigint),'attendance_rejected',sum((x->'attendance'->>'rejected')::bigint),'attendance_pending',sum((x->'attendance'->>'pending')::bigint),
 'patrols_reviewed',sum((x->'patrols'->>'reviewed')::bigint),'patrols_running',sum((x->'patrols'->>'running')::bigint),'patrols_overdue',sum((x->'patrols'->>'overdue')::bigint),'patrol_anomalies',sum((x->'patrols'->>'anomalies')::bigint),
 'work_total',sum((x->'work'->>'total')::bigint),'work_completed',sum((x->'work'->>'completed')::bigint),
 'passages_entries',sum((x->'passages'->>'entries')::bigint),'passages_exits',sum((x->'passages'->>'exits')::bigint),
 'devices_recent_contact',sum((x->'devices'->>'recent_contact')::bigint),'devices_unknown_contact',sum((x->'devices'->>'unknown_contact')::bigint),
 'shifts_accepted',sum((x->'shifts'->>'accepted')::bigint),'shifts_completed',sum((x->'shifts'->>'completed')::bigint),'shifts_cancelled',sum((x->'shifts'->>'cancelled')::bigint),
 'safety_closed',sum((x->'safety'->>'closed')::bigint),'visitor_passes_used',sum((x->'visitor_passes'->>'used')::bigint),'visitor_passes_revoked',sum((x->'visitor_passes'->>'revoked')::bigint),
 'subscriptions_started',sum((x->'subscriptions'->>'started')::bigint),
 'register_visitors',sum((x->'register'->>'visitors')::bigint),'register_vehicles',sum((x->'register'->>'vehicles')::bigint),'register_partners',sum((x->'register'->>'partners')::bigint),'register_compatibility',sum((x->'register'->>'compatibility')::bigint),
 'visible_support_cases',sum((x->>'visible_support_cases')::bigint),'personal_notifications',sum((x->>'personal_notifications')::bigint)) || jsonb_build_object(
 'diagnostics_total',sum((x->'diagnostics'->>'total')::bigint),'diagnostics_completed',sum((x->'diagnostics'->>'completed')::bigint),'diagnostics_expired_or_overdue',sum((x->'diagnostics'->>'expired_or_overdue')::bigint),
 'fire_alarm',sum((x->'fire_states'->>'alarm')::bigint),'fire_prealarm',sum((x->'fire_states'->>'prealarm')::bigint),'fire_evacuation',sum((x->'fire_states'->>'evacuation')::bigint),'fire_fault',sum((x->'fire_states'->>'fault')::bigint),'fire_restored',sum((x->'fire_states'->>'restored')::bigint),
 'telemetry_total',sum((x->'telemetry'->>'total')::bigint),'telemetry_online',sum((x->'telemetry'->>'online')::bigint),'telemetry_offline',sum((x->'telemetry'->>'offline')::bigint),'telemetry_fault',sum((x->'telemetry'->>'fault')::bigint),
 'geofences_created',sum((x->>'geofences_created')::bigint),'personal_evidence',sum((x->>'personal_evidence')::bigint),'personal_media_grants',sum((x->>'personal_media_grants')::bigint)) into totals from jsonb_array_elements(reports) q(x);
 return jsonb_build_object('organization_id',p_org,'start',p_start,'end',p_end,'generated_at',now(),'authorized_site_count',sites_count,'totals',totals,'sites',reports);
end $r$;
revoke all on function public.sec_org_report(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.sec_org_report(uuid,timestamptz,timestamptz) to authenticated;
commit;
