-- Disposable fixtures only; no real provider or user data.
begin;
insert into auth.users(id) values('00000000-0000-4000-8000-000000000081'),('00000000-0000-4000-8000-000000000082');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
('10000000-0000-4000-8000-000000000081','00000000-0000-4000-8000-000000000081','WM-RECHOST','rec-host@example.invalid','Host'),
('10000000-0000-4000-8000-000000000082','00000000-0000-4000-8000-000000000082','WM-RECGUEST','rec-guest@example.invalid','Guest');
insert into public.wm_workspaces(id,kind,name) values('20000000-0000-4000-8000-000000000081','enterprise','Recording recipe');
insert into public.wm_memberships(account_id,workspace_id,role) values
('10000000-0000-4000-8000-000000000081','20000000-0000-4000-8000-000000000081','promoteur'),
('10000000-0000-4000-8000-000000000082','20000000-0000-4000-8000-000000000081','staff');
insert into public.wm_room_entitlements(workspace_id,plan,enabled,valid_until) values('20000000-0000-4000-8000-000000000081','premium',true,now()+interval '2 hours');
do $wm$ begin
 if has_table_privilege('authenticated','public.wm_recording_runs','SELECT') or has_function_privilege('anon','public.wm_recording_claim(uuid,uuid)','EXECUTE') or has_function_privilege('authenticated','public.wm_recording_status(text,uuid)','EXECUTE') then raise exception 'recording ACL leak';end if;
end $wm$;
set local role service_role;
do $wm$
declare h uuid:='10000000-0000-4000-8000-000000000081';g uuid:='10000000-0000-4000-8000-000000000082';w uuid:='20000000-0000-4000-8000-000000000081';r uuid:=gen_random_uuid();req uuid:=gen_random_uuid();s jsonb;j jsonb;run uuid;t bigint:=floor(extract(epoch from clock_timestamp()+interval '30 minutes')*1000)::bigint;
begin
 perform public.wm_issue_verified_session(h,gen_random_uuid(),w,repeat('8',64),0);
 perform public.wm_issue_verified_session(g,gen_random_uuid(),w,repeat('9',64),0);
 s:=jsonb_build_object('id',r::text,'workspaceId',w::text,'hostId',h::text,'revision',1,'status','open','endMs',t,'hardEndMs',t,'recording','requested','participants',jsonb_build_array(jsonb_build_object('memberId',h,'response','accepted','excluded',false,'consent',true),jsonb_build_object('memberId',g,'response','accepted','excluded',false,'consent',false)),'events',jsonb_build_array(jsonb_build_object('id',req,'actor',h,'action','record','payload','["record",null,true,1]')));
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(r,w,h,1,s);
 if public.wm_recording_claim(r,req) is not null then raise exception 'recording without all consents';end if;
 s:=jsonb_set(s,'{participants,1,consent}','true');s:=jsonb_set(s,'{revision}','2');
 update public.wm_rooms set revision=2,state=s where id=r;
 j:=public.wm_recording_claim(r,req);run:=(j->>'id')::uuid;
 if run is null or public.wm_recording_claim(r,req) is not null then raise exception 'recording claim not unique';end if;
 update public.wm_recording_runs set phase='active',provider_id='fixture-provider',started_at=clock_timestamp() where id=run;
 j:=public.wm_recording_status(repeat('9',64),r);
 if j->>'phase' is distinct from 'active' or j ? 'provider_id' or j ? 'object_name' then raise exception 'invalid public recording projection';end if;
 s:=jsonb_set(jsonb_set(jsonb_set(s,'{participants,1,consent}','false'),'{recording}','"off"'),'{revision}','3');
 update public.wm_rooms set state=s,revision=3 where id=r;
 if not exists(select 1 from public.wm_recording_runs x where x.id=run and x.phase='stopping' and x.disposition='discard') then raise exception 'withdrawal failed to fence recording';end if;
 if public.wm_recording_status(repeat('9',64),r)->>'phase' is distinct from 'stopping' then raise exception 'false active indicator after withdrawal';end if;
 if public.wm_recording_claim(r,req) is not null then raise exception 'withdrawn recording reclaimed';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_RECORDING_SQL_PASS';
