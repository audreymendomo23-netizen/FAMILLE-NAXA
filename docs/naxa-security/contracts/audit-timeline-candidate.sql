-- Candidate audit projection: source RLS preserved; no payload, hash, token, or message.
begin;
create view public.sec_audit_timeline with(security_invoker=true) as
 select 'field'::text as source,id,organization_id,site_id,actor_id,operation,coalesce(result->>'state','recorded') as state,created_at from public.sec_field_events
 union all select 'service',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at from public.sec_service_action_log
 union all select 'erp',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at from public.sec_erp_events
 union all select 'support',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at from public.sec_support_events
 union all select 'fire_ack',event_id,organization_id,site_id,actor_id,'acknowledge','recorded',created_at from public.sec_fire_acknowledgments
 union all select 'admin',id,organization_id,site_id,actor_id,'site_membership',case when enabled then 'enabled' else 'revoked' end,created_at from public.sec_site_admin_log;
revoke all on public.sec_audit_timeline from public,anon,authenticated;
grant select on public.sec_audit_timeline to authenticated;
commit;
