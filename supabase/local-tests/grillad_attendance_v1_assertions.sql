\set ON_ERROR_STOP on
-- Self-contained test, fake non-person photo bytes, no actual personnel or GPS data.
begin;
insert into auth.users(id,email) values ('a1000000-0000-0000-0000-000000000001','attendance-test@x.invalid');
insert into auth.sessions(id,user_id) values ('a1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-000000000001');
insert into famille_core.organizations(id,legal_name,organization_type,status) values('a2000000-0000-0000-0000-000000000001','Test','retail','active');
update famille_core.applications set status='active' where code='grillad';
insert into famille_core.organization_apps(organization_id,app_id,status) select 'a2000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.locations(id,organization_id,name) values ('a3000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Test');
insert into grillad_private.enabled_sites(org,site) values ('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001');
insert into famille_core.client_app_access(user_id,app_id,status) select 'a1000000-0000-0000-0000-000000000001',id,'granted' from famille_core.applications where code='grillad';
insert into famille_core.memberships(user_id,organization_id,app_id,status) select 'a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select id,app_id,organization_id,'seller','a3000000-0000-0000-0000-000000000001' from famille_core.memberships where user_id='a1000000-0000-0000-0000-000000000001';
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select 'a2000000-0000-0000-0000-000000000001',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad_access_month';
-- Explicit fixture policy only; not a product decision.
insert into grillad_private.attendance_policy values('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001',true,0,0,200,50,300,1);
select set_config('grillad.test.app',(select id::text from famille_core.applications where code='grillad'),true);
set role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims',jsonb_build_object('session_id','a1000000-0000-0000-0000-000000000011','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,true);
do $$
declare o uuid:='a2000000-0000-0000-0000-000000000001';s uuid:='a3000000-0000-0000-0000-000000000001';i uuid:=gen_random_uuid();j uuid:=gen_random_uuid();a timestamptz:=now()-interval '60 seconds';p text:=encode(decode('ffd8ff000000000000000000000000ffd9','hex'),'base64');q text:=encode(decode('ffd8ff010000000000000000000000ffd9','hex'),'base64');v jsonb;
begin
 if not (public.grillad_attendance_status(o,s)->>'enabled')::boolean then raise exception 'expected enabled';end if;
 begin perform public.grillad_attendance_capture(o,s,i,'departure',a,0,0,10,p);raise exception 'expected missing arrival';exception when invalid_parameter_value then null;end;
 begin perform public.grillad_attendance_capture(o,s,i,'arrival',a,1,1,10,p);raise exception 'expected distance';exception when invalid_parameter_value then null;end;
 perform public.grillad_attendance_capture(o,s,i,'arrival',a,0,0,10,p);
 perform public.grillad_attendance_capture(o,s,i,'arrival',a,0,0,10,p);
 begin perform public.grillad_attendance_capture(o,s,j,'arrival',now(),0,0,10,q);raise exception 'expected duplicate arrival';exception when invalid_parameter_value then null;end;
 perform public.grillad_attendance_capture(o,s,j,'departure',now(),0,0,10,q);
 v:=public.grillad_attendance_status(o,s);
 if jsonb_array_length(v->'history')<>2 or (v->'history'->0->>'duration_seconds')::int<>60 or (v->'history'->0)?'photo' then raise exception 'history or privacy';end if;
 if (public.grillad_attendance_photo(o,s,i)->>'jpeg')<>p then raise exception 'own photo';end if;
 begin perform public.grillad_attendance_photo(o,s,gen_random_uuid());raise exception 'unknown proof must fail';exception when insufficient_privilege then null;end;
 begin perform count(*) from grillad_private.attendance;raise exception 'expected table denial';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin if (select count(*) from grillad_private.attendance_photo_access)<>1 then raise exception 'photo access audit';end if;end $$;
update grillad_private.attendance set photo_until=now()-interval '1 second';
do $$begin if grillad_private.purge_attendance_photos()<>2 or exists(select 1 from grillad_private.attendance where photo is not null) then raise exception 'photo retention';end if;end $$;
rollback;
