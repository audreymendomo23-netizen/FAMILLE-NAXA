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
set local role service_role;
do $wm$
declare h uuid:='10000000-0000-4000-8000-000000000091';g uuid:='10000000-0000-4000-8000-000000000092';w uuid:='20000000-0000-4000-8000-000000000091';r uuid:=gen_random_uuid();future_room uuid:=gen_random_uuid();s jsonb;deadline bigint:=floor(extract(epoch from clock_timestamp()-interval '1 second')*1000)::bigint;entitlement bigint:=floor(extract(epoch from clock_timestamp()+interval '2 hours')*1000)::bigint;
begin
 if has_function_privilege('anon','public.wm_close_due_rooms(integer)','EXECUTE') or has_function_privilege('authenticated','public.wm_close_due_rooms(integer)','EXECUTE') then raise exception 'expiry ACL leak';end if;
 perform public.wm_issue_verified_session(h,gen_random_uuid(),w,repeat('a',64),0);
 s:=jsonb_build_object('id',r,'workspaceId',w,'hostId',h,'revision',1,'title','Expiry fixture','status','open','recording','off','endMs',deadline,'startPlan','premium','startEntitlementEndMs',entitlement,'lobbyRequired',true,'participants',jsonb_build_array(jsonb_build_object('memberId',h,'response','accepted','excluded',false),jsonb_build_object('memberId',g,'response','accepted','excluded',false,'lobbyStatus','waiting')),'events','[]'::jsonb);
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(r,w,h,1,s),(future_room,w,h,1,s||jsonb_build_object('id',future_room,'endMs',deadline+600000));
 update public.wm_room_entitlements set valid_until=to_timestamp((deadline+500)::double precision/1000) where workspace_id=w;
 if (select count(*) from public.wm_close_due_rooms(100))<>1 then raise exception 'deadline closure count';end if;
 if (select count(*) from public.wm_close_due_rooms(100))<>0 then raise exception 'expiry not idempotent';end if;
 if not exists(select 1 from public.wm_rooms where id=r and state->>'status'='ended' and revision=2 and state->>'closeReason'='deadline') then raise exception 'closure missing';end if;
 if not exists(select 1 from public.wm_minutes_eligibility where room_id=r and premium) then raise exception 'paid archive lost at deadline';end if;
 if not exists(select 1 from public.wm_rooms where id=future_room and state->>'status'='open') then raise exception 'premature closure';end if;
 if jsonb_array_length(public.wm_minutes_action(repeat('a',64),'prepare',jsonb_build_object('room_id',r))->'recipients')<>1 then raise exception 'lobby participant incorrectly eligible';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_EXPIRY_SQL_PASS';
