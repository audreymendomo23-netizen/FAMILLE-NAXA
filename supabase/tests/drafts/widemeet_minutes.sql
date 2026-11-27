begin;
insert into auth.users(id) values('00000000-0000-4000-8000-000000000091'),('00000000-0000-4000-8000-000000000092'),('00000000-0000-4000-8000-000000000093');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
('10000000-0000-4000-8000-000000000091','00000000-0000-4000-8000-000000000091','WM-MINHOST01','minhost@example.invalid','Host'),
('10000000-0000-4000-8000-000000000092','00000000-0000-4000-8000-000000000092','WM-MINGUEST1','minguest@example.invalid','Guest'),
('10000000-0000-4000-8000-000000000093','00000000-0000-4000-8000-000000000093','WM-MINOTHER1','minother@example.invalid','Other');
insert into public.wm_workspaces(id,kind,name) values('20000000-0000-4000-8000-000000000091','enterprise','Minutes fixtures');
insert into public.wm_memberships(account_id,workspace_id,role) values
('10000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','promoteur'),
('10000000-0000-4000-8000-000000000092','20000000-0000-4000-8000-000000000091','staff'),
('10000000-0000-4000-8000-000000000093','20000000-0000-4000-8000-000000000091','staff');
insert into public.wm_room_entitlements(workspace_id,plan,enabled,valid_until) values('20000000-0000-4000-8000-000000000091','premium',true,now()+interval '2 hours');
do $wm$ begin
 if has_table_privilege('authenticated','public.wm_minutes_versions','SELECT') or has_function_privilege('anon','public.wm_minutes_action(text,text,jsonb)','EXECUTE') then raise exception 'minutes ACL leak';end if;
end $wm$;
set local role service_role;
do $wm$
declare h uuid:='10000000-0000-4000-8000-000000000091';g uuid:='10000000-0000-4000-8000-000000000092';o uuid:='10000000-0000-4000-8000-000000000093';w uuid:='20000000-0000-4000-8000-000000000091';r uuid:=gen_random_uuid();v1 uuid:=gen_random_uuid();v2 uuid:=gen_random_uuid();s jsonb;d jsonb;p jsonb;rr jsonb;
begin
 perform public.wm_issue_verified_session(h,gen_random_uuid(),w,repeat('a',64),0);
 perform public.wm_issue_verified_session(g,gen_random_uuid(),w,repeat('b',64),0);
 perform public.wm_issue_verified_session(o,gen_random_uuid(),w,repeat('c',64),0);
 s:=jsonb_build_object('id',r::text,'workspaceId',w::text,'hostId',h::text,'revision',1,'title','Minutes fixture','status','open','recording','off','participants',jsonb_build_array(jsonb_build_object('memberId',h,'response','accepted','excluded',false),jsonb_build_object('memberId',g,'response','accepted','excluded',false),jsonb_build_object('memberId',o,'response','accepted','excluded',false)),'events','[]'::jsonb);
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(r,w,h,1,s);
 update public.wm_rooms set state=jsonb_set(jsonb_set(s,'{status}','"ended"'),'{revision}','2'),revision=2 where id=r;
 if not exists(select 1 from public.wm_minutes_eligibility where room_id=r and premium) then raise exception 'missing closure eligibility';end if;
 update public.wm_room_entitlements set valid_until=clock_timestamp()-interval '1 hour' where workspace_id=w;
 d:=jsonb_build_object('room_id',r,'version_id',v1,'expected_version',0,'body','Human draft');
 if public.wm_minutes_action(repeat('b',64),'draft',d) is not null then raise exception 'staff drafted minutes';end if;
 if public.wm_minutes_action(repeat('a',64),'draft',d)->>'version' is distinct from '1' then raise exception 'draft after entitlement expiry failed';end if;
 if public.wm_minutes_action(repeat('a',64),'draft',d)->>'version' is distinct from '1' then raise exception 'draft retry failed';end if;
 if public.wm_minutes_action(repeat('a',64),'draft',d||jsonb_build_object('body','Changed')) is not null then raise exception 'version overwritten';end if;
 p:=jsonb_build_object('room_id',r,'version_id',v1,'recipients',jsonb_build_array(g));
 if public.wm_minutes_action(repeat('a',64),'publish',p) is not null then raise exception 'unapproved published';end if;
 if public.wm_minutes_action(repeat('b',64),'read',p) is not null then raise exception 'draft leaked';end if;
 if public.wm_minutes_action(repeat('a',64),'approve',p)->>'approved' is distinct from 'true' then raise exception 'approve failed';end if;
 if public.wm_minutes_action(repeat('a',64),'publish',p)->>'published' is distinct from 'true' then raise exception 'publish failed';end if;
 if public.wm_minutes_action(repeat('c',64),'read',p) is not null then raise exception 'unselected recipient read';end if;
 rr:=public.wm_minutes_action(repeat('b',64),'read',p);
 if rr->>'body' is distinct from 'Human draft' or (rr->'snapshot') ? 'participants' then raise exception 'recipient projection incorrect';end if;
 if not exists(select 1 from public.wm_minutes_recipients where version_id=v1 and account_id=g and read_at is not null) then raise exception 'read audit absent';end if;
 d:=jsonb_build_object('room_id',r,'version_id',v2,'expected_version',1,'body','Revised human draft');
 if public.wm_minutes_action(repeat('a',64),'draft',d)->>'version' is distinct from '2' then raise exception 'revision failed';end if;
 if public.wm_minutes_action(repeat('b',64),'read',d) is not null then raise exception 'revision exposed prematurely';end if;
 p:=jsonb_build_object('room_id',r,'version_id',v2,'recipients',jsonb_build_array(g));
 if public.wm_minutes_action(repeat('a',64),'approve',p)->>'approved' is distinct from 'true' then raise exception 'second approval failed';end if;
 if public.wm_minutes_action(repeat('a',64),'publish',p)->>'published' is distinct from 'true' then raise exception 'second publication failed';end if;
 if public.wm_minutes_action(repeat('b',64),'read',jsonb_build_object('room_id',r,'version_id',v1)) is not null then raise exception 'superseded version leaked';end if;
 if public.wm_minutes_action(repeat('a',64),'revoke',p)->>'revoked' is distinct from 'true' then raise exception 'revoke failed';end if;
 if public.wm_minutes_action(repeat('b',64),'read',p) is not null then raise exception 'revoked version leaked';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_MINUTES_SQL_PASS';
