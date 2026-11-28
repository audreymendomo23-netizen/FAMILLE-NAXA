-- Explicit technical site limits; do not imply commercial plan quotas or authorize deletion.
begin;
create table sec_private.evidence_site_policy(
 organization_id uuid not null,site_id uuid not null,max_bytes bigint not null check(max_bytes between 1 and 9007199254740991),
 retention_days integer not null check(retention_days between 1 and 3650),legal_hold boolean not null default true,
 changed_by uuid not null references auth.users(id),changed_at timestamptz not null default clock_timestamp(),
 primary key(organization_id,site_id),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
revoke all on sec_private.evidence_site_policy from public,anon,authenticated;
create index evidence_site_volume on public.sec_evidence_files(organization_id,site_id,created_at);
create function sec_private.evidence_limit_guard() returns trigger language plpgsql security definer set search_path=pg_catalog as $f$
declare cap bigint;used numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text||':'||new.site_id::text,431));
 select max_bytes into cap from sec_private.evidence_site_policy where organization_id=new.organization_id and site_id=new.site_id;
 if cap is not null then
  select coalesce(sum(size_bytes),0) into used from public.sec_evidence_files where organization_id=new.organization_id and site_id=new.site_id;
  if used+new.size_bytes>cap then raise exception 'site storage limit exceeded' using errcode='22023';end if;
 end if;
 return new;
end $f$;
revoke all on function sec_private.evidence_limit_guard() from public,anon,authenticated;
create trigger evidence_limit_before_insert before insert on public.sec_evidence_files for each row execute function sec_private.evidence_limit_guard();
create function sec_private.evidence_site_policy_rpc(p_org uuid,p_site uuid,p_max_bytes bigint default null,p_retention_days integer default null,p_hold boolean default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v sec_private.evidence_site_policy%rowtype;used numeric;n bigint;old_n bigint:=0;old_bytes numeric:=0;cutoff timestamptz;
begin
 if sec_private.field_role(p_org,p_site) is distinct from 'owner' then raise exception 'owner required' using errcode='42501';end if;
 if not ((p_max_bytes is null and p_retention_days is null and p_hold is null) or (p_max_bytes is not null and p_retention_days is not null and p_hold is not null)) or (p_max_bytes is not null and (p_max_bytes not between 1 and 9007199254740991 or p_retention_days not between 1 and 3650)) then raise exception 'invalid policy' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,431));
 select count(*),coalesce(sum(size_bytes),0) into n,used from public.sec_evidence_files where organization_id=p_org and site_id=p_site;
 if p_max_bytes is not null then
  if p_max_bytes<used then raise exception 'limit below existing volume' using errcode='22023';end if;
  insert into sec_private.evidence_site_policy(organization_id,site_id,max_bytes,retention_days,legal_hold,changed_by) values(p_org,p_site,p_max_bytes,p_retention_days,p_hold,auth.uid())
  on conflict(organization_id,site_id) do update set max_bytes=excluded.max_bytes,retention_days=excluded.retention_days,legal_hold=excluded.legal_hold,changed_by=excluded.changed_by,changed_at=clock_timestamp() returning * into v;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_policy_change',p_site);
 else
  select * into v from sec_private.evidence_site_policy where organization_id=p_org and site_id=p_site;
 end if;
 if v.retention_days is not null and not v.legal_hold then
  cutoff:=now()-make_interval(days=>v.retention_days);
  -- Preview excludes every file with a historical case, share or support reference, not just active grants.
  select count(*),coalesce(sum(f.size_bytes),0) into old_n,old_bytes from public.sec_evidence_files f
  where f.organization_id=p_org and f.site_id=p_site and f.created_at<cutoff
  and not exists(select 1 from public.sec_incident_notes n where n.evidence_id=f.id)
  and not exists(select 1 from sec_private.evidence_shares s where s.evidence_id=f.id)
  and not exists(select 1 from sec_private.support_attachments a where a.evidence_id=f.id);
 end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'configured',v.max_bytes is not null,'technical_max_bytes',v.max_bytes,'total_bytes',used,'total_files',n,'retention_days',v.retention_days,'legal_hold',coalesce(v.legal_hold,true),'unreferenced_old_files',old_n,'unreferenced_old_bytes',old_bytes,'preview_only',true,'commercial_quota',false);
end $f$;
revoke all on function sec_private.evidence_site_policy_rpc(uuid,uuid,bigint,integer,boolean) from public,anon,authenticated;
grant execute on function sec_private.evidence_site_policy_rpc(uuid,uuid,bigint,integer,boolean) to authenticated;
create function public.sec_evidence_site_policy(p_org uuid,p_site uuid,p_max_bytes bigint default null,p_retention_days integer default null,p_hold boolean default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.evidence_site_policy_rpc(p_org,p_site,p_max_bytes,p_retention_days,p_hold)$r$;
revoke all on function public.sec_evidence_site_policy(uuid,uuid,bigint,integer,boolean) from public,anon;
grant execute on function public.sec_evidence_site_policy(uuid,uuid,bigint,integer,boolean) to authenticated;
commit;
