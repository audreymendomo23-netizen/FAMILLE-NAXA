-- ZIPPLE professional workspace. Adapt NAXA Services management records, inbox
-- and explainable performance model; keep ZIPPLE's actor, subscription and site scopes.
begin;
create table public.zp_profile_details(
 org_id uuid not null,member_id uuid not null,display_name text not null check(length(display_name) between 1 and 120),
 phone text not null check(phone='' or phone~'^[0-9]{9,15}$'),language text not null check(language in ('fr','en')),
 updated_at timestamptz not null default now(),primary key(member_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_team_details(
 org_id uuid not null,site_id uuid not null,member_id uuid not null,job_title text not null check(length(job_title) between 1 and 120),
 skills text not null check(length(skills)<=500),updated_at timestamptz not null default now(),primary key(site_id,member_id),
 foreign key(site_id,org_id) references public.zp_sites(id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_work_items(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,author_id uuid not null,assignee_id uuid,
 kind text not null check(kind in ('ticket','shift','objective','training','incident')),
 title text not null check(length(title) between 1 and 160),detail text not null check(length(detail) between 1 and 1000),
 category text not null check(length(category) between 1 and 80),priority text not null check(priority in ('normal','urgent')),
 starts_at timestamptz,due_at timestamptz,state text not null default 'open' check(state in ('open','in_progress','done','cancelled')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(kind<>'shift' or (starts_at is not null and due_at>starts_at)),check(kind='ticket' or assignee_id is not null),
 unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id),
 foreign key(author_id,org_id) references public.zp_members(id,org_id),foreign key(assignee_id,org_id) references public.zp_members(id,org_id));
create table public.zp_work_messages(
 id uuid primary key default gen_random_uuid(),work_id uuid not null,org_id uuid not null,site_id uuid not null,member_id uuid not null,
 body text not null check(length(body) between 1 and 1000),created_at timestamptz not null default now(),
 foreign key(work_id,org_id,site_id) references public.zp_work_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_workspace_requests(
 member_id uuid not null,org_id uuid not null,site_id uuid not null,request_id uuid not null,action text not null,payload jsonb not null,outcome jsonb not null,
 created_at timestamptz not null default now(),primary key(member_id,request_id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id));
create table public.zp_inbox_reads(
 org_id uuid not null,site_id uuid not null,member_id uuid not null,event_key text not null,read_at timestamptz not null default now(),
 primary key(member_id,site_id,event_key),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id));
do $g$ declare n text;begin
 foreach n in array array['zp_profile_details','zp_team_details','zp_work_items','zp_work_messages','zp_workspace_requests','zp_inbox_reads'] loop
 execute format('alter table public.%I enable row level security',n);
 execute format('revoke all on public.%I from public,anon,authenticated',n);
 execute format('grant select,insert on public.%I to service_role',n);
 end loop;
end $g$;
grant update on public.zp_profile_details,public.zp_team_details,public.zp_work_items to service_role;
-- Inbox is generated from real scoped business events, not a fabricated push receipt.
create function public.zp_workspace_inbox(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;manage boolean;begin
 m:=public.zp_business_actor(p_access,p_site);manage:=m.role_code in ('promoteur','manager');
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc,x.event_key) from (
 select q.*,exists(select 1 from public.zp_inbox_reads r where r.member_id=m.id and r.site_id=p_site and r.event_key=q.event_key) as is_read from (
 select 'work:'||w.id||':'||w.state||':'||extract(epoch from w.updated_at)::text event_key,w.kind code,w.title label,w.updated_at created_at
 from public.zp_work_items w where w.org_id=m.org_id and w.site_id=p_site and (manage or w.author_id=m.id or w.assignee_id=m.id)
 union all select 'message:'||v.id,'message',w.title,v.created_at from public.zp_work_messages v join public.zp_work_items w on w.id=v.work_id where v.org_id=m.org_id and v.site_id=p_site and v.member_id<>m.id and (manage or w.author_id=m.id or w.assignee_id=m.id)
 union all select 'expense:'||e.id,'expense',e.label,e.created_at from public.zp_expense_requests e where manage and e.org_id=m.org_id and e.site_id=p_site and not exists(select 1 from public.zp_expense_decisions d where d.expense_request_id=e.id)
 union all select 'order:'||o.id||':late','late_order',left(o.id::text,8),o.promised_at from public.zp_orders o where manage and o.org_id=m.org_id and o.site_id=p_site and o.status not in ('served','cancelled') and o.promised_at<now()
 ) q order by q.created_at desc,q.event_key limit 200)x),'[]'::jsonb);
end $f$;
create function public.zp_workspace_snapshot(p_access text,p_site uuid,p_page text) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;manage boolean;kind_filter text;rows jsonb:='[]';members jsonb:='[]';profile jsonb;metrics jsonb;today date:=(now() at time zone 'Africa/Douala')::date;begin
 if p_page='profile' then m:=public.zp_actor(p_access,p_site);else m:=public.zp_business_actor(p_access,p_site);end if;
 manage:=m.role_code in ('promoteur','manager');
 if p_page not in ('profile','team','planning','objectives','training','incidents','tickets','notifications','intelligence') or p_page is null then raise exception 'INVALID_INPUT';end if;
 if p_page in ('team','intelligence') and not manage then raise exception 'DENIED';end if;
 if p_page='profile' then
 select jsonb_build_object('display_name',coalesce(d.display_name,m.login_id),'phone',coalesce(d.phone,''),'language',coalesce(d.language,'fr'),'has_preference',d.member_id is not null,'login',m.login_id,'role',m.role_code,'organization',(select name from public.zp_organizations where id=m.org_id),'site',(select name from public.zp_sites where id=p_site)) into profile from (select 1) z left join public.zp_profile_details d on d.member_id=m.id;
 elsif p_page='notifications' then rows:=public.zp_workspace_inbox(p_access,p_site);
 elsif p_page='intelligence' then metrics:=public.zp_pilotage(p_access,p_site,today-27,today);
 else
 if manage then
 select coalesce(jsonb_agg(to_jsonb(x) order by x.label),'[]') into members from (select u.id,coalesce(d.display_name,u.login_id) label,u.role_code,coalesce(t.job_title,'') job_title,coalesce(t.skills,'') skills from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id left join public.zp_profile_details d on d.member_id=u.id left join public.zp_team_details t on t.member_id=u.id and t.site_id=s.site_id where s.org_id=m.org_id and s.site_id=p_site and u.active and not u.reset_pending order by u.id limit 200)x;
 end if;
 if p_page='team' then rows:=members;
 else
 kind_filter:=case p_page when 'planning' then 'shift' when 'objectives' then 'objective' when 'training' then 'training' when 'incidents' then 'incident' else 'ticket' end;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]') into rows from (
 select w.id,w.title,w.detail,w.category,w.priority,w.state,w.starts_at,w.due_at,w.created_at,w.author_id,w.assignee_id,
 coalesce(p.display_name,u.login_id) assignee,coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'body',v.body,'author',coalesce(dp.display_name,mu.login_id),'created_at',v.created_at) order by v.created_at,v.id) from (select * from public.zp_work_messages msg where msg.work_id=w.id order by msg.created_at desc limit 100)v join public.zp_members mu on mu.id=v.member_id left join public.zp_profile_details dp on dp.member_id=mu.id),'[]') messages
 from public.zp_work_items w left join public.zp_members u on u.id=w.assignee_id left join public.zp_profile_details p on p.member_id=w.assignee_id
 where w.org_id=m.org_id and w.site_id=p_site and w.kind=kind_filter and (manage or w.author_id=m.id or w.assignee_id=m.id) order by w.created_at desc limit 200)x;
 end if;end if;
 return jsonb_build_object('page',p_page,'member_id',m.id,'can_manage',manage,'rows',rows,'members',members,'profile',profile,'metrics',metrics);
end $f$;
create function public.zp_workspace_write(p_access text,p_site uuid,p_action text,p_request uuid,p_payload jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;manage boolean;old public.zp_workspace_requests;w public.zp_work_items;rid uuid;target uuid;k text;title text;detail text;category text;priority text;st timestamptz;due timestamptz;next_state text;key_text text;outcome jsonb;begin
 if p_action='profile_save' then m:=public.zp_actor(p_access,p_site);else m:=public.zp_business_actor(p_access,p_site);end if;
 manage:=m.role_code in ('promoteur','manager');
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or length(p_payload::text)>4000 then raise exception 'INVALID_INPUT';end if;
 -- Lock per site before replay check; profile is additionally serialized per member.
 perform 1 from public.zp_sites where id=p_site and org_id=m.org_id for update;
 if p_action='profile_save' then perform 1 from public.zp_members where id=m.id for update;end if;
 select * into old from public.zp_workspace_requests where member_id=m.id and request_id=p_request;
 if old.request_id is not null then if (old.site_id,old.action,old.payload) is distinct from (p_site,p_action,p_payload) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.outcome;end if;
 if p_action='profile_save' then
 title:=trim(coalesce(p_payload->>'display_name',''));detail:=trim(coalesce(p_payload->>'phone',''));k:=p_payload->>'language';
 if length(title) not between 1 and 120 or (detail<>'' and detail!~'^[0-9]{9,15}$') or k is null or k not in ('fr','en') then raise exception 'INVALID_INPUT';end if;
 insert into public.zp_profile_details(org_id,member_id,display_name,phone,language) values(m.org_id,m.id,title,detail,k) on conflict(member_id) do update set display_name=excluded.display_name,phone=excluded.phone,language=excluded.language,updated_at=now();rid:=m.id;
 elsif p_action='team_save' then
 if not manage then raise exception 'DENIED';end if;
 target:=(p_payload->>'member_id')::uuid;title:=trim(coalesce(p_payload->>'job_title',''));detail:=trim(coalesce(p_payload->>'skills',''));
 if not exists(select 1 from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id where s.site_id=p_site and s.org_id=m.org_id and s.member_id=target and u.active and not u.reset_pending) then raise exception 'DENIED';end if;
 if length(title) not between 1 and 120 or length(detail)>500 then raise exception 'INVALID_INPUT';end if;
 insert into public.zp_team_details(org_id,site_id,member_id,job_title,skills) values(m.org_id,p_site,target,title,detail) on conflict(site_id,member_id) do update set job_title=excluded.job_title,skills=excluded.skills,updated_at=now();rid:=target;
 elsif p_action='work_create' then
 k:=p_payload->>'kind';title:=trim(coalesce(p_payload->>'title',''));detail:=trim(coalesce(p_payload->>'detail',''));category:=trim(coalesce(p_payload->>'category',''));priority:=p_payload->>'priority';
 if k is null or k not in ('ticket','shift','objective','training','incident') or length(title) not between 1 and 160 or length(detail) not between 1 and 1000 or length(category) not between 1 and 80 or priority is null or priority not in ('normal','urgent') then raise exception 'INVALID_INPUT';end if;
 if k<>'ticket' and not manage then raise exception 'DENIED';end if;
 target:=nullif(p_payload->>'assignee_id','')::uuid;st:=nullif(p_payload->>'starts_at','')::timestamptz;due:=nullif(p_payload->>'due_at','')::timestamptz;
 if target is not null and (not manage or not exists(select 1 from public.zp_site_scopes s join public.zp_members u on u.id=s.member_id and u.org_id=s.org_id where s.site_id=p_site and s.org_id=m.org_id and s.member_id=target and u.active and not u.reset_pending)) then raise exception 'DENIED';end if;
 if k<>'ticket' and target is null then raise exception 'INVALID_INPUT';end if;
 if k='shift' then
 perform 1 from public.zp_members where id=target and org_id=m.org_id for update;
 if st is null or due is null or due<=st or due-st>interval '24 hours' then raise exception 'INVALID_INPUT';end if;
 if exists(select 1 from public.zp_work_items x where x.org_id=m.org_id and x.assignee_id=target and x.kind='shift' and x.state<>'cancelled' and x.starts_at<due and x.due_at>st) then raise exception 'SHIFT_OVERLAP';end if;
 elsif st is not null or (k<>'ticket' and due is null) then raise exception 'INVALID_INPUT';end if;
 insert into public.zp_work_items(org_id,site_id,author_id,assignee_id,kind,title,detail,category,priority,starts_at,due_at) values(m.org_id,p_site,m.id,target,k,title,detail,category,priority,st,due) returning id into rid;
 elsif p_action='work_claim' then
 if not manage then raise exception 'DENIED';end if;
 target:=(p_payload->>'work_id')::uuid;select * into w from public.zp_work_items wi where wi.id=target and wi.org_id=m.org_id and wi.site_id=p_site and wi.kind='ticket' for update;
 if w.id is null then raise exception 'DENIED';end if;
 if w.state not in ('open','in_progress') or w.assignee_id is not null then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_work_items set assignee_id=m.id,state='in_progress',updated_at=clock_timestamp() where id=w.id;rid:=w.id;
 elsif p_action in ('work_reply','work_state') then
 target:=(p_payload->>'work_id')::uuid;select * into w from public.zp_work_items where id=target and org_id=m.org_id and site_id=p_site for update;
 if w.id is null or (not manage and m.id<>w.author_id and m.id is distinct from w.assignee_id) then raise exception 'DENIED';end if;
 if p_action='work_reply' then
 detail:=trim(coalesce(p_payload->>'body',''));if length(detail) not between 1 and 1000 or w.state in ('done','cancelled') then raise exception 'INVALID_TRANSITION';end if;
 insert into public.zp_work_messages(work_id,org_id,site_id,member_id,body) values(w.id,m.org_id,p_site,m.id,detail) returning id into rid;
 else
 if not manage then raise exception 'DENIED';end if;
 next_state:=p_payload->>'state';
 if (p_payload->>'expected_state') is distinct from w.state or next_state is null or not ((w.state='open' and next_state in ('in_progress','cancelled')) or (w.state='in_progress' and next_state in ('done','cancelled'))) then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_work_items set state=next_state,updated_at=clock_timestamp() where id=w.id;rid:=w.id;
 end if;
 elsif p_action='inbox_read' then
 key_text:=p_payload->>'event_key';if not exists(select 1 from jsonb_array_elements(public.zp_workspace_inbox(p_access,p_site)) q where q->>'event_key'=key_text) then raise exception 'DENIED';end if;
 insert into public.zp_inbox_reads(org_id,site_id,member_id,event_key) values(m.org_id,p_site,m.id,key_text) on conflict do nothing;
 else raise exception 'INVALID_INPUT';end if;
 outcome:=jsonb_build_object('id',rid,'confirmed',true);
 insert into public.zp_workspace_requests(member_id,org_id,site_id,request_id,action,payload,outcome) values(m.id,m.org_id,p_site,p_request,p_action,p_payload,outcome);return outcome;
end $f$;
do $g$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_workspace_inbox','zp_workspace_snapshot','zp_workspace_write') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $g$;
commit;
