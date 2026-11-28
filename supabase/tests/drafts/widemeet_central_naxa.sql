begin;
do $test$
declare
 admin uuid:='10000000-0000-4000-8000-000000000001'; agent uuid:='10000000-0000-4000-8000-000000000002'; other uuid:='10000000-0000-4000-8000-000000000003'; low uuid:='10000000-0000-4000-8000-000000000004';
 asid uuid:='20000000-0000-4000-8000-000000000001'; ssid uuid:='20000000-0000-4000-8000-000000000002'; osid uuid:='20000000-0000-4000-8000-000000000003'; lsid uuid:='20000000-0000-4000-8000-000000000004';
 customer uuid:='30000000-0000-4000-8000-000000000001'; aaccount uuid:='30000000-0000-4000-8000-000000000002'; oaccount uuid:='30000000-0000-4000-8000-000000000003';
 cw uuid:='40000000-0000-4000-8000-000000000001'; aw uuid:='40000000-0000-4000-8000-000000000002'; ow uuid:='40000000-0000-4000-8000-000000000003';
 t uuid:='50000000-0000-4000-8000-000000000001'; private_t uuid:='50000000-0000-4000-8000-000000000002'; msg uuid:='60000000-0000-4000-8000-000000000001'; callid uuid:='70000000-0000-4000-8000-000000000001';
 exp timestamptz:=now()+interval '30 minutes'; v jsonb; dev uuid;
begin
 insert into auth.users(id) values(admin),(agent),(other),(low),(customer),(aaccount),(oaccount);
 insert into auth.sessions values(asid,admin,'aal2',exp),(ssid,agent,'aal2',exp),(osid,other,'aal2',exp),(lsid,low,'aal1',exp);
 insert into famille_core.family_admins values(admin,'active',null);
 insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
 (customer,customer,'WM-CUSTOMER1','customer@fixture.test','Customer'),
 (aaccount,aaccount,'WM-AGENT0001','agent@fixture.test','Agent'),
 (oaccount,oaccount,'WM-AGENT0002','agent2@fixture.test','Agent 2');
 insert into public.wm_workspaces(id,kind,name) values(cw,'individual','Customer'),(aw,'individual','Agent'),(ow,'individual','Agent 2');
 insert into public.wm_memberships(account_id,workspace_id,role) values(customer,cw,'owner'),(aaccount,aw,'owner'),(oaccount,ow,'owner');
 insert into public.wm_support_agents(account_id,enabled) values(aaccount,true),(oaccount,true);
 perform public.wm_issue_device_session(customer,'80000000-0000-4000-8000-000000000001',cw,repeat('a',64));
 insert into public.wm_support_tickets(id,workspace_id,requester_id,subject,category) values(t,cw,customer,'Sujet confidentiel','account'),(private_t,cw,customer,'Demande privée','privacy_access');
 insert into public.wm_support_messages(id,ticket_id,actor_id,author_kind,body) values(msg,t,customer,'requester','Message client');
 if has_function_privilege('anon','public.wm_central_dispatch(uuid,uuid,timestamptz,text,text,jsonb)','execute') or has_function_privilege('authenticated','public.wm_central_dispatch(uuid,uuid,timestamptz,text,text,jsonb)','execute') or not has_function_privilege('service_role','public.wm_central_dispatch(uuid,uuid,timestamptz,text,text,jsonb)','execute') then raise exception 'bad grants';end if;
 v:=public.wm_central_dispatch(admin,asid,exp,repeat('b',64),'overview','{}');
 if (v->>'individuals')::int is distinct from 3 or (v->>'open_tickets')::int is distinct from 2 or v ? 'messages' then raise exception 'bad aggregates %',v;end if;
 if public.wm_central_dispatch(admin,asid,exp,repeat('b',64),'support-queue','{}') is not null then raise exception 'admin got support content';end if;
 if public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'overview','{}') is not null or public.wm_central_dispatch(low,lsid,exp,repeat('d',64),'capabilities','{}') is not null or public.wm_central_dispatch(admin,ssid,exp,repeat('b',64),'overview','{}') is not null then raise exception 'unauthorized caller';end if;
 v:=public.wm_central_dispatch(admin,asid,exp,repeat('b',64),'agent-set',jsonb_build_object('operator_id',agent,'account_id',aaccount,'enabled',true));
 if v->>'saved' is distinct from 'true' then raise exception 'agent provisioning %',v;end if;
 v:=public.wm_central_dispatch(admin,asid,exp,repeat('b',64),'agent-set',jsonb_build_object('operator_id',other,'account_id',oaccount,'enabled',true));
 if v->>'saved' is distinct from 'true' then raise exception 'second agent provisioning %',v;end if;
 v:=public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-queue','{}');
 if jsonb_array_length(v->'items') is distinct from 1 or v->'items'->0->>'subject' is not null then raise exception 'queue leaks %',v;end if;
 if public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-read',jsonb_build_object('ticket_id',t)) is not null then raise exception 'read before claim';end if;
 v:=public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-claim',jsonb_build_object('ticket_id',t));
 if v->>'claimed' is distinct from 'true' then raise exception 'claim %',v;end if;
 if public.wm_central_dispatch(other,osid,exp,repeat('e',64),'support-claim',jsonb_build_object('ticket_id',t)) is not null or public.wm_central_dispatch(other,osid,exp,repeat('e',64),'support-read',jsonb_build_object('ticket_id',t)) is not null then raise exception 'other agent read';end if;
 v:=public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-read',jsonb_build_object('ticket_id',t));
 if v->>'viewer' is distinct from 'agent' or v->'messages'->0->>'body' is distinct from 'Message client' then raise exception 'agent read %',v;end if;
 v:=public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-reply',jsonb_build_object('ticket_id',t,'message_id','60000000-0000-4000-8000-000000000002','body','Réponse centrale'));
 if v->>'sent' is distinct from 'true' then raise exception 'reply %',v;end if;
 v:=public.wm_support_action(repeat('a',64),'support-read',jsonb_build_object('ticket_id',t));
 if v->'messages'->1->>'body' is distinct from 'Réponse centrale' then raise exception 'customer did not see response %',v;end if;
 v:=public.wm_support_action(repeat('a',64),'support-call-request',jsonb_build_object('ticket_id',t,'call_id',callid));
 if v->>'state' is distinct from 'requested' then raise exception 'request call %',v;end if;
 v:=public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-call-accept',jsonb_build_object('ticket_id',t,'call_id',callid));
 if v->>'state' is distinct from 'active' then raise exception 'accept %',v;end if;
 v:=public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-call-grant',jsonb_build_object('ticket_id',t,'call_id',callid,'handle',repeat('f',64)));
 if v->>'identity' is distinct from aaccount::text or v->'sources' ? 'screen_share' then raise exception 'invalid media rights %',v;end if;
 select device_id into dev from public.wm_central_support_sessions where auth_session_id=ssid;
 if not public.wm_support_session_live(dev) then raise exception 'missing live session';end if;
 delete from auth.sessions where id=ssid;
 if public.wm_support_session_live(dev) or public.wm_central_dispatch(agent,ssid,exp,repeat('c',64),'support-read',jsonb_build_object('ticket_id',t)) is not null then raise exception 'revoked central auth accepted';end if;
 v:=public.wm_support_action(repeat('a',64),'support-call-read',jsonb_build_object('ticket_id',t));
 if v->>'state' is distinct from 'idle' then raise exception 'revoked agent call not ended %',v;end if;
 v:=public.wm_central_dispatch(admin,asid,exp,repeat('b',64),'agent-set',jsonb_build_object('operator_id',other,'account_id',oaccount,'enabled',false));
 if v->>'saved' is distinct from 'true' or public.wm_central_dispatch(other,osid,exp,repeat('e',64),'support-queue','{}') is not null then raise exception 'agent revocation';end if;
 -- Signed federation dispatcher: explicit mapping, role separation, nonce replay rejection and revocation.
 insert into public.wm_naxa_operator_links(legacy_user,operator_id,operator_role,enabled) values('90000000-0000-4000-8000-000000000001',admin,'admin',true);
 v:=public.wm_naxa_federated_dispatch('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002','admin',exp,'90000000-0000-4000-8000-000000000003',clock_timestamp(),repeat('1',64),'overview','{}');
 if v->>'individuals' is distinct from '3' then raise exception 'federated admin failed %',v;end if;
 if public.wm_naxa_federated_dispatch('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002','admin',exp,'90000000-0000-4000-8000-000000000003',clock_timestamp(),repeat('1',64),'overview','{}') is not null then raise exception 'signed nonce replay accepted';end if;
 if public.wm_naxa_federated_dispatch('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002','admin',exp,'90000000-0000-4000-8000-000000000004',clock_timestamp(),repeat('1',64),'support-queue','{}') is not null then raise exception 'federated admin got ticket content';end if;
 update public.wm_naxa_operator_links set enabled=false;
 if public.wm_naxa_federated_dispatch('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002','admin',exp,'90000000-0000-4000-8000-000000000005',clock_timestamp(),repeat('1',64),'overview','{}') is not null then raise exception 'federated revoked admin accepted';end if;
 update famille_core.family_admins set status='suspended' where user_id=admin;
 if public.wm_central_dispatch(admin,asid,exp,repeat('b',64),'overview','{}') is not null then raise exception 'suspended admin';end if;
 if not exists(select 1 from public.wm_central_audit where actor_id=agent and action='support-reply' and target_id=t) then raise exception 'audit missing';end if;
 raise notice 'WIDEMEET_CENTRAL_NAXA_SQL_PASS';
end $test$;
rollback;
