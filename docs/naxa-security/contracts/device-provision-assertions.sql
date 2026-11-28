begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000371'),('00000000-0000-0000-0000-000000000372');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000371','QA provision');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000371','00000000-0000-0000-0000-000000000371','owner',true),('10000000-0000-0000-0000-000000000371','00000000-0000-0000-0000-000000000372','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000371','10000000-0000-0000-0000-000000000371','QA'),('20000000-0000-0000-0000-000000000372','10000000-0000-0000-0000-000000000371','other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000371','20000000-0000-0000-0000-000000000371','00000000-0000-0000-0000-000000000371',true),('10000000-0000-0000-0000-000000000371','20000000-0000-0000-0000-000000000371','00000000-0000-0000-0000-000000000372',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000371',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000371';s uuid:='20000000-0000-0000-0000-000000000371';g uuid:='40000000-0000-0000-0000-000000000371';d uuid:='40000000-0000-0000-0000-000000000372';e uuid:=gen_random_uuid();v jsonb;j jsonb;begin
 j:='{"label":"QA gateway","kind":"gateway","manufacturer":"QA","model":"G1","firmware":"1","reference":"G1"}';v:=public.sec_device_provision(o,s,g,'register',j);if v<>public.sec_device_provision(o,s,g,'register',j) then raise exception 'duplicate registration';end if;
 perform public.sec_device_provision(o,s,d,'register','{"label":"QA sensor","kind":"environment","manufacturer":"QA","model":"S1","firmware":"1","reference":"S1"}');
 v:=public.sec_device_provision(o,s,e,'bind',jsonb_build_object('gateway_id',g,'device_id',d));if v->>'state'<>'bound' then raise exception 'bind';end if;
 v:=public.sec_device_inventory(o,s);if jsonb_array_length(v->'devices')<>2 or v->'devices'->1->'bindings'->0->>'enabled'<>'true' then raise exception 'inventory';end if;
 begin perform public.sec_device_provision(o,'20000000-0000-0000-0000-000000000372',gen_random_uuid(),'bind',jsonb_build_object('gateway_id',g,'device_id',d));raise exception 'cross site';exception when insufficient_privilege then null;end;
end $q$;
reset role;set local role sec_gateway_ingest;
select sec_private.ingest_observation('40000000-0000-0000-0000-000000000371','10000000-0000-0000-0000-000000000371','20000000-0000-0000-0000-000000000371','40000000-0000-0000-0000-000000000372',gen_random_uuid(),now(),'online',null,null);
reset role;set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000372',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000371';s uuid:='20000000-0000-0000-0000-000000000371';begin
 if public.sec_device_inventory(o,s)->>'can_provision'<>'false' then raise exception 'manager permission';end if;
 begin perform public.sec_device_provision(o,s,gen_random_uuid(),'revoke','{"gateway_id":"40000000-0000-0000-0000-000000000371","device_id":"40000000-0000-0000-0000-000000000372"}');raise exception 'manager revoked';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000371',true);
select public.sec_device_provision('10000000-0000-0000-0000-000000000371','20000000-0000-0000-0000-000000000371',gen_random_uuid(),'revoke','{"gateway_id":"40000000-0000-0000-0000-000000000371","device_id":"40000000-0000-0000-0000-000000000372"}');
reset role;set local role sec_gateway_ingest;
do $q$begin begin perform sec_private.ingest_observation('40000000-0000-0000-0000-000000000371','10000000-0000-0000-0000-000000000371','20000000-0000-0000-0000-000000000371','40000000-0000-0000-0000-000000000372',gen_random_uuid(),now(),'online',null,null);raise exception 'revoked ingress';exception when insufficient_privilege then null;end;end $q$;
reset role;rollback;
