-- Adapted from NAXA Services staff break and variable pay approval; ZIPPLE actor and site scope.
begin;
create table public.zp_hr_requests(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,author_id uuid not null,
 kind text not null check(kind in ('absence','bonus','commission','advance')),from_day date not null,to_day date not null,
 amount_xaf int,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default clock_timestamp(),
 check(to_day>=from_day and to_day-from_day<=365),check((kind='absence' and amount_xaf is null) or (kind<>'absence' and amount_xaf is not null and amount_xaf>0)),
 unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(author_id,org_id) references public.zp_members(id,org_id));
create table public.zp_hr_decisions(
 request_id uuid primary key,org_id uuid not null,site_id uuid not null,actor_id uuid not null,decision text not null check(decision in ('approved','rejected','cancelled')),
 reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default clock_timestamp(),
 foreign key(request_id,org_id,site_id) references public.zp_hr_requests(id,org_id,site_id),foreign key(actor_id,org_id) references public.zp_members(id,org_id));
alter table public.zp_hr_requests enable row level security;
alter table public.zp_hr_decisions enable row level security;
revoke all on public.zp_hr_requests,public.zp_hr_decisions from public,anon,authenticated;
grant select,insert on public.zp_hr_requests,public.zp_hr_decisions to service_role;
create function public.zp_hr_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;manage boolean;owner boolean;begin
 m:=public.zp_business_actor(p_access,p_site);manage:=m.role_code in ('promoteur','manager');owner:=m.role_code='promoteur';
 return jsonb_build_object('member_id',m.id,'can_manage',manage,'can_approve_pay',owner,
 'members',case when manage then coalesce((select jsonb_agg(to_jsonb(q) order by q.label) from (select u.id,coalesce(p.display_name,u.login_id) label from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id left join public.zp_profile_details p on p.member_id=u.id where s.org_id=m.org_id and s.site_id=p_site and u.active and not u.reset_pending order by u.id limit 200)q),'[]') else '[]'::jsonb end,
 'rows',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select x.id,x.kind,x.member_id,coalesce(p.display_name,u.login_id) label,x.author_id,x.from_day,x.to_day,x.amount_xaf,x.reason,x.created_at,coalesce(d.decision,'pending') state,d.reason decision_reason,d.actor_id,d.created_at decided_at from public.zp_hr_requests x join public.zp_members u on u.id=x.member_id left join public.zp_profile_details p on p.member_id=u.id left join public.zp_hr_decisions d on d.request_id=x.id where x.org_id=m.org_id and x.site_id=p_site and (x.member_id=m.id or x.author_id=m.id or owner or (manage and x.kind='absence')) order by x.created_at desc limit 200)q),'[]'));
end $f$;
create function public.zp_hr_write(p_access text,p_site uuid,p_action text,p_request uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;old public.zp_workspace_requests;x public.zp_hr_requests;target uuid;k text;why text;lo date;hi date;amount int;decision_code text;rid uuid;outcome jsonb;manage boolean;begin
 m:=public.zp_business_actor(p_access,p_site);manage:=m.role_code in ('promoteur','manager');
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or length(p_payload::text)>4000 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_sites where id=p_site and org_id=m.org_id for update;
 select * into old from public.zp_workspace_requests where member_id=m.id and request_id=p_request;
 if old.request_id is not null then if (old.site_id,old.action,old.payload) is distinct from (p_site,'hr:'||p_action,p_payload) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.outcome;end if;
 why:=trim(coalesce(p_payload->>'reason',''));if length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 if p_action='submit' then
 k:=p_payload->>'kind';target:=coalesce(nullif(p_payload->>'member_id','')::uuid,m.id);lo:=(p_payload->>'from_day')::date;hi:=(p_payload->>'to_day')::date;amount:=nullif(p_payload->>'amount_xaf','')::int;
 if k is null or k not in ('absence','bonus','commission','advance') or lo is null or hi is null or hi<lo or hi-lo>365 or (k='absence' and amount is not null) or (k<>'absence' and (amount is null or amount<=0)) then raise exception 'INVALID_INPUT';end if;
 if (not manage and (target<>m.id or k<>'absence')) or not exists(select 1 from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id where s.site_id=p_site and s.org_id=m.org_id and s.member_id=target and u.active and not u.reset_pending) then raise exception 'DENIED';end if;
 perform 1 from public.zp_members where id=target and org_id=m.org_id for update;
 if k='absence' and exists(select 1 from public.zp_hr_requests q left join public.zp_hr_decisions d on d.request_id=q.id where q.org_id=m.org_id and q.member_id=target and q.kind='absence' and coalesce(d.decision,'pending') in ('pending','approved') and q.from_day<=hi and q.to_day>=lo) then raise exception 'ABSENCE_OVERLAP';end if;
 insert into public.zp_hr_requests(org_id,site_id,member_id,author_id,kind,from_day,to_day,amount_xaf,reason) values(m.org_id,p_site,target,m.id,k,lo,hi,amount,why) returning id into rid;
 elsif p_action='decide' then
 select * into x from public.zp_hr_requests where id=(p_payload->>'id')::uuid and org_id=m.org_id and site_id=p_site for update;
 decision_code:=p_payload->>'decision';if x.id is null or decision_code is null or decision_code not in ('approved','rejected','cancelled') then raise exception 'DENIED';end if;
 if decision_code='cancelled' then if x.author_id<>m.id and not (m.role_code='promoteur' or (manage and x.kind='absence')) then raise exception 'DENIED';end if;
 elsif not (m.role_code='promoteur' or (manage and x.kind='absence')) then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_hr_decisions d where d.request_id=x.id) then raise exception 'INVALID_TRANSITION';end if;
 insert into public.zp_hr_decisions(request_id,org_id,site_id,actor_id,decision,reason) values(x.id,m.org_id,p_site,m.id,decision_code,why);rid:=x.id;
 else raise exception 'INVALID_INPUT';end if;
 outcome:=jsonb_build_object('id',rid,'confirmed',true);
 insert into public.zp_workspace_requests(member_id,org_id,site_id,request_id,action,payload,outcome) values(m.id,m.org_id,p_site,p_request,'hr:'||p_action,p_payload,outcome);return outcome;
end $f$;
revoke all on function public.zp_hr_snapshot(text,uuid),public.zp_hr_write(text,uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.zp_hr_snapshot(text,uuid),public.zp_hr_write(text,uuid,text,uuid,jsonb) to service_role;
commit;
