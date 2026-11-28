-- Keyset pagination over the existing RLS-preserving projection, never a privileged data read.
begin;
create or replace function public.sec_audit_page(p_org uuid,p_site uuid,p_source text,p_before jsonb default null) returns jsonb language plpgsql security invoker set search_path=pg_catalog as $f$
declare result jsonb;cursor_at timestamptz;cursor_source text;cursor_id uuid;cursor_actor uuid;n int;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'audit denied' using errcode='42501';end if;
 if p_source is null or p_source not in ('all','field','service','erp','support','fire_ack','admin','access','catalog') then raise exception 'invalid source' using errcode='22023';end if;
 if p_before is not null and p_before<>'null'::jsonb then
  if jsonb_typeof(p_before)<>'object' or p_before-'created_at'-'source'-'id'-'actor_id'<>'{}'::jsonb then raise exception 'invalid cursor' using errcode='22023';end if;
  cursor_at:=(p_before->>'created_at')::timestamptz;cursor_source:=p_before->>'source';cursor_id:=(p_before->>'id')::uuid;cursor_actor:=(p_before->>'actor_id')::uuid;
  if cursor_at is null or cursor_source is null or cursor_id is null or cursor_actor is null then raise exception 'invalid cursor' using errcode='22023';end if;
 end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.source desc,x.id desc,x.actor_id desc),'[]'::jsonb) into result from
 (select * from public.sec_audit_timeline a where a.organization_id=p_org and a.site_id=p_site and (p_source='all' or a.source=p_source) and (cursor_at is null or (a.created_at,a.source,a.id,a.actor_id)<(cursor_at,cursor_source,cursor_id,cursor_actor)) order by a.created_at desc,a.source desc,a.id desc,a.actor_id desc limit 101)x;
 n:=jsonb_array_length(result);
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'source',p_source,'rows',case when n>100 then result-100 else result end,
 'next',case when n>100 then jsonb_build_object('created_at',result->99->'created_at','source',result->99->'source','id',result->99->'id','actor_id',result->99->'actor_id') else null end);
end $f$;
revoke all on function public.sec_audit_page(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.sec_audit_page(uuid,uuid,text,jsonb) to authenticated;
commit;
