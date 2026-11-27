-- B2 fast, isolated transaction. All records and digests are synthetic.
begin;
do $wm$
begin
 if has_table_privilege('anon','public.wm_display_offers','SELECT')
 or has_table_privilege('authenticated','public.wm_display_leases','SELECT')
 or has_function_privilege('authenticated','public.wm_display_context(uuid)','EXECUTE')
 or has_function_privilege('authenticated','public.wm_display_action(text,text,jsonb)','EXECUTE')
 or has_function_privilege('anon','public.wm_display_transport_revoke(uuid)','EXECUTE')
 or has_function_privilege('authenticated','public.wm_group_chat(text,text,jsonb)','EXECUTE')
 or has_table_privilege('authenticated','public.wm_chat_group_messages','SELECT') then raise exception 'B2 unauthorized direct access';end if;
 if (select count(*) from pg_class where relname in ('wm_display_policy','wm_display_offers','wm_display_leases','wm_chat_groups','wm_chat_group_members','wm_chat_group_messages','wm_chat_group_reads') and relrowsecurity)<>7 then raise exception 'B2 RLS missing';end if;
end $wm$;
insert into auth.users(id) values
 ('00000000-0000-4000-8000-0000000000b1'),('00000000-0000-4000-8000-0000000000b2'),
 ('00000000-0000-4000-8000-0000000000b3'),('00000000-0000-4000-8000-0000000000b4'),('00000000-0000-4000-8000-0000000000b5');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
 ('10000000-0000-4000-8000-0000000000b1','00000000-0000-4000-8000-0000000000b1','WM-B2FIXHOST','b2host@example.invalid','Host'),
 ('10000000-0000-4000-8000-0000000000b2','00000000-0000-4000-8000-0000000000b2','WM-B2FIXGUEST','b2guest@example.invalid','Guest'),
 ('10000000-0000-4000-8000-0000000000b3','00000000-0000-4000-8000-0000000000b3','WM-B2FIXTHIRD','b2third@example.invalid','Third'),
 ('10000000-0000-4000-8000-0000000000b4','00000000-0000-4000-8000-0000000000b4','WM-B2FIXMANAGER','b2manager@example.invalid','Manager'),
 ('10000000-0000-4000-8000-0000000000b5','00000000-0000-4000-8000-0000000000b5','WM-B2FIXOTHER','b2other@example.invalid','Other');
insert into public.wm_workspaces(id,kind,name) values ('20000000-0000-4000-8000-0000000000b1','enterprise','B2 A'),('20000000-0000-4000-8000-0000000000b2','enterprise','B2 B');
insert into public.wm_memberships(account_id,workspace_id,role) values
 ('10000000-0000-4000-8000-0000000000b1','20000000-0000-4000-8000-0000000000b1','promoteur'),
 ('10000000-0000-4000-8000-0000000000b2','20000000-0000-4000-8000-0000000000b1','staff'),
 ('10000000-0000-4000-8000-0000000000b3','20000000-0000-4000-8000-0000000000b1','staff'),
 ('10000000-0000-4000-8000-0000000000b4','20000000-0000-4000-8000-0000000000b1','manager'),
 ('10000000-0000-4000-8000-0000000000b5','20000000-0000-4000-8000-0000000000b2','promoteur');
insert into public.wm_room_entitlements(workspace_id,plan,valid_until,enabled) values
 ('20000000-0000-4000-8000-0000000000b1','premium',now()+interval '2 hours',true),
 ('20000000-0000-4000-8000-0000000000b2','premium',now()+interval '2 hours',true);
set local role service_role;
do $wm$
declare host uuid:='10000000-0000-4000-8000-0000000000b1'; guest uuid:='10000000-0000-4000-8000-0000000000b2'; third uuid:='10000000-0000-4000-8000-0000000000b3'; manager uuid:='10000000-0000-4000-8000-0000000000b4'; outsider uuid:='10000000-0000-4000-8000-0000000000b5'; w uuid:='20000000-0000-4000-8000-0000000000b1'; otherw uuid:='20000000-0000-4000-8000-0000000000b2'; rid uuid:='40000000-0000-4000-8000-0000000000b1'; lid uuid:='50000000-0000-4000-8000-0000000000b1'; lid2 uuid:='50000000-0000-4000-8000-0000000000b2'; gid uuid:='60000000-0000-4000-8000-0000000000b1'; mid uuid:='70000000-0000-4000-8000-0000000000b1'; mid2 uuid:='70000000-0000-4000-8000-0000000000b2'; h text:=repeat('a',64); r text:=repeat('b',64); g text:=repeat('c',64); t text:=repeat('d',64); m text:=repeat('e',64); o text:=repeat('f',64); code text:=repeat('1',64); code2 text:=repeat('2',64); samecode text:=repeat('3',64); state jsonb; d jsonb; payload jsonb; x jsonb; endms bigint;
begin
 perform public.wm_issue_device_session(host,'30000000-0000-4000-8000-0000000000b1',w,h);
 perform public.wm_issue_device_session(host,'30000000-0000-4000-8000-0000000000b2',w,r);
 perform public.wm_issue_device_session(guest,'30000000-0000-4000-8000-0000000000b3',w,g);
 perform public.wm_issue_device_session(third,'30000000-0000-4000-8000-0000000000b4',w,t);
 perform public.wm_issue_device_session(manager,'30000000-0000-4000-8000-0000000000b5',w,m);
 perform public.wm_issue_device_session(outsider,'30000000-0000-4000-8000-0000000000b6',otherw,o);
 endms:=floor(extract(epoch from clock_timestamp()+interval '30 minutes')*1000)::bigint;
 state:=jsonb_build_object('id',rid,'workspaceId',w,'hostId',host,'revision',1,'status','open','endMs',endms,'hardEndMs',endms,'recording','off','confidentiality','standard','participants',jsonb_build_array(jsonb_build_object('memberId',host,'response','accepted','excluded',false),jsonb_build_object('memberId',guest,'response','accepted','excluded',false)));
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(rid,w,host,1,state);
 d:=jsonb_build_object('room_id',rid,'code_hash',code,'receiver_name','Display','lease_id',lid);
 -- Reject malformed hashes before INSERT (RPC must fail closed, not raise a CHECK error).
 if public.wm_display_action(r,'offer',jsonb_build_object('code_hash',repeat('a',63),'name','Invalid')) is not null
 or public.wm_display_action(r,'offer',jsonb_build_object('code_hash',repeat('a',65),'name','Invalid')) is not null
 or public.wm_display_action(r,'offer',jsonb_build_object('code_hash',repeat('G',64),'name','Invalid')) is not null
 or public.wm_display_action(r,'offer',jsonb_build_object('code_hash',repeat('a',64)||'x','name','Invalid')) is not null
 or public.wm_display_action(r,'offer',jsonb_build_object('name','Invalid')) is not null then raise exception 'malformed hash accepted';end if;
 -- Direct service-role writes must also obey the database constraint.
 begin
  insert into public.wm_display_offers(code_hash,receiver_session,receiver_name,expires_at)
  select repeat('a',65),session_id,'Invalid direct offer',clock_timestamp()+interval '1 minute'
  from public.wm_session_context(r);
  raise exception 'malformed direct offer accepted';
 exception when check_violation then null;
 end;
 raise notice 'B2_CONNECT_HASH_SQL_PASS: malformed hashes refused by RPC and table constraint';
 if public.wm_display_action(r,'offer',jsonb_build_object('code_hash',code,'name','Display')) is null then raise exception 'offer refused';end if;
 if public.wm_display_action(r,'receive',jsonb_build_object('code_hash',code))->>'pending' is distinct from 'true' then raise exception 'pending not enforced';end if;
 if public.wm_display_action(h,'preview',d) is not null then raise exception 'default display policy allowed';end if;
 if public.wm_display_action(g,'policy',jsonb_build_object('room_id',rid,'enabled',true)) is not null then raise exception 'guest changed policy';end if;
 if public.wm_display_action(h,'policy',jsonb_build_object('room_id',rid,'enabled',true)) is null then raise exception 'host policy refused';end if;
 if public.wm_display_action(g,'preview',d) is not null or public.wm_display_action(o,'preview',d) is not null then raise exception 'foreign receiver pairing';end if;
 if public.wm_display_action(h,'offer',jsonb_build_object('code_hash',samecode,'name','Same source')) is null then raise exception 'same source offer creation failed';end if;
 if public.wm_display_action(h,'preview',jsonb_set(d,'{code_hash}',to_jsonb(samecode))) is not null then raise exception 'same device accepted';end if;
 if public.wm_display_action(h,'preview',d)->>'receiver_name' is distinct from 'Display' then raise exception 'preview refused';end if;
 if public.wm_display_action(h,'confirm',jsonb_set(d,'{receiver_name}','"wrong"')) is not null then raise exception 'unconfirmed name accepted';end if;
 if public.wm_display_action(h,'confirm',d) is null then raise exception 'confirmation refused';end if;
 if public.wm_display_action(h,'confirm',d) is not null then raise exception 'code reused';end if;
 if public.wm_display_action(g,'receive',jsonb_build_object('code_hash',code)) is not null then raise exception 'receiver session binding failed';end if;
 x:=public.wm_display_action(r,'receive',jsonb_build_object('code_hash',code));
 if x is null or x#>>'{lease,id}' is distinct from lid::text or x#>>'{lease,canPublish}' is distinct from 'false' or x#>>'{lease,canChat}' is distinct from 'false' then raise exception 'receiver grant incorrect';end if;
 if public.wm_display_context(lid) is null then raise exception 'active lease rejected';end if;
 if not public.wm_display_transport_revoke(lid) or public.wm_display_context(lid) is not null then raise exception 'transport revocation failed';end if;
 if public.wm_display_action(r,'receive',jsonb_build_object('code_hash',code)) is not null then raise exception 'revoked lease reactivated';end if;
 if public.wm_display_action(r,'offer',jsonb_build_object('code_hash',code2,'name','Display')) is null then raise exception 'second offer refused';end if;
 if public.wm_display_action(h,'confirm',jsonb_build_object('room_id',rid,'code_hash',code2,'receiver_name','Display','lease_id',lid2)) is null then raise exception 'second confirmation refused';end if;
 update public.wm_display_leases set expires_at=clock_timestamp()-interval '1 second' where id=lid2;
 if public.wm_display_action(r,'receive',jsonb_build_object('code_hash',code2)) is not null then raise exception 'expired lease renewed';end if;
 raise notice 'B2_CONNECT_SQL_PASS: RLS, host policy, distinct devices, one use, lease scopes, revoke and expiry';

 payload:=jsonb_build_object('group_id',gid,'name','Original','member_ids',jsonb_build_array(guest,third));
 if public.wm_group_chat(h,'group-chat-create',payload) is null then raise exception 'group create';end if;
 if public.wm_group_chat(h,'group-chat-create',payload) is null then raise exception 'group retry';end if;
 if public.wm_group_chat(m,'group-chat-thread',jsonb_build_object('group_id',gid)) is not null or public.wm_group_chat(o,'group-chat-thread',jsonb_build_object('group_id',gid)) is not null then raise exception 'group privacy';end if;
 d:=jsonb_build_object('group_id',gid,'message_id',mid,'body','Before admission');
 if public.wm_group_chat(g,'group-chat-send',d) is null or public.wm_group_chat(g,'group-chat-send',d) is null then raise exception 'group send retry';end if;
 if jsonb_array_length(public.wm_group_chat(t,'group-chat-thread',jsonb_build_object('group_id',gid))->'items') is distinct from 1 then raise exception 'third read';end if;
 if public.wm_group_chat(t,'group-chat-seen',d) is null then raise exception 'seen refused';end if;
 if public.wm_group_chat(g,'group-chat-rename',jsonb_build_object('group_id',gid,'name','New')) is not null then raise exception 'rename escalation';end if;
 if public.wm_group_chat(h,'group-chat-rename',jsonb_build_object('group_id',gid,'name','New')) is null then raise exception 'rename refused';end if;
 if public.wm_group_chat(h,'group-chat-create',payload) is null then raise exception 'original retry after rename refused';end if;
 if public.wm_group_chat(h,'group-chat-add',jsonb_build_object('group_id',gid,'member_id',outsider)) is not null then raise exception 'foreign added';end if;
 if public.wm_group_chat(h,'group-chat-remove',jsonb_build_object('group_id',gid,'member_id',third)) is null then raise exception 'remove refused';end if;
 if public.wm_group_chat(t,'group-chat-thread',jsonb_build_object('group_id',gid)) is not null then raise exception 'removed read';end if;
 if public.wm_group_chat(h,'group-chat-add',jsonb_build_object('group_id',gid,'member_id',third)) is null or public.wm_group_chat(h,'group-chat-add',jsonb_build_object('group_id',gid,'member_id',manager)) is null then raise exception 'add/rejoin refused';end if;
 if jsonb_array_length(public.wm_group_chat(m,'group-chat-thread',jsonb_build_object('group_id',gid))->'items') is distinct from 0
 or jsonb_array_length(public.wm_group_chat(t,'group-chat-thread',jsonb_build_object('group_id',gid))->'items') is distinct from 0
 or public.wm_group_chat(t,'group-chat-seen',d) is not null then raise exception 'pre-admission history leak';end if;
 if public.wm_group_chat(h,'group-chat-send',jsonb_build_object('group_id',gid,'message_id',mid2,'body','After admission')) is null then raise exception 'new send refused';end if;
 if jsonb_array_length(public.wm_group_chat(m,'group-chat-thread',jsonb_build_object('group_id',gid))->'items') is distinct from 1 then raise exception 'new member delivery';end if;
 raise notice 'B2_GROUP_SQL_PASS: ACL, exact retry, privacy, rename, remove/rejoin and history boundary';
end $wm$;
reset role;
rollback;
