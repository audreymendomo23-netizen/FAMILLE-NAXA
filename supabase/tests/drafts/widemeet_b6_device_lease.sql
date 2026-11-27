begin;
insert into auth.users(id) values('00000000-0000-4000-8000-000000000088');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values('10000000-0000-4000-8000-000000000088','00000000-0000-4000-8000-000000000088','WM-LEASE088','lease88@example.invalid','Lease fixture');
insert into public.wm_workspaces(id,kind,name) values('20000000-0000-4000-8000-000000000088','enterprise','Lease fixture');
insert into public.wm_memberships(account_id,workspace_id,role) values('10000000-0000-4000-8000-000000000088','20000000-0000-4000-8000-000000000088','promoteur');
insert into public.wm_room_entitlements(workspace_id,plan,valid_until,enabled) values('20000000-0000-4000-8000-000000000088','premium',now()+interval '2 hours',true);
do $wm$ begin
 if has_table_privilege('authenticated','public.wm_b6_device_media_leases','SELECT') or has_function_privilege('anon','public.wm_b6_device_media_claim(text,uuid,uuid)','EXECUTE') then raise exception 'lease ACL leak';end if;
end $wm$;
set local role service_role;
do $wm$
declare h uuid:='10000000-0000-4000-8000-000000000088';w uuid:='20000000-0000-4000-8000-000000000088';r uuid:=gen_random_uuid();r2 uuid:=gen_random_uuid();d uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();l uuid:=gen_random_uuid();l2 uuid:=gen_random_uuid();l3 uuid:=gen_random_uuid();t bigint:=floor(extract(epoch from now()+interval '30 minutes')*1000)::bigint;
begin
 perform public.wm_issue_device_session(h,d,w,repeat('6',64));perform public.wm_issue_device_session(h,d2,w,repeat('7',64));
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) select x,w,h,1,jsonb_build_object('id',x,'workspaceId',w,'hostId',h,'revision',1,'status','open','endMs',t,'participants',jsonb_build_array(jsonb_build_object('memberId',h,'response','accepted','excluded',false))) from unnest(array[r,r2]) x;
 if not public.wm_b6_device_media_claim(repeat('6',64),r,l) then raise exception 'first lease denied';end if;
 if not public.wm_b6_device_media_claim(repeat('6',64),r,l) then raise exception 'renewal denied';end if;
 if public.wm_b6_device_media_claim(repeat('6',64),r2,l2) then raise exception 'second room granted same installation';end if;
 if not public.wm_b6_device_media_claim(repeat('7',64),r2,l3) then raise exception 'independent installation blocked';end if;
 if public.wm_b6_device_media_release(repeat('7',64),l) then raise exception 'foreign installation release';end if;
 if not public.wm_b6_device_media_release(repeat('6',64),l) or not public.wm_b6_device_media_claim(repeat('6',64),r2,l2) then raise exception 'release/switch failed';end if;
 update public.wm_device_sessions set revoked_at=clock_timestamp() where token_hash=repeat('6',64);
 if public.wm_b6_device_media_claim(repeat('6',64),r2,l2) then raise exception 'revoked session renewed';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_B6_DEVICE_LEASE_SQL_PASS';
