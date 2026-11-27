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
 or has_table_privilege('authenticated','public.wm_chat_group_messages','SELECT')
 or has_table_privilege('authenticated','public.wm_chat_media','SELECT')
 or has_function_privilege('anon','public.wm_chat_media_action(text,text,jsonb)','EXECUTE') then raise exception 'B2 unauthorized direct access';end if;
 if (select count(*) from pg_class where relname in ('wm_display_policy','wm_display_offers','wm_display_leases','wm_chat_groups','wm_chat_group_members','wm_chat_group_messages','wm_chat_group_reads','wm_chat_group_reports','wm_chat_media') and relrowsecurity)<>9 then raise exception 'B2 RLS missing';end if;
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
 if has_function_privilege('authenticated','public.wm_periodic_run(integer)','EXECUTE') or has_table_privilege('anon','public.wm_periodic_reports','SELECT') then raise exception 'periodic grants';end if;
 if public.wm_periodic_next('2024-02-01','monthly')<>'2024-03-01'::date or public.wm_periodic_next('2024-01-01','quarterly')<>'2024-04-01'::date or public.wm_periodic_next('2024-01-01','yearly')<>'2025-01-01'::date then raise exception 'calendar';end if;
 if public.wm_periodic_action(g,'center-periodic-list','{}') is not null then raise exception 'staff report access';end if;
 if public.wm_periodic_action(h,'center-periodic-save','{"cadence":"invalid","enabled":true}') is not null then raise exception 'invalid cadence';end if;
 perform public.wm_periodic_action(h,'center-periodic-save','{"cadence":"daily","enabled":true}');
 perform public.wm_periodic_action(m,'center-periodic-save','{"cadence":"daily","enabled":true}');
 if (select count(*) from public.wm_periodic_preferences where workspace_id=w)<>2 then raise exception 'preferences not saved';end if;
 update public.wm_periodic_preferences set next_start=(clock_timestamp() at time zone 'Africa/Douala')::date-1 where workspace_id=w;
 update public.wm_rooms as room_fixture set state=room_fixture.state||jsonb_build_object('scheduledMs',floor(extract(epoch from (((clock_timestamp() at time zone 'Africa/Douala')::date-1)::timestamp at time zone 'Africa/Douala'))*1000)::bigint,'durationMinutes',30) where id=rid;
 if public.wm_periodic_run(10)<>2 or public.wm_periodic_run(10)<>0 then raise exception 'periodic retry';end if;
 if (public.wm_periodic_action(h,'center-periodic-list','{}')->'items'->0->'metrics'->>'total') is distinct from '1' then raise exception 'promoter total';end if;
 if (public.wm_periodic_action(m,'center-periodic-list','{}')->'items'->0->'metrics'->>'total') is distinct from '0' then raise exception 'manager scope';end if;
 if jsonb_array_length(public.wm_periodic_action(o,'center-periodic-list','{}')->'items') is distinct from 0 then raise exception 'foreign report';end if;
 select n into x from jsonb_array_elements(public.wm_notices(h)->'items') n where n->>'kind'='periodic_report';
 if x is null or x->>'read_at' is not null then raise exception 'periodic private notice absent';end if;
 if exists(select 1 from jsonb_array_elements(public.wm_notices(o)->'items') n where n->>'kind'='periodic_report') or exists(select 1 from jsonb_array_elements(public.wm_notices(g)->'items') n where n->>'kind'='periodic_report') then raise exception 'periodic notice leak';end if;
 if public.wm_notices(g,x->>'k') is not null or public.wm_notices(o,x->>'k') is not null then raise exception 'foreign periodic acknowledgement';end if;
 if public.wm_notices(h,x->>'k')->>'read' is distinct from 'true' or public.wm_notices(h,x->>'k')->>'read' is distinct from 'true' then raise exception 'periodic acknowledgement';end if;
 if not exists(select 1 from jsonb_array_elements(public.wm_notices(h)->'items') n where n->>'k'=x->>'k' and n->>'read_at' is not null) then raise exception 'periodic acknowledgement persistence';end if;
 if not exists(select 1 from jsonb_array_elements(public.wm_notices(m)->'items') n where n->>'kind'='periodic_report' and n->>'read_at' is null) then raise exception 'manager acknowledgement isolation';end if;
 raise notice 'B4_PERIODIC_NOTICE_SQL_PASS: private delivery, exact acknowledgement, tenant and role isolation';
 perform public.wm_periodic_action(h,'center-periodic-save','{"cadence":"daily","enabled":false}');
 if (public.wm_periodic_action(h,'center-periodic-list','{}')->'preferences'->0->>'enabled') is distinct from 'false' then raise exception 'disable failed';end if;
 update public.wm_memberships set enabled=false where account_id=manager and workspace_id=w;
 if public.wm_periodic_action(m,'center-periodic-list','{}') is not null or public.wm_notices(m) is not null then raise exception 'revoked report access';end if;
 update public.wm_memberships set enabled=true where account_id=manager and workspace_id=w;
 update public.wm_rooms as room_fixture set state=room_fixture.state-'scheduledMs'-'durationMinutes' where id=rid;
 raise notice 'B4_PERIODIC_SQL_PASS: calendar, preference, snapshot, retry, roles, isolation, disable and revocation';
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
 -- Fresh pairing revoked durably by a pause followed immediately by reopen, before the proxy can poll.
 d:=jsonb_build_object('room_id',rid,'code_hash',repeat('4',64),'receiver_name','Display','lease_id','50000000-0000-4000-8000-0000000000b3');
 if public.wm_display_action(r,'offer',jsonb_build_object('code_hash',repeat('4',64),'name','Display')) is null or public.wm_display_action(h,'confirm',d) is null then raise exception 'pause fixture failed';end if;
 update public.wm_rooms set state=jsonb_set(wm_rooms.state,'{status}','"paused"') where id=rid;
 update public.wm_rooms set state=jsonb_set(wm_rooms.state,'{status}','"open"') where id=rid;
 if public.wm_display_action(r,'receive',jsonb_build_object('code_hash',repeat('4',64))) is not null then raise exception 'pause/reopen resurrected receiver';end if;
 raise notice 'B2_CONNECT_FENCE_SQL_PASS: durable pause and reopen revocation';
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
 -- B2 files and voice share the same conversation ACL, not a public bucket or admin grant.
 d:=jsonb_build_object('group_id',gid,'id','80000000-0000-4000-8000-0000000000b1','kind','file','mime','application/pdf','name','test.pdf','bytes',20,'sha256',repeat('a',64));
 if public.wm_chat_media_action(h,'reserve',d) is null then raise exception 'media reserve refused';end if;
 if public.wm_chat_media_action(h,'reserve',d) is null then raise exception 'media exact retry refused';end if;
 if public.wm_chat_media_action(h,'reserve',jsonb_set(d,'{name}','"changed.pdf"')) is not null then raise exception 'media conflicting retry accepted';end if;
 if public.wm_chat_media_action(t,'read',d) is not null then raise exception 'staged media visible';end if;
 if public.wm_chat_media_action(t,'publish',d) is not null then raise exception 'foreign sender publish';end if;
 if public.wm_chat_media_action(h,'publish',d)->>'state' is distinct from 'ready' then raise exception 'media publish refused';end if;
 if public.wm_chat_media_action(t,'read',d) is null or public.wm_chat_media_action(o,'read',d) is not null then raise exception 'media group isolation';end if;
 if public.wm_chat_media_action(t,'revoke',d) is not null then raise exception 'member revoked sender media';end if;
 if public.wm_group_chat(h,'group-chat-remove',jsonb_build_object('group_id',gid,'member_id',third)) is null then raise exception 'media remove member';end if;
 if public.wm_chat_media_action(t,'read',d) is not null then raise exception 'removed member read';end if;
 if public.wm_group_chat(h,'group-chat-add',jsonb_build_object('group_id',gid,'member_id',third)) is null then raise exception 'media rejoin member';end if;
 if public.wm_chat_media_action(t,'read',d) is not null or jsonb_array_length(public.wm_chat_media_action(t,'list',d)->'items') is distinct from 0 then raise exception 'media pre-admission leak';end if;
 if public.wm_chat_media_action(h,'revoke',d)->>'state' is distinct from 'revoked' or public.wm_chat_media_action(h,'publish',d) is not null or public.wm_chat_media_action(h,'reserve',d) is not null or public.wm_chat_media_action(m,'read',d) is not null then raise exception 'revoked media revived';end if;
 d:=jsonb_build_object('peer_id',guest,'id','80000000-0000-4000-8000-0000000000b2','kind','voice','mime','audio/ogg','name','voice.ogg','bytes',20,'sha256',repeat('b',64));
 if public.wm_chat_media_action(h,'reserve',d) is null or public.wm_chat_media_action(h,'publish',d) is null then raise exception 'voice reserve/publish failed';end if;
 if public.wm_chat_media_action(g,'read',jsonb_set(d,'{peer_id}',to_jsonb(host))) is null then raise exception 'voice peer refused';end if;
 if public.wm_chat_media_action(m,'read',jsonb_set(d,'{peer_id}',to_jsonb(host))) is not null then raise exception 'voice manager leak';end if;
 if public.wm_chat_media_action(o,'read',jsonb_set(d,'{peer_id}',to_jsonb(host))) is not null then raise exception 'voice tenant leak';end if;
 update public.wm_chat_media set revoked_at=clock_timestamp()-interval '3 minutes' where id='80000000-0000-4000-8000-0000000000b1';
 if jsonb_array_length(public.wm_chat_media_purge_candidates(50)->'items') is distinct from 1 then raise exception 'purge candidate scope';end if;
 if public.wm_chat_media_purge_ack('80000000-0000-4000-8000-0000000000b2') then raise exception 'ready file purged';end if;
 if not public.wm_chat_media_purge_ack('80000000-0000-4000-8000-0000000000b1') then raise exception 'revoked ack refused';end if;
 if jsonb_array_length(public.wm_chat_media_purge_candidates(50)->'items') is distinct from 0 then raise exception 'purged file retained in queue';end if;
 raise notice 'B2_CHAT_MEDIA_PURGE_SQL_PASS: terminal ledger and worker scope';
 raise notice 'B2_CHAT_MEDIA_SQL_PASS: service-only ACL, staging, exact retry, publish, direct/group access, revoke and history fence';
end $wm$;
reset role;
rollback;
