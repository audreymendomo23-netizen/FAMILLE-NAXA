begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000341'),('00000000-0000-0000-0000-000000000342');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000341','QA tracker');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000341','00000000-0000-0000-0000-000000000341','manager',true),('10000000-0000-0000-0000-000000000341','00000000-0000-0000-0000-000000000342','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000341','10000000-0000-0000-0000-000000000341','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','00000000-0000-0000-0000-000000000341',true),('10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','00000000-0000-0000-0000-000000000342',true);
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000341','10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','QA gateway','gateway'),('40000000-0000-0000-0000-000000000342','10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','QA tracker','tracker');
insert into sec_private.gateway_bindings values ('40000000-0000-0000-0000-000000000341','10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','40000000-0000-0000-0000-000000000342',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000341',true);
select public.sec_tracker_manage('10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','40000000-0000-0000-0000-000000000342','QA vehicle',true);
select public.sec_create_geofence('10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341',gen_random_uuid(),'QA zone',4,9,100);
reset role;set local role sec_gateway_ingest;
do $q$declare g uuid:='40000000-0000-0000-0000-000000000341';d uuid:='40000000-0000-0000-0000-000000000342';o uuid:='10000000-0000-0000-0000-000000000341';s uuid:='20000000-0000-0000-0000-000000000341';e uuid:=gen_random_uuid();v jsonb;begin
 v:=sec_private.ingest_asset_position(g,o,s,d,e,now(),4,9,10);
 if v<>sec_private.ingest_asset_position(g,o,s,d,e,now(),4,9,10) then raise exception 'replay';end if;
 begin perform sec_private.ingest_asset_position(g,o,s,d,e,now(),4,10,10);raise exception 'conflict';exception when unique_violation then null;end;
 for i in 1..100 loop perform sec_private.ingest_asset_position(g,o,s,d,gen_random_uuid(),now()-interval '5 seconds',4,9,10);end loop;
end $q$;
reset role;set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000341',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000341';s uuid:='20000000-0000-0000-0000-000000000341';d uuid:='40000000-0000-0000-0000-000000000342';v jsonb;w jsonb;begin
 v:=public.sec_tracker_history(o,s,d);if jsonb_array_length(v->'rows')<>100 or v->'zones'->0->>'assessment'<>'inside' then raise exception 'history/zone';end if;
 w:=public.sec_tracker_history(o,s,d,(v->'next'->>'before')::timestamptz,(v->'next'->>'before_id')::uuid);
 if jsonb_array_length(w->'rows')<>1 or w->'next'<>'null'::jsonb then raise exception 'pagination';end if;
 perform public.sec_tracker_manage(o,s,d,'QA vehicle',false);
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000342',true);
do $q$begin
 if exists(select 1 from public.sec_asset_positions) then raise exception 'operator data leak';end if;
 begin perform public.sec_tracker_history('10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','40000000-0000-0000-0000-000000000342');raise exception 'operator history';exception when insufficient_privilege then null;end;
end $q$;
reset role;set local role sec_gateway_ingest;
do $q$begin
 begin perform sec_private.ingest_asset_position('40000000-0000-0000-0000-000000000341','10000000-0000-0000-0000-000000000341','20000000-0000-0000-0000-000000000341','40000000-0000-0000-0000-000000000342',gen_random_uuid(),now(),4,9,10);raise exception 'disabled tracker';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
