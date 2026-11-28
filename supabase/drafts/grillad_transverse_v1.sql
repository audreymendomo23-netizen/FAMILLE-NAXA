-- Candidate GRILLAD only: reuse the shared Famille support ticket registry; no separate Auth.
begin;
create function grillad_private.support_list(p_org uuid,p_site uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare a uuid;v jsonb;
begin
 perform grillad_private.scope(p_org,p_site);
 select id into a from famille_core.applications where code='grillad';
 select coalesce(jsonb_agg(to_jsonb(t) order by t.updated_at desc),'[]'::jsonb) into v
 from (select id,subject,status,created_at,updated_at from famille_core.support_tickets where app_id=a and organization_id=p_org and user_id=auth.uid() and deleted_at is null order by updated_at desc limit 50)t;
 return v;
end $fn$;
create function grillad_private.support_open(p_org uuid,p_site uuid,p_event uuid,p_subject text,p_description text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare a uuid;u uuid:=auth.uid();t famille_core.support_tickets%rowtype;s text:=btrim(p_subject);d text:=btrim(p_description);
begin
 perform grillad_private.scope(p_org,p_site);
 if p_event is null or s is null or length(s) not between 3 and 120 or d is null or length(d) not between 10 and 2000 or s ~ '[[:cntrl:]]' then raise exception 'GRILLAD_SUPPORT_INPUT' using errcode='22023';end if;
 select id into a from famille_core.applications where code='grillad';
 perform pg_advisory_xact_lock(hashtextextended('grillad-support:'||u::text,0));
 select * into t from famille_core.support_tickets where id=p_event;
 if found then
  if t.user_id<>u or t.app_id<>a or t.organization_id is distinct from p_org or t.subject<>s or t.description<>d or t.deleted_at is not null then raise exception 'GRILLAD_SUPPORT_REPLAY' using errcode='42501';end if;
 else
  if (select count(*) from famille_core.support_tickets where user_id=u and app_id=a and created_at>now()-interval '1 hour')>=5 then raise exception 'GRILLAD_SUPPORT_LIMIT' using errcode='22023';end if;
  insert into famille_core.support_tickets(id,user_id,app_id,organization_id,subject,description) values(p_event,u,a,p_org,s,d) returning * into t;
 end if;
 return jsonb_build_object('id',t.id,'status',t.status,'subject',t.subject);
end $fn$;
-- Central identity only. No membership-based platform_admin fallback; no business detail or ticket text.
create function grillad_private.central_overview() returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare a uuid;sid uuid;allowed boolean:=false;u uuid:=auth.uid();
begin
 if u is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid;exception when invalid_text_representation then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end;
 if sid is null or not exists(select 1 from auth.sessions where id=sid and user_id=u) or to_regclass('famille_core.family_admins') is null then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end if;
 execute 'select exists(select 1 from famille_core.family_admins where user_id=$1 and status=''active'' and revoked_at is null)' into allowed using u;
 if not allowed then raise exception 'GRILLAD_CENTRAL_DENIED' using errcode='42501';end if;
 select id into a from famille_core.applications where code='grillad';
 return jsonb_build_object('app','grillad','organizations',(select count(*) from famille_core.organization_apps where app_id=a and status='active'),'active_subscriptions',(select count(*) from famille_core.subscriptions where app_id=a and status='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now())),'open_support',(select count(*) from famille_core.support_tickets where app_id=a and status in ('open','in_progress','waiting_user') and deleted_at is null));
end $fn$;
create function public.grillad_support_list(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.support_list(p_org,p_site)$fn$;
create function public.grillad_support_open(p_org uuid,p_site uuid,p_event uuid,p_subject text,p_description text) returns jsonb language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.support_open(p_org,p_site,p_event,p_subject,p_description)$fn$;
create function public.grillad_central_overview() returns jsonb language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.central_overview()$fn$;
revoke all on function grillad_private.support_list(uuid,uuid),grillad_private.support_open(uuid,uuid,uuid,text,text),grillad_private.central_overview(),public.grillad_support_list(uuid,uuid),public.grillad_support_open(uuid,uuid,uuid,text,text),public.grillad_central_overview() from public,anon,authenticated;
grant execute on function grillad_private.support_list(uuid,uuid),grillad_private.support_open(uuid,uuid,uuid,text,text),grillad_private.central_overview(),public.grillad_support_list(uuid,uuid),public.grillad_support_open(uuid,uuid,uuid,text,text),public.grillad_central_overview() to authenticated;
commit;
