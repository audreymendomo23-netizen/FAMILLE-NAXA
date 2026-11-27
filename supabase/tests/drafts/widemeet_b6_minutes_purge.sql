begin;
insert into auth.users(id) values('00000000-0000-4000-8000-000000000087');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values('10000000-0000-4000-8000-000000000087','00000000-0000-4000-8000-000000000087','WM-PURGE087','purge87@example.invalid','Purge fixture');
insert into public.wm_workspaces(id,kind,name) values('20000000-0000-4000-8000-000000000087','enterprise','Purge fixture');
insert into public.wm_memberships(account_id,workspace_id,role) values('10000000-0000-4000-8000-000000000087','20000000-0000-4000-8000-000000000087','promoteur');
do $wm$ begin
 if has_function_privilege('anon','public.wm_b6_minutes_purge_one()','EXECUTE') or has_function_privilege('authenticated','public.wm_b6_minutes_purge_one()','EXECUTE') then raise exception 'purge ACL leak';end if;
end $wm$;
set local role service_role;
do $wm$
declare h uuid:='10000000-0000-4000-8000-000000000087';w uuid:='20000000-0000-4000-8000-000000000087';r uuid:=gen_random_uuid();fresh uuid:=gen_random_uuid();v uuid:=gen_random_uuid();fv uuid:=gen_random_uuid();task uuid:=gen_random_uuid();receipt uuid:=gen_random_uuid();
begin
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values
 (r,w,h,1,jsonb_build_object('id',r,'workspaceId',w,'hostId',h,'revision',1,'status','ended')),
 (fresh,w,h,1,jsonb_build_object('id',fresh,'workspaceId',w,'hostId',h,'revision',1,'status','ended'));
 insert into public.wm_minutes_eligibility(room_id,premium,closed_at,retain_until,snapshot) values
 (r,true,now()-interval '91 days',now()-interval '1 day','{"title":"private old"}'),
 (fresh,true,now(),now()+interval '90 days','{"title":"private fresh"}');
 insert into public.wm_minutes_versions(id,room_id,version,author_id,body,approved_at,published_at) values
 (v,r,1,h,'private expired body',now(),now()),(fv,fresh,1,h,'private fresh body',now(),now());
 insert into public.wm_minutes_recipients(version_id,account_id) values(v,h);
 insert into public.wm_minutes_exports(request_id,version_id,account_id) values(receipt,v,h);
 insert into public.wm_tasks(id,room_id,version_id,assignee_id,created_by,title,due_at,evidence) values(task,r,v,h,h,'private title',now(),'private evidence');
 if public.wm_b6_minutes_purge_one() is distinct from r then raise exception 'wrong expired room';end if;
 if not exists(select 1 from public.wm_minutes_eligibility where room_id=r and snapshot='{}' and content_purged_at is not null) then raise exception 'snapshot retained';end if;
 if not exists(select 1 from public.wm_minutes_versions where id=v and body='[expired]' and revoked_at is not null) then raise exception 'body retained';end if;
 if not exists(select 1 from public.wm_tasks where id=task and title='[expired]' and evidence is null and state='cancelled') then raise exception 'task data retained';end if;
 if not exists(select 1 from public.wm_minutes_recipients where version_id=v and revoked_at is not null) or not exists(select 1 from public.wm_minutes_exports where request_id=receipt) then raise exception 'access or audit invariant';end if;
 if public.wm_b6_minutes_purge_one() is not null or not exists(select 1 from public.wm_minutes_versions where id=fv and body='private fresh body' and revoked_at is null) then raise exception 'fresh data affected or non-idempotent';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_B6_MINUTES_PURGE_SQL_PASS';
