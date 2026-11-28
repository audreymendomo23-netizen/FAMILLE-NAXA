-- Server-issued trace for actual authorized sensitive RPC calls; no client-supplied actor, content or token.
begin;
create table public.sec_access_audit(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,actor_id uuid not null references auth.users(id),
 operation text not null check(operation in ('evidence_download','site_members_read','integration_list_read','audit_export','retention_policy_change','environment_threshold_set','environment_threshold_remove','media_grant_revoke','media_open_authorized','alarm_ack','alarm_escalate','alarm_review','evidence_share_create','evidence_share_revoke','evidence_share_download','tracker_config','device_register','device_bind','device_revoke','support_attachment_add','support_attachment_revoke','support_attachment_download','support_agent_enable','support_agent_disable','evidence_inventory_read','evidence_integrity_check','presence_qr_issue','presence_qr_consume','presence_exception_submit','presence_exception_review','evidence_policy_change')),
 object_id uuid,outcome text not null default 'authorized' check(outcome in ('authorized','denied')),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_access_audit enable row level security;
revoke all on public.sec_access_audit from public,anon,authenticated;
grant select on public.sec_access_audit to authenticated;
create policy sec_access_audit_self on public.sec_access_audit for select to authenticated using(actor_id=auth.uid() and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create index sec_access_audit_scope on public.sec_access_audit(organization_id,site_id,actor_id,created_at desc,id);
create or replace function sec_private.site_members(p_org uuid,p_site uuid) returns jsonb language plpgsql volatile security definer set search_path=pg_catalog as $q$
declare v jsonb;
begin
 if sec_private.field_role(p_org,p_site) is distinct from 'owner' then
  if sec_private.field_role(p_org,p_site) in ('manager','operator') then insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id,outcome) values(p_org,p_site,auth.uid(),'site_members_read',null,'denied');end if;
  return '[]'::jsonb;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'site_active',coalesce(sm.active,false)) order by m.user_id),'[]'::jsonb) into v
 from public.sec_memberships m left join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id and sm.site_id=p_site where m.organization_id=p_org and m.active;
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'site_members_read',p_site);
 return v;
end $q$;
create or replace function sec_private.integration_list(p_org uuid,p_site uuid) returns jsonb language plpgsql volatile security definer set search_path=pg_catalog as $q$
declare v jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager') then
  if sec_private.field_role(p_org,p_site)='operator' then insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id,outcome) values(p_org,p_site,auth.uid(),'integration_list_read',null,'denied');end if;
  return '[]'::jsonb;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('gateway_id',b.gateway_id,'device_id',b.device_id,'enabled',b.enabled) order by b.gateway_id,b.device_id),'[]'::jsonb) into v from sec_private.gateway_bindings b where b.organization_id=p_org and b.site_id=p_site;
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'integration_list_read',p_site);
 return v;
end $q$;
create or replace function sec_private.evidence_download(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql volatile security definer set search_path=pg_catalog as $q$
declare v jsonb;
begin
 select jsonb_build_object('id',f.id,'digest',f.digest,'base64',replace(encode(c.content,'base64'),E'\n','')) into v
 from public.sec_evidence_files f join sec_private.evidence_content c using(id)
 where f.id=p_id and f.organization_id=p_org and f.site_id=p_site and f.owner_id=auth.uid() and sec_private.field_role(p_org,p_site) in ('owner','manager','operator');
 if v is not null then insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_download',p_id);
 elsif sec_private.field_role(p_org,p_site) in ('owner','manager','operator') then insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id,outcome) values(p_org,p_site,auth.uid(),'evidence_download',null,'denied');end if;
 return v;
end $q$;
-- Extend original projection: the first eight columns are preserved, new columns appended.
create or replace view public.sec_audit_timeline with(security_invoker=true) as
 select 'field'::text as source,id,organization_id,site_id,actor_id,operation,coalesce(result->>'state','recorded') as state,created_at,target_id as object_id,'field_rpc'::text as origin,id as correlation_id from public.sec_field_events
 union all select 'service',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at,target_id,'service_rpc',id from public.sec_service_action_log
 union all select 'erp',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at,target_id,'erp_rpc',id from public.sec_erp_events
 union all select 'support',id,organization_id,site_id,actor_id,operation,coalesce(receipt->>'state','recorded'),created_at,case_id,'support_rpc',id from public.sec_support_events
 union all select 'fire_ack',event_id,organization_id,site_id,actor_id,'acknowledge','recorded',created_at,event_id,'fire_rpc',event_id from public.sec_fire_acknowledgments
 union all select 'admin',id,organization_id,site_id,actor_id,'site_membership',case when enabled then 'enabled' else 'revoked' end,created_at,target_id,'admin_rpc',id from public.sec_site_admin_log
 union all select 'access',id,organization_id,site_id,actor_id,operation,outcome,created_at,object_id,'access_rpc',id from public.sec_access_audit;
revoke all on public.sec_audit_timeline from public,anon;
grant select on public.sec_audit_timeline to authenticated;
commit;
