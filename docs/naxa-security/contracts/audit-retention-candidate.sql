-- A site policy is explicit; an unset policy or legal hold never makes records eligible.
-- Preview only, no destructive job until policy and retention of all source journals are approved.
begin;
create table sec_private.audit_retention_policy(
 organization_id uuid not null,site_id uuid not null,days integer not null check(days between 1 and 3650),
 legal_hold boolean not null default true,changed_by uuid not null references auth.users(id),changed_at timestamptz not null default clock_timestamp(),
 primary key(organization_id,site_id),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
revoke all on sec_private.audit_retention_policy from public,anon,authenticated;
create function sec_private.audit_retention(p_org uuid,p_site uuid,p_days integer default null,p_hold boolean default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v sec_private.audit_retention_policy%rowtype; eligible bigint; cutoff timestamptz;
begin
 if sec_private.field_role(p_org,p_site) is distinct from 'owner' then raise exception 'owner required' using errcode='42501';end if;
 if (p_days is null)<>(p_hold is null) or (p_days is not null and p_days not between 1 and 3650) then raise exception 'invalid policy' using errcode='22023';end if;
 if p_days is not null then
  insert into sec_private.audit_retention_policy(organization_id,site_id,days,legal_hold,changed_by) values(p_org,p_site,p_days,p_hold,auth.uid())
  on conflict(organization_id,site_id) do update set days=excluded.days,legal_hold=excluded.legal_hold,changed_by=excluded.changed_by,changed_at=clock_timestamp() returning * into v;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'retention_policy_change',p_site);
 else select * into v from sec_private.audit_retention_policy where organization_id=p_org and site_id=p_site;end if;
 if v.days is not null then cutoff:=now()-make_interval(days=>v.days);end if;
 if v.days is null or v.legal_hold then eligible:=0;
 else select count(*) into eligible from public.sec_access_audit where organization_id=p_org and site_id=p_site and created_at<cutoff;end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'configured',v.days is not null,'days',v.days,'legal_hold',coalesce(v.legal_hold,true),'cutoff',cutoff,'access_trace_candidates',eligible,'preview_only',true);
end $f$;
revoke all on function sec_private.audit_retention(uuid,uuid,integer,boolean) from public,anon,authenticated;
grant execute on function sec_private.audit_retention(uuid,uuid,integer,boolean) to authenticated;
create function public.sec_audit_retention(p_org uuid,p_site uuid,p_days integer default null,p_hold boolean default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.audit_retention(p_org,p_site,p_days,p_hold)$r$;
revoke all on function public.sec_audit_retention(uuid,uuid,integer,boolean) from public,anon;
grant execute on function public.sec_audit_retention(uuid,uuid,integer,boolean) to authenticated;
commit;
