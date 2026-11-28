-- Full interval export, isolated non-bypass role inheriting the same source RLS.
begin;
create role sec_audit_exporter nologin inherit nosuperuser nocreatedb nocreaterole nobypassrls;
grant authenticated to sec_audit_exporter;
grant usage,create on schema sec_private to sec_audit_exporter;
grant insert on public.sec_access_audit to sec_audit_exporter;
create policy sec_export_trace_insert on public.sec_access_audit for insert to sec_audit_exporter with check(actor_id=auth.uid() and operation='audit_export' and outcome='authorized' and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create function sec_private.audit_export(p_org uuid,p_site uuid,p_source text,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare data jsonb; n integer; trace uuid:=gen_random_uuid();
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'export denied' using errcode='42501';end if;
 if p_source is null or p_source not in ('all','field','service','erp','support','fire_ack','admin','access') or p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '366 days' or p_end>now()+interval '1 minute' then raise exception 'invalid interval or source' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.source desc,x.id desc,x.actor_id desc),'[]'::jsonb) into data from
 (select * from public.sec_audit_timeline a where a.organization_id=p_org and a.site_id=p_site and a.created_at>=p_start and a.created_at<p_end and (p_source='all' or a.source=p_source) order by a.created_at desc,a.source desc,a.id desc,a.actor_id desc limit 10001)x;
 n:=jsonb_array_length(data);
 if n>10000 or octet_length(data::text)>7500000 then raise exception 'export exceeds row or byte limit; split interval' using errcode='22023';end if;
 insert into public.sec_access_audit(id,organization_id,site_id,actor_id,operation,object_id) values(trace,p_org,p_site,auth.uid(),'audit_export',p_site);
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'source',p_source,'start',p_start,'end',p_end,'count',n,'rows',data,'export_id',trace);
end $f$;
alter function sec_private.audit_export(uuid,uuid,text,timestamptz,timestamptz) owner to sec_audit_exporter;
revoke create on schema sec_private from sec_audit_exporter;
revoke all on function sec_private.audit_export(uuid,uuid,text,timestamptz,timestamptz) from public,anon,authenticated;
grant execute on function sec_private.audit_export(uuid,uuid,text,timestamptz,timestamptz) to authenticated;
create function public.sec_audit_export(p_org uuid,p_site uuid,p_source text,p_start timestamptz,p_end timestamptz) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.audit_export(p_org,p_site,p_source,p_start,p_end)$r$;
revoke all on function public.sec_audit_export(uuid,uuid,text,timestamptz,timestamptz) from public,anon;
grant execute on function public.sec_audit_export(uuid,uuid,text,timestamptz,timestamptz) to authenticated;
commit;
