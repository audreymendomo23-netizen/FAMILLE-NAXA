\set ON_ERROR_STOP on
-- Self-contained test, fake non-person photo bytes, no actual personnel or GPS data.
begin;
insert into auth.users(id,email) values ('a1000000-0000-0000-0000-000000000001','attendance-test@x.invalid'),('a1000000-0000-0000-0000-000000000002','attendance-owner@x.invalid');
insert into auth.sessions(id,user_id) values ('a1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-000000000001'),('a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-000000000002');
insert into famille_core.organizations(id,legal_name,organization_type,status) values('a2000000-0000-0000-0000-000000000001','Test','retail','active');
update famille_core.applications set status='active' where code='grillad';
insert into famille_core.organization_apps(organization_id,app_id,status) select 'a2000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.locations(id,organization_id,name) values ('a3000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Test');
insert into grillad_private.enabled_sites(org,site) values ('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001');
insert into famille_core.client_app_access(user_id,app_id,status) select u.id,a.id,'granted' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002');
insert into famille_core.memberships(user_id,organization_id,app_id,status) select u.id,'a2000000-0000-0000-0000-000000000001',a.id,'active' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002');
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select id,app_id,organization_id,'seller','a3000000-0000-0000-0000-000000000001' from famille_core.memberships where user_id='a1000000-0000-0000-0000-000000000001';
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select id,app_id,organization_id,'owner',null from famille_core.memberships where user_id='a1000000-0000-0000-0000-000000000002';
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select 'a2000000-0000-0000-0000-000000000001',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad_access_month';
-- Explicit fixture policy only; not a product decision.
insert into grillad_private.attendance_policy values('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001',true,0,0,200,50,300,1);
select set_config('grillad.test.app',(select id::text from famille_core.applications where code='grillad'),true);
set role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims',jsonb_build_object('session_id','a1000000-0000-0000-0000-000000000011','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,true);
do $$
declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';i uuid:=gen_random_uuid();j uuid:=gen_random_uuid();req uuid:=gen_random_uuid();missing_arr uuid:=gen_random_uuid();missing_req uuid:=gen_random_uuid();a timestamptz:=now()-interval '180 seconds';p text:=encode(decode('ffd8ff000000000000000000000000ffd9','hex'),'base64');q text:=encode(decode('ffd8ff010000000000000000000000ffd9','hex'),'base64');v jsonb;
begin
 if not (public.grillad_attendance_status(o,s)->>'enabled')::boolean or public.grillad_attendance_status(o,s)->'settings'<>'null'::jsonb then raise exception 'expected enabled or leaked settings';end if;
 begin perform public.grillad_action(o,s,gen_random_uuid(),'set_attendance_policy','{"enabled":false}');raise exception 'seller policy allowed';exception when insufficient_privilege then null;end;
 begin perform public.grillad_attendance_capture(o,s,i,'departure',a,0,0,10,p);raise exception 'expected missing arrival';exception when invalid_parameter_value then null;end;
 begin perform public.grillad_attendance_capture(o,s,i,'arrival',a,1,1,10,p);raise exception 'expected distance';exception when invalid_parameter_value then null;end;
 perform public.grillad_attendance_capture(o,s,i,'arrival',a,0,0,10,p);
 perform public.grillad_attendance_capture(o,s,i,'arrival',a,0,0,10,p);
 begin perform public.grillad_attendance_capture(o,s,j,'arrival',now(),0,0,10,q);raise exception 'expected duplicate arrival';exception when invalid_parameter_value then null;end;
 perform public.grillad_attendance_capture(o,s,j,'departure',now()-interval '120 seconds',0,0,10,q);
 v:=public.grillad_attendance_status(o,s);
 if jsonb_array_length(v->'history')<>2 or (v->'history'->0->>'duration_seconds')::int<>60 or (v->'history'->0)?'photo' then raise exception 'history or privacy';end if;
 v:=public.grillad_action(o,s,req,'attendance_request',jsonb_build_object('departure',j,'seconds',30,'reason','Pause à déduire'));
 if (v->>'status')<>'pending' or public.grillad_action(o,s,req,'attendance_request',jsonb_build_object('departure',j,'seconds',30,'reason','Pause à déduire'))<>v then raise exception 'attendance request replay';end if;
 begin perform public.grillad_action(o,s,gen_random_uuid(),'attendance_decide',jsonb_build_object('request',req,'decision','approved','reason','Test'));raise exception 'seller self approval';exception when insufficient_privilege then null;end;
 perform set_config('grillad.test.request',req::text,true);
 perform public.grillad_attendance_capture(o,s,missing_arr,'arrival',now()-interval '60 seconds',0,0,10,encode(decode('ffd8ff020000000000000000000000ffd9','hex'),'base64'));
 v:=public.grillad_action(o,s,missing_req,'missing_departure_request',jsonb_build_object('arrival',missing_arr,'seconds',30,'reason','Oubli'));
 if v->>'status'<>'pending' or public.grillad_action(o,s,missing_req,'missing_departure_request',jsonb_build_object('arrival',missing_arr,'seconds',30,'reason','Oubli'))<>v then raise exception 'missing request replay';end if;
 begin perform public.grillad_action(o,s,gen_random_uuid(),'missing_departure_decide',jsonb_build_object('request',missing_req,'decision','approved','reason','Test'));raise exception 'seller manual approval';exception when insufficient_privilege then null;end;
 perform set_config('grillad.test.missing',missing_req::text,true);
 if (public.grillad_attendance_photo(o,s,i)->>'jpeg')<>p then raise exception 'own photo';end if;
 begin perform public.grillad_attendance_photo(o,s,gen_random_uuid());raise exception 'unknown proof must fail';exception when insufficient_privilege then null;end;
 begin perform count(*) from grillad_private.attendance;raise exception 'expected table denial';exception when insufficient_privilege then null;end;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims',jsonb_build_object('session_id','a1000000-0000-0000-0000-000000000012','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,true);
do $$declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';req uuid:=current_setting('grillad.test.request')::uuid;e uuid:=gen_random_uuid();p jsonb:=jsonb_build_object('request',req,'decision','approved','reason','Vérifié');v jsonb;
begin
 v:=public.grillad_action(o,s,e,'attendance_decide',p);if (v->>'status')<>'approved' or public.grillad_action(o,s,e,'attendance_decide',p)<>v then raise exception 'attendance approval replay';end if;
 v:=public.grillad_attendance_status(o,s);if not exists(select 1 from jsonb_array_elements(v->'history') x where (x->>'duration_seconds')::int=60 and (x->>'effective_duration_seconds')::int=30) or (v->'corrections'->0->>'status')<>'approved' then raise exception 'original evidence or effective duration';end if;
 e:=gen_random_uuid();p:=jsonb_build_object('request',current_setting('grillad.test.missing')::uuid,'decision','approved','reason','Vérifié');
 v:=public.grillad_action(o,s,e,'missing_departure_decide',p);if v->>'status'<>'approved' or public.grillad_action(o,s,e,'missing_departure_decide',p)<>v then raise exception 'missing approval replay';end if;
 v:=public.grillad_attendance_status(o,s);if jsonb_array_length(v->'history')<>3 or (v->'history'->0->>'open_arrival')::boolean or v->'missing_departures'->0->>'status'<>'approved' then raise exception 'manual evidence separation';end if;
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims',jsonb_build_object('session_id','a1000000-0000-0000-0000-000000000011','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,true);
do $$declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';dep uuid:=gen_random_uuid();e uuid:=gen_random_uuid();p jsonb;v jsonb;
begin
 perform public.grillad_attendance_capture(o,s,dep,'departure_without_arrival',now(),0,0,10,encode(decode('ffd8ff030000000000000000000000ffd9','hex'),'base64'));
 begin perform public.grillad_action(o,s,gen_random_uuid(),'missing_arrival_request',jsonb_build_object('departure',dep,'seconds',120,'reason','Overlap'));raise exception 'overlap accepted';exception when invalid_parameter_value then null;end;
 p:=jsonb_build_object('departure',dep,'seconds',10,'reason','Arrivée oubliée');v:=public.grillad_action(o,s,e,'missing_arrival_request',p);
 if v->>'status'<>'pending' or public.grillad_action(o,s,e,'missing_arrival_request',p)<>v then raise exception 'missing arrival replay';end if;
 perform set_config('grillad.test.missing_arrival',e::text,true);
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims',jsonb_build_object('session_id','a1000000-0000-0000-0000-000000000012','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,true);
do $$declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';v jsonb;
begin
 perform public.grillad_action(o,s,gen_random_uuid(),'missing_arrival_decide',jsonb_build_object('request',current_setting('grillad.test.missing_arrival')::uuid,'decision','approved','reason','Vérifié'));
 v:=public.grillad_attendance_status(o,s);
 if jsonb_array_length(v->'history')<>4 or v->'missing_arrivals'->0->>'status'<>'approved' or v->'history'->0->>'kind'<>'departure_without_arrival' or v->'history'->0->>'duration_seconds' is not null then raise exception 'manual arrival evidence separation';end if;
end $$;
do $$declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';begin
 if public.grillad_attendance_status(o,s)->'settings'->>'radius_m'<>'200' then raise exception 'owner policy';end if;
 perform public.grillad_action(o,s,gen_random_uuid(),'set_attendance_policy','{"enabled":true,"latitude":0,"longitude":0,"radius_m":250,"max_accuracy_m":50,"max_age_seconds":300,"photo_retention_days":2,"staff_informed":true,"reason":"Test site"}');
 if public.grillad_attendance_status(o,s)->'settings'->>'radius_m'<>'250' then raise exception 'policy update';end if;
end $$;
reset role;
-- REC-30 deterministic historical midnight fixture: verifies persisted elapsed time,
-- not the live GPS freshness policy (already exercised above).
update grillad_private.attendance set captured_at='2026-11-26 23:59:30 Africa/Douala' where id in (select paired_arrival from grillad_private.attendance where kind='departure');
update grillad_private.attendance set captured_at='2026-11-27 00:00:30 Africa/Douala' where kind='departure';
set role authenticated;
do $declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';v jsonb;
begin
 v:=public.grillad_attendance_status(o,s);
 if not exists(select 1 from jsonb_array_elements(v->'history') x where x->>'kind'='departure' and (x->>'duration_seconds')::int=60 and (x->>'effective_duration_seconds')::int=30) then raise exception 'REC-30 midnight elapsed or correction';end if;
 begin perform public.grillad_attendance_status(o,gen_random_uuid());raise exception 'REC-30 unauthorized site';exception when insufficient_privilege then null;end;
end $;
reset role;
do $begin if (select count(*) from grillad_private.attendance_photo_access)<>1 then raise exception 'photo access audit';end if;end $$;
update grillad_private.attendance set photo_until=now()-interval '1 second';
do $$declare n bigint;begin n:=grillad_private.purge_attendance_photos();if n<>4 then raise exception 'photo retention count %',n;end if;if exists(select 1 from grillad_private.attendance where photo is not null) then raise exception 'photo retention bytes';end if;n:=grillad_private.purge_attendance_photos();if n<>0 then raise exception 'photo retention replay';end if;end $$;
rollback;
