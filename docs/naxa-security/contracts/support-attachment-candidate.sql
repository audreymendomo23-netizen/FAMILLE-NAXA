-- Case-scoped explicit attachments reuse the existing bounded evidence store.
begin;
create table sec_private.support_attachments(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,case_id uuid not null references public.sec_support_cases(id),
 evidence_id uuid not null references public.sec_evidence_files(id),owner_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),revoked_at timestamptz,
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
revoke all on sec_private.support_attachments from public,anon,authenticated;
create index support_attachment_case on sec_private.support_attachments(organization_id,site_id,case_id,created_at);
create function sec_private.support_attachment(p_org uuid,p_site uuid,p_case uuid,p_op text,p_id uuid default null,p_evidence uuid default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare c public.sec_support_cases%rowtype;v sec_private.support_attachments%rowtype;result jsonb;customer boolean;agent boolean;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 select * into c from public.sec_support_cases where id=p_case and organization_id=p_org and site_id=p_site for update;
 if not found then raise exception 'case denied' using errcode='42501';end if;
 customer:=c.requester_id=auth.uid();agent:=coalesce(c.agent_id=auth.uid(),false) and sec_private.is_support_agent(p_org,p_site) and c.state in ('assigned','waiting_customer');
 if not(customer or agent) then raise exception 'case denied' using errcode='42501';end if;
 if p_op='list' and p_id is null and p_evidence is null then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id),'[]'::jsonb) into result from
  (select s.id,s.evidence_id,s.owner_id,s.created_at,s.revoked_at,f.reference,f.digest,f.size_bytes from sec_private.support_attachments s join public.sec_evidence_files f on f.id=s.evidence_id and f.owner_id=s.owner_id and f.organization_id=s.organization_id and f.site_id=s.site_id where s.organization_id=p_org and s.site_id=p_site and s.case_id=p_case and (s.owner_id=auth.uid() or s.revoked_at is null) order by s.created_at desc,s.id limit 100)x;
 elsif p_op='add' and p_id is not null and p_evidence is not null and c.state in ('open','assigned','waiting_customer') then
  if not exists(select 1 from public.sec_evidence_files where id=p_evidence and owner_id=auth.uid() and organization_id=p_org and site_id=p_site) then raise exception 'evidence denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,381));
  select * into v from sec_private.support_attachments where id=p_id;
  if found then
   if v.organization_id<>p_org or v.site_id<>p_site or v.case_id<>p_case or v.owner_id<>auth.uid() or v.evidence_id<>p_evidence then raise exception 'event conflict' using errcode='23505';end if;
  else
   if (select count(*) from sec_private.support_attachments where case_id=p_case and revoked_at is null)>=100 then raise exception 'attachment limit' using errcode='22023';end if;
   insert into sec_private.support_attachments(id,organization_id,site_id,case_id,evidence_id,owner_id) values(p_id,p_org,p_site,p_case,p_evidence,auth.uid()) returning * into v;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'support_attachment_add',v.id);
  end if;
  result:=to_jsonb(v);
 elsif p_op='revoke' and p_id is not null and p_evidence is null then
  select * into v from sec_private.support_attachments where id=p_id and organization_id=p_org and site_id=p_site and case_id=p_case and owner_id=auth.uid() for update;
  if not found then raise exception 'attachment denied' using errcode='42501';end if;
  if v.revoked_at is null then update sec_private.support_attachments set revoked_at=clock_timestamp() where id=v.id returning * into v;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'support_attachment_revoke',v.id);end if;
  result:=to_jsonb(v);
 elsif p_op='download' and p_id is not null and p_evidence is null then
  select * into v from sec_private.support_attachments where id=p_id and organization_id=p_org and site_id=p_site and case_id=p_case and revoked_at is null for update;
  if not found then raise exception 'attachment denied' using errcode='42501';end if;
  select jsonb_build_object('id',v.id,'evidence_id',f.id,'digest',f.digest,'base64',replace(encode(b.content,'base64'),E'\n','')) into result from public.sec_evidence_files f join sec_private.evidence_content b using(id) where f.id=v.evidence_id and f.organization_id=p_org and f.site_id=p_site and f.owner_id=v.owner_id;
  if result is null then raise exception 'attachment denied' using errcode='42501';end if;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'support_attachment_download',v.id);
 else raise exception 'invalid operation' using errcode='22023';end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'case_id',p_case,'operation',p_op,'result',result);
end $f$;
revoke all on function sec_private.support_attachment(uuid,uuid,uuid,text,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.support_attachment(uuid,uuid,uuid,text,uuid,uuid) to authenticated;
create function public.sec_support_attachment(p_org uuid,p_site uuid,p_case uuid,p_op text,p_id uuid default null,p_evidence uuid default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.support_attachment(p_org,p_site,p_case,p_op,p_id,p_evidence)$r$;
revoke all on function public.sec_support_attachment(uuid,uuid,uuid,text,uuid,uuid) from public,anon;
grant execute on function public.sec_support_attachment(uuid,uuid,uuid,text,uuid,uuid) to authenticated;
commit;
