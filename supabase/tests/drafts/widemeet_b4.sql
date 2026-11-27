begin;
do $b4$
declare t timestamptz:='2026-11-27 12:30:00+01'; b record; p text; expected timestamptz;
begin
 for p,expected in select * from (values
 ('daily','2026-11-27 00:00:00+01'::timestamptz),
 ('weekly','2026-11-23 00:00:00+01'::timestamptz),
 ('monthly','2026-11-01 00:00:00+01'::timestamptz),
 ('quarterly','2026-10-01 00:00:00+01'::timestamptz),
 ('yearly','2026-01-01 00:00:00+01'::timestamptz),
 ('rolling','2026-11-20 12:30:00+01'::timestamptz)) v(period,expected)
 loop
  select * into b from public.wm_b4_window(p,7,t);
  if b.start_ms is distinct from (extract(epoch from expected)*1000)::bigint or b.end_ms is distinct from (extract(epoch from t)*1000)::bigint then raise exception 'calendar window mismatch %',p;end if;
 end loop;
 if exists(select 1 from public.wm_b4_window('bad',7,t)) or exists(select 1 from public.wm_b4_window('rolling',999,t)) then raise exception 'invalid window accepted';end if;
 if has_function_privilege('anon','public.wm_b4_window(text,integer,timestamptz)','EXECUTE') then raise exception 'window ACL leak';end if;
end $b4$;
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
declare h uuid:='10000000-0000-4000-8000-000000000091';g uuid:='10000000-0000-4000-8000-000000000092';o uuid:='10000000-0000-4000-8000-000000000093';w uuid:='20000000-0000-4000-8000-000000000091';r uuid:=gen_random_uuid();v1 uuid:=gen_random_uuid();v2 uuid:=gen_random_uuid();s jsonb;d jsonb;p jsonb;rr jsonb;k text; metrics jsonb;
begin
 perform public.wm_issue_verified_session(h,gen_random_uuid(),w,repeat('a',64),0);
 perform public.wm_issue_verified_session(g,gen_random_uuid(),w,repeat('b',64),0);
 perform public.wm_issue_verified_session(o,gen_random_uuid(),w,repeat('c',64),0);
 s:=jsonb_build_object('id',r::text,'workspaceId',w::text,'hostId',h::text,'revision',1,'title','Minutes fixture','status','open','recording','off','participants',jsonb_build_array(jsonb_build_object('memberId',h,'response','accepted','excluded',false),jsonb_build_object('memberId',g,'response','accepted','excluded',false),jsonb_build_object('memberId',o,'response','accepted','excluded',false)),'events','[]'::jsonb);
 s:=s||jsonb_build_object('scheduledMs',floor(extract(epoch from clock_timestamp()-interval '1 minute')*1000)::bigint,'durationMinutes',30,'polls',jsonb_build_array(
  jsonb_build_object('open',false,'kind','multiple','question','B4 fixture quorum','options',jsonb_build_array('Oui','Non'),'eligible',jsonb_build_array(h,g,o),'votes',jsonb_build_object(h::text,jsonb_build_array(0),g::text,jsonb_build_array(0,1)),'quorum',60,'threshold',50),
  jsonb_build_object('open',true,'closesMs',floor(extract(epoch from clock_timestamp()-interval '1 second')*1000)::bigint,'kind','single','question','B4 majority','options',jsonb_build_array('Oui','Non','Abstention'),'eligible',jsonb_build_array(h,g,o),'votes',jsonb_build_object(h::text,jsonb_build_array(0),g::text,jsonb_build_array(2)),'quorum',60,'threshold',50,'decisionMode','absolute_majority','abstentionIndex',2),
  jsonb_build_object('open',true,'closesMs',floor(extract(epoch from clock_timestamp()+interval '1 hour')*1000)::bigint),
  jsonb_build_object('open',true)));
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(r,w,h,1,s);
 insert into public.wm_presence_samples(id,room_id,observed_at,observed) values
 (gen_random_uuid(),r,clock_timestamp()-interval '30 seconds',array[h,g]),
 (gen_random_uuid(),r,clock_timestamp()-interval '28 seconds',array[h]),
 (gen_random_uuid(),r,clock_timestamp()-interval '26 seconds',array[h,g]),
 (gen_random_uuid(),r,clock_timestamp()-interval '2 seconds',array[h,g]);
 metrics:=public.wm_workspace_center(repeat('a',64),'center-statistics','{"period":"yearly"}');
 if metrics->>'invitees' is distinct from '2' or metrics->>'accepted_invites' is distinct from '2' or metrics->>'rooms_with_observations' is distinct from '1' or metrics->'by_organizer'->0->>'meetings' is distinct from '1' then raise exception 'B4 scoped KPI mismatch: %',metrics;end if;
 if metrics->>'polls_closed' is distinct from '1' or metrics->>'polls_effectively_closed' is distinct from '2' or metrics->>'total' is distinct from '1' then raise exception 'B4 effective vote closure mismatch: %',metrics;end if;
 if public.wm_workspace_center(repeat('b',64),'center-statistics','{"period":"yearly"}') is not null then raise exception 'B4 staff access';end if;
 if public.wm_workspace_center(repeat('a',64),'center-statistics','{"period":"weekly","days":7}') is not null then raise exception 'B4 ambiguous period';end if;
 update public.wm_rooms set state=jsonb_set(jsonb_set(s,'{status}','"ended"'),'{revision}','2'),revision=2 where id=r;
 if not exists(select 1 from public.wm_minutes_eligibility where room_id=r and premium) then raise exception 'missing closure eligibility';end if;
 metrics:=public.wm_workspace_center(repeat('a',64),'center-statistics','{"days":7}');
 if metrics->>'polls_effectively_closed' is distinct from '4' then raise exception 'B4 ended room closure mismatch: %',metrics;end if;
 rr:=public.wm_presence_report(repeat('a',64),r);
 if rr->>'unobserved_gap_count' is distinct from '1' or rr->'summary'->>'unknown' is distinct from '1' or not exists(select 1 from jsonb_array_elements(rr->'rows') x where x->>'member_id'=g::text and x->>'observed_arrivals'='1' and x->>'observed_departures'='1') then raise exception 'B4 presence transitions mismatch: %',rr;end if;
 if jsonb_array_length(public.wm_presence_report(repeat('b',64),r)->'rows')<>1 then raise exception 'B4 staff attendance leaked';end if;
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

 if has_table_privilege('authenticated','public.wm_tasks','SELECT') or has_function_privilege('anon','public.wm_task_action(text,text,jsonb)','EXECUTE') then raise exception 'task ACL leak';end if;
 d:=jsonb_build_object('id',gen_random_uuid(),'room_id',r,'version_id',v1,'assignee_id',g,'title','Verify decision','due_at',clock_timestamp()+interval '1 day');
 if public.wm_task_action(repeat('b',64),'create',d) is not null then raise exception 'staff assigned task';end if;
 if public.wm_task_action(repeat('a',64),'create',d||jsonb_build_object('assignee_id',o)) is not null then raise exception 'nonrecipient assigned';end if;
 if public.wm_task_action(repeat('a',64),'create',d)->>'revision' is distinct from '1' then raise exception 'task creation failed';end if;
 if public.wm_task_action(repeat('a',64),'create',d)->>'revision' is distinct from '1' then raise exception 'task replay failed';end if;
 if jsonb_array_length(public.wm_task_action(repeat('c',64),'list','{}')->'items')<>0 then raise exception 'unselected task leaked';end if;
 if jsonb_array_length(public.wm_task_action(repeat('b',64),'list','{}')->'items')<>1 then raise exception 'assigned task missing';end if;
 k:='task:'||(d->>'id')||':1';
 if not exists(select 1 from jsonb_array_elements(public.wm_notices(repeat('b',64))->'items') n where n->>'k'=k and n->>'kind'='task_assigned' and n->>'read_at' is null) then raise exception 'B4 task notice missing';end if;
 if public.wm_notices(repeat('b',64),k)->>'read' is distinct from 'true' then raise exception 'B4 mark read failed';end if;
 update public.wm_tasks set due_at=clock_timestamp()-interval '1 second' where id=(d->>'id')::uuid;
 select d||jsonb_build_object('due_at',due_at) into d from public.wm_tasks where id=(d->>'id')::uuid;
 if public.wm_task_action(repeat('a',64),'create',d)->>'revision' is distinct from '1' then raise exception 'B4 exact retry after due date failed';end if;
 if public.wm_task_action(repeat('a',64),'create',d||jsonb_build_object('id',gen_random_uuid())) is not null then raise exception 'B4 expired new task accepted';end if;
 if not exists(select 1 from jsonb_array_elements(public.wm_notices(repeat('b',64))->'items') n where n->>'k'=k||':overdue' and n->>'kind'='task_overdue' and n->>'read_at' is null) then raise exception 'B4 overdue notice did not become unread';end if;
 if public.wm_notices(repeat('c',64),k||':overdue') is not null then raise exception 'B4 overdue notice leaked';end if;
 if public.wm_notices(repeat('b',64),k||':overdue')->>'read' is distinct from 'true' then raise exception 'B4 overdue mark read failed';end if;
 if not exists(select 1 from jsonb_array_elements(public.wm_notices(repeat('b',64))->'items') n where n->>'k'=k||':overdue' and n->>'read_at' is not null) then raise exception 'B4 overdue read idempotence failed';end if;
 p:=jsonb_build_object('id',d->>'id','expected_revision',1,'evidence','Completed verification');
 if public.wm_task_action(repeat('c',64),'submit',p) is not null then raise exception 'other submitted';end if;
 if public.wm_task_action(repeat('b',64),'submit',p)->>'revision' is distinct from '2' then raise exception 'submission failed';end if;
 if public.wm_task_action(repeat('a',64),'approve',p) is not null then raise exception 'stale approval accepted';end if;
 if public.wm_task_action(repeat('b',64),'approve',p||jsonb_build_object('expected_revision',2)) is not null then raise exception 'self approval';end if;
 if public.wm_task_action(repeat('a',64),'return',p||jsonb_build_object('expected_revision',2))->>'revision' is distinct from '3' then raise exception 'return failed';end if;
 if public.wm_task_action(repeat('b',64),'submit',p||jsonb_build_object('expected_revision',3))->>'revision' is distinct from '4' then raise exception 'resubmission failed';end if;
 if public.wm_task_action(repeat('a',64),'approve',p||jsonb_build_object('expected_revision',4))->>'revision' is distinct from '5' then raise exception 'approve failed';end if;
 if (public.wm_task_action(repeat('b',64),'list','{}')->'items'->0->>'state') is distinct from 'done' then raise exception 'task not done';end if;
 rr:=public.wm_task_action(repeat('b',64),'list','{}')->'items'->0;
 if jsonb_array_length(rr->'history')<>5 or rr->'history'->0->>'action' is distinct from 'create' or rr->'history'->4->>'action' is distinct from 'approve' or rr->'history'->4 ? 'actor_id' then raise exception 'B4 task history mismatch: %',rr;end if;
 if has_table_privilege('authenticated','public.wm_task_history','SELECT') or has_table_privilege('service_role','public.wm_task_history','UPDATE') then raise exception 'B4 history ACL';end if;
 update public.wm_room_entitlements set valid_until=clock_timestamp()+interval '1 hour' where workspace_id=w;
 update public.wm_memberships set role='manager' where workspace_id=w and account_id=o;
 insert into public.wm_manager_assignments(workspace_id,staff_id,manager_id) values(w,g,o);
 metrics:=public.wm_workspace_center(repeat('a',64),'center-statistics','{"days":7}');
 if metrics->'by_team'->0->>'manager_id' is distinct from o::text or metrics->'by_team'->0->>'done' is distinct from '1' then raise exception 'B4 team KPI mismatch: %',metrics;end if;
 rr:=public.wm_workspace_center(repeat('c',64),'center-statistics','{"days":7}');
 if rr->>'scope' is distinct from 'organizer' or rr->>'total' is distinct from '0' or jsonb_array_length(rr->'by_team')<>0 then raise exception 'B4 manager scope leaked: %',rr;end if;
 if metrics->>'tasks_done' is distinct from '1' or metrics->'by_assignee'->0->>'done' is distinct from '1' then raise exception 'B4 assignee KPI mismatch: %',metrics;end if;
 rr:=public.wm_report_export(repeat('a',64),r,gen_random_uuid());
 metrics:=rr->'polls'->0;
 if metrics->>'eligible' is distinct from '3' or metrics->>'responses' is distinct from '2' or metrics->>'nonresponses' is distinct from '1' or (metrics->>'response_rate')::numeric is distinct from 66.67::numeric or metrics->>'quorum_met' is distinct from 'true' or metrics->'options'->0->>'accepted' is distinct from 'true' or (metrics->'options'->1->>'share_pct')::numeric is distinct from 50::numeric then raise exception 'B4 survey export metrics mismatch: %',metrics;end if;
 if metrics ? 'votes' or metrics ? 'nominativeResponses' then raise exception 'B4 voter identity leaked';end if;
 metrics:=rr->'polls'->1;
 if metrics->>'abstentions' is distinct from '1' or metrics->>'expressed' is distinct from '1' or metrics->>'decision_denominator' is distinct from '3' or metrics->'options'->0->>'accepted' is distinct from 'false' or metrics->'options'->2->>'accepted' is distinct from 'false' then raise exception 'B4 absolute majority export mismatch: %',metrics;end if;
 if public.wm_report_export(repeat('b',64),r,gen_random_uuid()) is not null then raise exception 'B4 report exposed to staff';end if;
 perform public.wm_minutes_action(repeat('a',64),'revoke',jsonb_build_object('room_id',r,'version_id',v1));
 if jsonb_array_length(public.wm_task_action(repeat('b',64),'list','{}')->'items')<>0 then raise exception 'revoked task leaked';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_B4_SQL_PASS';
