-- Personal evidence inventory, bounded keyset pagination and server-side byte integrity checks.
begin;
create index sec_evidence_inventory_scope on public.sec_evidence_files(organization_id,site_id,owner_id,created_at desc,id desc);
create function sec_private.evidence_inventory(p_org uuid,p_site uuid,p_before timestamptz default null,p_before_id uuid default null,p_verify uuid default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v jsonb;total bigint;bytes bigint;next_at timestamptz;next_id uuid;n int;checked jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) or (p_verify is not null and p_before is not null) then raise exception 'invalid operation' using errcode='22023';end if;
 if p_verify is not null then
  select jsonb_build_object('id',f.id,'size_matches',coalesce(octet_length(c.content)=f.size_bytes,false),'digest_matches',coalesce(encode(sha256(c.content),'hex')=f.digest,false),'checked_at',clock_timestamp()) into checked
  from public.sec_evidence_files f left join sec_private.evidence_content c using(id)
  where f.id=p_verify and f.organization_id=p_org and f.site_id=p_site and f.owner_id=auth.uid();
  if checked is null then
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,outcome) values(p_org,p_site,auth.uid(),'evidence_integrity_check','denied');
   return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'verification',null,'denied',true);
  end if;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_integrity_check',p_verify);
  return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'verification',checked,'denied',false);
 end if;
 select count(*),coalesce(sum(size_bytes),0) into total,bytes from public.sec_evidence_files where organization_id=p_org and site_id=p_site and owner_id=auth.uid();
 with batch as (select id,reference,digest,size_bytes,created_at from public.sec_evidence_files where organization_id=p_org and site_id=p_site and owner_id=auth.uid() and (p_before is null or (created_at,id)<(p_before,p_before_id)) order by created_at desc,id desc limit 101),
 page as(select * from batch order by created_at desc,id desc limit 100)
 select coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id desc) from page x),'[]'::jsonb),(select count(*) from batch),(select created_at from page order by created_at,id limit 1),(select id from page order by created_at,id limit 1) into v,n,next_at,next_id;
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_inventory_read',p_site);
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'files',v,'total_files',total,'total_bytes',bytes,'max_file_bytes',262144,'quota_configured',false,'next',case when n>100 then jsonb_build_object('before',next_at,'before_id',next_id) end);
end $f$;
revoke all on function sec_private.evidence_inventory(uuid,uuid,timestamptz,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.evidence_inventory(uuid,uuid,timestamptz,uuid,uuid) to authenticated;
create function public.sec_evidence_inventory(p_org uuid,p_site uuid,p_before timestamptz default null,p_before_id uuid default null,p_verify uuid default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.evidence_inventory(p_org,p_site,p_before,p_before_id,p_verify)$r$;
revoke all on function public.sec_evidence_inventory(uuid,uuid,timestamptz,uuid,uuid) from public,anon;
grant execute on function public.sec_evidence_inventory(uuid,uuid,timestamptz,uuid,uuid) to authenticated;
commit;
