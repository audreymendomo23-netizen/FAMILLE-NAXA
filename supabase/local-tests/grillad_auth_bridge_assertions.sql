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
 begin perform public.grillad_action(o,s,gen_random_uuid(),'sell',jsonb_build_object('item',i,'qty',4,'price',1000,'received',4000));raise exception 'reserved stock leak';exception when invalid_parameter_value then null;end;
 perform public.grillad_connect_transition(o,s,p,gen_random_uuid(),'preparing',null,null);
 perform public.grillad_connect_transition(o,s,p,gen_random_uuid(),'ready',null,null);
 perform public.grillad_connect_transition(o,s,p,e,'handed',2000,null);
 perform public.grillad_connect_transition(o,s,p,e,'handed',2000,null);
 v:=public.grillad_snapshot(o,s,d,d);
 if (v#>>'{finance,connect_ca}')::int<>2000 or (v#>>'{finance,ca}')::int<>2000 or (v->'items'->0->>'remaining')::int<>3 then raise exception 'connect accounting';end if;
 if public.grillad_connect_list(o,s)->'links'->0->'items'->>0<>i::text then raise exception 'connect catalog owner';end if;
 perform public.grillad_action(o,s,gen_random_uuid(),'connect_item_set',jsonb_build_object('link','b5000000-0000-0000-0000-000000000001','item',i,'enabled',false,'reason','Test retrait'));
 if jsonb_array_length(public.grillad_connect_list(o,s)->'links'->0->'items')<>0 then raise exception 'catalog withdrawal';end if;
 perform public.grillad_action(o,s,gen_random_uuid(),'connect_item_set',jsonb_build_object('link','b5000000-0000-0000-0000-000000000001','item',i,'enabled',true,'reason','Test retour'));
 perform public.grillad_action(o,s,gen_random_uuid(),'connect_link_set','{"link":"b5000000-0000-0000-0000-000000000001","enabled":false,"reason":"Test pause"}');
 if (public.grillad_connect_list(o,s)->>'available')::boolean then raise exception 'link pause';end if;
 perform public.grillad_action(o,s,gen_random_uuid(),'connect_link_set','{"link":"b5000000-0000-0000-0000-000000000001","enabled":true,"reason":"Test retour"}');
 if not(public.grillad_connect_list(o,s)->>'available')::boolean then raise exception 'link restart';end if;
end $$;
reset role;
-- Network report and surveillance, explicit independent default.
set role authenticated;
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';d date:=(now() at time zone 'Africa/Douala')::date;v jsonb;
begin
 v:=public.grillad_report(o,s,d,d,false,null,null,null);
 if (v->>'ca')::int<>2000 or (v->>'connect_ca')::int<>2000 or (v->>'encaissements')::int<>2000 or (v->>'sales_count')::int<>1 then raise exception 'report accounting';end if;
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
 v:=public.grillad_action(o,s,gen_random_uuid(),'schedule_service_hours',jsonb_build_object('start_minute',1200,'effective_from',today+2,'reason','Horaire futur'));
 if not(v->>'scheduled')::boolean or (public.grillad_pilotage_status(o,s)#>>'{service,start_minute}')::int<>1080 or jsonb_array_length(public.grillad_pilotage_status(o,s)->'service_revisions')<>1 then raise exception 'future schedule';end if;
 begin perform public.grillad_action(o,s,gen_random_uuid(),'schedule_service_hours',jsonb_build_object('start_minute',0,'effective_from',today,'reason','Rewrite'));raise exception 'retroactive schedule';exception when invalid_parameter_value then null;end;
 e:=gen_random_uuid();p:='{"phone":"+237699000009","name":"Collaborateur test","role":"seller"}';v:=public.grillad_action(o,s,e,'employee_request',p);
 if v->>'status'<>'pending' or public.grillad_action(o,s,e,'employee_request',p)<>v then raise exception 'employee request replay';end if;
 begin perform public.grillad_action(o,s,gen_random_uuid(),'employee_request',p);raise exception 'duplicate employee request';exception when invalid_parameter_value then null;end;
 v:=public.grillad_action(o,s,gen_random_uuid(),'renewal_request','{"plan":"grillad_premium_year"}');
 if v->>'status'<>'pending' or not exists(select 1 from jsonb_array_elements(public.grillad_pilotage_status(o,s)->'central_requests') x where x->>'kind'='renewal' and (x->>'amount')::int=60000) then raise exception 'renewal quote';end if;
 begin perform public.grillad_central_queue(10);raise exception 'central queue leaked';exception when insufficient_privilege then null;end;
 perform public.grillad_action(o,s,gen_random_uuid(),'central_request_cancel',jsonb_build_object('request',e,'reason','Annulé'));
end $$;
reset role;
set role authenticated;
do $$
declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';d date:=(now() at time zone 'Africa/Douala')::date;
begin if (public.grillad_report(o,s,d,d,true,null,null,null)->>'ca')::int<>2000 then raise exception 'network total';end if;end $$;
reset role;
-- Central resolution must match real payment evidence and cannot be set by a client.
set role service_role;
do $$declare q uuid;begin select (x->>'id')::uuid into q from jsonb_array_elements(public.grillad_central_queue(20)) x where x->>'kind'='renewal';if q is null then raise exception 'missing renewal request';end if;
 begin perform public.grillad_central_resolve(q,'processed',gen_random_uuid()::text);raise exception 'fake payment proof accepted';exception when invalid_parameter_value then null;end;
end $$;
reset role;
-- Isolated proof fixture, not a real payment or activation.
insert into famille_core.payment_intents(id,subscription_id,expected_amount_fcfa,channel,status)
 select 'b8000000-0000-0000-0000-000000000001',id,60000,'fixture','matched' from famille_core.subscriptions where organization_id='b2000000-0000-0000-0000-000000000001';
insert into famille_core.payment_matches(id,payment_intent_id,provider,transaction_reference,amount_fcfa,verified_at,status)
 values('b8000000-0000-0000-0000-000000000002','b8000000-0000-0000-0000-000000000001','fixture','GRILLAD-TEST-1',59999,now(),'confirmed');
update famille_core.subscriptions set plan_id=(select id from famille_core.plans where code='grillad_premium_year'),ends_at=now()+interval '1 year' where organization_id='b2000000-0000-0000-0000-000000000001';
set role service_role;
do $$declare q uuid;begin select (x->>'id')::uuid into q from jsonb_array_elements(public.grillad_central_queue(20)) x where x->>'kind'='renewal';
 begin perform public.grillad_central_resolve(q,'processed','b8000000-0000-0000-0000-000000000002');raise exception 'wrong amount accepted';exception when invalid_parameter_value then null;end;
end $$;
reset role;
update famille_core.payment_matches set amount_fcfa=60000 where id='b8000000-0000-0000-0000-000000000002';
set role service_role;
do $$declare q uuid;begin select (x->>'id')::uuid into q from jsonb_array_elements(public.grillad_central_queue(20)) x where x->>'kind'='renewal';
 if not public.grillad_central_resolve(q,'processed','b8000000-0000-0000-0000-000000000002') or not public.grillad_central_resolve(q,'processed','b8000000-0000-0000-0000-000000000002') then raise exception 'central payment proof or replay';end if;
end $$;
reset role;
-- Restore fixture plan so expiry notice and existing test cases stay applicable.
update famille_core.subscriptions set plan_id=(select id from famille_core.plans where code='grillad_premium_month'),ends_at=now()+interval '1 day' where organization_id='b2000000-0000-0000-0000-000000000001';
-- Test-only auth stub lacks phone; this adds the real field only within the rollback fixture.
alter table auth.users add column if not exists phone text;
update auth.users set phone='+237699000009' where id='b1000000-0000-0000-0000-000000000002';
set role authenticated;
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';e uuid:='b8000000-0000-0000-0000-000000000003';begin
 perform public.grillad_action(o,s,e,'employee_request','{"phone":"+237699000009","name":"Collaborateur test","role":"seller"}');
end $$;
reset role;
insert into famille_private.account_invites(id,request_id,user_id,token_hash,app_code,account_kind,organization_id,location_id,role_code,status,created_by,expires_at,accepted_at,accepted_by)
 values('b8000000-0000-0000-0000-000000000004','b8000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000002',decode(repeat('a1',32),'hex'),'grillad','employee','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','seller','accepted','b1000000-0000-0000-0000-000000000001',now()+interval '1 day',now(),'b1000000-0000-0000-0000-000000000002');
set role service_role;
do $$begin if not public.grillad_central_resolve('b8000000-0000-0000-0000-000000000003','processed','b8000000-0000-0000-0000-000000000004') then raise exception 'accepted employee evidence';end if;end $$;
reset role;
-- Expired subscription grants billing only; no access to transactions.
update famille_core.subscriptions set status='expired',ends_at=now()-interval '1 hour' where organization_id='b2000000-0000-0000-0000-000000000001';
set role authenticated;
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';e uuid:=gen_random_uuid();p jsonb:='{"plan":"grillad_premium_month"}';v jsonb;begin
 if jsonb_array_length(public.grillad_workspace())<>0 or jsonb_array_length(public.grillad_renewal_workspace())<>1 then raise exception 'expired scope separation';end if;
 begin perform public.grillad_snapshot(o,s,current_date,current_date);raise exception 'expired snapshot';exception when insufficient_privilege then null;end;
 v:=public.grillad_renewal_action(o,s,e,'renewal_request',p);if v->>'status'<>'pending' or public.grillad_renewal_action(o,s,e,'renewal_request',p)<>v then raise exception 'renewal only replay';end if;
 if not exists(select 1 from jsonb_array_elements(public.grillad_renewal_status(o,s)->'central_requests') x where x->>'id'=e::text and x->>'status'='pending') then raise exception 'renewal only status';end if;
 perform public.grillad_renewal_action(o,s,gen_random_uuid(),'central_request_cancel',jsonb_build_object('request',e,'reason','Annulation'));
end $$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin if jsonb_array_length(public.grillad_renewal_workspace())<>0 then raise exception 'seller renewal leak';end if;end $$;
reset role;
update famille_core.subscriptions set status='active',ends_at=now()+interval '1 day' where organization_id='b2000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
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
-- Pause a second point without changing shared location or losing data.
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';a uuid:='b3000000-0000-0000-0000-000000000001';b uuid:='b3000000-0000-0000-0000-000000000003';e uuid:=gen_random_uuid();v jsonb;p jsonb:=jsonb_build_object('site',b,'enabled',false,'reason','Pause');d date:=(now() at time zone 'Africa/Douala')::date;
begin
 perform public.grillad_action(o,b,gen_random_uuid(),'open_cash','{"opening":0}');
 begin perform public.grillad_action(o,a,e,'set_site_enabled',p);raise exception 'site with open cash suspended';exception when invalid_parameter_value then null;end;
 perform public.grillad_action(o,b,gen_random_uuid(),'close_cash','{"counted":0}');
 v:=public.grillad_action(o,a,e,'set_site_enabled',p);
 if (v->>'enabled')::boolean or public.grillad_action(o,a,e,'set_site_enabled',p)<>v or jsonb_array_length(public.grillad_workspace())<>1 then raise exception 'site suspension replay';end if;
 begin perform public.grillad_snapshot(o,b,d,d);raise exception 'suspended access';exception when insufficient_privilege then null;end;
 if not exists(select 1 from jsonb_array_elements(public.grillad_pilotage_status(o,a)->'site_directory') x where x->>'site'=b::text and not(x->>'enabled')::boolean) then raise exception 'suspended directory';end if;
 if not exists(select 1 from jsonb_array_elements(public.grillad_report(o,a,d,d,true,null,null,null)->'sites') x where x->>'site'=b::text and not(x->>'enabled')::boolean) then raise exception 'suspended historical site report';end if;
 perform public.grillad_action(o,a,gen_random_uuid(),'set_site_enabled',jsonb_build_object('site',b,'enabled',true,'reason','Reprise'));
 if jsonb_array_length(public.grillad_workspace())<>2 or jsonb_array_length(public.grillad_snapshot(o,b,d,d)->'cash_history')<>1 then raise exception 'reactivation/history';end if;
end $$;
reset role;
-- Service across midnight, using an explicit fixture policy only.
-- Fixture backdating only to exercise historical summaries; not available via API.
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';d date:=(now() at time zone 'Africa/Douala')::date;begin if grillad_private.service_boundary(o,s,d+2)-grillad_private.service_boundary(o,s,d+1)<>interval '26 hours' then raise exception 'non contiguous schedule boundary';end if;end $$;
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
 if not((v->0->'data')?'provisional') or not((v->0->'data')?'operating_result') then raise exception 'daily financial completeness';end if;
 v:=public.grillad_prediction(o,s);if not(v?'families') or not(v?'current_service') or v->'current_service'->'projection'<>'null'::jsonb then raise exception 'insufficient current forecast';end if;
 if v->'ca_estimate'<>'null'::jsonb or v->'items'->0->>'quality'<>'insufficient' then raise exception 'insufficient forecast must be explicit';end if;
 v:=public.grillad_notice_feed(o,s);if not exists(select 1 from jsonb_array_elements(v->'items') x where x->>'category'='connect') then raise exception 'connect notification missing';end if;
 if (select count(*) from jsonb_array_elements(v->'items') x where x->>'category'='connect')<>(select count(distinct x->>'id') from jsonb_array_elements(v->'items') x where x->>'category'='connect') then raise exception 'duplicate connect notices';end if;
 select x->>'id' into notice from jsonb_array_elements(v->'items') x where x->>'category'='daily' limit 1;
 if notice is null then raise exception 'missing notice';end if;
 perform public.grillad_notice_ack(o,s,notice);perform public.grillad_notice_ack(o,s,notice);
 v:=public.grillad_notice_feed(o,s);if not exists(select 1 from jsonb_array_elements(v->'items') x where x->>'id'=notice and (x->>'read')::boolean) then raise exception 'notice read';end if;
 perform public.grillad_notice_set(o,s,'target',false);perform public.grillad_notice_set(o,s,'subscription',false);
 perform public.grillad_notice_set(o,s,'daily',false);
 if exists(select 1 from jsonb_array_elements(public.grillad_notice_feed(o,s)->'items') x where x->>'category'='daily') then raise exception 'notice preference';end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin
 if jsonb_array_length(public.grillad_workspace())<>1 then raise exception 'bound session failed';end if;
 if exists(select 1 from jsonb_array_elements(public.grillad_notice_feed('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001')->'items') x where x->>'category' in ('connect','security')) then raise exception 'seller partner notice leak';end if;
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
