begin;
insert into auth.users(id) values('00000000-0000-4000-8000-000000000086');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values('10000000-0000-4000-8000-000000000086','00000000-0000-4000-8000-000000000086','WM-PURGE086','purge86@example.invalid','Purge fixture');
insert into public.wm_workspaces(id,kind,name) values('20000000-0000-4000-8000-000000000086','enterprise','Purge fixture');
insert into public.wm_memberships(account_id,workspace_id,role) values('10000000-0000-4000-8000-000000000086','20000000-0000-4000-8000-000000000086','promoteur');
do $wm$ begin
 if has_function_privilege('anon','public.wm_b6_audio_purge_claim()','EXECUTE') or has_function_privilege('authenticated','public.wm_b6_audio_purge_ack(uuid,text)','EXECUTE') then raise exception 'purge ACL leak';end if;
end $wm$;
set local role service_role;
do $wm$
declare h uuid:='10000000-0000-4000-8000-000000000086';w uuid:='20000000-0000-4000-8000-000000000086';r uuid:=gen_random_uuid();expired uuid:=gen_random_uuid();fresh uuid:=gen_random_uuid();k text;j jsonb;run uuid:=gen_random_uuid();
begin
 k:=r::text||'/'||expired::text||'.ogg';
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(r,w,h,1,jsonb_build_object('id',r,'workspaceId',w,'hostId',h,'revision',1,'status','ended'));
 insert into public.wm_recording_runs(id,room_id,request_id,phase,object_name,finished_at,content_sha256,bytes,stored_at,storage_key) values
 (expired,r,gen_random_uuid(),'complete',expired::text||'.ogg',now()-interval '91 days',repeat('a',64),1000,now()-interval '91 days',k),
 (fresh,r,gen_random_uuid(),'complete',fresh::text||'.ogg',now()-interval '1 day',repeat('b',64),1000,null,null);
 insert into public.wm_transcription_jobs(recording_id,room_id,requester_id,status,lease,lease_until) values(expired,r,h,'running',run,now()+interval '5 minutes');
 j:=public.wm_b6_audio_purge_claim();
 if j->>'id' is distinct from expired::text or j->>'storage_key' is distinct from k then raise exception 'incorrect purge selection';end if;
 if exists(select 1 from public.wm_transcription_jobs where recording_id=expired) then raise exception 'transcript not removed';end if;
 if public.wm_transcription_worker('finish',expired,run,'{}') is not null then raise exception 'stale lease survived';end if;
 if not exists(select 1 from public.wm_recording_runs where id=expired and phase='discarded' and storage_key=k and purged_at is null) then raise exception 'purge fence failed';end if;
 if public.wm_b6_audio_purge_ack(expired,'wrong') then raise exception 'wrong key acknowledged';end if;
 if public.wm_b6_audio_purge_claim()->>'id' is distinct from expired::text then raise exception 'retry lost';end if;
 if not public.wm_b6_audio_purge_ack(expired,k) then raise exception 'ack failed';end if;
 if not public.wm_b6_audio_purge_ack(expired,k) then raise exception 'ack not idempotent';end if;
 if not exists(select 1 from public.wm_recording_runs where id=expired and purged_at is not null and storage_key is null and content_sha256 is null and bytes is null) then raise exception 'metadata not minimized';end if;
 if public.wm_b6_audio_purge_claim() is not null or not exists(select 1 from public.wm_recording_runs where id=fresh and phase='complete') then raise exception 'fresh content affected';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_B6_AUDIO_PURGE_SQL_PASS';
