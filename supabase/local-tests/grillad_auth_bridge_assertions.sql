\set ON_ERROR_STOP on
begin;
-- Synthetic actors: owner plus three distinct sellers on one point.
insert into auth.users(id,email) select ('b1000000-0000-0000-0000-00000000000'||n)::uuid,'grillad-'||n||'@x.invalid' from generate_series(1,4) n;
insert into auth.sessions(id,user_id) select ('b1000000-0000-0000-0000-00000000001'||n)::uuid,id from auth.users cross join lateral (select right(id::text,1) n) q where id::text like 'b1000000%';
insert into famille_core.organizations(id,legal_name,organization_type,status) values('b2000000-0000-0000-0000-000000000001','Test','retail','active');
update famille_core.applications set status='active' where code='grillad';
insert into famille_core.organization_apps(organization_id,app_id,status) select 'b2000000-0000-0000-0000-000000000001',id,'active' from famille_core.applications where code='grillad';
insert into famille_core.locations(id,organization_id,name) values ('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','Test');
insert into grillad_private.enabled_sites(org,site) values ('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001');
insert into famille_core.client_app_access(user_id,app_id,status) select u.id,a.id,'granted' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.id::text like 'b1000000%';
insert into famille_core.memberships(user_id,organization_id,app_id,status) select u.id,'b2000000-0000-0000-0000-000000000001',a.id,'active' from auth.users u cross join famille_core.applications a where a.code='grillad' and u.id::text like 'b1000000%';
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id) select id,app_id,organization_id,case when user_id='b1000000-0000-0000-0000-000000000001' then 'owner' else 'seller' end,case when user_id='b1000000-0000-0000-0000-000000000001' then null else 'b3000000-0000-0000-0000-000000000001'::uuid end from famille_core.memberships;
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select 'b2000000-0000-0000-0000-000000000001',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='grillad_access_month';
insert into famille_private.account_app_access(user_id,app_code,account_kind,organization_id,location_id,role_code)
select m.user_id,'grillad','professional',m.organization_id,r.location_id,r.role_code from famille_core.memberships m join famille_core.role_assignments r on r.membership_id=m.id;
set role service_role;
do $$
declare n int;u uuid;s uuid;installation uuid;h text;
begin
 for n in 1..4 loop
  u:=('b1000000-0000-0000-0000-00000000000'||n)::uuid;s:=('b1000000-0000-0000-0000-00000000001'||n)::uuid;installation:=('b4000000-0000-0000-0000-00000000000'||n)::uuid;h:=repeat(n::text,64);
  if not public.grillad_auth_begin(h,false) or not public.grillad_auth_finish(h,u,s,installation,'android') then raise exception 'login %',n;end if;
 end loop;
 for n in 1..5 loop if not public.grillad_auth_begin(repeat('a',64),false) then raise exception 'early throttle';end if;end loop;
 if public.grillad_auth_begin(repeat('a',64),false) then raise exception 'expected throttle';end if;
end $$;
reset role;
do $$begin if (select count(*) from famille_private.account_devices where app_code='grillad' and status='active')<>4 then raise exception 'cross seller eviction';end if;end $$;
-- Explicit bilateral fake fixture only.
update famille_core.applications set status='active' where code='zipple';
insert into famille_core.organizations(id,legal_name,organization_type,status) values('b2000000-0000-0000-0000-000000000002','Test ZIPPLE','retail','active');
insert into famille_core.organization_apps(organization_id,app_id,status) select 'b2000000-0000-0000-0000-000000000002',id,'active' from famille_core.applications where code='zipple';
insert into famille_core.locations(id,organization_id,name) values('b3000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002','Snack test');
insert into famille_core.plans(app_id,code,name,amount_fcfa,billing_period) select id,'zipple-fixture','Test only',1,'monthly' from famille_core.applications where code='zipple';
insert into famille_core.subscriptions(organization_id,app_id,plan_id,status,starts_at,ends_at) select 'b2000000-0000-0000-0000-000000000002',app_id,id,'active',now()-interval '1 day',now()+interval '1 day' from famille_core.plans where code='zipple-fixture';
update famille_core.subscriptions set plan_id=(select id from famille_core.plans where code='grillad_premium_month') where organization_id='b2000000-0000-0000-0000-000000000001';
insert into grillad_private.connect_links(id,org,site,zipple_org,zipple_site,token_hash,enabled,grillad_approved,zipple_approved,expires_at) values('b5000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000002','b3000000-0000-0000-0000-000000000002',repeat('f',64),true,true,true,now()+interval '1 day');
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';i uuid:='b6000000-0000-0000-0000-000000000001';
begin
 perform public.grillad_action(o,s,i,'add_item','{"name":"Poulet","family":"Poulet","price":1000,"cost":400}');
 perform public.grillad_action(o,s,gen_random_uuid(),'prepare',jsonb_build_object('item',i,'qty',5));
 perform public.grillad_action(o,s,gen_random_uuid(),'open_cash','{"opening":0}');
end $$;
reset role;
insert into grillad_private.connect_catalog values('b5000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000001');
set role service_role;
do $$
declare v jsonb;p uuid:='b7000000-0000-0000-0000-000000000001';line jsonb:='[{"item":"b6000000-0000-0000-0000-000000000001","qty":2}]';
begin
 v:=public.grillad_connect_catalog(repeat('f',64));if (v->'items'->0)?'cost' or (v->'items'->0)?'remaining' then raise exception 'catalog leak';end if;
 perform public.grillad_connect_submit(repeat('f',64),p,line);perform public.grillad_connect_submit(repeat('f',64),p,line);
 if (public.grillad_connect_status(repeat('f',64),p)->>'status')<>'submitted' then raise exception 'order';end if;
end $$;
reset role;
set role authenticated;
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';i uuid:='b6000000-0000-0000-0000-000000000001';p uuid:='b7000000-0000-0000-0000-000000000001';e uuid:=gen_random_uuid();d date:=(now() at time zone 'Africa/Douala')::date;v jsonb;
begin
 perform public.grillad_connect_transition(o,s,p,gen_random_uuid(),'accepted',null,null);
 begin perform public.grillad_action(o,s,gen_random_uuid(),'sell',jsonb_build_object('item',i,'qty',4));raise exception 'reserved stock leak';exception when invalid_parameter_value then null;end;
 perform public.grillad_connect_transition(o,s,p,gen_random_uuid(),'preparing',null,null);
 perform public.grillad_connect_transition(o,s,p,gen_random_uuid(),'ready',null,null);
 perform public.grillad_connect_transition(o,s,p,e,'handed',2000,null);
 perform public.grillad_connect_transition(o,s,p,e,'handed',2000,null);
 v:=public.grillad_snapshot(o,s,d,d);
 if (v#>>'{finance,connect_ca}')::int<>2000 or (v#>>'{finance,ca}')::int<>2000 or (v->'items'->0->>'remaining')::int<>3 then raise exception 'connect accounting';end if;
end $$;
reset role;
-- Network report and surveillance, explicit independent default.
set role authenticated;
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';d date:=(now() at time zone 'Africa/Douala')::date;v jsonb;
begin
 v:=public.grillad_report(o,s,d,d,false,null,null,null);
 if (v->>'ca')::int<>2000 or (v->>'connect_ca')::int<>2000 or (v->>'sales_count')::int<>1 then raise exception 'report accounting';end if;
 v:=public.grillad_report(o,s,d,d,false,'Poulet',null,null);
 if (v->>'ca')::int<>2000 or v->'expenses'<>'null'::jsonb then raise exception 'report filtered expense allocation';end if;
 begin perform public.grillad_report(o,s,d,d,true,null,null,null);raise exception 'network must be explicit';exception when insufficient_privilege then null;end;
 if (public.grillad_security_list(o,s)->>'available')::boolean then raise exception 'unlinked camera available';end if;
end $$;
reset role;
set role authenticated;
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';e uuid:=gen_random_uuid();p jsonb:='{"centralized":true,"reason":"Test configuration"}';v jsonb;today date:=(now() at time zone 'Africa/Douala')::date;
begin
 v:=public.grillad_action(o,s,e,'set_network_mode',p);
 if not(v->>'centralized')::boolean or public.grillad_action(o,s,e,'set_network_mode',p)<>v then raise exception 'network mode replay';end if;
 perform public.grillad_action(o,s,gen_random_uuid(),'set_service_hours',jsonb_build_object('start_minute',1080,'effective_from',today,'reason','Test configuration'));
 if (public.grillad_pilotage_status(o,s)#>>'{service,start_minute}')::int<>1080 then raise exception 'service configuration';end if;
 begin perform public.grillad_action(o,s,gen_random_uuid(),'set_service_hours',jsonb_build_object('start_minute',0,'effective_from',today,'reason','Rewrite'));raise exception 'retroactive service rewrite';exception when invalid_parameter_value then null;end;
end $$;
reset role;
set role authenticated;
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';d date:=(now() at time zone 'Africa/Douala')::date;
begin if (public.grillad_report(o,s,d,d,true,null,null,null)->>'ca')::int<>2000 then raise exception 'network total';end if;end $$;
reset role;
-- Existing activated seller assignment to a second GRILLAD site, then revocation.
set role authenticated;
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';s2 uuid:='b3000000-0000-0000-0000-000000000003';u uuid:='b1000000-0000-0000-0000-000000000002';e uuid:=gen_random_uuid();p jsonb:=jsonb_build_object('user',u,'role','seller','reason','Renfort');v jsonb;
begin
 perform public.grillad_action(o,s,s2,'create_site','{"name":"Second GRILLAD","reason":"Extension"}');
 if not exists(select 1 from jsonb_array_elements(public.grillad_pilotage_status(o,s2)->'team_candidates') x where x->>'id'=u::text and x->>'role'='none') then raise exception 'candidate roster';end if;
 v:=public.grillad_action(o,s2,e,'set_team_assignment',p);
 if v->>'role'<>'seller' or public.grillad_action(o,s2,e,'set_team_assignment',p)<>v then raise exception 'assignment replay';end if;
 begin perform public.grillad_action(o,s2,gen_random_uuid(),'set_team_assignment',jsonb_build_object('user',gen_random_uuid(),'role','manager','reason','Test'));raise exception 'external user assigned';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin if jsonb_array_length(public.grillad_workspace())<>2 then raise exception 'second site access';end if;
 begin perform public.grillad_action('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000003',gen_random_uuid(),'set_team_assignment','{"user":"b1000000-0000-0000-0000-000000000003","role":"manager","reason":"Test"}');raise exception 'seller assignment';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
do $$begin perform public.grillad_action('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000003',gen_random_uuid(),'set_team_assignment','{"user":"b1000000-0000-0000-0000-000000000002","role":"none","reason":"Fin renfort"}');end $$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin if jsonb_array_length(public.grillad_workspace())<>1 then raise exception 'assignment revocation';end if;
 begin perform public.grillad_snapshot('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000003',current_date,current_date);raise exception 'revoked access';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Service across midnight, using an explicit fixture policy only.
-- Fixture backdating only to exercise historical summaries; not available via API.
update grillad_private.service_policy set effective_from=current_date-2 where org='b2000000-0000-0000-0000-000000000001' and site='b3000000-0000-0000-0000-000000000001';
set role service_role;
do $$begin
 if (public.grillad_daily_tick(100)->>'changed')::int<1 then raise exception 'daily first run';end if;
 if (public.grillad_daily_tick(100)->>'changed')::int<>0 then raise exception 'daily duplicate';end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';v jsonb;notice text;
begin
 v:=public.grillad_daily_list(o,s);if jsonb_array_length(v)<1 then raise exception 'missing daily';end if;
 v:=public.grillad_prediction(o,s);if v->'ca_estimate'<>'null'::jsonb or v->'items'->0->>'quality'<>'insufficient' then raise exception 'insufficient forecast must be explicit';end if;
 v:=public.grillad_notice_feed(o,s);select x->>'id' into notice from jsonb_array_elements(v->'items') x where x->>'category'='daily' limit 1;
 if notice is null then raise exception 'missing notice';end if;
 perform public.grillad_notice_ack(o,s,notice);perform public.grillad_notice_ack(o,s,notice);
 v:=public.grillad_notice_feed(o,s);if not exists(select 1 from jsonb_array_elements(v->'items') x where x->>'id'=notice and (x->>'read')::boolean) then raise exception 'notice read';end if;
 perform public.grillad_notice_set(o,s,'daily',false);
 if exists(select 1 from jsonb_array_elements(public.grillad_notice_feed(o,s)->'items') x where x->>'category'='daily') then raise exception 'notice preference';end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin
 if jsonb_array_length(public.grillad_workspace())<>1 then raise exception 'bound session failed';end if;
 if not (public.grillad_push_register('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001',repeat('t',64),'grillad-fixture',true)->>'registered')::boolean then raise exception 'push register';end if;
 begin perform count(*) from grillad_private.push_devices;raise exception 'token table leak';exception when insufficient_privilege then null;end;
 if (public.grillad_push_register('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001',null,null,false)->>'registered')::boolean then raise exception 'push disable';end if;
 begin perform public.grillad_security_list('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001');raise exception 'seller camera leak';exception when insufficient_privilege then null;end;
 begin perform public.grillad_action('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001',gen_random_uuid(),'set_network_mode','{"centralized":false,"reason":"Test"}');raise exception 'seller network change';exception when insufficient_privilege then null;end;
 begin perform public.grillad_report('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001',current_date,current_date,false,null,null,null);raise exception 'seller report leak';exception when insufficient_privilege then null;end;
 begin perform public.grillad_daily_list('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001');raise exception 'seller daily leak';exception when insufficient_privilege then null;end;
 begin perform public.grillad_auth_begin(repeat('b',64),false);raise exception 'service-only auth bridge leaked';exception when insufficient_privilege then null;end;
end $$;
reset role;
update famille_private.account_devices set status='revoked',revoked_at=now() where user_id='b1000000-0000-0000-0000-000000000002';
set role authenticated;
do $$begin
 begin perform public.grillad_workspace();raise exception 'revocation failed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
