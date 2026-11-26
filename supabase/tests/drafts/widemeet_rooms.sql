-- Disposable PostgreSQL 17 only; fixture accounts and entitlement, never production rights.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000011'),('00000000-0000-4000-8000-000000000012'),('00000000-0000-4000-8000-000000000013');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
('10000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000011','WM-ROOMHOST','wm-host@example.invalid','Host'),
('10000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000012','WM-ROOMGUEST','wm-guest@example.invalid','Guest'),
('10000000-0000-4000-8000-000000000013','00000000-0000-4000-8000-000000000013','WM-ROOMOTHER','wm-other@example.invalid','Other');
insert into public.wm_workspaces(id,kind,name) values
('20000000-0000-4000-8000-000000000011','enterprise','A'),
('20000000-0000-4000-8000-000000000012','enterprise','B');
insert into public.wm_memberships(account_id,workspace_id,role) values
('10000000-0000-4000-8000-000000000011','20000000-0000-4000-8000-000000000011','promoteur'),
('10000000-0000-4000-8000-000000000012','20000000-0000-4000-8000-000000000011','staff'),
('10000000-0000-4000-8000-000000000013','20000000-0000-4000-8000-000000000012','promoteur');
insert into public.wm_room_entitlements(workspace_id,plan,valid_until,enabled) values
('20000000-0000-4000-8000-000000000011','premium',now()+interval '2 hours',true),
('20000000-0000-4000-8000-000000000012','premium',now()+interval '2 hours',true);
do $wm$ begin
 if has_table_privilege('authenticated','public.wm_rooms','SELECT') or has_function_privilege('anon','public.wm_room_read(text,uuid)','EXECUTE') or has_function_privilege('authenticated','public.wm_room_write(text,uuid,bigint,text,text,jsonb)','EXECUTE') then raise exception 'room ACL leak';end if;
 if (select count(*) from pg_class where relname in ('wm_rooms','wm_room_entitlements') and relrowsecurity)<>2 then raise exception 'RLS missing';end if;
end $wm$;
set local role service_role;
select public.wm_issue_device_session('10000000-0000-4000-8000-000000000011','30000000-0000-4000-8000-000000000011','20000000-0000-4000-8000-000000000011',repeat('a',64));
select public.wm_issue_device_session('10000000-0000-4000-8000-000000000012','30000000-0000-4000-8000-000000000012','20000000-0000-4000-8000-000000000011',repeat('b',64));
select public.wm_issue_device_session('10000000-0000-4000-8000-000000000013','30000000-0000-4000-8000-000000000013','20000000-0000-4000-8000-000000000012',repeat('c',64));
do $wm$
declare r uuid:='40000000-0000-4000-8000-000000000011'; s jsonb; n jsonb;
begin
 s:=jsonb_build_object('id',r::text,'workspaceId','20000000-0000-4000-8000-000000000011','hostId','10000000-0000-4000-8000-000000000011','status','scheduled','revision',1,'hardEndMs',floor(extract(epoch from now()+interval '1 hour')*1000)::bigint,'recording','off','participants',jsonb_build_array(jsonb_build_object('memberId','10000000-0000-4000-8000-000000000011','response','accepted','excluded',false),jsonb_build_object('memberId','10000000-0000-4000-8000-000000000012','response','pending','excluded',false)));
 if public.wm_room_create(repeat('b',64),s) then raise exception 'staff created room';end if;
 if public.wm_room_create(repeat('c',64),s) then raise exception 'foreign created room';end if;
 if public.wm_room_create(repeat('a',64),jsonb_set(s,'{participants,1,memberId}',to_jsonb('10000000-0000-4000-8000-000000000013'::text))) then raise exception 'foreign invitation accepted';end if;
 if not public.wm_room_create(repeat('a',64),s) then raise exception 'host creation failed';end if;
 if public.wm_room_create(repeat('a',64),s) then raise exception 'duplicate room created';end if;
 if public.wm_room_read(repeat('b',64),r) is distinct from s then raise exception 'invitee read failed';end if;
 if public.wm_room_read(repeat('c',64),r) is not null then raise exception 'cross tenant leak';end if;
 if (select count(*) from public.wm_room_list(repeat('a',64)))<>1 or (select count(*) from public.wm_room_list(repeat('c',64)))<>0 then raise exception 'agenda leak';end if;
 if (select count(*) from public.wm_room_contacts(repeat('a',64)))<>1 or (select count(*) from public.wm_room_contacts(repeat('c',64)))<>0 then raise exception 'contacts leak';end if;
 n:=jsonb_set(jsonb_set(s,'{revision}','2'::jsonb),'{status}','"open"'::jsonb);
 if public.wm_room_write(repeat('c',64),r,1,'promoteur','premium',n) then raise exception 'foreign write';end if;
 if public.wm_room_write(repeat('a',64),r,1,'manager','premium',n) then raise exception 'stale role accepted';end if;
 if not public.wm_room_write(repeat('a',64),r,1,'promoteur','premium',n) then raise exception 'CAS failed';end if;
 if public.wm_room_write(repeat('a',64),r,1,'promoteur','premium',n) then raise exception 'stale version accepted';end if;
 update public.wm_room_entitlements set plan='access' where workspace_id='20000000-0000-4000-8000-000000000011';
 n:=jsonb_set(jsonb_set(n,'{revision}','3'::jsonb),'{recording}','"requested"'::jsonb);
 if public.wm_room_write(repeat('a',64),r,2,'promoteur','premium',n) or public.wm_room_write(repeat('a',64),r,2,'promoteur','access',n) then raise exception 'record after downgrade';end if;
 update public.wm_device_sessions set revoked_at=clock_timestamp() where token_hash=repeat('b',64);
 if public.wm_room_read(repeat('b',64),r) is not null then raise exception 'revoked session read';end if;
 update public.wm_room_entitlements set enabled=false where workspace_id='20000000-0000-4000-8000-000000000011';
 if public.wm_room_read(repeat('a',64),r) is not null then raise exception 'inactive entitlement access';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_ROOM_SQL_PASS';
