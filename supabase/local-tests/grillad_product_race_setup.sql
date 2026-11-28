\set ON_ERROR_STOP on
insert into auth.users(id,email) values ('91000000-0000-0000-0000-000000000001','grillad-owner@test.invalid'),('91000000-0000-0000-0000-000000000002','grillad-seller@test.invalid'),('91000000-0000-0000-0000-000000000003','grillad-manager@test.invalid'),('91000000-0000-0000-0000-000000000004','grillad-seller4@test.invalid'),('91000000-0000-0000-0000-000000000005','grillad-seller5@test.invalid');
insert into auth.sessions(id,user_id) values ('91000000-0000-0000-0000-000000000011','91000000-0000-0000-0000-000000000001'),('91000000-0000-0000-0000-000000000012','91000000-0000-0000-0000-000000000002'),('91000000-0000-0000-0000-000000000013','91000000-0000-0000-0000-000000000003'),('91000000-0000-0000-0000-000000000014','91000000-0000-0000-0000-000000000004'),('91000000-0000-0000-0000-000000000015','91000000-0000-0000-0000-000000000005');
insert into famille_core.organizations(id,legal_name,organization_type,status) values('92000000-0000-0000-0000-000000000001','Test GrillaD','retail','active');
update famille_core.applications set status='active' where code in ('grillad','zipple');
insert into famille_core.organization_apps(organization_id,app_id,status) select '92000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.locations(id,organization_id,name) values ('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','A'),('93000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','B');
insert into famille_core.locations(id,organization_id,name) values ('93000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','Other app');
insert into grillad_private.enabled_sites(org,site) values ('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001'),('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002');
insert into famille_core.client_app_access(user_id,app_id,status) select u.id,a.id,'granted' from auth.users u cross join famille_core.applications a where a.code='grillad';
insert into famille_core.memberships(user_id,organization_id,app_id,status) select u.id,'92000000-0000-0000-0000-000000000001',a.id,'active' from auth.users u cross join famille_core.applications a where a.code='grillad';
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select id,app_id,organization_id,case when user_id='91000000-0000-0000-0000-000000000001' then 'owner' when user_id='91000000-0000-0000-0000-000000000003' then 'manager' else 'seller' end,case when user_id<>'91000000-0000-0000-0000-000000000001' then '93000000-0000-0000-0000-000000000001'::uuid else null end from famille_core.memberships;
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select '92000000-0000-0000-0000-000000000001',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad_premium_month';
select set_config('grillad.test.app',(select id::text from famille_core.applications where code='grillad'),false);
select set_config('grillad.test.other',(select id::text from famille_core.applications where code='zipple'),false);
set role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',false);
select set_config('request.jwt.claims',jsonb_build_object('session_id','91000000-0000-0000-0000-000000000011','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,false);

-- REC-01/02/03/11/23/24/26/33: independent disposable database, committed fixtures for concurrent sessions.
do $test$ declare o uuid:='92000000-0000-0000-0000-000000000001';a uuid:='93000000-0000-0000-0000-000000000001';b uuid:='93000000-0000-0000-0000-000000000002';f text;i uuid;v jsonb;d date:=(now() at time zone 'Africa/Douala')::date;
begin
 perform public.grillad_action(o,a,gen_random_uuid(),'open_cash','{"opening":100}');
 perform public.grillad_action(o,b,gen_random_uuid(),'open_cash','{"opening":200}');
 foreach f in array array['Porc','Poulet','Poisson','Brochettes','Omelettes'] loop
  i:=gen_random_uuid();
  perform public.grillad_action(o,a,i,'add_item',jsonb_build_object('name',f,'family',f,'price',1000,'cost',400));
  perform public.grillad_action(o,a,gen_random_uuid(),'prepare',jsonb_build_object('item',i,'qty',3));
  v:=public.grillad_action(o,a,gen_random_uuid(),'sell',jsonb_build_object('item',i,'qty',1,'price',1000,'received',1000));
  if (v->>'remaining')::int<>2 then raise exception 'REC-03/33 remaining %',f;end if;
 end loop;
 begin
  perform public.grillad_action(o,a,gen_random_uuid(),'add_item','{"name":"Invalid","family":"Boeuf","price":1000}');
  raise exception 'REC-02 invalid family accepted';
 exception when check_violation or invalid_parameter_value then null;end;
 i:='94000000-0000-0000-0000-000000000099';
 perform public.grillad_action(o,a,i,'add_item','{"name":"Concurrent","family":"Poulet","price":1000,"cost":400}');
 perform public.grillad_action(o,a,gen_random_uuid(),'prepare',jsonb_build_object('item',i,'qty',7));
 i:=gen_random_uuid();
 perform public.grillad_action(o,b,i,'add_item','{"name":"B only","family":"Poisson","price":500,"cost":200}');
 perform public.grillad_action(o,b,gen_random_uuid(),'prepare',jsonb_build_object('item',i,'qty',2));
 perform public.grillad_action(o,b,gen_random_uuid(),'sell',jsonb_build_object('item',i,'qty',1,'price',500,'received',500));
 v:=public.grillad_snapshot(o,b,d,d);
 if (v#>>'{finance,ca}')::int<>500 or jsonb_array_length(v->'items')<>1 then raise exception 'REC-20 site B';end if;
end $test$;
reset role;
