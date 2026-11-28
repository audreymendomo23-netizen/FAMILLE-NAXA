-- Explicit, recipient-bound, temporary sharing of personal evidence. No anonymous URL.
begin;
create table sec_private.evidence_shares(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,evidence_id uuid not null references public.sec_evidence_files(id),
 owner_id uuid not null references auth.users(id),recipient_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),expires_at timestamptz not null,revoked_at timestamptz,
 check(owner_id<>recipient_id),check(expires_at>created_at and expires_at<=created_at+interval '24 hours'),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
revoke all on sec_private.evidence_shares from public,anon,authenticated;
create index evidence_share_scope on sec_private.evidence_shares(organization_id,site_id,recipient_id,expires_at);
create function sec_private.evidence_share_active(p_org uuid,p_site uuid,p_user uuid) returns boolean language sql stable security definer set search_path=pg_catalog as $f$
 select exists(select 1 from public.sec_memberships m join public.sec_site_memberships sm using(organization_id,user_id)
 join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id
 where m.organization_id=p_org and sm.site_id=p_site and m.user_id=p_user and m.active and sm.active and s.active and o.active and m.role in ('owner','manager','operator'))
$f$;
revoke all on function sec_private.evidence_share_active(uuid,uuid,uuid) from public,anon,authenticated;
create function sec_private.evidence_share(p_org uuid,p_site uuid,p_op text,p_id uuid default null,p_evidence uuid default null,p_recipient uuid default null,p_minutes integer default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare f public.sec_evidence_files%rowtype;v sec_private.evidence_shares%rowtype;rows jsonb;result jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 if p_op='create' then
  if p_id is null or p_evidence is null or p_recipient is null or p_recipient=auth.uid() or p_minutes is null or p_minutes not between 1 and 1440 then raise exception 'invalid share' using errcode='22023';end if;
  select * into f from public.sec_evidence_files where id=p_evidence and organization_id=p_org and site_id=p_site and owner_id=auth.uid();
  if not found or not sec_private.evidence_share_active(p_org,p_site,p_recipient) then raise exception 'share denied' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,319));
  select * into v from sec_private.evidence_shares where id=p_id;
  if found then
   if v.organization_id<>p_org or v.site_id<>p_site or v.owner_id<>auth.uid() or v.evidence_id<>p_evidence or v.recipient_id<>p_recipient or v.expires_at-v.created_at<>make_interval(mins=>p_minutes) then raise exception 'event conflict' using errcode='23505';end if;
  else
   insert into sec_private.evidence_shares(id,organization_id,site_id,evidence_id,owner_id,recipient_id,expires_at) values(p_id,p_org,p_site,p_evidence,auth.uid(),p_recipient,now()+make_interval(mins=>p_minutes)) returning * into v;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_share_create',v.id);
  end if;
  result:=to_jsonb(v);
 elsif p_op='revoke' then
  if p_id is null or p_evidence is not null or p_recipient is not null or p_minutes is not null then raise exception 'invalid revoke' using errcode='22023';end if;
  select * into v from sec_private.evidence_shares where id=p_id and organization_id=p_org and site_id=p_site and owner_id=auth.uid() for update;
  if not found then raise exception 'share denied' using errcode='42501';end if;
  if v.revoked_at is null then update sec_private.evidence_shares set revoked_at=clock_timestamp() where id=v.id returning * into v;insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_share_revoke',v.id);end if;
  result:=to_jsonb(v);
 elsif p_op='list' then
  if p_id is not null or p_evidence is not null or p_recipient is not null or p_minutes is not null then raise exception 'invalid list' using errcode='22023';end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id),'[]'::jsonb) into rows from
  (select sh.id,sh.evidence_id,sh.owner_id,sh.recipient_id,sh.created_at,sh.expires_at,sh.revoked_at,ef.reference from sec_private.evidence_shares sh join public.sec_evidence_files ef on ef.id=sh.evidence_id and ef.organization_id=sh.organization_id and ef.site_id=sh.site_id and ef.owner_id=sh.owner_id where sh.organization_id=p_org and sh.site_id=p_site and (sh.owner_id=auth.uid() or (sh.recipient_id=auth.uid() and sh.revoked_at is null and sh.expires_at>now() and sec_private.evidence_share_active(p_org,p_site,sh.owner_id))) order by sh.created_at desc,sh.id limit 100)x;
  result:=jsonb_build_object('shares',rows);
 else raise exception 'invalid operation' using errcode='22023';end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'operation',p_op,'result',result);
end $f$;
revoke all on function sec_private.evidence_share(uuid,uuid,text,uuid,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function sec_private.evidence_share(uuid,uuid,text,uuid,uuid,uuid,integer) to authenticated;
create function public.sec_evidence_share(p_org uuid,p_site uuid,p_op text,p_id uuid default null,p_evidence uuid default null,p_recipient uuid default null,p_minutes integer default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.evidence_share(p_org,p_site,p_op,p_id,p_evidence,p_recipient,p_minutes)$r$;
revoke all on function public.sec_evidence_share(uuid,uuid,text,uuid,uuid,uuid,integer) from public,anon;
grant execute on function public.sec_evidence_share(uuid,uuid,text,uuid,uuid,uuid,integer) to authenticated;
create function sec_private.evidence_share_download(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v sec_private.evidence_shares%rowtype;data jsonb;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 select * into v from sec_private.evidence_shares where id=p_id and organization_id=p_org and site_id=p_site and recipient_id=auth.uid() and revoked_at is null and expires_at>now() for update;
 if not found or not sec_private.evidence_share_active(p_org,p_site,v.owner_id) then raise exception 'share denied' using errcode='42501';end if;
 select jsonb_build_object('share_id',v.id,'id',f.id,'digest',f.digest,'base64',replace(encode(c.content,'base64'),E'\n',''),'organization_id',p_org,'site_id',p_site,'actor_id',auth.uid()) into data
 from public.sec_evidence_files f join sec_private.evidence_content c using(id)
 where f.id=v.evidence_id and f.organization_id=p_org and f.site_id=p_site and f.owner_id=v.owner_id;
 if data is null then raise exception 'share denied' using errcode='42501';end if;
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'evidence_share_download',v.id);
 return data;
end $f$;
revoke all on function sec_private.evidence_share_download(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.evidence_share_download(uuid,uuid,uuid) to authenticated;
create function public.sec_evidence_share_download(p_org uuid,p_site uuid,p_id uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.evidence_share_download(p_org,p_site,p_id)$r$;
revoke all on function public.sec_evidence_share_download(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_evidence_share_download(uuid,uuid,uuid) to authenticated;
commit;
